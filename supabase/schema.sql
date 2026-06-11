-- ============================================================
-- Wani — Supabase Schema
-- ============================================================
-- Single source of truth for the Milestone 2 collaborative MVP
-- database shape. Run in the Supabase SQL editor to bootstrap or
-- update the project database.
--
-- Design goals:
-- - account-backed members and display-name-only guest members
-- - expense participants remain separate from access members
-- - shared trip tables are protected by RLS
-- - helper functions avoid recursive trip_members RLS policies
-- - no secrets, keys, tokens, or project URLs belong in this file
-- ============================================================

create extension if not exists pgcrypto;

-- ============================================================
-- SHARED HELPERS
-- ============================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Guard owner/audit columns that should be written only by the current user
-- at creation time and should never be rewritten afterward. This keeps RLS
-- policy grants from accidentally making attribution columns mutable.
create or replace function public.assert_attribution_columns_current_user()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  column_name text;
  new_value text;
  old_value text;
  current_user_id text := auth.uid()::text;
begin
  foreach column_name in array tg_argv loop
    new_value := to_jsonb(new) ->> column_name;

    if tg_op = 'INSERT' then
      if new_value is not null and (current_user_id is null or new_value <> current_user_id) then
        raise exception '% must match the authenticated user', column_name;
      end if;
    elsif tg_op = 'UPDATE' then
      old_value := to_jsonb(old) ->> column_name;
      if new_value is distinct from old_value then
        raise exception '% is immutable', column_name;
      end if;
    end if;
  end loop;

  return new;
end;
$$;

-- Security-definer helpers intentionally centralize membership checks so
-- policies do not recursively query trip_members through trip_members RLS.
create or replace function public.is_trip_member(check_trip_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return exists (
    select 1
    from public.trip_members tm
    where tm.trip_id = check_trip_id
      and tm.user_id = auth.uid()
  );
end;
$$;

create or replace function public.is_trip_owner(check_trip_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return exists (
    select 1
    from public.trip_members tm
    where tm.trip_id = check_trip_id
      and tm.user_id = auth.uid()
      and tm.role = 'owner'
  );
end;
$$;

grant execute on function public.is_trip_member(uuid) to authenticated;
grant execute on function public.is_trip_owner(uuid) to authenticated;

-- ============================================================
-- PROFILES
-- ============================================================

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

drop policy if exists "profiles are readable by authenticated users" on public.profiles;
create policy "profiles are readable by authenticated users"
on public.profiles for select
to authenticated
using (true);

drop policy if exists "users can insert their own profile" on public.profiles;
create policy "users can insert their own profile"
on public.profiles for insert
to authenticated
with check (auth.uid() = id);

drop policy if exists "users can update their own profile" on public.profiles;
create policy "users can update their own profile"
on public.profiles for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1), 'Traveler')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- TRIPS
-- ============================================================

create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  destination text,
  emoji text,
  image_url text,
  start_date date not null,
  end_date date not null,
  created_by uuid not null references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint trips_date_order_check check (end_date >= start_date)
);

alter table public.trips add column if not exists description text;
alter table public.trips add column if not exists updated_at timestamptz not null default now();
alter table public.trips drop constraint if exists trips_date_order_check;
alter table public.trips add constraint trips_date_order_check check (end_date >= start_date);

create index if not exists idx_trips_created_by on public.trips (created_by);

alter table public.trips enable row level security;

drop trigger if exists trips_set_updated_at on public.trips;
create trigger trips_set_updated_at
  before update on public.trips
  for each row execute function public.set_updated_at();

drop trigger if exists trips_assert_created_by on public.trips;
create trigger trips_assert_created_by
  before insert or update on public.trips
  for each row execute function public.assert_attribution_columns_current_user('created_by');

drop policy if exists "trip members can read trips" on public.trips;
create policy "trip members can read trips"
on public.trips for select
to authenticated
using (created_by = auth.uid() or public.is_trip_member(id));

drop policy if exists "authenticated users can create their own trips" on public.trips;
create policy "authenticated users can create their own trips"
on public.trips for insert
to authenticated
with check (created_by = auth.uid());

drop policy if exists "trip members can update trips" on public.trips;
create policy "trip members can update trips"
on public.trips for update
to authenticated
using (public.is_trip_member(id))
with check (public.is_trip_member(id));

drop policy if exists "trip owners can delete trips" on public.trips;
create policy "trip owners can delete trips"
on public.trips for delete
to authenticated
using (created_by = auth.uid() or public.is_trip_owner(id));

-- ============================================================
-- TRIP MEMBERS
-- ============================================================
-- Access/collaboration records. Account members have user_id.
-- Display-name-only guests have guest_member_id and no user_id.
-- A later upgrade can attach an auth user by setting user_id and
-- member_kind = 'account' while keeping the same member id.
-- ============================================================

create table if not exists public.trip_members (
  id uuid default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  guest_member_id uuid,
  display_name text,
  role text not null default 'member',
  member_kind text not null default 'account',
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (id)
);

-- Upgrade the original Milestone 1/early-M2 composite-key table shape.
alter table public.trip_members add column if not exists id uuid;
update public.trip_members set id = gen_random_uuid() where id is null;
alter table public.trip_members alter column id set default gen_random_uuid();
alter table public.trip_members alter column id set not null;
do $$
declare
  current_pkey_columns text[];
begin
  select array_agg(a.attname order by k.ordinality)
  into current_pkey_columns
  from pg_constraint c
  join unnest(c.conkey) with ordinality as k(attnum, ordinality) on true
  join pg_attribute a on a.attrelid = c.conrelid and a.attnum = k.attnum
  where c.conrelid = 'public.trip_members'::regclass
    and c.conname = 'trip_members_pkey'
    and c.contype = 'p';

  if current_pkey_columns is null then
    alter table public.trip_members add constraint trip_members_pkey primary key (id);
  elsif current_pkey_columns <> array['id']::text[] then
    alter table public.trip_members drop constraint trip_members_pkey;
    alter table public.trip_members add constraint trip_members_pkey primary key (id);
  end if;
end $$;

alter table public.trip_members alter column user_id drop not null;
alter table public.trip_members add column if not exists guest_member_id uuid;
alter table public.trip_members add column if not exists display_name text;
alter table public.trip_members add column if not exists member_kind text not null default 'account';
alter table public.trip_members add column if not exists created_by uuid references auth.users(id);
alter table public.trip_members add column if not exists updated_at timestamptz not null default now();

alter table public.trip_members drop constraint if exists trip_members_role_check;
alter table public.trip_members add constraint trip_members_role_check
  check (role in ('owner', 'member', 'guest'));

alter table public.trip_members drop constraint if exists trip_members_kind_check;
alter table public.trip_members add constraint trip_members_kind_check
  check (member_kind in ('account', 'guest'));

alter table public.trip_members drop constraint if exists trip_members_identity_check;
alter table public.trip_members add constraint trip_members_identity_check
  check (
    (member_kind = 'account' and user_id is not null)
    or
    (member_kind = 'guest' and user_id is null and guest_member_id is not null and nullif(trim(display_name), '') is not null)
  );

create unique index if not exists idx_trip_members_trip_user
  on public.trip_members (trip_id, user_id)
  where user_id is not null;

create unique index if not exists idx_trip_members_trip_guest
  on public.trip_members (trip_id, guest_member_id)
  where guest_member_id is not null;

create index if not exists idx_trip_members_trip_id on public.trip_members (trip_id);
create index if not exists idx_trip_members_user_id on public.trip_members (user_id);

alter table public.trip_members enable row level security;

drop trigger if exists trip_members_set_updated_at on public.trip_members;
create trigger trip_members_set_updated_at
  before update on public.trip_members
  for each row execute function public.set_updated_at();

drop trigger if exists trip_members_assert_created_by on public.trip_members;
create trigger trip_members_assert_created_by
  before insert or update on public.trip_members
  for each row execute function public.assert_attribution_columns_current_user('created_by');

drop policy if exists "trip members can read memberships" on public.trip_members;
create policy "trip members can read memberships"
on public.trip_members for select
to authenticated
using (user_id = auth.uid() or public.is_trip_member(trip_id));

drop policy if exists "trip creators can add owner membership" on public.trip_members;
create policy "trip creators can add owner membership"
on public.trip_members for insert
to authenticated
with check (
  member_kind = 'account'
  and user_id = auth.uid()
  and role = 'owner'
  and exists (
    select 1 from public.trips t
    where t.id = trip_members.trip_id
      and t.created_by = auth.uid()
  )
);

drop policy if exists "trip owners can add memberships" on public.trip_members;
create policy "trip owners can add memberships"
on public.trip_members for insert
to authenticated
with check (public.is_trip_owner(trip_id));

drop policy if exists "trip owners can update memberships" on public.trip_members;
create policy "trip owners can update memberships"
on public.trip_members for update
to authenticated
using (public.is_trip_owner(trip_id))
with check (public.is_trip_owner(trip_id));

drop policy if exists "trip owners can delete memberships" on public.trip_members;
create policy "trip owners can delete memberships"
on public.trip_members for delete
to authenticated
using (public.is_trip_owner(trip_id));

-- ============================================================
-- TRIP PARTICIPANTS
-- ============================================================
-- People represented in planning and expense calculations. They
-- are deliberately separate from trip_members/access records.
-- ============================================================

create table if not exists public.trip_participants (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  display_name text not null,
  linked_member_id uuid references public.trip_members(id) on delete set null,
  linked_user_id uuid references auth.users(id) on delete set null,
  is_organizer boolean not null default false,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint trip_participants_display_name_check check (nullif(trim(display_name), '') is not null)
);

create unique index if not exists idx_trip_participants_one_organizer
  on public.trip_participants (trip_id)
  where is_organizer = true;

create index if not exists idx_trip_participants_trip_id on public.trip_participants (trip_id);
create index if not exists idx_trip_participants_linked_member on public.trip_participants (linked_member_id);

alter table public.trip_participants enable row level security;

drop trigger if exists trip_participants_set_updated_at on public.trip_participants;
create trigger trip_participants_set_updated_at
  before update on public.trip_participants
  for each row execute function public.set_updated_at();

drop trigger if exists trip_participants_assert_created_by on public.trip_participants;
create trigger trip_participants_assert_created_by
  before insert or update on public.trip_participants
  for each row execute function public.assert_attribution_columns_current_user('created_by');

drop policy if exists "trip members can read participants" on public.trip_participants;
create policy "trip members can read participants"
on public.trip_participants for select
to authenticated
using (public.is_trip_member(trip_id));

drop policy if exists "trip members can create participants" on public.trip_participants;
create policy "trip members can create participants"
on public.trip_participants for insert
to authenticated
with check (public.is_trip_member(trip_id));

drop policy if exists "trip members can update participants" on public.trip_participants;
create policy "trip members can update participants"
on public.trip_participants for update
to authenticated
using (public.is_trip_member(trip_id))
with check (public.is_trip_member(trip_id));

drop policy if exists "trip members can delete participants" on public.trip_participants;
create policy "trip members can delete participants"
on public.trip_participants for delete
to authenticated
using (public.is_trip_member(trip_id));

-- ============================================================
-- TRIP INVITES
-- ============================================================

create table if not exists public.trip_invites (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  code text not null,
  created_by uuid not null references auth.users(id),
  role text not null default 'guest',
  max_uses integer,
  use_count integer not null default 0,
  expires_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint trip_invites_role_check check (role in ('member', 'guest')),
  constraint trip_invites_max_uses_check check (max_uses is null or max_uses > 0),
  constraint trip_invites_use_count_check check (use_count >= 0)
);

create unique index if not exists idx_trip_invites_code on public.trip_invites (code);
create index if not exists idx_trip_invites_trip_id on public.trip_invites (trip_id);

alter table public.trip_invites enable row level security;

drop trigger if exists trip_invites_set_updated_at on public.trip_invites;
create trigger trip_invites_set_updated_at
  before update on public.trip_invites
  for each row execute function public.set_updated_at();

drop trigger if exists trip_invites_assert_created_by on public.trip_invites;
create trigger trip_invites_assert_created_by
  before insert or update on public.trip_invites
  for each row execute function public.assert_attribution_columns_current_user('created_by');

drop policy if exists "trip members can read invites for their trips" on public.trip_invites;
create policy "trip members can read invites for their trips"
on public.trip_invites for select
to authenticated
using (public.is_trip_member(trip_id));

drop policy if exists "trip members can create invites" on public.trip_invites;
create policy "trip members can create invites"
on public.trip_invites for insert
to authenticated
with check (public.is_trip_member(trip_id) and created_by = auth.uid());

drop policy if exists "trip members can update invites" on public.trip_invites;
create policy "trip members can update invites"
on public.trip_invites for update
to authenticated
using (public.is_trip_member(trip_id))
with check (public.is_trip_member(trip_id));

drop policy if exists "trip owners can delete invites" on public.trip_invites;
create policy "trip owners can delete invites"
on public.trip_invites for delete
to authenticated
using (public.is_trip_owner(trip_id));

-- Narrow invite lookup for join screens. This avoids opening table-level
-- anonymous SELECT that could list every active invite.
create or replace function public.lookup_active_trip_invite(invite_code text)
returns table (
  invite_id uuid,
  trip_id uuid,
  trip_name text,
  role text,
  expires_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select i.id, i.trip_id, t.name, i.role, i.expires_at
  from public.trip_invites i
  join public.trips t on t.id = i.trip_id
  where i.code = invite_code
    and i.is_active = true
    and (i.expires_at is null or i.expires_at > now())
    and (i.max_uses is null or i.use_count < i.max_uses)
  limit 1;
$$;

revoke all on function public.lookup_active_trip_invite(text) from public;
grant execute on function public.lookup_active_trip_invite(text) to anon, authenticated;

-- ============================================================
-- TRIP PLACES
-- ============================================================

create table if not exists public.trip_places (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  name text not null,
  note text not null default '',
  category text not null default '',
  google_place_id text,
  latitude double precision,
  longitude double precision,
  added_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint trip_places_name_check check (nullif(trim(name), '') is not null),
  constraint trip_places_latitude_check check (latitude is null or latitude between -90 and 90),
  constraint trip_places_longitude_check check (longitude is null or longitude between -180 and 180)
);

create index if not exists idx_trip_places_trip_id on public.trip_places (trip_id);

alter table public.trip_places enable row level security;

drop trigger if exists trip_places_set_updated_at on public.trip_places;
create trigger trip_places_set_updated_at
  before update on public.trip_places
  for each row execute function public.set_updated_at();

drop trigger if exists trip_places_assert_added_by on public.trip_places;
create trigger trip_places_assert_added_by
  before insert or update on public.trip_places
  for each row execute function public.assert_attribution_columns_current_user('added_by');

drop policy if exists "trip members can read places" on public.trip_places;
create policy "trip members can read places"
on public.trip_places for select
to authenticated
using (public.is_trip_member(trip_id));

drop policy if exists "trip members can create places" on public.trip_places;
create policy "trip members can create places"
on public.trip_places for insert
to authenticated
with check (public.is_trip_member(trip_id) and (added_by is null or added_by = auth.uid()));

drop policy if exists "trip members can update places" on public.trip_places;
create policy "trip members can update places"
on public.trip_places for update
to authenticated
using (public.is_trip_member(trip_id))
with check (public.is_trip_member(trip_id));

drop policy if exists "trip members can delete places" on public.trip_places;
create policy "trip members can delete places"
on public.trip_places for delete
to authenticated
using (public.is_trip_member(trip_id));

-- ============================================================
-- TRIP PLANNING ITEMS
-- ============================================================

create table if not exists public.trip_planning_items (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  title text not null,
  note text not null default '',
  scheduled_date date,
  is_done boolean not null default false,
  added_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint trip_planning_items_title_check check (nullif(trim(title), '') is not null)
);

create index if not exists idx_trip_planning_items_trip_id on public.trip_planning_items (trip_id);
create index if not exists idx_trip_planning_items_scheduled_date on public.trip_planning_items (scheduled_date);

alter table public.trip_planning_items enable row level security;

drop trigger if exists trip_planning_items_set_updated_at on public.trip_planning_items;
create trigger trip_planning_items_set_updated_at
  before update on public.trip_planning_items
  for each row execute function public.set_updated_at();

drop trigger if exists trip_planning_items_assert_added_by on public.trip_planning_items;
create trigger trip_planning_items_assert_added_by
  before insert or update on public.trip_planning_items
  for each row execute function public.assert_attribution_columns_current_user('added_by');

drop policy if exists "trip members can read planning items" on public.trip_planning_items;
create policy "trip members can read planning items"
on public.trip_planning_items for select
to authenticated
using (public.is_trip_member(trip_id));

drop policy if exists "trip members can create planning items" on public.trip_planning_items;
create policy "trip members can create planning items"
on public.trip_planning_items for insert
to authenticated
with check (public.is_trip_member(trip_id) and (added_by is null or added_by = auth.uid()));

drop policy if exists "trip members can update planning items" on public.trip_planning_items;
create policy "trip members can update planning items"
on public.trip_planning_items for update
to authenticated
using (public.is_trip_member(trip_id))
with check (public.is_trip_member(trip_id));

drop policy if exists "trip members can delete planning items" on public.trip_planning_items;
create policy "trip members can delete planning items"
on public.trip_planning_items for delete
to authenticated
using (public.is_trip_member(trip_id));

-- ============================================================
-- EXPENSE INTEGRITY HELPERS
-- ============================================================

create or replace function public.assert_expense_participant_matches_trip()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.trip_participants p
    where p.id = new.paid_by_participant_id
      and p.trip_id = new.trip_id
  ) then
    raise exception 'paid_by_participant_id must belong to the expense trip';
  end if;
  return new;
end;
$$;

create or replace function public.assert_expense_split_participant_matches_trip()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  expense_trip_id uuid;
begin
  select e.trip_id into expense_trip_id
  from public.trip_expenses e
  where e.id = new.expense_id;

  if expense_trip_id is null then
    raise exception 'expense_id does not reference an existing expense';
  end if;

  if not exists (
    select 1
    from public.trip_participants p
    where p.id = new.participant_id
      and p.trip_id = expense_trip_id
  ) then
    raise exception 'participant_id must belong to the same trip as the expense';
  end if;

  return new;
end;
$$;

create or replace function public.assert_direct_payment_participants_match_trip()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.trip_participants p
    where p.id = new.from_participant_id
      and p.trip_id = new.trip_id
  ) then
    raise exception 'from_participant_id must belong to the payment trip';
  end if;

  if not exists (
    select 1
    from public.trip_participants p
    where p.id = new.to_participant_id
      and p.trip_id = new.trip_id
  ) then
    raise exception 'to_participant_id must belong to the payment trip';
  end if;

  return new;
end;
$$;

-- ============================================================
-- TRIP EXPENSES
-- ============================================================

create table if not exists public.trip_expenses (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  title text not null,
  paid_by_participant_id uuid not null references public.trip_participants(id) on delete restrict,
  amount numeric(12, 2) not null,
  currency_code text not null default 'USD',
  incurred_on date,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint trip_expenses_title_check check (nullif(trim(title), '') is not null),
  constraint trip_expenses_amount_check check (amount > 0),
  constraint trip_expenses_currency_check check (currency_code ~ '^[A-Z]{3}$')
);

create index if not exists idx_trip_expenses_trip_id on public.trip_expenses (trip_id);
create index if not exists idx_trip_expenses_paid_by on public.trip_expenses (paid_by_participant_id);

alter table public.trip_expenses enable row level security;

drop trigger if exists trip_expenses_set_updated_at on public.trip_expenses;
create trigger trip_expenses_set_updated_at
  before update on public.trip_expenses
  for each row execute function public.set_updated_at();

drop trigger if exists trip_expenses_assert_created_by on public.trip_expenses;
create trigger trip_expenses_assert_created_by
  before insert or update on public.trip_expenses
  for each row execute function public.assert_attribution_columns_current_user('created_by');

drop trigger if exists trip_expenses_participant_trip_check on public.trip_expenses;
create trigger trip_expenses_participant_trip_check
  before insert or update on public.trip_expenses
  for each row execute function public.assert_expense_participant_matches_trip();

drop policy if exists "trip members can read expenses" on public.trip_expenses;
create policy "trip members can read expenses"
on public.trip_expenses for select
to authenticated
using (public.is_trip_member(trip_id));

drop policy if exists "trip members can create expenses" on public.trip_expenses;
create policy "trip members can create expenses"
on public.trip_expenses for insert
to authenticated
with check (public.is_trip_member(trip_id) and (created_by is null or created_by = auth.uid()));

drop policy if exists "trip members can update expenses" on public.trip_expenses;
create policy "trip members can update expenses"
on public.trip_expenses for update
to authenticated
using (public.is_trip_member(trip_id))
with check (public.is_trip_member(trip_id));

drop policy if exists "trip members can delete expenses" on public.trip_expenses;
create policy "trip members can delete expenses"
on public.trip_expenses for delete
to authenticated
using (public.is_trip_member(trip_id));

-- ============================================================
-- TRIP EXPENSE SPLITS
-- ============================================================

create table if not exists public.trip_expense_splits (
  expense_id uuid not null references public.trip_expenses(id) on delete cascade,
  participant_id uuid not null references public.trip_participants(id) on delete cascade,
  share_amount numeric(12, 2),
  created_at timestamptz not null default now(),
  primary key (expense_id, participant_id),
  constraint trip_expense_splits_share_amount_check check (share_amount is null or share_amount >= 0)
);

create index if not exists idx_trip_expense_splits_participant_id on public.trip_expense_splits (participant_id);

alter table public.trip_expense_splits enable row level security;

drop trigger if exists trip_expense_splits_participant_trip_check on public.trip_expense_splits;
create trigger trip_expense_splits_participant_trip_check
  before insert or update on public.trip_expense_splits
  for each row execute function public.assert_expense_split_participant_matches_trip();

drop policy if exists "trip members can read expense splits" on public.trip_expense_splits;
create policy "trip members can read expense splits"
on public.trip_expense_splits for select
to authenticated
using (
  exists (
    select 1 from public.trip_expenses e
    where e.id = trip_expense_splits.expense_id
      and public.is_trip_member(e.trip_id)
  )
);

drop policy if exists "trip members can create expense splits" on public.trip_expense_splits;
create policy "trip members can create expense splits"
on public.trip_expense_splits for insert
to authenticated
with check (
  exists (
    select 1 from public.trip_expenses e
    where e.id = trip_expense_splits.expense_id
      and public.is_trip_member(e.trip_id)
  )
);

drop policy if exists "trip members can delete expense splits" on public.trip_expense_splits;
create policy "trip members can delete expense splits"
on public.trip_expense_splits for delete
to authenticated
using (
  exists (
    select 1 from public.trip_expenses e
    where e.id = trip_expense_splits.expense_id
      and public.is_trip_member(e.trip_id)
  )
);

-- ============================================================
-- TRIP DIRECT PAYMENTS
-- ============================================================

create table if not exists public.trip_direct_payments (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  title text not null,
  from_participant_id uuid not null references public.trip_participants(id) on delete restrict,
  to_participant_id uuid not null references public.trip_participants(id) on delete restrict,
  amount numeric(12, 2) not null,
  currency_code text not null default 'USD',
  paid_on date,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint trip_direct_payments_title_check check (nullif(trim(title), '') is not null),
  constraint trip_direct_payments_amount_check check (amount > 0),
  constraint trip_direct_payments_currency_check check (currency_code ~ '^[A-Z]{3}$'),
  constraint trip_direct_payments_no_self_check check (from_participant_id <> to_participant_id)
);

create index if not exists idx_trip_direct_payments_trip_id on public.trip_direct_payments (trip_id);
create index if not exists idx_trip_direct_payments_from on public.trip_direct_payments (from_participant_id);
create index if not exists idx_trip_direct_payments_to on public.trip_direct_payments (to_participant_id);

alter table public.trip_direct_payments enable row level security;

drop trigger if exists trip_direct_payments_set_updated_at on public.trip_direct_payments;
create trigger trip_direct_payments_set_updated_at
  before update on public.trip_direct_payments
  for each row execute function public.set_updated_at();

drop trigger if exists trip_direct_payments_assert_created_by on public.trip_direct_payments;
create trigger trip_direct_payments_assert_created_by
  before insert or update on public.trip_direct_payments
  for each row execute function public.assert_attribution_columns_current_user('created_by');

drop trigger if exists trip_direct_payments_participant_trip_check on public.trip_direct_payments;
create trigger trip_direct_payments_participant_trip_check
  before insert or update on public.trip_direct_payments
  for each row execute function public.assert_direct_payment_participants_match_trip();

drop policy if exists "trip members can read direct payments" on public.trip_direct_payments;
create policy "trip members can read direct payments"
on public.trip_direct_payments for select
to authenticated
using (public.is_trip_member(trip_id));

drop policy if exists "trip members can create direct payments" on public.trip_direct_payments;
create policy "trip members can create direct payments"
on public.trip_direct_payments for insert
to authenticated
with check (public.is_trip_member(trip_id) and (created_by is null or created_by = auth.uid()));

drop policy if exists "trip members can update direct payments" on public.trip_direct_payments;
create policy "trip members can update direct payments"
on public.trip_direct_payments for update
to authenticated
using (public.is_trip_member(trip_id))
with check (public.is_trip_member(trip_id));

drop policy if exists "trip members can delete direct payments" on public.trip_direct_payments;
create policy "trip members can delete direct payments"
on public.trip_direct_payments for delete
to authenticated
using (public.is_trip_member(trip_id));
