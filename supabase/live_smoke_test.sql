-- Wani live Supabase RLS smoke test
-- Safe to run against linked live Supabase project: all inserted rows are rolled back.
-- This verifies authenticated users can create/read trip data, members can collaborate,
-- non-members are blocked by RLS, anonymous table reads are blocked, invite lookup works,
-- and expense participant integrity triggers fire.

begin;

-- Create deterministic fake auth users for FK checks. Transaction rollback removes them.
insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000101', 'authenticated', 'authenticated', 'wani-smoke-owner@example.invalid', '', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000102', 'authenticated', 'authenticated', 'wani-smoke-member@example.invalid', '', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000103', 'authenticated', 'authenticated', 'wani-smoke-stranger@example.invalid', '', now(), now(), now())
on conflict (id) do nothing;

set local role authenticated;
set local "request.jwt.claim.role" = 'authenticated';
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000101';

-- Owner can create a trip.
insert into public.trips (id, name, destination, emoji, start_date, end_date, created_by)
values (
  '00000000-0000-0000-0000-000000001001',
  'Wani Live Smoke Trip',
  'Test City',
  '🧪',
  current_date,
  current_date + 1,
  auth.uid()
);

-- Trip creator can add their owner membership.
insert into public.trip_members (id, trip_id, user_id, role, member_kind, display_name, created_by)
values (
  '00000000-0000-0000-0000-000000002001',
  '00000000-0000-0000-0000-000000001001',
  auth.uid(),
  'owner',
  'account',
  'Smoke Owner',
  auth.uid()
);

-- Owner helper functions work through RLS context.
do $$
begin
  if not public.is_trip_member('00000000-0000-0000-0000-000000001001') then
    raise exception 'owner should be recognized as trip member';
  end if;
  if not public.is_trip_owner('00000000-0000-0000-0000-000000001001') then
    raise exception 'owner should be recognized as trip owner';
  end if;
end $$;

-- Owner can add an account member and a guest access member.
insert into public.trip_members (id, trip_id, user_id, role, member_kind, display_name, created_by)
values (
  '00000000-0000-0000-0000-000000002002',
  '00000000-0000-0000-0000-000000001001',
  '00000000-0000-0000-0000-000000000102',
  'member',
  'account',
  'Smoke Member',
  auth.uid()
);

insert into public.trip_members (id, trip_id, guest_member_id, role, member_kind, display_name, created_by)
values (
  '00000000-0000-0000-0000-000000002003',
  '00000000-0000-0000-0000-000000001001',
  '00000000-0000-0000-0000-000000000201',
  'guest',
  'guest',
  'Smoke Guest',
  auth.uid()
);

insert into public.trip_participants (id, trip_id, display_name, linked_member_id, linked_user_id, is_organizer, created_by)
values
  ('00000000-0000-0000-0000-000000003001', '00000000-0000-0000-0000-000000001001', 'Smoke Owner', '00000000-0000-0000-0000-000000002001', '00000000-0000-0000-0000-000000000101', true, auth.uid()),
  ('00000000-0000-0000-0000-000000003002', '00000000-0000-0000-0000-000000001001', 'Smoke Member', '00000000-0000-0000-0000-000000002002', '00000000-0000-0000-0000-000000000102', false, auth.uid());

insert into public.trip_places (id, trip_id, name, note, category, added_by)
values ('00000000-0000-0000-0000-000000004001', '00000000-0000-0000-0000-000000001001', 'Smoke Place', 'created by smoke test', 'test', auth.uid());

insert into public.trip_planning_items (id, trip_id, title, note, scheduled_date, added_by)
values ('00000000-0000-0000-0000-000000005001', '00000000-0000-0000-0000-000000001001', 'Smoke Planning Item', 'created by smoke test', current_date, auth.uid());

insert into public.trip_invites (id, trip_id, code, created_by, role, max_uses, use_count, expires_at, is_active)
values
  ('00000000-0000-0000-0000-000000006001', '00000000-0000-0000-0000-000000001001', 'WANI-SMOKE-CODE', auth.uid(), 'guest', 3, 0, now() + interval '1 hour', true),
  ('00000000-0000-0000-0000-000000006002', '00000000-0000-0000-0000-000000001001', 'WANI-SMOKE-EXPIRED', auth.uid(), 'guest', 3, 0, now() - interval '1 hour', true),
  ('00000000-0000-0000-0000-000000006003', '00000000-0000-0000-0000-000000001001', 'WANI-SMOKE-MAXED', auth.uid(), 'guest', 1, 1, now() + interval '1 hour', true),
  ('00000000-0000-0000-0000-000000006004', '00000000-0000-0000-0000-000000001001', 'WANI-SMOKE-INACTIVE', auth.uid(), 'guest', 3, 0, now() + interval '1 hour', false);

insert into public.trip_expenses (id, trip_id, title, paid_by_participant_id, amount, currency_code, incurred_on, created_by)
values ('00000000-0000-0000-0000-000000007001', '00000000-0000-0000-0000-000000001001', 'Smoke Expense', '00000000-0000-0000-0000-000000003001', 42.50, 'USD', current_date, auth.uid());

insert into public.trip_expense_splits (expense_id, participant_id, share_amount)
values
  ('00000000-0000-0000-0000-000000007001', '00000000-0000-0000-0000-000000003001', 21.25),
  ('00000000-0000-0000-0000-000000007001', '00000000-0000-0000-0000-000000003002', 21.25);

insert into public.trip_direct_payments (id, trip_id, title, from_participant_id, to_participant_id, amount, currency_code, paid_on, created_by)
values ('00000000-0000-0000-0000-000000008001', '00000000-0000-0000-0000-000000001001', 'Smoke Settlement', '00000000-0000-0000-0000-000000003002', '00000000-0000-0000-0000-000000003001', 21.25, 'USD', current_date, auth.uid());

-- Member can read and collaborate.
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000102';

do $$
declare
  visible_trips integer;
begin
  select count(*) into visible_trips
  from public.trips
  where id = '00000000-0000-0000-0000-000000001001';

  if visible_trips <> 1 then
    raise exception 'member should be able to read shared trip, got % rows', visible_trips;
  end if;

  if not public.is_trip_member('00000000-0000-0000-0000-000000001001') then
    raise exception 'member should be recognized as trip member';
  end if;

  if public.is_trip_owner('00000000-0000-0000-0000-000000001001') then
    raise exception 'member should not be recognized as trip owner';
  end if;
end $$;

insert into public.trip_places (id, trip_id, name, note, category, added_by)
values ('00000000-0000-0000-0000-000000004002', '00000000-0000-0000-0000-000000001001', 'Member Smoke Place', 'created by member', 'test', auth.uid());

-- Member-only hardening: non-owner members must not be able to escalate,
-- delete trips, or manage trip memberships.
do $$
declare
  owner_id constant uuid := '00000000-0000-0000-0000-000000000101';
  member_id constant uuid := '00000000-0000-0000-0000-000000000102';
  actual_created_by uuid;
  affected_rows integer;
begin
  begin
    update public.trips
    set created_by = member_id
    where id = '00000000-0000-0000-0000-000000001001';
  exception
    when insufficient_privilege or check_violation or raise_exception then
      null;
  end;

  select created_by into actual_created_by
  from public.trips
  where id = '00000000-0000-0000-0000-000000001001';

  if actual_created_by <> owner_id then
    raise exception 'member should not be able to change trips.created_by; got %', actual_created_by;
  end if;

  delete from public.trips
  where id = '00000000-0000-0000-0000-000000001001';
  get diagnostics affected_rows = row_count;
  if affected_rows <> 0 then
    raise exception 'member should not be able to delete shared trip';
  end if;

  begin
    insert into public.trip_members (id, trip_id, user_id, role, member_kind, display_name, created_by)
    values ('00000000-0000-0000-0000-000000002901', '00000000-0000-0000-0000-000000001001', '00000000-0000-0000-0000-000000000103', 'member', 'account', 'Forbidden Member', member_id);
    raise exception 'member should not be able to insert memberships';
  exception
    when insufficient_privilege or check_violation then
      null;
  end;

  update public.trip_members
  set role = 'owner'
  where id = '00000000-0000-0000-0000-000000002002';
  get diagnostics affected_rows = row_count;
  if affected_rows <> 0 then
    raise exception 'member should not be able to update memberships';
  end if;

  delete from public.trip_members
  where id = '00000000-0000-0000-0000-000000002001';
  get diagnostics affected_rows = row_count;
  if affected_rows <> 0 then
    raise exception 'member should not be able to delete memberships';
  end if;
end $$;

-- Attribution hardening: members must not spoof another user's audit identity.
do $$
declare
  operation_blocked boolean;
begin
  operation_blocked := false;
  begin
    insert into public.trip_participants (id, trip_id, display_name, is_organizer, created_by)
    values ('00000000-0000-0000-0000-000000003901', '00000000-0000-0000-0000-000000001001', 'Spoofed Participant', false, '00000000-0000-0000-0000-000000000101');
  exception
    when insufficient_privilege or check_violation or raise_exception then
      operation_blocked := true;
  end;
  if not operation_blocked then
    raise exception 'member should not be able to spoof participant created_by';
  end if;

  operation_blocked := false;
  begin
    update public.trip_places
    set added_by = '00000000-0000-0000-0000-000000000101'
    where id = '00000000-0000-0000-0000-000000004002';
  exception
    when insufficient_privilege or check_violation or raise_exception then
      operation_blocked := true;
  end;
  if not operation_blocked then
    raise exception 'member should not be able to change place added_by';
  end if;
end $$;

-- Non-member should not see or write trip rows.
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000103';

do $$
declare
  visible_trips integer;
begin
  select count(*) into visible_trips
  from public.trips
  where id = '00000000-0000-0000-0000-000000001001';

  if visible_trips <> 0 then
    raise exception 'stranger should not be able to read shared trip, got % rows', visible_trips;
  end if;

  begin
    insert into public.trip_places (id, trip_id, name, note, category, added_by)
    values ('00000000-0000-0000-0000-000000004003', '00000000-0000-0000-0000-000000001001', 'Forbidden Place', '', 'test', auth.uid());
    raise exception 'stranger should not be able to insert place';
  exception
    when insufficient_privilege or check_violation then
      null;
  end;
end $$;

-- A signed-in non-member can accept an active invite exactly once.
do $$
declare
  joined_rows integer;
  invite_uses integer;
begin
  perform public.accept_trip_invite('WANI-SMOKE-CODE');

  select count(*) into joined_rows
  from public.trip_members
  where trip_id = '00000000-0000-0000-0000-000000001001'
    and user_id = '00000000-0000-0000-0000-000000000103'
    and role = 'guest'
    and member_kind = 'account';

  if joined_rows <> 1 then
    raise exception 'invite accept should add one guest membership, got %', joined_rows;
  end if;

  select use_count into invite_uses
  from public.trip_invites
  where id = '00000000-0000-0000-0000-000000006001';

  if invite_uses <> 1 then
    raise exception 'invite accept should increment use_count once, got %', invite_uses;
  end if;

  perform public.accept_trip_invite('WANI-SMOKE-CODE');

  select count(*) into joined_rows
  from public.trip_members
  where trip_id = '00000000-0000-0000-0000-000000001001'
    and user_id = '00000000-0000-0000-0000-000000000103';

  select use_count into invite_uses
  from public.trip_invites
  where id = '00000000-0000-0000-0000-000000006001';

  if joined_rows <> 1 or invite_uses <> 1 then
    raise exception 'repeat invite accept should be idempotent; members %, uses %', joined_rows, invite_uses;
  end if;

  begin
    perform public.accept_trip_invite('WANI-SMOKE-MAXED');
    raise exception 'maxed invite should not be accepted';
  exception
    when invalid_parameter_value then
      null;
  end;
end $$;

-- Anonymous users should not get table-level reads.
reset role;
set local role anon;
set local "request.jwt.claim.role" = 'anon';
set local "request.jwt.claim.sub" = '';

do $$
declare
  visible_invites integer;
  lookup_rows integer;
begin
  select count(*) into visible_invites
  from public.trip_invites
  where code = 'WANI-SMOKE-CODE';

  if visible_invites <> 0 then
    raise exception 'anon should not be able to table-read invites, got % rows', visible_invites;
  end if;

  select count(*) into lookup_rows
  from public.lookup_active_trip_invite('WANI-SMOKE-CODE');

  if lookup_rows <> 1 then
    raise exception 'anon invite lookup function should return one row, got %', lookup_rows;
  end if;

  select count(*) into lookup_rows
  from public.lookup_active_trip_invite('WANI-SMOKE-EXPIRED');
  if lookup_rows <> 0 then
    raise exception 'expired invite lookup should return zero rows, got %', lookup_rows;
  end if;

  select count(*) into lookup_rows
  from public.lookup_active_trip_invite('WANI-SMOKE-MAXED');
  if lookup_rows <> 0 then
    raise exception 'max-use invite lookup should return zero rows, got %', lookup_rows;
  end if;

  select count(*) into lookup_rows
  from public.lookup_active_trip_invite('WANI-SMOKE-INACTIVE');
  if lookup_rows <> 0 then
    raise exception 'inactive invite lookup should return zero rows, got %', lookup_rows;
  end if;

  select count(*) into lookup_rows
  from public.lookup_active_trip_invite('WANI-SMOKE-RANDOM');
  if lookup_rows <> 0 then
    raise exception 'random invite lookup should return zero rows, got %', lookup_rows;
  end if;

  begin
    perform public.accept_trip_invite('WANI-SMOKE-CODE');
    raise exception 'anon should not be able to accept invites';
  exception
    when insufficient_privilege or invalid_authorization_specification then
      null;
  end;
end $$;

-- Integrity trigger should reject expense paid by a participant from a different trip.
reset role;
set local role authenticated;
set local "request.jwt.claim.role" = 'authenticated';
set local "request.jwt.claim.sub" = '00000000-0000-0000-0000-000000000101';

insert into public.trips (id, name, destination, emoji, start_date, end_date, created_by)
values ('00000000-0000-0000-0000-000000001002', 'Wani Smoke Other Trip', 'Other City', '🧪', current_date, current_date + 1, auth.uid());

insert into public.trip_members (id, trip_id, user_id, role, member_kind, display_name, created_by)
values ('00000000-0000-0000-0000-000000002004', '00000000-0000-0000-0000-000000001002', auth.uid(), 'owner', 'account', 'Smoke Owner', auth.uid());

insert into public.trip_participants (id, trip_id, display_name, is_organizer, created_by)
values ('00000000-0000-0000-0000-000000003003', '00000000-0000-0000-0000-000000001002', 'Other Trip Participant', true, auth.uid());

do $$
begin
  begin
    insert into public.trip_expenses (id, trip_id, title, paid_by_participant_id, amount, currency_code, incurred_on, created_by)
    values ('00000000-0000-0000-0000-000000007002', '00000000-0000-0000-0000-000000001001', 'Invalid Cross Trip Expense', '00000000-0000-0000-0000-000000003003', 10.00, 'USD', current_date, auth.uid());
    raise exception 'cross-trip expense participant should have been rejected';
  exception
    when raise_exception then
      if sqlerrm <> 'paid_by_participant_id must belong to the expense trip' then
        raise;
      end if;
  end;
end $$;

rollback;

select 'Wani live Supabase RLS smoke test passed' as result;
