"""Synthetic Redmond pilot household. Clearly fictional data; no network, secrets or real credentials.

One simulated day elapses per `interval` seconds for each authorized source:
- utility: electricity kWh as daily totals, gas therms as separate monthly statements
- orca: synthetic tap-on events at public Sound Transit 2 Line stations in Redmond
  (station, time, agency, fare only; no alighting, trip or distance is inferred)
- bank: transactions via the existing connectors.PlaidConnector, fed by an injected fake
  /transactions/sync transport (pagination, pending->posted replacement, mutation retry)

All state lives in dedicated redmond_* tables. Each source update runs in one
BEGIN IMMEDIATE transaction that re-reads the cursor, so concurrent or restarted
workers never apply the same simulated day twice. Records are inserted idempotently and
are never rewritten by disconnect/expire/re-authorize.
"""
import contextlib
import hashlib
import time
from datetime import date, timedelta

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


def utility_records(day):
    when = sim_date(day)
    kwh = round(16 + _h('kwh', day) % 120 / 10, 1)
    rows = [dict(id=f'utility:{when}:electricity', seq=0, kind='electricity', quantity=kwh, unit='kWh',
                 label=f'Electricity {kwh} kWh',
                 detail=f'Synthetic daily electricity total; service date {when}')]
    current = date.fromisoformat(when)
    if day == 1 or current.day == 1:
        end = current.replace(day=1) - timedelta(days=1)
        start = end.replace(day=1)
        therms = round(27 + _h('therm', start) % 420 / 10, 1)
        rows.append(dict(id=f'utility:{start}..{end}:gas', seq=1, kind='gas', quantity=therms, unit='therms',
                         label=f'Natural gas {therms} therms',
                         detail=f'Synthetic monthly gas statement; service period {start} to {end}'))
    return rows


def orca_records(day):
    when = date.fromisoformat(sim_date(day))
    if when.weekday() >= 5:
        return []
    taps = [(STATIONS[_h('am', day) % 2], f'07:{30 + _h("amt", day) % 25:02d}'),
            (STATIONS[2 + _h('pm', day) % 2], f'17:{10 + _h("pmt", day) % 40:02d}')]
    return [dict(id=f'orca:{when.isoformat()}:{n}', seq=n, kind='transit_tap', quantity=FARE_CENTS, unit='USD cents',
                 label=f'Tap at {station} station',
                 detail=f'Synthetic ORCA tap {when.isoformat()} {clock} PT; {AGENCY} 2 Line; fare ${FARE_CENTS / 100:.2f}; '
                        'no alighting or distance inferred')
            for n, (station, clock) in enumerate(taps)]


def _merchant(day):
    return MERCHANTS[_h('merchant', day) % len(MERCHANTS)]


def _amount(day):
    return (_merchant(day)[1] + _h('cents', day) % 300) / 100


def fake_plaid_transport(fault=None):
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
            return {'added': [{'transaction_id': f'syn-pend-{day}', 'amount': _amount(day), 'date': sim_date(day),
                               'pending': True, 'iso_currency_code': 'USD'}],
                    'next_cursor': f'syn-{done}-p1', 'has_more': True}
        if day % 4 == 0 and not mutated['done']:
            mutated['done'] = True
            return {'error_code': 'TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION'}
        added = []
        if done >= 1:
            added.append({'transaction_id': f'syn-post-{done}', 'pending_transaction_id': f'syn-pend-{done}',
                          'amount': _amount(done), 'date': sim_date(done), 'iso_currency_code': 'USD'})
        removed = [{'transaction_id': f'syn-pend-{done}'}] if done else []
        if done >= 1 and done % 5 == 0:
            added.append({'transaction_id': f'syn-refund-{done}', 'amount': -_amount(done),
                          'date': sim_date(done), 'iso_currency_code': 'USD'})
        modified = []
        if done >= 2 and done % 5 == 0:
            modified.append({'transaction_id': f'syn-post-{done - 1}',
                             'amount': round(_amount(done - 1) + 0.25, 2),
                             'date': sim_date(done - 1), 'iso_currency_code': 'USD'})
        return {'added': added, 'modified': modified, 'removed': removed,
                'next_cursor': f'syn-{day}', 'has_more': False}


    return transport


def _bank_label(tid):
    kind, day = tid.split('-')[1], int(tid.split('-')[2])
    name = _merchant(day)[0]
    return f'{name} refund' if kind == 'refund' else name


class RedmondDemo:
    def __init__(self, platform, interval=10, clock=time.time, fault=None):
        self.platform, self.clock = platform, clock
        self.interval = max(1, int(interval))
        # Optional fault(source) -> None | 'error' | 'auth', used to simulate provider failures.
        self.fault = fault
        with self._db() as c:
            c.executescript(SCHEMA)
            c.execute('BEGIN IMMEDIATE')
            c.execute('INSERT OR IGNORE INTO redmond_households VALUES(?,?,?)', (UID, NAME, REGION))
            for source in SOURCES:
                c.execute("INSERT OR IGNORE INTO redmond_sources(user,source,status) VALUES(?,?,'disconnected')", (UID, source))
            # Lets the existing /api/me resolve the household; separate org keeps it out of seeded cohorts.
            c.execute('INSERT OR IGNORE INTO users(id,name,org,region,consent) VALUES(?,?,?,?,0)', (UID, NAME, UID, REGION))
            c.commit()

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
        """Additive /api/me fields. Empty for accounts that are not Redmond demo households."""
        with self._db() as c:
            if not self._household(c, uid):
                return {}
            sources = []
            for source in SOURCES:
                s = c.execute('SELECT status,last_success FROM redmond_sources WHERE user=? AND source=?', (uid, source)).fetchone()
                rows = c.execute("SELECT label,detail FROM redmond_records WHERE user=? AND source=? AND state='active' "
                                 "AND kind!='gas' ORDER BY sim_day DESC, seq DESC, id DESC LIMIT ?",
                                 (uid, source, SNAPSHOT_RECORDS)).fetchall()
                if source == 'utility':
                    gas = c.execute("SELECT label,detail FROM redmond_records WHERE user=? AND kind='gas' "
                                    'ORDER BY sim_day DESC LIMIT 1', (uid,)).fetchone()
                    if gas:
                        rows.insert(1, gas)
                sources.append({'id': source, 'status': s['status'], 'lastSyncedAt': _iso(s['last_success']),
                                'records': [{'label': r['label'], 'detail': r['detail']} for r in rows]})
        return {'redmondDemo': True, 'demoSources': sources}

    def mutate(self, uid, action, body):
        if action not in ('demo-authorize', 'demo-disconnect', 'demo-expire'):
            raise ValueError('Unsupported demo action.')
        source = body.get('source') if isinstance(body, dict) else None
        if source not in SOURCES:
            raise ValueError('Unknown demo source.')
        now = int(self.clock())
        with self._db() as c:
            c.execute('BEGIN IMMEDIATE')
            if not self._household(c, uid):
                raise ValueError('Not a Redmond demo household.')
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
            c.commit()
        return self.snapshot(uid)

    def run_once(self):
        """Apply at most one due simulated day per authorized source. Returns {uid: {source: status}}."""
        now, results = int(self.clock()), {}
        with self._db() as c:
            users = [r[0] for r in c.execute('SELECT user FROM redmond_households ORDER BY user')]
        for uid in users:
            results[uid] = {source: self._sync(uid, source, now) for source in SOURCES}
        return results

    def _sync(self, uid, source, now):
        with self._db() as c:
            c.execute('BEGIN IMMEDIATE')
            s = c.execute('SELECT * FROM redmond_sources WHERE user=? AND source=?', (uid, source)).fetchone()
            if s['status'] not in ACTIVE or (s['next_due'] is not None and now < s['next_due']):
                return s['status']
            fault = self.fault(source) if self.fault else None
            outcome, rows, removed, cursor, day = 'ok', [], [], s['cursor'], s['sim_day']
            if source == 'bank':
                try:
                    result = PlaidConnector(fake_plaid_transport(fault)).fetch(s['cursor'])
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
                                         label=f'{_bank_label(t["id"])} ${abs(t["cents"]) / 100:.2f}',
                                         detail=f'Synthetic Plaid transaction {t["day"]}; '
                                                f'{"pending" if t["pending"] else "refund" if t["refund"] else "posted"}; '
                                                'no carbon quantity inferred from payments'))
            elif fault in ('auth', 'error'):
                outcome = 'auth_required' if fault == 'auth' else 'error'
            else:
                day += 1
                cursor = f'day-{day}'
                rows = utility_records(day) if source == 'utility' else orca_records(day)
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
