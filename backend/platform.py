"""Verdi pilot API: durable evidence, rewards, consent and institution analytics.

Standard library only. Run `python3 backend/platform.py --demo` for synthetic data.
Live mode starts empty and requires VERDI_SESSIONS_JSON. No money is moved.
"""
import argparse
import calendar
import hmac
import json
import math
import os
import sqlite3
import urllib.request
from datetime import date, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

EPA = 'https://www.epa.gov/system/files/documents/2025-01/ghg-emission-factors-hub-2025.pdf'
FACTORS = {
    'car': ((.297 + .0059 * 28 / 1000 + .0053 * 265 / 1000) / 1.609344, 'km', 'Travel'),
    'bus': ((.066 + .0046 * 28 / 1000 + .0019 * 265 / 1000) / 1.609344, 'passenger-km', 'Travel'),
    'train': ((.133 + .0105 * 28 / 1000 + .0026 * 265 / 1000) / 1.609344, 'passenger-km', 'Travel'),
    'bicycle': (0., 'km', 'Travel'),
    'electricity': ((771.5 + .057 * 28 + .008 * 265) * .45359237 / 1000, 'kWh', 'Home'),
}
PROVIDERS = {'bank': 'Bank transactions', 'utility': 'Home energy', 'transport': 'Travel receipts', 'iot': 'Smart devices'}
NATIONAL_VERSION = 'us-epa-2025-v1'
NORTHWEST_VERSION = 'nwpp-epa-2025-v1'
NORTHWEST_KG_PER_KWH = (631.7 + .054 * 28 + .008 * 265) * .45359237 / 1000
REGIONS = {'us': 'US national fallback', 'nwpp': 'WECC Northwest (NWPP)',
           'redmond': 'Redmond, WA (NWPP)'}


class Problem(Exception):
    def __init__(self, message, status=400):
        super().__init__(message)
        self.status = status


def positive(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0 or value > 1e6:
        raise Problem('Quantity must be finite, positive and at most 1,000,000.')
    return value


def round_up(cents, pending=False, refund=False):
    """Integer cents only. Whole dollars, pending charges and refunds contribute zero."""
    if type(cents) is not int:
        raise Problem('Money requires integer cents.')
    return 0 if pending or refund or cents <= 0 else (100 - cents % 100) % 100


class Platform:
    def __init__(self, path, demo=False):
        self.path, self.demo = str(path), demo
        with self.db() as c:
            c.executescript('''
            CREATE TABLE IF NOT EXISTS metadata(key TEXT PRIMARY KEY,value TEXT);
            CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY,name TEXT,org TEXT,region TEXT,consent INTEGER DEFAULT 0);
            CREATE TABLE IF NOT EXISTS connections(user TEXT,provider TEXT,connected INTEGER,PRIMARY KEY(user,provider));
            CREATE TABLE IF NOT EXISTS evidence(id TEXT,user TEXT,provider TEXT,day TEXT,kind TEXT,quantity REAL,description TEXT,status TEXT,factor REAL,version TEXT,PRIMARY KEY(user,id));
            CREATE TABLE IF NOT EXISTS transactions(id TEXT,user TEXT,day TEXT,cents INTEGER,pending INTEGER,refund INTEGER,PRIMARY KEY(user,id));
            CREATE TABLE IF NOT EXISTS ledger(user TEXT,id TEXT,points INTEGER,description TEXT,PRIMARY KEY(user,id));
            CREATE TABLE IF NOT EXISTS pledges(user TEXT,id TEXT,cents INTEGER,PRIMARY KEY(user,id));
            CREATE TABLE IF NOT EXISTS audit(id INTEGER PRIMARY KEY,user TEXT,event TEXT,created TEXT DEFAULT CURRENT_TIMESTAMP);
            CREATE TABLE IF NOT EXISTS cursors(user TEXT PRIMARY KEY,cursor TEXT);
            CREATE TABLE IF NOT EXISTS pilot_settings(user TEXT PRIMARY KEY,meter_timezone TEXT);
            CREATE INDEX IF NOT EXISTS evidence_provider_day ON evidence(user,provider,day);
            ''')
            mode = c.execute("SELECT value FROM metadata WHERE key='mode'").fetchone()
            if mode and mode[0] != ('demo' if demo else 'live'):
                raise Problem('Demo and live must use separate database files.')
            c.execute("INSERT OR IGNORE INTO metadata VALUES('mode',?)", ('demo' if demo else 'live',))
        if demo:
            self.seed()

    def db(self):
        c = sqlite3.connect(self.path, timeout=10)
        c.row_factory = sqlite3.Row
        return c

    def seed(self):
        # Fixed complete months make the investor walkthrough reproducible across dates.
        with self.db() as c:
            if c.execute('SELECT count(*) FROM users').fetchone()[0]:
                return
            for org in ['cascadia', 'evergreen', 'lakeside']:
                for n in range(24):
                    uid = 'alex' if org == 'cascadia' and n == 0 else f'{org}-{n:02}'
                    c.execute('INSERT INTO users VALUES(?,?,?,?,?)', (uid, 'Alex Morgan' if uid == 'alex' else f'Participant {n+1}', org, 'US national fallback', 1 if n < 20 else 0))
                    for provider in PROVIDERS:
                        c.execute('INSERT INTO connections VALUES(?,?,1)', (uid, provider))
                    for month in [9, 10]:
                        for day in range(1, calendar.monthrange(2026, month)[1] + 1):
                            when = date(2026, month, day).isoformat()
                            kind = 'car' if month == 9 or day % 3 == 0 else 'bus'
                            for k, q, provider, desc in [(kind, 22 + n % 5, 'transport', 'Commute receipt'), ('electricity', 13 + n % 4, 'utility', 'Daily meter reading')]:
                                c.execute('INSERT INTO evidence VALUES(?,?,?,?,?,?,?,?,?,?)', (f'{when}:{k}', uid, provider, when, k, q, desc, 'confirmed', FACTORS[k][0], 'us-epa-2025-v1'))
                            c.execute('INSERT INTO transactions VALUES(?,?,?,?,0,0)', (when, uid, when, 1245 + day))
            c.execute("INSERT INTO audit(user,event) VALUES('system','Seeded 72 fictional participants. No partner relationships implied.')")

    def user(self, uid):
        with self.db() as c:
            r = c.execute('SELECT * FROM users WHERE id=?', (uid,)).fetchone()
        if not r:
            raise Problem('Account not provisioned.', 404)
        return dict(r)

    def ingest(self, uid, provider, records, *, green_button=False):
        user = self.user(uid)
        if not isinstance(provider, str) or provider not in PROVIDERS or not isinstance(records, list) or not 0 < len(records) <= 1000:
            raise Problem('Unknown provider or too many records.')
        prepared = []
        for r in records:
            if not isinstance(r, dict):
                raise Problem('Each evidence record must be an object.')
            kind = r.get('kind')
            if not isinstance(kind, str) or kind not in FACTORS:
                raise Problem('Unsupported factor. Product, flight and waste estimates require reviewed factors before import.')
            if provider == 'bank' or (provider in ['utility', 'iot'] and kind != 'electricity') or (provider == 'transport' and kind == 'electricity'):
                raise Problem('Physical units must match the data source. Bank spending is not physical evidence.')
            quantity = r.get('quantity')
            q = 0 if green_button and type(quantity) in (int, float) and quantity == 0 else positive(quantity)
            try:
                day = date.fromisoformat(r['day'])
            except (ValueError, KeyError, TypeError):
                raise Problem('Use a valid ISO date.')
            if day > date.today():
                raise Problem('Future activity cannot be confirmed.')
            rid = str(r.get('id', '')).strip()
            if not rid or len(rid) > 160 or (rid.startswith('green-button:') and not green_button):
                raise Problem('Stable source record ID required.')
            # Submeters remain supporting evidence until an explicit meter boundary model exists.
            status = 'supporting' if provider == 'iot' else 'pending'
            regional = kind == 'electricity' and user['region'] in (REGIONS['nwpp'], REGIONS['redmond'])
            factor = NORTHWEST_KG_PER_KWH if regional else FACTORS[kind][0]
            version = NORTHWEST_VERSION if regional else NATIONAL_VERSION
            prepared.append((f'{provider}:{rid}', uid, provider, day.isoformat(), kind, q, str(r.get('description', provider))[:240], status, factor, version))
        with self.db() as c:
            c.execute('BEGIN IMMEDIATE')
            conn = c.execute('SELECT connected FROM connections WHERE user=? AND provider=?', (uid, provider)).fetchone()
            if not conn or not conn[0]:
                raise Problem('Connection and consent required before ingestion.', 403)
            added = 0
            for row in prepared:
                old = c.execute('SELECT day,kind,quantity FROM evidence WHERE user=? AND id=?', (uid, row[0])).fetchone()
                if old and tuple(old) != (row[3], row[4], row[5]):
                    raise Problem('Source record changed. Review the correction before importing.', 409)
                if provider == 'utility' and not old:
                    overlaps = c.execute(
                        "SELECT id FROM evidence WHERE user=? AND provider='utility' AND day=? AND status!='dismissed'",
                        (uid, row[3])).fetchall()
                    if any(green_button or item['id'].startswith('utility:green-button:') for item in overlaps):
                        raise Problem('This day already has utility evidence. Import each day from one file source.', 409)
                added += c.execute('INSERT OR IGNORE INTO evidence VALUES(?,?,?,?,?,?,?,?,?,?)', row).rowcount
            c.execute('INSERT INTO audit(user,event) VALUES(?,?)', (uid, f'Imported {added} {provider} records'))
        return {'added': added, 'duplicates': len(records) - added}

    def import_green_button(self, uid, document):
        from green_button import daily_readings
        if self.demo:
            raise Problem('Green Button imports require a provisioned pilot account.', 403)
        if not isinstance(document, str) or len(document.encode('utf-8', errors='replace')) > 5_000_000:
            raise Problem('Choose a Green Button XML file up to 5 MB.', 400)
        with self.db() as c:
            settings = c.execute('SELECT meter_timezone FROM pilot_settings WHERE user=?', (uid,)).fetchone()
        if not settings or not settings['meter_timezone']:
            raise Problem('Set a meter time zone with your pilot administrator before importing XML.', 409)
        try:
            records, skipped = daily_readings(document, settings['meter_timezone'])
        except ValueError as e:
            raise Problem(str(e)) from None
        result = self.ingest(uid, 'utility', records, green_button=True)
        return {**result, 'incompleteDays': skipped}

    def snapshot(self, uid):
        from connectors import PlaidConnector

        user = self.user(uid)
        with self.db() as c:
            rows = [dict(r) for r in c.execute(
                "SELECT * FROM evidence WHERE user=? ORDER BY (status='pending') DESC,day DESC,id", (uid,))]
            connections = [dict(r) for r in c.execute('SELECT provider,connected FROM connections WHERE user=?', (uid,))]
            settings = c.execute('SELECT meter_timezone FROM pilot_settings WHERE user=?', (uid,)).fetchone()
            ledger = [dict(r) for r in c.execute('SELECT id,points,description FROM ledger WHERE user=?', (uid,))]
            cents = sum(r[0] for r in c.execute('SELECT cents FROM pledges WHERE user=?', (uid,)))
        categories = {}
        for connection in connections:
            provider = connection['provider']
            connection['mode'] = 'demo' if self.demo else {
                'bank': f"plaid-{os.getenv('PLAID_ENV', 'sandbox')}" if PlaidConnector.configured(uid) else 'unavailable',
                'utility': 'file-import',
                'transport': 'manual',
                'iot': 'supporting',
            }[provider]
        for r in rows:
            r['kg'] = r['quantity'] * r['factor']
            r['unit'] = FACTORS[r['kind']][1]
            r['factorSource'] = EPA
            if r['status'] == 'confirmed' and r['day'].startswith('2026-10' if self.demo else date.today().strftime('%Y-%m')):
                category = FACTORS[r['kind']][2]
                categories[category] = categories.get(category, 0) + r['kg']
        return {'demo': self.demo, 'period': 'October 2026' if self.demo else date.today().strftime('%B %Y'), 'user': user,
                'meterTimeZone': settings['meter_timezone'] if settings else None,
                'connections': connections, 'categories': categories, 'activities': rows[:300],
                'points': sum(r['points'] for r in ledger), 'ledger': ledger, 'pledgedCents': cents,
                'boundary': f"Operational estimates. Electricity profile: {user['region']}. Each reading retains its original factor.",
                'rewards': [{'id': 'transit-pass', 'title': 'Transit discount', 'points': 200}, {'id': 'community', 'title': 'Community project contribution', 'points': 100}],
                'aiAvailable': bool(os.getenv('OLLAMA_MODEL')) and (os.getenv('OLLAMA_HOST', 'https://ollama.com').rstrip('/') != 'https://ollama.com' or bool(os.getenv('OLLAMA_API_KEY')))}

    def monthly_reward(self, uid, month):
        self.user(uid)
        try:
            start = date.fromisoformat(month + '-01')
        except (ValueError, TypeError):
            raise Problem('Use YYYY-MM.')
        if start.replace(day=calendar.monthrange(start.year, start.month)[1]) >= date.today():
            raise Problem('Rewards require a completed month.')
        previous = start - timedelta(days=1)
        prior = previous.strftime('%Y-%m')
        with self.db() as c:
            c.execute('BEGIN IMMEDIATE')
            sums = []
            versions = {}
            # Only matched categories with daily measured evidence qualify. No reward for a missing source.
            for period in [prior, month]:
                y, m = map(int, period.split('-'))
                days = calendar.monthrange(y, m)[1]
                connected = {r[0] for r in c.execute('SELECT provider FROM connections WHERE user=? AND connected=1', (uid,))}
                if not {'transport', 'utility'}.issubset(connected):
                    raise Problem('Connected travel and utility evidence required in both periods.')
                total = 0
                for provider in ['transport', 'utility']:
                    rows = c.execute(
                        """SELECT day,quantity,factor,version FROM evidence
                           WHERE user=? AND provider=? AND substr(day,1,7)=? AND status='confirmed'
                           AND id NOT LIKE 'transport:manual:%'""", (uid, provider, period)).fetchall()
                    allowed = {NATIONAL_VERSION, NORTHWEST_VERSION} if provider == 'utility' else {NATIONAL_VERSION}
                    used = {r['version'] for r in rows}
                    if len(used) > 1 or not used.issubset(allowed) or (provider in versions and used != versions[provider]):
                        raise Problem('Reward periods need matching factor methods.')
                    versions[provider] = used
                    if len({r['day'] for r in rows}) != days:
                        raise Problem('Incomplete daily evidence. Missing data cannot earn points.')
                    total += sum(r['quantity'] * r['factor'] for r in rows) / days
                sums.append(total)
            reduction = max(0, (sums[0] - sums[1]) * calendar.monthrange(start.year, start.month)[1])
            points = min(2000, math.floor(reduction * 10))
            rid = f'reduction:{month}'
            c.execute('INSERT OR IGNORE INTO ledger VALUES(?,?,?,?)', (uid, rid, points, f'{month}: {reduction:.2f} kg estimated reduction, matched daily coverage'))
        return {'id': rid, 'points': points, 'kgReduced': reduction, 'simulation': self.demo}

    def mutate(self, uid, action, body):
        self.user(uid)
        if action == 'reward':
            return self.monthly_reward(uid, str(body.get('month', '')))
        if action == 'sync':
            if not self.demo:
                return self.sync_bank(uid)
            # Provider snapshot replay uses stable IDs, so repeated sync cannot inflate totals.
            return self.ingest(uid, 'transport', [{'id': 'receipt-oct31', 'day': '2026-10-31', 'kind': 'bus', 'quantity': 18.4, 'description': 'Transit receipt awaiting review'}])
        if action == 'import':
            return self.ingest(uid, body.get('provider'), body.get('records'))
        if action == 'import-green-button':
            return self.import_green_button(uid, body.get('xml'))
        with self.db() as c:
            c.execute('BEGIN IMMEDIATE')
            if action == 'consent':
                if type(body.get('enabled')) is not bool:
                    raise Problem('Choose enabled true or false.')
                c.execute('UPDATE users SET consent=? WHERE id=?', (int(body['enabled']), uid))
                action = 'sharing enabled' if body['enabled'] else 'sharing disabled'
            elif action == 'connection':
                p, enabled = body.get('provider'), body.get('enabled')
                if p not in PROVIDERS or type(enabled) is not bool:
                    raise Problem('Unknown provider or invalid consent.')
                if enabled and not self.demo and p == 'bank':
                    from connectors import PlaidConnector
                    if not PlaidConnector.configured(uid):
                        raise Problem('Consented Plaid account not provisioned. Provider authorization is required.', 503)
                c.execute('INSERT OR REPLACE INTO connections VALUES(?,?,?)', (uid, p, int(enabled)))
                action = f'{p} import enabled' if enabled else f'{p} import disabled'
            elif action == 'review':
                status = body.get('status')
                if status not in ['confirmed', 'dismissed']:
                    raise Problem('Choose confirm or dismiss.')
                result = c.execute("UPDATE evidence SET status=? WHERE user=? AND id=? AND status='pending'", (status, uid, body.get('id')))
                if not result.rowcount:
                    raise Problem('Pending record not found.', 404)
            elif action == 'redeem':
                if not self.demo:
                    raise Problem('Redemption partner not configured.', 503)
                reward = {'transit-pass': 200, 'community': 100}.get(body.get('reward'))
                key = str(body.get('key', ''))
                if reward is None or not key or len(key) > 120:
                    raise Problem('Reward and idempotency key required.')
                rid = f'redeem:{key}'
                old = c.execute('SELECT points,description FROM ledger WHERE user=? AND id=?', (uid, rid)).fetchone()
                if old and old['description'] != body['reward']:
                    raise Problem('Idempotency key belongs to another reward.', 409)
                if not old:
                    balance = c.execute('SELECT coalesce(sum(points),0) FROM ledger WHERE user=?', (uid,)).fetchone()[0]
                    if balance < reward:
                        raise Problem('Insufficient points.', 409)
                    c.execute('INSERT INTO ledger VALUES(?,?,?,?)', (uid, rid, -reward, body['reward']))
            elif action == 'roundups':
                if not self.demo:
                    raise Problem('Payment processor not configured. No funds collected.', 503)
                cap = body.get('capCents', 500)
                if type(cap) is not int or not 0 <= cap <= 10000:
                    raise Problem('Cap must be 0 to 10,000 cents.')
                period = '2026-10'
                used = c.execute('SELECT coalesce(sum(cents),0) FROM pledges WHERE user=? AND substr(id,1,7)=?', (uid, period)).fetchone()[0]
                for tx in c.execute('SELECT * FROM transactions WHERE user=? AND substr(day,1,7)=? ORDER BY day,id', (uid, period)).fetchall():
                    if c.execute('SELECT 1 FROM pledges WHERE user=? AND id=?', (uid, tx['id'])).fetchone():
                        continue
                    amount = min(round_up(tx['cents'], tx['pending'], tx['refund']), max(0, cap-used))
                    c.execute('INSERT INTO pledges VALUES(?,?,?)', (uid, tx['id'], amount))
                    used += amount
            else:
                raise Problem('Unknown action.', 404)
            c.execute('INSERT INTO audit(user,event) VALUES(?,?)', (uid, action))
        return {'ok': True, 'simulation': self.demo}

    def sync_bank(self, uid):
        from connectors import PlaidConnector
        if not PlaidConnector.configured(uid):
            raise Problem('No authorized live banking account configured. Utility CSV imports remain available.', 503)
        with self.db() as c:
            connection = c.execute("SELECT connected FROM connections WHERE user=? AND provider='bank'", (uid,)).fetchone()
            cursor = c.execute('SELECT cursor FROM cursors WHERE user=?', (uid,)).fetchone()
        if not connection or not connection[0]:
            raise Problem('Bank connection consent required.', 403)
        try:
            result = PlaidConnector().fetch(cursor[0] if cursor else '')
        except Exception:
            raise Problem('Bank provider unavailable. Saved cursor and transactions kept for retry.', 503)
        with self.db() as c:
            c.execute('BEGIN IMMEDIATE')
            # Consent may have changed while the provider request was in flight.
            connection = c.execute("SELECT connected FROM connections WHERE user=? AND provider='bank'", (uid,)).fetchone()
            if not connection or not connection[0]:
                raise Problem('Bank connection was disconnected during sync.', 403)
            current = c.execute('SELECT cursor FROM cursors WHERE user=?', (uid,)).fetchone()
            if (current[0] if current else '') != (cursor[0] if cursor else ''):
                raise Problem('Another sync completed first. Retry.', 409)
            for row in result['transactions']:
                c.execute('INSERT OR REPLACE INTO transactions VALUES(?,?,?,?,?,?)', (row['id'],uid,row['day'],row['cents'],int(row['pending']),int(row['refund'])))
            for rid in result['removed']:
                c.execute('DELETE FROM transactions WHERE user=? AND id=?', (uid,rid))
            c.execute('INSERT OR REPLACE INTO cursors VALUES(?,?)', (uid,result['cursor']))
            c.execute('INSERT INTO audit(user,event) VALUES(?,?)', (uid,'Synced consented bank transactions; no distance inferred'))
        return {'added':len(result['transactions']), 'duplicates':0, 'removed':len(result['removed'])}

    def aggregate(self, org):
        with self.db() as c:
            users = c.execute('SELECT id FROM users WHERE org=? AND consent=1', (org,)).fetchall()
            # Fixed reports only: no arbitrary filters that enable differencing of small cohorts.
            if len(users) < 10:
                return {'suppressed': True, 'reason': 'At least 10 consenting participants required.'}
            rows = c.execute("SELECT substr(e.day,1,7) month,e.kind,sum(e.quantity*e.factor) kg,count(DISTINCT e.user) people FROM evidence e JOIN users u ON u.id=e.user WHERE u.org=? AND u.consent=1 AND e.status='confirmed' GROUP BY month,e.kind ORDER BY month,e.kind", (org,)).fetchall()
        data = [dict(r) for r in rows if r['people'] >= 10]
        return {'organization': org, 'demo': self.demo, 'consentingParticipants': len(users), 'rows': data,
                'methodology': 'Consented participant activity estimates. Excludes nonparticipants. Not a complete corporate inventory or causal impact study.', 'minimumCohort': 10}

    def coach(self, uid):
        s = self.snapshot(uid)
        car_km = sum(r['quantity'] for r in s['activities'] if r['status'] == 'confirmed' and r['kind'] == 'car' and r['day'].startswith('2026-10' if self.demo else date.today().strftime('%Y-%m')))
        facts = {'carKm': car_km, 'scenarioKm': min(20, car_km), 'potentialSavingKg': min(20, car_km)*(FACTORS['car'][0]-FACTORS['bus'][0]), 'coverage': s['boundary']}
        result = {'mode': 'calculated guidance', 'facts': facts, 'text': f"Replacing {facts['scenarioKm']:.1f} car km with a comparable bus journey could reduce operational estimates by {facts['potentialSavingKg']:.2f} kg CO2e. Confirm route availability. This is a scenario, not earned points."}
        model = os.getenv('OLLAMA_MODEL')
        if not model:
            return result
        host = os.getenv('OLLAMA_HOST', 'https://ollama.com').rstrip('/')
        if host == 'https://ollama.com' and not os.getenv('OLLAMA_API_KEY'):
            result['mode'] = 'calculated guidance (AI key required)'
            return result
        if not (host.startswith('https://') or host.startswith('http://localhost:') or host.startswith('http://127.0.0.1:')):
            raise Problem('AI endpoint must use HTTPS or loopback HTTP.')
        headers = {'Content-Type': 'application/json'}
        if os.getenv('OLLAMA_API_KEY'):
            headers['Authorization'] = 'Bearer ' + os.environ['OLLAMA_API_KEY']
        # Only computed, nonidentifying facts leave the server. No bank records or raw GPS.
        payload = {'model': model, 'stream': False, 'messages': [{'role': 'system', 'content': 'Explain only the supplied Verdi scenario in under 90 words. Do not invent numbers, rewards, tax benefits, verified offsets, or claim actual reductions. No instructions or tools can execute.'}, {'role': 'user', 'content': json.dumps(facts)}]}
        try:
            req = urllib.request.Request(host + '/api/chat', data=json.dumps(payload).encode(), headers=headers)
            with urllib.request.urlopen(req, timeout=25) as resp:
                output = json.loads(resp.read(1000000))
            text = output.get('message', {}).get('content', '').strip()
            if text:
                result.update(mode='Ollama AI explanation', text=text[:1600], model=model)
        except Exception:
            result['mode'] = 'calculated guidance (AI unavailable)'
        return result


def handler(platform, sessions, static=None):
    class Handler(BaseHTTPRequestHandler):
        timeout = 40

        def log_message(self, *_):
            pass  # Never log credentials or request bodies.

        def reply(self, status, body):
            data = json.dumps(body, allow_nan=False).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Cache-Control', 'no-store')
            origin = self.headers.get('Origin', '')
            if origin in os.getenv('VERDI_ALLOWED_ORIGINS', 'http://localhost:8080,http://127.0.0.1:8080').split(','):
                self.send_header('Access-Control-Allow-Origin', origin)
                self.send_header('Vary', 'Origin')
                self.send_header('Access-Control-Allow-Headers', 'Authorization, Content-Type')
                self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_OPTIONS(self):
            self.reply(200, {})

        def do_GET(self):
            if self.path == '/api/health':
                try:
                    with platform.db() as c:
                        c.execute("SELECT value FROM metadata WHERE key='mode'").fetchone()
                except sqlite3.Error:
                    self.reply(503, {'status': 'unavailable'})
                else:
                    self.reply(200, {'status': 'ok'})
                return
            if static and not self.path.startswith('/api/'):
                import mimetypes
                file = (Path(static) / self.path.split('?')[0].lstrip('/')).resolve()
                if self.path.split('?')[0] == '/':
                    file = Path(static).resolve() / 'index.html'
                if file.is_relative_to(Path(static).resolve()) and file.is_file():
                    data = file.read_bytes()
                    self.send_response(200)
                    self.send_header('Content-Type', mimetypes.guess_type(str(file))[0] or 'application/octet-stream')
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                    return
                self.reply(404, {'error': 'Not found'})
                return
            self.route()

        def do_POST(self):
            self.route()

        def route(self):
            try:
                authorization = self.headers.get('Authorization', '')
                token = authorization[7:].encode() if authorization.startswith('Bearer ') else b''
                session = next((v for k, v in sessions.items() if token and hmac.compare_digest(k.encode(), token)), None)
                if not session:
                    raise Problem('Sign in required.', 401)
                uid = session['user']
                body = {}
                if self.command == 'POST':
                    length = int(self.headers.get('Content-Length', '0'))
                    limit = 6_000_000 if self.path == '/api/import-green-button' else 1_000_000
                    if length < 0 or length > limit:
                        raise Problem('Request too large.', 413)
                    body = json.loads(self.rfile.read(length) or b'{}')
                    if not isinstance(body, dict):
                        raise Problem('JSON object required.')
                path = self.path.split('?')[0]
                if path == '/api/me' and self.command == 'GET':
                    if session.get('role') != 'consumer':
                        raise Problem('Consumer session required.', 403)
                    result = platform.snapshot(uid)
                elif path == '/api/institution' and self.command == 'GET':
                    if session.get('role') != 'analyst':
                        raise Problem('Institution analyst role required.', 403)
                    result = platform.aggregate(session['org'])
                elif path == '/api/coach' and self.command == 'POST':
                    if session.get('role') != 'consumer':
                        raise Problem('Consumer session required.', 403)
                    result = platform.coach(uid)
                elif path.startswith('/api/') and self.command == 'POST':
                    if session.get('role') != 'consumer':
                        raise Problem('Consumer session required.', 403)
                    result = platform.mutate(uid, path[5:], body)
                else:
                    raise Problem('Not found.', 404)
                self.reply(200, result)
            except Problem as e:
                self.reply(e.status, {'error': str(e)})
            except (ValueError, TypeError, KeyError):
                self.reply(400, {'error': 'Invalid request.'})
            except Exception:
                self.reply(500, {'error': 'Request failed. No sensitive details returned.'})
    return Handler


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--demo', action='store_true')
    p.add_argument('--db')
    p.add_argument('--port', type=int, default=8787)
    p.add_argument('--static')
    p.add_argument('--config', help='Private JSON with server environment values; never commit this file.')
    args = p.parse_args()
    if args.config:
        values = json.loads(Path(args.config).read_text())
        for key in ['OLLAMA_HOST', 'OLLAMA_MODEL', 'OLLAMA_API_KEY', 'VERDI_SESSIONS_JSON', 'VERDI_ALLOWED_ORIGINS', 'PLAID_USER', 'PLAID_CLIENT_ID', 'PLAID_SECRET', 'PLAID_ACCESS_TOKEN', 'PLAID_ENV']:
            if values.get(key):
                os.environ[key] = str(values[key])
    sessions = {'verdi-demo-consumer': {'user': 'alex', 'role': 'consumer'}, 'verdi-demo-analyst': {'user': 'analyst', 'role': 'analyst', 'org': 'cascadia'}} if args.demo else json.loads(os.getenv('VERDI_SESSIONS_JSON', '{}'))
    if not sessions:
        raise SystemExit('Live mode requires server-provisioned VERDI_SESSIONS_JSON. Do not embed live tokens in app builds.')
    app = Platform(args.db or ('verdi-demo.sqlite' if args.demo else 'verdi-live.sqlite'), args.demo)
    print(f'Verdi {"synthetic demo" if args.demo else "live pilot"}: http://127.0.0.1:{args.port}')
    ThreadingHTTPServer(('127.0.0.1', args.port), handler(app, sessions, args.static)).serve_forever()
