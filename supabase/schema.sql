create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  destination text,
  emoji text,
  image_url text,
  start_date date not null,
  end_date date not null,
  created_by uuid not null references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now()
);

create table if not exists public.trip_members (
  trip_id uuid not null references public.trips(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member',
  created_at timestamptz not null default now(),
  primary key (trip_id, user_id)
);

alter table public.trips enable row level security;
alter table public.trip_members enable row level security;

drop policy if exists "trip members can read trips" on public.trips;
create policy "trip members can read trips"
on public.trips for select
using (
  created_by = auth.uid()
  or
  exists (
    select 1
    from public.trip_members
    where trip_members.trip_id = trips.id
    and trip_members.user_id = auth.uid()
  )
);

drop policy if exists "authenticated users can create their own trips" on public.trips;
create policy "authenticated users can create their own trips"
on public.trips for insert
to authenticated
with check (created_by = auth.uid());

drop policy if exists "trip members can update trips" on public.trips;
create policy "trip members can update trips"
on public.trips for update
using (
  exists (
    select 1
    from public.trip_members
    where trip_members.trip_id = trips.id
    and trip_members.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.trip_members
    where trip_members.trip_id = trips.id
    and trip_members.user_id = auth.uid()
  )
);

drop policy if exists "trip members can read memberships" on public.trip_members;
create policy "trip members can read memberships"
on public.trip_members for select
using (user_id = auth.uid());

drop policy if exists "users can add themselves to trips" on public.trip_members;
create policy "users can add themselves to trips"
on public.trip_members for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.trips
    where trips.id = trip_members.trip_id
    and trips.created_by = auth.uid()
  )
);
