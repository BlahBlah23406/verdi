"""Synthetic Redmond provider tests. No network, credentials or real endpoints."""
import importlib.util
import os
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

here = Path(__file__).parent
sys.path.insert(0, str(here))
spec = importlib.util.spec_from_file_location('verdi_platform', here/'platform.py')
v = importlib.util.module_from_spec(spec); spec.loader.exec_module(v)
import redmond_demo as rd
from redmond_demo import RedmondDemo


class Clock:
    def __init__(self): self.t = 2_000_000
    def __call__(self): return self.t


class RedmondDemoTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.app = v.Platform(Path(self.tmp.name)/'demo.sqlite', True)
        self.clock = Clock()
        self.demo = RedmondDemo(self.app, 10, self.clock)

    def tearDown(self):
        import gc; gc.collect(); self.tmp.cleanup()

    def src(self, name, demo=None):
        return next(s for s in (demo or self.demo).snapshot('redmond-demo')['demoSources'] if s['id'] == name)

    def count(self, source=None):
        with self.app.db() as c:
            q = 'SELECT count(*) FROM redmond_records' + (' WHERE source=?' if source else '')
            return c.execute(q, (source,) if source else ()).fetchone()[0]

    def authorize_all(self):
        for s in rd.SOURCES:
            self.demo.mutate('redmond-demo', 'demo-authorize', {'source': s})

    def tick(self, n=1):
        for _ in range(n):
            self.demo.run_once(); self.clock.t += 10

    def test_seeded_household_starts_disconnected_and_needs_consent(self):
        snap = self.demo.snapshot('redmond-demo')
        self.assertTrue(snap['redmondDemo'])
        self.assertEqual([s['id'] for s in snap['demoSources']], ['utility', 'orca', 'bank'])
        for s in snap['demoSources']:
            self.assertEqual((s['status'], s['lastSyncedAt'], s['records']), ('disconnected', None, []))
        user = self.app.user('redmond-demo')
        self.assertEqual((user['name'], user['region']), ('Cedar Household', 'Redmond, WA (NWPP)'))
        self.tick(3)
        self.assertEqual(self.count(), 0)
        self.demo.mutate('redmond-demo', 'demo-authorize', {'source': 'utility'})
        self.assertEqual(self.src('utility')['status'], 'waiting')
        self.tick()
        self.assertEqual(self.src('utility')['status'], 'ok')
        self.assertIsNotNone(self.src('utility')['lastSyncedAt'])
        self.assertEqual(self.src('orca')['records'], [])

    def test_interval_controls_simulated_days_without_get(self):
        self.authorize_all()
        self.demo.run_once(); self.demo.run_once()
        with self.app.db() as c:
            self.assertEqual({r[0] for r in c.execute('SELECT sim_day FROM redmond_sources')}, {1})
        self.clock.t += 9; self.demo.run_once()
        self.clock.t += 1; self.demo.run_once()
        with self.app.db() as c:
            self.assertEqual({r[0] for r in c.execute('SELECT sim_day FROM redmond_sources')}, {2})

    def test_utility_distinct_electricity_and_gas_periods(self):
        self.demo.mutate('redmond-demo', 'demo-authorize', {'source': 'utility'})
        self.tick(31)
        with self.app.db() as c:
            rows = c.execute("SELECT kind,unit,id FROM redmond_records WHERE source='utility'").fetchall()
        elec = [r for r in rows if r['kind'] == 'electricity']
        gas = [r for r in rows if r['kind'] == 'gas']
        self.assertEqual(len(elec), 31); self.assertEqual(len(gas), 2)
        self.assertEqual({r['unit'] for r in elec}, {'kWh'}); self.assertEqual({r['unit'] for r in gas}, {'therms'})
        self.assertIn('2026-10-01..2026-10-31', gas[0]['id'])
        details = [r['detail'] for r in self.src('utility')['records']]
        self.assertTrue(any('service period 2026-11-01 to 2026-11-30' in d for d in details))

    def test_orca_taps_have_no_inferred_trip(self):
        self.demo.mutate('redmond-demo', 'demo-authorize', {'source': 'orca'})
        self.tick(7)  # one simulated week; weekend has no taps
        self.assertEqual(self.count('orca'), 10)
        for r in self.src('orca')['records']:
            self.assertTrue(any(st in r['label'] for st in rd.STATIONS))
            self.assertIn('Sound Transit 2 Line', r['detail']); self.assertIn('$3.00', r['detail'])
            self.assertIn('no alighting or distance inferred', r['detail'])
        with self.app.db() as c:
            self.assertEqual(c.execute("SELECT count(*) FROM redmond_records WHERE source='orca' AND kind!='transit_tap'").fetchone()[0], 0)

    def test_bank_uses_plaid_connector_with_pending_replacement_and_retry(self):
        calls = []
        real = rd.fake_plaid_transport
        def spy(fault=None):
            t = real(fault)
            def wrapped(path, body):
                calls.append(body['cursor']); return t(path, body)
            return wrapped
        with patch.object(rd, 'fake_plaid_transport', spy), patch('urllib.request.urlopen', side_effect=AssertionError('network')):
            self.demo.mutate('redmond-demo', 'demo-authorize', {'source': 'bank'})
            self.tick(6)
        self.assertEqual(calls[:4], ['', 'syn-0-p1', 'syn-1', 'syn-1-p1'])
        self.assertIn('syn-3', calls)
        self.assertEqual(calls.count('syn-3'), 2)  # day 4 mutation restarted from the saved cursor
        with self.app.db() as c:
            rows = {r['id']: dict(r) for r in c.execute("SELECT * FROM redmond_records WHERE source='bank'")}
            cursor = c.execute("SELECT cursor FROM redmond_sources WHERE source='bank'").fetchone()[0]
        self.assertEqual(cursor, 'syn-6')
        self.assertEqual(rows['bank:syn-pend-1']['state'], 'replaced')  # kept as evidence, hidden from view
        self.assertEqual(rows['bank:syn-post-1']['state'], 'active')
        self.assertEqual(rows['bank:syn-pend-6']['pending'], 1)
        self.assertEqual(rows['bank:syn-pend-5']['state'], 'replaced')
        self.assertLess(rows['bank:syn-refund-5']['quantity'], 0)
        self.assertEqual(rows['bank:syn-post-4']['quantity'], round(rd._amount(4) * 100) + 25)
        labels = [r['label'] for r in self.src('bank')['records']]
        self.assertFalse(any('syn-pend-1' in l for l in labels))
        details = ' '.join(r['detail'] for r in self.src('bank')['records'])
        self.assertIn('pending', details); self.assertIn('no carbon quantity inferred', details)

    def test_restart_preserves_state_and_does_not_reseed(self):
        self.authorize_all(); self.tick(2)
        before, total = self.demo.snapshot('redmond-demo'), self.count()
        again = RedmondDemo(self.app, 10, self.clock)
        self.assertEqual(again.snapshot('redmond-demo'), before)
        again.run_once()
        self.assertGreater(self.count(), total)
        again.run_once()  # same instant: not due again
        with self.app.db() as c:
            self.assertEqual({r[0] for r in c.execute('SELECT sim_day FROM redmond_sources')}, {3})

    def test_failure_retries_and_reconnect_keeps_evidence(self):
        faults = {}
        demo = RedmondDemo(self.app, 10, self.clock, fault=lambda s: faults.get(s))
        for s in rd.SOURCES:
            demo.mutate('redmond-demo', 'demo-authorize', {'source': s})
        demo.run_once(); self.clock.t += 10
        faults.update(utility='error', bank='error', orca='auth')
        demo.run_once(); self.clock.t += 10
        self.assertEqual(self.src('utility', demo)['status'], 'ok')
        self.assertEqual(self.src('orca', demo)['status'], 'auth_required')
        with self.app.db() as c:
            st = {r['source']: dict(r) for r in c.execute('SELECT * FROM redmond_sources')}
        self.assertEqual((st['utility']['sim_day'], st['utility']['failures']), (1, 1))
        self.assertEqual((st['bank']['cursor'], st['bank']['failures']), ('syn-1', 1))
        faults.clear(); faults['bank'] = 'auth'
        demo.run_once(); self.clock.t += 10
        self.assertEqual(self.src('bank', demo)['status'], 'auth_required')
        self.assertEqual(self.src('utility', demo)['status'], 'ok')
        faults.clear()
        orca_rows = self.count('orca')
        demo.run_once()  # auth_required sources stay paused
        self.assertEqual(self.count('orca'), orca_rows)
        self.clock.t += 10
        demo.mutate('redmond-demo', 'demo-authorize', {'source': 'orca'})
        demo.mutate('redmond-demo', 'demo-authorize', {'source': 'bank'})
        self.assertEqual(self.src('orca', demo)['status'], 'waiting')
        demo.run_once()
        with self.app.db() as c:
            st = {r['source']: dict(r) for r in c.execute('SELECT * FROM redmond_sources')}
            gens = {r[0] for r in c.execute("SELECT generation FROM redmond_records WHERE source='orca'")}
        self.assertEqual((st['orca']['sim_day'], st['orca']['generation']), (2, 2))
        self.assertEqual(st['bank']['cursor'], 'syn-2')
        self.assertEqual(gens, {1, 2})  # first-generation evidence was not rewritten

    def test_disconnect_and_expire(self):
        self.authorize_all(); self.tick()
        n = self.count()
        self.demo.mutate('redmond-demo', 'demo-disconnect', {'source': 'utility'})
        snap = self.demo.mutate('redmond-demo', 'demo-expire', {'source': 'bank'})
        self.assertEqual(next(s for s in snap['demoSources'] if s['id'] == 'bank')['status'], 'auth_required')
        self.assertEqual(self.src('utility')['status'], 'disconnected')
        self.assertTrue(self.src('utility')['records'])  # retained
        self.tick()
        with self.app.db() as c:
            st = {r['source']: r['sim_day'] for r in c.execute('SELECT * FROM redmond_sources')}
        self.assertEqual(st, {'utility': 1, 'orca': 2, 'bank': 1})
        self.assertEqual(self.count(), n + 2)
        with self.assertRaises(ValueError):
            self.demo.mutate('redmond-demo', 'demo-expire', {'source': 'utility'})

    def test_duplicate_and_concurrent_runs_apply_once(self):
        self.authorize_all()
        demos = [RedmondDemo(self.app, 10, self.clock) for _ in range(4)]
        threads = [threading.Thread(target=d.run_once) for d in demos]
        [t.start() for t in threads]; [t.join() for t in threads]
        with self.app.db() as c:
            self.assertEqual({r[0] for r in c.execute('SELECT sim_day FROM redmond_sources')}, {1})
        n = self.count()
        with self.app.db() as c:  # replay a stale cursor: inserts stay idempotent
            c.execute("UPDATE redmond_sources SET sim_day=0,cursor='',next_due=0")
        self.demo.run_once()
        self.assertEqual(self.count(), n)
        self.demo.mutate('redmond-demo', 'demo-authorize', {'source': 'utility'})  # already active: no-op
        with self.app.db() as c:
            self.assertEqual(c.execute("SELECT generation FROM redmond_sources WHERE source='utility'").fetchone()[0], 1)

    def test_account_isolation_and_validation(self):
        self.authorize_all(); self.tick(2)
        self.assertEqual(self.demo.snapshot('alex'), {})
        with self.assertRaises(ValueError):
            self.demo.mutate('alex', 'demo-authorize', {'source': 'utility'})
        for action, body in [('demo-reset', {'source': 'utility'}), ('demo-authorize', {'source': 'gym'}),
                             ('demo-authorize', {}), ('demo-authorize', None), ('demo-authorize', 'utility')]:
            with self.assertRaises(ValueError):
                self.demo.mutate('redmond-demo', action, body)
        with self.app.db() as c:
            self.assertEqual(c.execute("SELECT count(*) FROM evidence WHERE user='redmond-demo'").fetchone()[0], 0)
            self.assertEqual(c.execute("SELECT count(*) FROM transactions WHERE user='redmond-demo'").fetchone()[0], 0)
            self.assertEqual(c.execute("SELECT count(DISTINCT user) FROM redmond_records").fetchone()[0], 1)
            self.assertEqual(c.execute("SELECT org FROM users WHERE id='redmond-demo'").fetchone()[0], 'redmond-demo')
        self.assertEqual(self.app.user('alex')['name'], 'Alex Morgan')

    def test_no_credentials_needed(self):
        with patch.dict(os.environ, {}, clear=True):
            self.authorize_all(); self.tick(2)
        self.assertEqual(self.src('bank')['status'], 'ok')


if __name__ == '__main__': unittest.main()
