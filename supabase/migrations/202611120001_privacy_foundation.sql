-- All cloud activity fields are client-encrypted. No organization can query a
-- member's ledger. Membership is authorization, not permission to share data.
begin;

create table public.ledger_vaults (
  user_id uuid primary key references auth.users(id) on delete cascade,
  key_token text not null check (key_token ~ '^[0-9a-f]{64}$'),
  unique (user_id, key_token)
);
alter table public.ledger_vaults enable row level security;
revoke all on public.ledger_vaults from anon, authenticated;
grant select, insert, delete on public.ledger_vaults to authenticated;
create policy vault_read_own on public.ledger_vaults for select to authenticated
  using ((select auth.uid()) = user_id);
create policy vault_create_own on public.ledger_vaults for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy vault_delete_own on public.ledger_vaults for delete to authenticated
  using ((select auth.uid()) = user_id);

create table public.activity_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  key_token text not null,
  record_token text not null check (record_token ~ '^[0-9a-f]{64}$'),
  version integer not null check (version = 1),
  nonce text not null check (nonce ~ '^[A-Za-z0-9+/]{16}$'),
  ciphertext text not null check (
    length(ciphertext) between 4 and 2097152 and
    ciphertext ~ '^[A-Za-z0-9+/]+={0,2}$'
  ),
  mac text not null check (mac ~ '^[A-Za-z0-9+/]{22}==$'),
  created_at timestamptz not null default now(),
  unique (user_id, record_token),
  foreign key (user_id,key_token) references public.ledger_vaults(user_id,key_token) on delete cascade
);
alter table public.activity_ledger enable row level security;
revoke all on public.activity_ledger from anon, authenticated;
grant select, insert, delete on public.activity_ledger to authenticated;
create policy ledger_read_own on public.activity_ledger for select to authenticated
  using ((select auth.uid()) = user_id);
create policy ledger_append_own on public.activity_ledger for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy ledger_delete_own on public.activity_ledger for delete to authenticated
  using ((select auth.uid()) = user_id);
-- No UPDATE privilege or policy: confirmed backup records are immutable.

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) between 1 and 120),
  created_at timestamptz not null default now()
);
create table public.organization_members (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'member')),
  created_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);
create index organization_members_user on public.organization_members(user_id);
alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
revoke all on public.organizations, public.organization_members from anon, authenticated;
grant select on public.organizations, public.organization_members to authenticated;

-- Definer helpers avoid recursive membership RLS. No user-supplied subject.
create function public.is_organization_member(organization_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.organization_members m
    where m.organization_id = $1 and m.user_id = (select auth.uid()));
$$;
create function public.is_organization_owner(organization_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.organization_members m
    where m.organization_id = $1 and m.user_id = (select auth.uid()) and m.role = 'owner');
$$;
revoke all on function public.is_organization_member(uuid), public.is_organization_owner(uuid) from public;
grant execute on function public.is_organization_member(uuid), public.is_organization_owner(uuid) to authenticated;

create policy organizations_read_member on public.organizations for select to authenticated
  using (public.is_organization_member(id));
create policy members_read_self_or_owner on public.organization_members for select to authenticated
  using (user_id = (select auth.uid()) or public.is_organization_owner(organization_id));

create function public.create_organization(organization_name text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare new_id uuid;
begin
  if auth.uid() is null then raise exception 'Sign in required' using errcode = '42501'; end if;
  if length(btrim(organization_name)) not between 1 and 120 or organization_name is null then
    raise exception 'Organization name must be 1 to 120 characters' using errcode = '22023';
  end if;
  insert into public.organizations(name) values (btrim(organization_name)) returning id into new_id;
  insert into public.organization_members(organization_id,user_id,role) values (new_id,auth.uid(),'owner');
  return new_id;
end;
$$;

-- The owner needs the intended member's account UUID, shared out of band.
-- No email directory enumeration, public invitation token or self-join path.
create function public.add_organization_member(organization_id uuid, member_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_organization_owner($1) then
    raise exception 'Only the organization owner may add members' using errcode = '42501';
  end if;
  insert into public.organization_members(organization_id,user_id,role) values ($1,$2,'member')
    on conflict do nothing;
end;
$$;
create function public.remove_organization_member(organization_id uuid, member_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or (auth.uid() <> $2 and not public.is_organization_owner($1)) then
    raise exception 'Only the member or organization owner may remove membership' using errcode = '42501';
  end if;
  if exists(select 1 from public.organization_members m
    where m.organization_id = $1 and m.user_id = $2 and m.role = 'owner') then
    raise exception 'The owner cannot be removed; delete the account through the operator retention process' using errcode = '22023';
  end if;
  delete from public.organization_members m where m.organization_id = $1 and m.user_id = $2;
end;
$$;
revoke all on function public.create_organization(text), public.add_organization_member(uuid,uuid),
  public.remove_organization_member(uuid,uuid) from public;
grant execute on function public.create_organization(text), public.add_organization_member(uuid,uuid),
  public.remove_organization_member(uuid,uuid) to authenticated;

commit;
