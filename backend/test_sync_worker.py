"""Recurring sync tests. No network: transport is always patched."""
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
import connectors
from sync_worker import SyncWorker

ENV = {'PLAID_USER': 'u1', 'PLAID_CLIENT_ID': 'c', 'PLAID_SECRET': 's', 'PLAID_ACCESS_TOKEN': 't'}
OK = {'added': [{'transaction_id': 'a', 'date': '2026-11-01', 'amount': 5.25, 'iso_currency_code': 'USD'}], 'next_cursor': 'c1', 'has_more': False}


class Clock:
    t = 1_000_000
    def __call__(self): return self.t


class SyncTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.app = v.Platform(Path(self.tmp.name)/'live.sqlite', False)
        with self.app.db() as c:
            c.execute("INSERT INTO users(id,name,org,region) VALUES('u1','U','o','r')")
            c.execute("INSERT INTO connections VALUES('u1','bank',1)")
        self.env = patch.dict(os.environ, ENV); self.env.start()
        self.clock = Clock()
        self.w = SyncWorker(self.app, 3600, 7200, self.clock)

    def tearDown(self):
        self.env.stop(); self.tmp.cleanup()

    def failures(self):
        with self.app.db() as connection:
            return connection.execute("SELECT failures FROM sync_state WHERE user='u1'").fetchone()[0]

    def run_with(self, payload):
        with patch.object(connectors.PlaidConnector, '_post', side_effect=lambda *a: payload) as m:
            return self.w.run_once(), m

    def bank(self):
        return next(c for c in self.app.snapshot('u1')['connections'] if c['provider'] == 'bank')

    def test_started_worker_syncs_without_any_client_request(self):
        completed = threading.Event()
        self.app = v.Platform(Path(self.tmp.name) / 'live.sqlite')
        worker = SyncWorker(self.app, clock=self.clock)
        run_once = worker.run_once

        def tick():
            try:
                run_once()
            finally:
                completed.set()

        with patch.object(worker, 'run_once', side_effect=tick):
            with patch.object(connectors.PlaidConnector, '_post', return_value=OK) as post:
                worker.start()
                try:
                    self.assertTrue(completed.wait(2))
                    post.assert_called_once()
                finally:
                    worker.stop()
        reopened = v.Platform(Path(self.tmp.name) / 'live.sqlite')
        self.assertEqual(reopened.sync_public('u1')['syncStatus'], 'ok')
        self.assertEqual(reopened.due_bank_users(self.clock.t, 3600), [])

    def test_success_exposes_status_and_timestamp_then_waits_interval(self):
        r, _ = self.run_with(OK)
        self.assertEqual(r, {'u1': 'ok'})
        self.assertEqual(self.bank()['syncStatus'], 'ok')
        self.assertTrue(self.bank()['lastSyncedAt'].endswith('Z'))
        self.clock.t += 100
        r, m = self.run_with(OK)
        self.assertEqual(r, {}); m.assert_not_called()
        self.clock.t += 3600
        self.assertEqual(self.run_with({**OK, 'added': [], 'next_cursor': 'c2'})[0], {'u1': 'ok'})

    def test_failure_retries_with_backoff_keeps_last_success(self):
        self.run_with(OK); last = self.bank()['lastSyncedAt']
        self.clock.t += 3600
        self.assertEqual(self.run_with({'error_code': 'INTERNAL_SERVER_ERROR'})[0], {'u1': 'retrying'})
        self.assertEqual(self.bank()['lastSyncedAt'], last)
        self.clock.t += 3600 + 30   # failed at t; first retry backoff 60s but interval gate applies
        self.assertEqual(self.run_with({'error_code': 'INTERNAL_SERVER_ERROR'})[0], {'u1': 'retrying'})
        self.assertEqual(self.failures(), 2)
        self.clock.t += 3600
        self.assertEqual(self.run_with(OK)[0], {'u1': 'ok'})
        self.assertEqual(self.failures(), 0)

    def test_auth_required_stops_until_reconnect(self):
        self.assertEqual(self.run_with({'error_code': 'ITEM_LOGIN_REQUIRED', 'error_message': 'secret detail'})[0], {'u1': 'auth_required'})
        self.assertNotIn('secret', str(self.app.snapshot('u1')))
        self.clock.t += 10**6
        r, m = self.run_with(OK); self.assertEqual(r, {}); m.assert_not_called()
        self.app.mutate('u1', 'connection', {'provider': 'bank', 'enabled': True})
        self.assertEqual(self.run_with(OK)[0], {'u1': 'ok'})

    def test_disconnect_and_reconnect_invalidates_in_flight_response(self):
        def respond(*args):
            for enabled in [False, True]:
                self.app.mutate('u1', 'connection', {'provider': 'bank', 'enabled': enabled})
            return OK
        with patch.object(connectors.PlaidConnector, '_post', side_effect=respond):
            self.assertEqual(self.w.run_once(), {'u1': 'idle'})
        self.assertIsNone(self.bank()['lastSyncedAt'])
        with self.app.db() as connection:
            self.assertEqual(connection.execute('SELECT COUNT(*) FROM transactions').fetchone()[0], 0)
        self.assertEqual(self.run_with(OK)[0], {'u1': 'ok'})

    def test_disconnect_is_respected(self):
        self.app.mutate('u1', 'connection', {'provider': 'bank', 'enabled': False})
        r, m = self.run_with(OK); self.assertEqual(r, {}); m.assert_not_called()
        self.assertEqual(self.bank()['syncStatus'], 'disconnected')

    def test_demo_isolation_and_activation(self):
        demo = v.Platform(Path(self.tmp.name)/'demo.sqlite', True)
        with self.assertRaises(ValueError): SyncWorker(demo)
        self.assertIsNone(SyncWorker.from_env(demo))
        with patch.dict(os.environ, {'VERDI_SYNC_ENABLED': ''}): self.assertIsNone(SyncWorker.from_env(self.app))
        with patch.dict(os.environ, {'VERDI_SYNC_ENABLED': '1'}): self.assertIsNotNone(SyncWorker.from_env(self.app))
        self.assertEqual(demo.due_bank_users(10**9, 60), [])

    def test_offline_ui_independence(self):
        """Snapshot reads local state only; a failing provider never blocks it."""
        with patch.object(connectors.PlaidConnector, '_post', side_effect=OSError('offline')) as m:
            self.assertEqual(self.w.run_once(), {'u1': 'retrying'})
            m.reset_mock()
            snap = self.app.snapshot('u1')
            m.assert_not_called()
        self.assertEqual(self.bank()['syncStatus'], 'retrying')
        self.assertIsNone(snap['connections'][0]['lastSyncedAt'])


if __name__ == '__main__':
    unittest.main()
