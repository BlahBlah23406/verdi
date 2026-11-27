"""Synthetic Puget Sound pilot households. Clearly fictional data; no network, secrets or real credentials.

The Redmond 'Cedar Household' (UID redmond-demo) is seeded at startup; other city profiles from
regional_demo_profiles are seeded on first use (see RedmondDemo.user_for_household).

One simulated day elapses per `interval` seconds for each authorized source:
- utility: electricity kWh as daily totals, plus gas therms as separate monthly statements where combined
- gas: separate monthly natural gas statements (therms) for households with a separate gas utility (Tacoma)
- orca: synthetic tap-on events at public transit stops for the household's city (Redmond: 2 Line)
  (station, time, agency, fare only; no alighting, trip or distance is inferred)
- bank: transactions via the existing connectors.PlaidConnector, fed by an injected fake
  /transactions/sync transport (pagination, pending->posted replacement, mutation retry)
- vehicle: optional read-only Smartcar-style monotonic odometer (km) and EV battery (%) snapshots
  (Bellevue, Sammamish; no coordinates or commands)
- charger: optional read-only Enode-style home charging sessions (kWh) for Sammamish, marked
  supporting / overlapping the home utility meter and never added to totals

All state lives in dedicated redmond_* tables. Each source update runs in one
BEGIN IMMEDIATE transaction that re-reads the cursor, so concurrent or restarted
workers never apply the same simulated day twice. Records are inserted idempotently and
are never rewritten by disconnect/expire/re-authorize.
"""
import contextlib
import hashlib
import time
from datetime import date, timedelta

import regional_demo_profiles as profiles
from connectors import AuthRequired, PlaidConnector

UID = 'redmond-demo'
NAME = 'Cedar Household'
REGION = 'Redmond, WA (NWPP)'
SOURCES = ('utility', 'orca', 'bank')
ACTIVE = ('waiting', 'ok')
BASE_DAY = date(2026, 11, 2)  # simulated day 1 (a Monday)
SNAPSHOT_RECORDS = 6

# Public Sound Transit 2 Line stations serving Redmond / Overlake.
STATIONS = ('Downtown Redmond', 'Marymoor Village', 'Redmond Technology', 'Overlake Village')
AGENCY = 'Sound Transit'
FARE_CENTS = 300
MERCHANTS = (('Synthetic Grocer', 4823), ('Synthetic Cafe', 575), ('Synthetic Hardware', 2199),
             ('Synthetic Pharmacy', 1349), ('Synthetic Bakery', 860))

SCHEMA = '''
CREATE TABLE IF NOT EXISTS redmond_households(user TEXT PRIMARY KEY,name TEXT NOT NULL,region TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS redmond_sources(user TEXT,source TEXT,status TEXT NOT NULL,generation INTEGER NOT NULL DEFAULT 0,
  cursor TEXT NOT NULL DEFAULT '',sim_day INTEGER NOT NULL DEFAULT 0,last_success INTEGER,next_due INTEGER,
  failures INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(user,source));
CREATE TABLE IF NOT EXISTS redmond_records(user TEXT,source TEXT,id TEXT,sim_day INTEGER,seq INTEGER,kind TEXT,
  quantity REAL,unit TEXT,label TEXT,detail TEXT,pending INTEGER NOT NULL DEFAULT 0,state TEXT NOT NULL DEFAULT 'active',
  generation INTEGER,PRIMARY KEY(user,id));
CREATE INDEX IF NOT EXISTS redmond_records_source ON redmond_records(user,source,sim_day);
'''


def _iso(ts):
    return time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(ts)) if ts else None


def _h(*parts):
    return int(hashlib.sha256(':'.join(map(str, parts)).encode()).hexdigest()[:8], 16)


def sim_date(day):
    return (BASE_DAY + timedelta(days=day - 1)).isoformat()


def _ph(profile, *parts):
    # Redmond keeps the original unsalted sequence so existing households replay identically.
    return _h(*parts) if profile['id'] == 'redmond' else _h(profile['id'], *parts)


def utility_records(day, profile=profiles.BY_ID['redmond']):
    when = sim_date(day)
    base, spread = profile['utility']['kwh']
    kwh = round(base + _ph(profile, 'kwh', day) % spread / 10, 1)
    rows = [dict(id=f'utility:{when}:electricity', seq=0, kind='electricity', quantity=kwh, unit='kWh',
                 label=f'Electricity {kwh} kWh',
                 detail=f'Synthetic daily electricity total; service date {when}')]
    current = date.fromisoformat(when)
    if profile['utility']['therms'] and (day == 1 or current.day == 1):
        end = current.replace(day=1) - timedelta(days=1)
        start = end.replace(day=1)
        base, spread = profile['utility']['therms']
        therms = round(base + _ph(profile, 'therm', start) % spread / 10, 1)
        rows.append(dict(id=f'utility:{start}..{end}:gas', seq=1, kind='gas', quantity=therms, unit='therms',
                         label=f'Natural gas {therms} therms',
                         detail=f'Synthetic monthly gas statement; service period {start} to {end}'))
    return rows


def orca_records(day, profile=profiles.BY_ID['redmond']):
    when = date.fromisoformat(sim_date(day))
    if when.weekday() >= 5:
        return []
    t = profile['transit']
    taps = [(t['am'][_ph(profile, 'am', day) % len(t['am'])], f'07:{30 + _ph(profile, "amt", day) % 25:02d}'),
            (t['pm'][_ph(profile, 'pm', day) % len(t['pm'])], f'17:{10 + _ph(profile, "pmt", day) % 40:02d}')]
    fare = t['fare_cents']
    return [dict(id=f'orca:{when.isoformat()}:{n}', seq=n, kind='transit_tap', quantity=fare, unit='USD cents',
                 label=f'Tap at {stop}',
                 detail=f'Synthetic ORCA tap {when.isoformat()} {clock} PT; {t["agency"]} {t["line"]}; fare ${fare / 100:.2f}; '
                        'no alighting or distance inferred')
            for n, (stop, clock) in enumerate(taps)]


def gas_records(day, profile):
    gas = profile.get('gas')
    if not gas or not gas.get('therms'):
        return []
    when = sim_date(day)
    current = date.fromisoformat(when)
    if day != 1 and current.day != 1:
        return []
    end = current.replace(day=1) - timedelta(days=1)
    start = end.replace(day=1)
    base, spread = gas['therms']
    therms = round(base + _ph(profile, 'therm', start) % spread / 10, 1)
    return [dict(id=f'gas:{start}..{end}:gas', seq=0, kind='gas', quantity=therms, unit='therms',
                 label=f'Natural gas {therms} therms',
                 detail=f'Synthetic monthly PSE gas statement; service period {start} to {end}; '
                        'separate from electricity utility')]


def _vehicle_delta_km(day, profile):
    v = profile['vehicle']
    when = date.fromisoformat(sim_date(day))
    base, spread = v['weekend_km'] if when.weekday() >= 5 else v['weekday_km']
    return round(base + _ph(profile, 'odo', day) % spread / 10, 1)


def vehicle_records(day, profile):
    v = profile.get('vehicle')
    if not v:
        return []
    when = sim_date(day)
    delta_km = _vehicle_delta_km(day, profile)
    odometer_km = round(v['base_km'] + sum(_vehicle_delta_km(d, profile) for d in range(1, day + 1)), 1)
    min_soc, soc_span = v['soc']
    soc = min_soc + _ph(profile, 'soc', day) % soc_span
    est_range_km = round(soc / 100 * v['range_km'], 1)
    return [
        dict(id=f'vehicle:{when}:odometer', seq=0, kind='vehicle_odometer', quantity=odometer_km, unit='km',
             label=f'Odometer {odometer_km:,.1f} km',
             detail=f'Synthetic Smartcar-style read-only odometer ({when}); metric km; +{delta_km:.1f} km since prior day; '
                    'no coordinates or vehicle commands'),
        dict(id=f'vehicle:{when}:battery', seq=1, kind='ev_battery', quantity=soc, unit='%',
             label=f'EV battery {soc}% ({est_range_km:.0f} km range)',
             detail=f'Synthetic Smartcar-style read-only battery state of charge ({when}); {soc}% remaining, '
                    f'est. {est_range_km:.1f} km range; no coordinates or vehicle commands'),
    ]


def charger_records(day, profile):
    ch = profile.get('charger')
    if not ch:
        return []
    if day > 1 and _ph(profile, 'charger_skip', day) % 3 == 0:
        return []
    when = sim_date(day)
    base, spread = ch['kwh']
    kwh = round(base + _ph(profile, 'charger_kwh', day) % spread / 10, 1)
    minutes = max(15, round(kwh / ch['kw'] * 60))
    return [
        dict(id=f'charger:{when}:session', seq=0, kind='ev_charging_session', quantity=kwh, unit='kWh',
             label=f'Home EV charging {kwh:.1f} kWh (supporting)',
             detail=f'Synthetic Enode-style read-only home charging session ({when}, {minutes} min at ~{ch["kw"]:.1f} kW); '
                    'supporting detail only, overlaps PSE utility meter and is never added to totals; no charger commands'),
    ]


def _merchant(day, profile=None):
    if not profile or profile['id'] == 'redmond':
        return MERCHANTS[_h('merchant', day) % len(MERCHANTS)]
    merchants = profile.get('merchants') or MERCHANTS
    return merchants[_ph(profile, 'merchant', day) % len(merchants)]


def _amount(day, profile=None):
    if not profile or profile['id'] == 'redmond':
        return (_merchant(day)[1] + _h('cents', day) % 300) / 100
    return (_merchant(day, profile)[1] + _ph(profile, 'cents', day) % 450) / 100


def fake_plaid_transport(fault=None, profile=None):
    """Fake /transactions/sync. Cursor 'syn-N' means N simulated days were delivered.

    Page 1 adds day N+1 as pending; page 2 adds day N posted (replacing its pending
    transaction). Every 4th day mutates during pagination once, forcing the connector to
    restart from the saved cursor. `fault` is 'error' or 'auth' to simulate failures.
    """
    mutated = {'done': False}

    def transport(path, body):
        if path != '/transactions/sync':
            raise ValueError('Unexpected synthetic endpoint.')
        if fault == 'auth':
            return {'error_code': 'ITEM_LOGIN_REQUIRED'}
        if fault == 'error':
            return {'error_code': 'INTERNAL_SERVER_ERROR'}
        cursor = body['cursor'] or 'syn-0'
        base, _, page = cursor.partition('-p')
        done = int(base.split('-')[1])
        day = done + 1
        if not page:
            return {'added': [{'transaction_id': f'syn-pend-{day}', 'amount': _amount(day, profile), 'date': sim_date(day),
                               'pending': True, 'iso_currency_code': 'USD'}],
                    'next_cursor': f'syn-{done}-p1', 'has_more': True}
        if day % 4 == 0 and not mutated['done']:
            mutated['done'] = True
            return {'error_code': 'TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION'}
        added = []
        if done >= 1:
            added.append({'transaction_id': f'syn-post-{done}', 'pending_transaction_id': f'syn-pend-{done}',
                          'amount': _amount(done, profile), 'date': sim_date(done), 'iso_currency_code': 'USD'})
        removed = [{'transaction_id': f'syn-pend-{done}'}] if done else []
        if done >= 1 and done % 5 == 0:
            added.append({'transaction_id': f'syn-refund-{done}', 'amount': -_amount(done, profile),
                          'date': sim_date(done), 'iso_currency_code': 'USD'})
        modified = []
        if done >= 2 and done % 5 == 0:
            modified.append({'transaction_id': f'syn-post-{done - 1}',
                             'amount': round(_amount(done - 1, profile) + 0.25, 2),
                             'date': sim_date(done - 1), 'iso_currency_code': 'USD'})
        return {'added': added, 'modified': modified, 'removed': removed,
                'next_cursor': f'syn-{day}', 'has_more': False}


    return transport


def _bank_label(tid, profile=None):
    kind, day = tid.split('-')[1], int(tid.split('-')[2])
    name = _merchant(day, profile)[0]
    return f'{name} refund' if kind == 'refund' else name


def _profile(uid):
    return profiles.BY_UID.get(uid) or profiles.BY_ID['redmond']


def _source_ids(action, body, allowed=SOURCES):
    """Validated, de-duplicated source list. Only demo-authorize accepts a `sources` array."""
    if not isinstance(body, dict):
        raise ValueError('Unknown demo source.')
    if 'sources' in body:
        if action != 'demo-authorize' or 'source' in body:
            raise ValueError('Use `sources` only with demo-authorize, without `source`.')
        sources = body['sources']
        if not isinstance(sources, list) or not sources:
            raise ValueError('Unknown demo source.')
    else:
        sources = [body.get('source')]
    if not all(isinstance(s, str) and s in allowed for s in sources):
        raise ValueError('Unknown demo source.')
    return list(dict.fromkeys(sources))


_RECORD_GENERATORS = {
    'utility': utility_records,
    'gas': gas_records,
    'orca': orca_records,
    'vehicle': vehicle_records,
    'charger': charger_records,
}


class RedmondDemo:
    def __init__(self, platform, interval=10, clock=time.time, fault=None, households=('redmond',)):
        self.platform, self.clock = platform, clock
        self.interval = max(1, int(interval))
        # Optional fault(source) -> None | 'error' | 'auth', used to simulate provider failures.
        self.fault = fault
        self._seeded = set()
        unknown = set(households) - set(profiles.BY_ID)
        if unknown:
            raise ValueError(f'Unknown demo household: {sorted(unknown)}')
        with self._db() as c:
            c.executescript(SCHEMA)
        self._seed(*households)

    def _seed(self, *ids):
        """Idempotently create household rows; never touches existing status or records."""
        pending = [profiles.BY_ID[i] for i in ids if profiles.BY_ID[i]['uid'] not in self._seeded]
        if not pending:
            return
        with self._db() as c:
            missing = []
            for profile in pending:
                uid = profile['uid']
                have_h = c.execute('SELECT 1 FROM redmond_households WHERE user=?', (uid,)).fetchone()
                have_u = c.execute('SELECT 1 FROM users WHERE id=?', (uid,)).fetchone()
                have_s = {r[0] for r in c.execute('SELECT source FROM redmond_sources WHERE user=?', (uid,))}
                if not (have_h and have_u and set(profile['sources']) <= have_s):
                    missing.append(profile)
            if missing:
                c.execute('BEGIN IMMEDIATE')
                for profile in missing:
                    uid, name, region = profile['uid'], profile['name'], profile['region']
                    c.execute('INSERT OR IGNORE INTO redmond_households VALUES(?,?,?)', (uid, name, region))
                    for source in profile['sources']:
                        c.execute("INSERT OR IGNORE INTO redmond_sources(user,source,status) VALUES(?,?,'disconnected')",
                                  (uid, source))
                    # Lets the existing /api/me resolve the household; separate org keeps it out of seeded cohorts.
                    c.execute('INSERT OR IGNORE INTO users(id,name,org,region,consent) VALUES(?,?,?,?,0)',
                              (uid, name, uid, region))
                c.commit()
        for profile in pending:
            self._seeded.add(profile['uid'])

    def households(self):
        """Selectable demo households: [{id, name, city, scenario, sources}], Redmond first."""
        return [profiles.summary(p) for p in profiles.PROFILES]

    def user_for_household(self, household_id):
        """UID for a household profile id (seeding it on first use), or None if unknown."""
        profile = profiles.BY_ID.get(household_id) if isinstance(household_id, str) else None
        if not profile:
            return None
        self._seed(profile['id'])
        return profile['uid']

    def _ensure(self, uid):
        if uid in self._seeded:
            return
        profile = profiles.BY_UID.get(uid)
        if profile:
            self._seed(profile['id'])

    @contextlib.contextmanager
    def _db(self):
        c = self.platform.db()
        try:
            with c:
                yield c
        finally:
            c.close()

    def _household(self, c, uid):
        return c.execute('SELECT name,region FROM redmond_households WHERE user=?', (uid,)).fetchone()

    def snapshot(self, uid):
        """Additive /api/me fields. Empty for accounts that are not demo households."""
        self._ensure(uid)
        profile = profiles.BY_UID.get(uid)
        if not profile:
            return {}
        with self._db() as c:
            if not self._household(c, uid):
                return {}
            sources = []
            for source in profile['sources']:
                s = c.execute('SELECT status,last_success FROM redmond_sources WHERE user=? AND source=?', (uid, source)).fetchone()
                if source == 'utility':
                    rows = c.execute("SELECT label,detail FROM redmond_records WHERE user=? AND source='utility' AND state='active' "
                                     "AND kind!='gas' ORDER BY sim_day DESC, seq DESC, id DESC LIMIT ?",
                                     (uid, SNAPSHOT_RECORDS)).fetchall()
                    gas = c.execute("SELECT label,detail FROM redmond_records WHERE user=? AND source='utility' AND state='active' "
                                    "AND kind='gas' ORDER BY sim_day DESC LIMIT 1", (uid,)).fetchone()
                    if gas:
                        rows.insert(1, gas)
                else:
                    rows = c.execute("SELECT label,detail FROM redmond_records WHERE user=? AND source=? AND state='active' "
                                     'ORDER BY sim_day DESC, seq DESC, id DESC LIMIT ?',
                                     (uid, source, SNAPSHOT_RECORDS)).fetchall()
                item = {'id': source, 'status': s['status'], 'lastSyncedAt': _iso(s['last_success']),
                        **profiles.source_meta(profile, source),
                        'records': [{'label': r['label'], 'detail': r['detail']} for r in rows]}
                sources.append(item)
        return {'redmondDemo': True, 'demoHousehold': profiles.summary(profile), 'demoSources': sources}

    def mutate(self, uid, action, body):
        if action not in ('demo-authorize', 'demo-disconnect', 'demo-expire'):
            raise ValueError('Unsupported demo action.')
        profile = profiles.BY_UID.get(uid)
        if not profile:
            raise ValueError('Not a demo household.')
        sources = _source_ids(action, body, profile['sources'])
        self._ensure(uid)
        now = int(self.clock())
        with self._db() as c:
            # All sources are validated above against the selected profile and applied in one
            # transaction, so a grouped authorization either fully applies or leaves every source untouched.
            c.execute('BEGIN IMMEDIATE')
            if not self._household(c, uid):
                raise ValueError('Not a demo household.')
            for source in sources:
                self._apply(c, uid, source, action, now)
            c.commit()
        return self.snapshot(uid)

    def _apply(self, c, uid, source, action, now):
        status = c.execute('SELECT status FROM redmond_sources WHERE user=? AND source=?', (uid, source)).fetchone()[0]
        if action == 'demo-authorize':
            if status not in ACTIVE:
                # New consent generation; cursor and prior evidence are kept, never rewritten.
                c.execute("UPDATE redmond_sources SET status='waiting',generation=generation+1,next_due=?,failures=0 "
                          'WHERE user=? AND source=?', (now, uid, source))
                event = f'Synthetic {source} source authorized'
            else:
                event = None
        elif action == 'demo-disconnect':
            c.execute("UPDATE redmond_sources SET status='disconnected',next_due=NULL WHERE user=? AND source=?", (uid, source))
            event = f'Synthetic {source} source disconnected; prior evidence retained'
        else:
            if status not in ACTIVE:
                raise ValueError('Only an authorized source can expire.')
            c.execute("UPDATE redmond_sources SET status='auth_required',next_due=NULL WHERE user=? AND source=?", (uid, source))
            event = f'Synthetic {source} authorization expired'
        if event:
            c.execute('INSERT INTO audit(user,event) VALUES(?,?)', (uid, event))

    def run_once(self):
        """Apply at most one due simulated day per authorized source. Returns {uid: {source: status}}."""
        now, results = int(self.clock()), {}
        with self._db() as c:
            users = [r[0] for r in c.execute('SELECT user FROM redmond_households ORDER BY user')]
        for uid in users:
            results[uid] = {source: self._sync(uid, source, now) for source in _profile(uid)['sources']}
        return results

    def _sync(self, uid, source, now):
        profile = _profile(uid)
        with self._db() as c:
            c.execute('BEGIN IMMEDIATE')
            s = c.execute('SELECT * FROM redmond_sources WHERE user=? AND source=?', (uid, source)).fetchone()
            if not s:
                return 'disconnected'
            if s['status'] not in ACTIVE or (s['next_due'] is not None and now < s['next_due']):
                return s['status']
            fault = self.fault(source) if self.fault else None
            outcome, rows, removed, cursor, day = 'ok', [], [], s['cursor'], s['sim_day']
            if source == 'bank':
                try:
                    transport = fake_plaid_transport(fault) if profile['id'] == 'redmond' else fake_plaid_transport(fault, profile)
                    result = PlaidConnector(transport).fetch(s['cursor'])
                except AuthRequired:
                    outcome = 'auth_required'
                except ValueError:
                    outcome = 'error'
                else:
                    cursor, removed = result['cursor'], result['removed']
                    day = int(cursor.split('-')[1])
                    for t in result['transactions']:
                        rows.append(dict(id=f'bank:{t["id"]}', seq=0 if t['pending'] else 1, kind='bank_txn',
                                         quantity=t['cents'], unit='USD cents', pending=int(t['pending']),
                                         sim_day=(date.fromisoformat(t['day']) - BASE_DAY).days + 1,
                                         label=f'{_bank_label(t["id"], profile)} ${abs(t["cents"]) / 100:.2f}',
                                         detail=f'Synthetic Plaid transaction {t["day"]}; '
                                                f'{"pending" if t["pending"] else "refund" if t["refund"] else "posted"}; '
                                                'no carbon quantity inferred from payments'))
            elif fault in ('auth', 'error'):
                outcome = 'auth_required' if fault == 'auth' else 'error'
            else:
                day += 1
                cursor = f'day-{day}'
                rows = _RECORD_GENERATORS[source](day, profile)
            if outcome == 'auth_required':
                c.execute("UPDATE redmond_sources SET status='auth_required',next_due=NULL,failures=failures+1 "
                          'WHERE user=? AND source=?', (uid, source))
                c.execute('INSERT INTO audit(user,event) VALUES(?,?)', (uid, f'Synthetic {source} needs re-authorization'))
            elif outcome == 'error':
                # Keep the cursor; retry after the next interval.
                c.execute('UPDATE redmond_sources SET next_due=?,failures=failures+1 WHERE user=? AND source=?',
                          (now + self.interval, uid, source))
            else:
                for r in rows:
                    c.execute('INSERT INTO redmond_records(user,source,id,sim_day,seq,kind,quantity,unit,label,detail,'
                              'pending,generation) VALUES(?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(user,id) '
                              'DO UPDATE SET quantity=excluded.quantity,label=excluded.label,detail=excluded.detail',

                              (uid, source, r['id'], r.get('sim_day', day), r['seq'], r['kind'], r['quantity'], r['unit'],
                               r['label'], r['detail'], r.get('pending', 0), s['generation']))
                for rid in removed:
                    c.execute("UPDATE redmond_records SET state='replaced' WHERE user=? AND id=?", (uid, f'bank:{rid}'))
                c.execute("UPDATE redmond_sources SET status='ok',cursor=?,sim_day=?,last_success=?,next_due=?,failures=0 "
                          'WHERE user=? AND source=?', (cursor, day, now, now + self.interval, uid, source))
            c.commit()
            return 'ok' if outcome == 'ok' else ('auth_required' if outcome == 'auth_required' else s['status'])
