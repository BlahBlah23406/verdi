"""Exercise the Redmond pilot through the same authenticated HTTP routes as Flutter."""
from datetime import date, datetime, time, timedelta
import json
from pathlib import Path
import tempfile
import threading
import unittest
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo

from http.server import ThreadingHTTPServer
from test_platform import v


def export(day, *, omit_last=False, watt_hours=500):
    zone = ZoneInfo('America/Los_Angeles')
    start = int(datetime.combine(day, time.min, zone).timestamp())
    end = int(datetime.combine(day + timedelta(days=1), time.min, zone).timestamp())
    starts = range(start, end - (3600 if omit_last else 0), 3600)
    intervals = ''.join(
        f'<e:IntervalReading><e:timePeriod><e:start>{i}</e:start><e:duration>3600</e:duration>'
        f'</e:timePeriod><e:value>{watt_hours}</e:value></e:IntervalReading>' for i in starts
    )
    return f'''<feed xmlns="http://www.w3.org/2005/Atom" xmlns:e="http://naesb.org/espi">
      <entry><link rel="self" href="/MeterReading/1"/><link rel="related" href="/ReadingType/1"/>
        <content><e:MeterReading/></content></entry>
      <entry><link rel="self" href="/ReadingType/1"/><content><e:ReadingType>
        <e:accumulationBehaviour>4</e:accumulationBehaviour><e:uom>72</e:uom>
        <e:flowDirection>1</e:flowDirection><e:powerOfTenMultiplier>0</e:powerOfTenMultiplier>
      </e:ReadingType></content></entry>
      <entry><link rel="up" href="/MeterReading/1/IntervalBlock"/><content><e:IntervalBlock>
        {intervals}
      </e:IntervalBlock></content></entry>
    </feed>'''


class GreenButtonTests(unittest.TestCase):
    def test_day_boundaries_and_unit_validation(self):
        from green_button import daily_readings

        for day, expected in [(date(2025, 3, 9), 11.5), (date(2025, 11, 2), 12.5)]:
            with self.subTest(day=day):
                readings, skipped = daily_readings(export(day), 'America/Los_Angeles')
                self.assertEqual(readings[0]['quantity'], expected)
                self.assertEqual(skipped, 0)
        for xml in (export(day, omit_last=True), export(day).replace('>72<', '>169<'),
                    '<!DOCTYPE feed>' + export(day)):
            with self.assertRaises(ValueError):
                daily_readings(xml, 'America/Los_Angeles')

    def test_live_import_review_replay_overlap_and_consent(self):
        with tempfile.TemporaryDirectory() as directory:
            db = Path(directory) / 'pilot.sqlite'
            app = v.Platform(db)
            with app.db() as conn:
                conn.execute('INSERT INTO users VALUES(?,?,?,?,0)',
                             ('user', 'Redmond tester', 'cohort', v.REGIONS['redmond']))
                conn.execute('INSERT INTO pilot_settings VALUES(?,?)',
                             ('user', 'America/Los_Angeles'))
                conn.execute("INSERT INTO connections VALUES('user','utility',0)")
            sessions = {'consumer': {'user': 'user', 'role': 'consumer'},
                        'analyst': {'user': 'analyst', 'role': 'analyst', 'org': 'cohort'}}
            server = ThreadingHTTPServer(('127.0.0.1', 0), v.handler(app, sessions))
            thread = threading.Thread(target=server.serve_forever)
            thread.start()

            def request(route, body=None, *, token='consumer'):
                data = None if body is None else json.dumps(body).encode()
                req = Request(f'http://127.0.0.1:{server.server_port}/api/{route}', data=data,
                              headers={'Authorization': 'Bearer ' + token})
                with urlopen(req, timeout=5) as response:
                    return json.load(response)

            try:
                day = date(2025, 11, 2)
                payload = {'xml': export(day)}
                for token in ('consumer', 'analyst'):
                    with self.assertRaises(HTTPError) as error:
                        request('import-green-button', payload, token=token)
                    self.assertEqual(error.exception.code, 403)
                request('connection', {'provider': 'utility', 'enabled': True})
                self.assertEqual(request('import-green-button', payload)['added'], 1)
                self.assertEqual(request('import-green-button', payload)['duplicates'], 1)
                row, = request('me')['activities']
                self.assertEqual(row['status'], 'pending')
                self.assertEqual(row['version'], v.NORTHWEST_VERSION)
                self.assertAlmostEqual(row['kg'], 12.5 * v.NORTHWEST_KG_PER_KWH)
                request('review', {'id': row['id'], 'status': 'confirmed'})
                with self.assertRaises(HTTPError) as conflict:
                    request('import', {'provider': 'utility', 'records': [
                        {'id': 'csv', 'day': day.isoformat(), 'kind': 'electricity', 'quantity': 12.5},
                    ]})
                self.assertEqual(conflict.exception.code, 409)
                request('connection', {'provider': 'utility', 'enabled': False})
                with self.assertRaises(HTTPError) as disabled:
                    request('import-green-button', payload)
                self.assertEqual(disabled.exception.code, 403)
                self.assertEqual(v.Platform(db).snapshot('user')['activities'][0]['status'], 'confirmed')
                self.assertTrue(request('institution', token='analyst')['suppressed'])
            finally:
                server.shutdown()
                server.server_close()
                thread.join()
