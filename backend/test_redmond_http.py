"""Exercise the standalone regional server with no provider credentials."""
import json
import selectors
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.error
import urllib.request
from pathlib import Path


class RedmondHttpTest(unittest.TestCase):
    def setUp(self):
        folder = self.enterContext(tempfile.TemporaryDirectory())
        self.database = Path(folder) / 'cedar.sqlite'
        self.start_server()

    def start_server(self):
        server = subprocess.Popen([
            sys.executable, '-u', str(Path(__file__).with_name('platform.py')),
            '--redmond-demo', '--db', str(self.database),
            '--demo-interval', '1', '--port', '0',
        ], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        self.addCleanup(self.stop_server, server)
        with selectors.DefaultSelector() as selector:
            selector.register(server.stdout, selectors.EVENT_READ)
            self.assertTrue(selector.select(timeout=5), 'Demo server did not start.')
        line = server.stdout.readline()
        self.assertIn('http://127.0.0.1:', line, line)
        self.base = line.split()[-1]
        self.server = server

    @staticmethod
    def stop_server(server):
        if server.poll() is None:
            server.terminate()
            server.wait(timeout=5)
        server.stdout.close()

    def request(self, path, body=None, token='verdi-redmond-demo'):
        request = urllib.request.Request(
            f'{self.base}/api/{path}',
            headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
            data=None if body is None else json.dumps(body).encode(),
        )
        with urllib.request.urlopen(request, timeout=3) as response:
            return json.load(response)

    def sources(self, token='verdi-redmond-demo'):
        return {item['id']: item for item in self.request('me', token=token)['demoSources']}

    def wait_for_bank_sync(self):
        deadline = time.monotonic() + 4
        while time.monotonic() < deadline:
            bank = self.sources()['bank']
            if bank['status'] == 'ok':
                return bank
            time.sleep(.1)
        self.fail('Bank source never reached automatic sync.')

    def test_demo_routes_and_persistence(self):
        with self.assertRaises(urllib.error.HTTPError) as invalid:
            self.request('me', token='verdi-demo-consumer')
        self.assertEqual(invalid.exception.code, 401)
        with self.assertRaises(urllib.error.HTTPError) as unsupported:
            self.request('sync', {})
        self.assertEqual(unsupported.exception.code, 404)
        snapshot = self.request('me')
        self.assertTrue(snapshot['redmondDemo'])
        self.assertFalse(snapshot['aiAvailable'])
        self.assertEqual(snapshot['user']['name'], 'Cedar Household')
        sources = self.sources()
        self.assertEqual(set(sources), {'utility', 'orca', 'bank'})
        self.assertTrue(all(source['status'] == 'disconnected' and not source['records']
                            for source in sources.values()))
        self.request('demo-authorize', {'source': 'bank'})
        bank = self.wait_for_bank_sync()
        self.assertTrue(bank['records'])
        self.request('demo-expire', {'source': 'bank'})
        frozen = self.sources()['bank']
        self.assertEqual(frozen['status'], 'auth_required')
        self.assertTrue(frozen['records'])
        self.stop_server(self.server)

        self.start_server()
        self.assertEqual(self.sources()['bank'], frozen)
        self.request('demo-authorize', {'source': 'bank'})
        self.assertTrue(self.wait_for_bank_sync()['lastSyncedAt'])
        self.request('demo-disconnect', {'source': 'bank'})
        disconnected = self.sources()['bank']
        self.assertEqual(disconnected['status'], 'disconnected')
        self.assertTrue(disconnected['records'])

    def test_regional_households_have_separate_consent_and_history(self):
        profiles = self.request('demo/households', token='')['households']
        self.assertEqual({p['id'] for p in profiles},
                         {'redmond', 'bellevue', 'sammamish', 'seattle', 'renton', 'tacoma'})
        tokens = {p['id']: self.request(f'demo/session?household={p["id"]}', token='')['token']
                  for p in profiles}
        self.assertEqual(len(set(tokens.values())), len(profiles))
        self.assertEqual(self.request('demo/session', token='')['token'], tokens['redmond'])
        for invalid in ('unavailable', '', 'redmond&household=seattle'):
            with self.assertRaises(urllib.error.HTTPError) as result:
                self.request(f'demo/session?household={invalid}', token='')
            self.assertEqual(result.exception.code, 404)

        for profile in profiles:
            token = tokens[profile['id']]
            self.assertEqual(self.request('me', token=token)['demoHousehold'], profile)
            self.assertTrue(all(item['status'] == 'disconnected' for item in self.sources(token).values()))

        seattle = tokens['seattle']
        with self.assertRaises(urllib.error.HTTPError) as result:
            self.request('demo-authorize', {'sources': ['utility', 'unavailable']}, token=seattle)
        self.assertEqual(result.exception.code, 400)
        self.assertEqual(self.sources(seattle)['utility']['status'], 'disconnected')

        enabled = {
            'bellevue': ['utility', 'orca', 'bank'], 'sammamish': ['orca'],
            'seattle': ['utility', 'orca', 'bank'], 'renton': ['orca'], 'tacoma': ['utility', 'orca'],
        }
        for city, sources in enabled.items():
            self.request('demo-authorize', {'sources': sources}, token=tokens[city])
        # Let the server tick with no requests or open browser.
        time.sleep(1.5)
        records = {city: self.sources(token) for city, token in tokens.items()}
        for city, items in records.items():
            for source, item in items.items():
                active = source in enabled.get(city, [])
                self.assertEqual(item['status'], 'ok' if active else 'disconnected', (city, source))
                self.assertEqual(bool(item['records']), active, (city, source))

        def history(city, source):
            return ' '.join(f'{r["label"]} {r["detail"]}' for r in records[city][source]['records'])

        self.assertIn('therms', history('bellevue', 'utility'))
        self.assertIn('kWh', history('seattle', 'utility'))
        self.assertNotIn('therms', history('seattle', 'utility'))
        self.assertNotEqual(history('bellevue', 'bank'), history('seattle', 'bank'))
        for city, transit in [('bellevue', '2 Line'), ('sammamish', '269'), ('seattle', '1 Line'),
                              ('renton', 'RapidRide F'), ('tacoma', 'T Line')]:
            self.assertIn(transit, history(city, 'orca'))

        self.request('demo-expire', {'source': 'bank'}, token=seattle)
        frozen = self.sources(seattle)['bank']
        self.assertEqual(frozen['status'], 'auth_required')
        self.assertEqual(self.sources(tokens['bellevue'])['bank']['status'], 'ok')
        self.stop_server(self.server)
        self.start_server()
        seattle = self.request('demo/session?household=seattle', token='')['token']
        self.assertEqual(self.sources(seattle)['bank'], frozen)

    def test_optional_sources_and_separate_tacoma_meters(self):
        def session(city):
            return self.request(f'demo/session?household={city}', token='')['token']

        fir, hemlock, madrona = map(session, ('sammamish', 'tacoma', 'seattle'))
        self.assertTrue({'vehicle', 'charger'} <= self.sources(fir).keys())
        self.assertTrue({'utility', 'gas'} <= self.sources(hemlock).keys())
        self.assertEqual(set(self.sources(madrona)), {'utility', 'orca', 'bank'})
        with self.assertRaises(urllib.error.HTTPError) as result:
            self.request('demo-authorize', {'sources': ['utility', 'charger']}, token=madrona)
        self.assertEqual(result.exception.code, 400)
        self.assertEqual(self.sources(madrona)['utility']['status'], 'disconnected')

        self.request('demo-authorize', {'sources': ['vehicle', 'charger']}, token=fir)
        self.request('demo-authorize', {'sources': ['utility', 'gas']}, token=hemlock)
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            fir_sources = self.sources(fir)
            hemlock_sources = self.sources(hemlock)
            if all(items[key]['records'] for items, key in (
                (fir_sources, 'vehicle'), (fir_sources, 'charger'),
                (hemlock_sources, 'utility'), (hemlock_sources, 'gas'),
            )):
                break
            time.sleep(.1)
        else:
            self.fail('The server did not deliver all four source histories.')

        self.assertIn('kWh', json.dumps(hemlock_sources['utility']['records']))
        self.assertNotIn('therms', json.dumps(hemlock_sources['utility']['records']))
        self.assertIn('therms', json.dumps(hemlock_sources['gas']['records']))
        self.assertIn('kWh', json.dumps(fir_sources['charger']['records']))
        self.assertIn('km', json.dumps(fir_sources['vehicle']['records']))
        self.assertFalse(fir_sources['charger']['addsToTotals'])
        self.assertEqual(fir_sources['charger']['overlaps'], 'utility')
        self.assertEqual(fir_sources['utility']['status'], 'disconnected')
        self.assertFalse(self.request('me', token=fir)['activities'])
        self.request('demo-disconnect', {'source': 'gas'}, token=hemlock)
        disconnected = self.sources(hemlock)
        self.assertEqual(disconnected['gas']['status'], 'disconnected')
        self.assertTrue(disconnected['gas']['records'])
        self.assertEqual(disconnected['utility']['status'], 'ok')


if __name__ == '__main__':
    unittest.main()
