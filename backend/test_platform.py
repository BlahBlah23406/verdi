"""Behavioral tests of reward integrity, tenant boundaries and durable demo state."""
import importlib.util
import json
from pathlib import Path
import tempfile
import threading
import unittest
import urllib.request
import urllib.error
from http.server import ThreadingHTTPServer
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('verdi_platform', Path(__file__).with_name('platform.py'))
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)


class PlatformTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name)/'demo.sqlite'
        self.app = v.Platform(self.path, True)
        self.uid = 'alex'

    def tearDown(self):
        self.tmp.cleanup()

    def test_roundup_edge_cases_and_integer_money(self):
        for cents, expected in [(1200,0),(1201,99),(1299,1),(0,0),(-20,0)]:
            self.assertEqual(v.round_up(cents), expected)
        self.assertEqual(v.round_up(1245,pending=True),0)
        self.assertEqual(v.round_up(1245,refund=True),0)
        with self.assertRaises(v.Problem): v.round_up(12.45)

    def test_seed_persists_and_never_duplicates(self):
        before = self.app.snapshot(self.uid)
        after = v.Platform(self.path,True).snapshot(self.uid)
        self.assertEqual(before,after)
        self.assertEqual(len(before['activities']),122)

    def test_database_modes_cannot_mix(self):
        with self.assertRaises(v.Problem): v.Platform(self.path,False)

    def test_live_starts_empty_and_has_no_demo_connections(self):
        app=v.Platform(Path(self.tmp.name)/'live.sqlite')
        with self.assertRaises(v.Problem): app.snapshot(self.uid)

    def test_sync_review_and_replay_idempotency(self):
        self.assertEqual(self.app.mutate(self.uid,'sync',{})['added'],1)
        self.assertEqual(self.app.mutate(self.uid,'sync',{})['added'],0)
        item=next(r for r in self.app.snapshot(self.uid)['activities'] if r['status']=='pending')
        self.app.mutate(self.uid,'review',{'id':item['id'],'status':'confirmed'})
        self.assertEqual(self.app.mutate(self.uid,'sync',{})['added'],0)
        self.assertEqual(next(r for r in self.app.snapshot(self.uid)['activities'] if r['id']==item['id'])['status'],'confirmed')

    def test_import_is_atomic_and_rejects_conflicting_correction(self):
        self.app.mutate(self.uid,'sync',{})
        with self.assertRaises(v.Problem):
            self.app.ingest(self.uid,'transport',[{'id':'receipt-oct31','day':'2026-10-31','kind':'bus','quantity':99}])
        with self.assertRaises(v.Problem):
            self.app.ingest(self.uid,'utility',[{'id':'new','day':'2026-10-10','kind':'electricity','quantity':12}, {'id':'bad','day':'2026-02-31','kind':'electricity','quantity':12}])
        self.assertFalse(any(r['id']=='utility:new' for r in self.app.snapshot(self.uid)['activities']))

    def test_nonfinite_negative_and_unsupported_imports(self):
        for quantity in [0,-1,float('nan'),float('inf'),True,'10']:
            with self.assertRaises(v.Problem):
                self.app.ingest(self.uid,'utility',[{'id':'x','day':'2026-10-10','kind':'electricity','quantity':quantity}])
        with self.assertRaises(v.Problem):
            self.app.ingest(self.uid,'bank',[{'id':'flight','day':'2026-10-10','kind':'flight','quantity':300}])

    def test_nested_device_reading_is_supporting_not_additive(self):
        before=sum(self.app.snapshot(self.uid)['categories'].values())
        self.app.ingest(self.uid,'iot',[{'id':'charger','day':'2026-10-10','kind':'electricity','quantity':12}])
        after=self.app.snapshot(self.uid)
        self.assertEqual(sum(after['categories'].values()),before)
        self.assertEqual(next(r for r in after['activities'] if r['id']=='iot:charger')['status'],'supporting')
        with self.assertRaises(v.Problem):
            self.app.ingest(self.uid,'bank',[{'id':'fare','day':'2026-10-10','kind':'car','quantity':12}])

    def test_reward_rejects_incomparable_factor_versions(self):
        with self.app.db() as c:
            c.execute("UPDATE evidence SET version='new-method' WHERE user='alex' AND day='2026-10-01'")
        with self.assertRaises(v.Problem): self.app.monthly_reward(self.uid,'2026-10')

    def test_disconnect_stops_sync_and_keeps_history(self):
        count=len(self.app.snapshot(self.uid)['activities'])
        self.app.mutate(self.uid,'connection',{'provider':'transport','enabled':False})
        with self.assertRaises(v.Problem): self.app.mutate(self.uid,'sync',{})
        self.assertEqual(len(self.app.snapshot(self.uid)['activities']),count)

    def test_reward_idempotent_and_redemption_cannot_overdraw(self):
        r=self.app.monthly_reward(self.uid,'2026-10')
        self.assertGreater(r['points'],200)
        self.app.monthly_reward(self.uid,'2026-10')
        self.assertEqual(self.app.snapshot(self.uid)['points'],r['points'])
        request={'reward':'transit-pass','key':'one-request'}
        self.app.mutate(self.uid,'redeem',request)
        self.app.mutate(self.uid,'redeem',request)
        self.assertEqual(self.app.snapshot(self.uid)['points'],r['points']-200)
        with self.assertRaises(v.Problem):
            self.app.mutate(self.uid,'redeem',{'reward':'community','key':'one-request'})
        for n in range(30):
            try: self.app.mutate(self.uid,'redeem',{'reward':'transit-pass','key':str(n)})
            except v.Problem: pass
        self.assertGreaterEqual(self.app.snapshot(self.uid)['points'],0)

    def test_missing_day_and_incomplete_period_cannot_earn(self):
        with self.app.db() as c:
            c.execute("DELETE FROM evidence WHERE user='alex' AND day='2026-10-01'")
        with self.assertRaises(v.Problem): self.app.monthly_reward(self.uid,'2026-10')
        with self.assertRaises(v.Problem): self.app.monthly_reward(self.uid,'2099-01')

    def test_roundups_cap_and_replay(self):
        for _ in range(3): self.app.mutate(self.uid,'roundups',{'capCents':500})
        self.assertEqual(self.app.snapshot(self.uid)['pledgedCents'],500)

    def test_consent_changes_aggregates_and_small_cohorts_suppress(self):
        before=self.app.aggregate('cascadia')
        self.assertEqual(before['consentingParticipants'],20)
        self.app.mutate(self.uid,'consent',{'enabled':False})
        after=self.app.aggregate('cascadia')
        self.assertEqual(after['consentingParticipants'],19)
        self.assertLess(sum(r['kg'] for r in after['rows']),sum(r['kg'] for r in before['rows']))
        self.assertNotIn('name',json.dumps(after))
        with self.app.db() as c: c.execute("UPDATE users SET consent=0 WHERE org='cascadia' AND id!='alex'")
        self.assertTrue(self.app.aggregate('cascadia')['suppressed'])

    def test_ollama_only_receives_calculated_facts_and_fallback(self):
        with patch.dict('os.environ',{'OLLAMA_MODEL':'test-model','OLLAMA_HOST':'https://ollama.com','OLLAMA_API_KEY':'test-only'}):
            with patch.object(v.urllib.request,'urlopen',side_effect=TimeoutError):
                response=self.app.coach(self.uid)
            self.assertIn('AI unavailable',response['mode'])
            self.assertGreater(response['facts']['potentialSavingKg'],0)
        with patch.dict('os.environ',{'OLLAMA_MODEL':'test-model','OLLAMA_API_KEY':'test-only'}):
            class Response:
                def __enter__(self): return self
                def __exit__(self,*_): pass
                def read(self,*_): return b'{"message":{"content":"Compare a bus journey."}}'
            with patch.object(v.urllib.request,'urlopen',return_value=Response()) as call:
                result=self.app.coach(self.uid)
                sent=json.loads(call.call_args.args[0].data)
                self.assertNotIn('Alex',json.dumps(sent))
                self.assertNotIn('merchant',json.dumps(sent))
                self.assertEqual(result['mode'],'Ollama AI explanation')

    def test_randomized_roundup_invariants(self):
        import random
        rng=random.Random(91)
        for _ in range(2000):
            cents=rng.randint(-1000000,1000000)
            value=v.round_up(cents)
            self.assertGreaterEqual(value,0)
            self.assertLess(value,100)
            if cents>0: self.assertEqual((cents+value)%100,0)

    def test_concurrent_redemptions_preserve_nonnegative_balance(self):
        from concurrent.futures import ThreadPoolExecutor
        self.app.monthly_reward(self.uid,'2026-10')
        def redeem(n):
            try: return self.app.mutate(self.uid,'redeem',{'reward':'transit-pass','key':str(n)})
            except v.Problem: return None
        with ThreadPoolExecutor(max_workers=8) as pool: list(pool.map(redeem,range(20)))
        self.assertEqual(self.app.snapshot(self.uid)['points'],65)

    def test_http_auth_roles_and_tenant_identity(self):
        sessions={'consumer':{'user':'alex','role':'consumer'},'analyst':{'user':'x','role':'analyst','org':'cascadia'}}
        server=ThreadingHTTPServer(('127.0.0.1',0),v.handler(self.app,sessions))
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        def request(path,token,body=None):
            req=urllib.request.Request(f'http://127.0.0.1:{server.server_port}/api/{path}',headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'},data=json.dumps(body).encode() if body is not None else None)
            return urllib.request.urlopen(req)
        try:
            for path,token,status in [('me','missing',401),('institution','consumer',403),('me','analyst',403)]:
                with self.assertRaises(urllib.error.HTTPError) as err: request(path,token)
                self.assertEqual(err.exception.code,status)
            with request('institution','analyst') as response:
                self.assertEqual(json.load(response)['organization'],'cascadia')
            with request('consent','consumer',{'enabled':False,'user':'evergreen-01'}) as response: self.assertEqual(response.status,200)
            self.assertEqual(self.app.user('evergreen-01')['consent'],1)
        finally:
            server.shutdown();server.server_close();thread.join()


if __name__=='__main__': unittest.main()
