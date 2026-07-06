begin;

create temp table smoke_ids (
  key text primary key,
  id uuid not null
) on commit drop;

grant select on smoke_ids to authenticated;

insert into smoke_ids (key, id) values
  ('user_a', '00000000-0000-4000-8000-00000000a001'),
  ('user_b', '00000000-0000-4000-8000-00000000b001'),
  ('trip', '00000000-0000-4000-8000-00000000c001'),
  ('owner_member', '00000000-0000-4000-8000-00000000d001'),
  ('invite', '00000000-0000-4000-8000-00000000e001'),
  ('bill_participant', '00000000-0000-4000-8000-00000000f001'),
  ('plan', '00000000-0000-4000-8000-00000000a002'),
  ('expense', '00000000-0000-4000-8000-00000000e002');

insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
) values
  (
    '00000000-0000-4000-8000-00000000a001',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'wanderaid-smoke-user-a@example.invalid',
    crypt('not-used', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Smoke User A"}'::jsonb,
    now(),
    now()
  ),
  (
    '00000000-0000-4000-8000-00000000b001',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'wanderaid-smoke-user-b@example.invalid',
    crypt('not-used', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Smoke User B"}'::jsonb,
    now(),
    now()
  );

-- User A creates a trip, owner membership, and invite.
set role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-4000-8000-00000000a001';
set local "request.jwt.claim.role" = 'authenticated';

insert into public.trips (id, name, destination, emoji, image_url, start_date, end_date)
values (
  '00000000-0000-4000-8000-00000000c001',
  'Rollback Cross-User Smoke Trip',
  'Austin',
  '🧪',
  '',
  current_date,
  current_date + 2
);

insert into public.trip_members (id, trip_id, user_id, role, member_kind)
values (
  '00000000-0000-4000-8000-00000000d001',
  '00000000-0000-4000-8000-00000000c001',
  '00000000-0000-4000-8000-00000000a001',
  'owner',
  'account'
);

insert into public.trip_invites (id, trip_id, code, created_by, role, max_uses, expires_at, is_active)
values (
  '00000000-0000-4000-8000-00000000e001',
  '00000000-0000-4000-8000-00000000c001',
  'SMOKE123',
  auth.uid(),
  'member',
  null,
  null,
  true
);

reset role;

-- User B accepts the invite. This should create both access membership and a linked participant row.
set role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-4000-8000-00000000b001';
set local "request.jwt.claim.role" = 'authenticated';
select public.accept_trip_invite('SMOKE123');
reset role;

-- User A creates a free-standing person, a planning item, and an expense involving that person.
set role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-4000-8000-00000000a001';
set local "request.jwt.claim.role" = 'authenticated';

insert into public.trip_participants (id, trip_id, display_name, created_by)
values (
  '00000000-0000-4000-8000-00000000f001',
  '00000000-0000-4000-8000-00000000c001',
  'Bill',
  auth.uid()
);

insert into public.trip_planning_items (id, trip_id, title, note, scheduled_date, is_done, added_by)
values (
  '00000000-0000-4000-8000-00000000a002',
  '00000000-0000-4000-8000-00000000c001',
  'Book dinner reservation',
  'Smoke test plan item',
  current_date + 1,
  false,
  auth.uid()
);

insert into public.trip_expenses (id, trip_id, title, paid_by_participant_id, amount, currency_code, incurred_on, created_by)
values (
  '00000000-0000-4000-8000-00000000e002',
  '00000000-0000-4000-8000-00000000c001',
  'Tacos with Bill',
  '00000000-0000-4000-8000-00000000f001',
  42.00,
  'USD',
  current_date,
  auth.uid()
);

insert into public.trip_expense_splits (expense_id, participant_id, share_amount)
values (
  '00000000-0000-4000-8000-00000000e002',
  '00000000-0000-4000-8000-00000000f001',
  42.00
);

reset role;

-- User B reads the trip and every child row through normal authenticated RLS.
set role authenticated;
set local "request.jwt.claim.sub" = '00000000-0000-4000-8000-00000000b001';
set local "request.jwt.claim.role" = 'authenticated';

do $$
declare
  trip_count integer;
  bill_count integer;
  linked_user_b_participant_count integer;
  plan_count integer;
  expense_count integer;
  split_count integer;
begin
  select count(*) into trip_count
  from public.trips
  where id = '00000000-0000-4000-8000-00000000c001';

  select count(*) into bill_count
  from public.trip_participants
  where trip_id = '00000000-0000-4000-8000-00000000c001'
    and display_name = 'Bill';

  select count(*) into linked_user_b_participant_count
  from public.trip_participants
  where trip_id = '00000000-0000-4000-8000-00000000c001'
    and linked_user_id = '00000000-0000-4000-8000-00000000b001';

  select count(*) into plan_count
  from public.trip_planning_items
  where trip_id = '00000000-0000-4000-8000-00000000c001'
    and title = 'Book dinner reservation';

  select count(*) into expense_count
  from public.trip_expenses
  where trip_id = '00000000-0000-4000-8000-00000000c001'
    and title = 'Tacos with Bill'
    and paid_by_participant_id = '00000000-0000-4000-8000-00000000f001';

  select count(*) into split_count
  from public.trip_expense_splits s
  join public.trip_expenses e on e.id = s.expense_id
  where e.trip_id = '00000000-0000-4000-8000-00000000c001'
    and s.participant_id = '00000000-0000-4000-8000-00000000f001'
    and s.share_amount = 42.00;

  if trip_count <> 1 then
    raise exception 'User B could not read trip. count=%', trip_count;
  end if;
  if bill_count <> 1 then
    raise exception 'User B could not read Bill participant. count=%', bill_count;
  end if;
  if linked_user_b_participant_count <> 1 then
    raise exception 'Invite accept did not create/read User B linked participant. count=%', linked_user_b_participant_count;
  end if;
  if plan_count <> 1 then
    raise exception 'User B could not read planning item. count=%', plan_count;
  end if;
  if expense_count <> 1 then
    raise exception 'User B could not read Bill expense. count=%', expense_count;
  end if;
  if split_count <> 1 then
    raise exception 'User B could not read Bill expense split. count=%', split_count;
  end if;
end $$;

select
  'PASS rollback cross-user smoke: User B can read trip, Bill participant, invite-created participant, planning item, expense, and expense split' as result,
  (select count(*) from public.trips where id = '00000000-0000-4000-8000-00000000c001') as trips_readable_by_user_b,
  (select count(*) from public.trip_participants where trip_id = '00000000-0000-4000-8000-00000000c001') as participants_readable_by_user_b,
  (select count(*) from public.trip_planning_items where trip_id = '00000000-0000-4000-8000-00000000c001') as plans_readable_by_user_b,
  (select count(*) from public.trip_expenses where trip_id = '00000000-0000-4000-8000-00000000c001') as expenses_readable_by_user_b,
  (
    select count(*)
    from public.trip_expense_splits s
    join public.trip_expenses e on e.id = s.expense_id
    where e.trip_id = '00000000-0000-4000-8000-00000000c001'
  ) as expense_splits_readable_by_user_b;

reset role;
rollback;
