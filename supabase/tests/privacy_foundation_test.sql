-- Run against local Supabase after `supabase db reset`: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(17);

insert into auth.users(id, email) values
 ('10000000-0000-0000-0000-000000000001', 'owner@example.invalid'),
 ('10000000-0000-0000-0000-000000000002', 'member@example.invalid'),
 ('10000000-0000-0000-0000-000000000003', 'outsider@example.invalid');

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
insert into public.ledger_vaults values(auth.uid(),repeat('c',64));
select throws_ok($$insert into public.ledger_vaults values(auth.uid(),repeat('d',64))$$,
 '23505',null,'only one device key can claim the account vault');
select lives_ok($$insert into public.activity_ledger(user_id,key_token,record_token,version,nonce,ciphertext,mac)
 values(auth.uid(),repeat('c',64),repeat('a',64),1,repeat('A',16),'dGVzdA==',repeat('A',22)||'==')$$,
 'owner can append ciphertext');
select throws_ok($$insert into public.activity_ledger(user_id,key_token,record_token,version,nonce,ciphertext,mac)
 values('10000000-0000-0000-0000-000000000002',repeat('c',64),repeat('b',64),1,repeat('A',16),'dGVzdA==',repeat('A',22)||'==')$$,
 '42501',null,'cannot write another user ledger');
select throws_ok($$insert into public.activity_ledger(user_id,key_token,record_token,version,nonce,ciphertext,mac)
 values(auth.uid(),repeat('d',64),repeat('b',64),1,repeat('A',16),'dGVzdA==',repeat('A',22)||'==')$$,
 '23503',null,'ciphertext must use the account vault key token');
select throws_ok($$update public.activity_ledger set ciphertext='YWJjZA=='$$,
 '42501',null,'ledger is immutable');
select public.create_organization('Privacy test') as organization_id \gset
select lives_ok(format('select public.add_organization_member(%L,%L)', :'organization_id',
 '10000000-0000-0000-0000-000000000002'),'owner can add intended existing account');

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
select is((select count(*)::integer from public.activity_ledger),0,'membership does not reveal owner ledger');
select is((select count(*)::integer from public.ledger_vaults),0,'member cannot see owner vault');
select is((select count(*)::integer from public.organizations),1,'member can see own organization');
select throws_ok(format('select public.add_organization_member(%L,%L)', :'organization_id',
 '10000000-0000-0000-0000-000000000003'),'42501',null,'member cannot add arbitrary accounts');
select is((select count(*)::integer from public.organization_members),1,'member cannot list other members');

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
select is((select count(*)::integer from public.organizations),0,'outsider sees no organization');
select throws_ok(format('select public.add_organization_member(%L,auth.uid())', :'organization_id'),
 '42501',null,'outsider cannot self join');

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
select lives_ok(format('select public.remove_organization_member(%L,auth.uid())', :'organization_id'),
 'member can withdraw membership');
select is((select count(*)::integer from public.organizations),0,'withdrawal immediately removes visibility');

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select lives_ok($$delete from public.ledger_vaults where user_id=auth.uid()$$,'owner can delete cloud vault');
select is((select count(*)::integer from public.activity_ledger),0,'vault deletion cascades ciphertext deletion');

select * from finish();
rollback;
