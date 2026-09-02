-- ============================================================
-- CHUNK 2: ITEM TAGS + PARTICIPANT SETS (M4 cross-cutting)
-- ============================================================

-- One shared tag vocabulary column on places + planning items.
-- Existing free-text place categories are valid custom tags, so rename preserves values.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'trip_places'
      and column_name = 'category'
  ) and not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'trip_places'
      and column_name = 'tag'
  ) then
    alter table public.trip_places rename column category to tag;
  end if;
end $$;

alter table public.trip_places add column if not exists tag text not null default '';
alter table public.trip_planning_items add column if not exists tag text not null default '';

alter table public.trip_places drop constraint if exists trip_places_tag_check;
alter table public.trip_places
  add constraint trip_places_tag_check check (tag = '' or nullif(trim(tag), '') is not null);

alter table public.trip_planning_items drop constraint if exists trip_planning_items_tag_check;
alter table public.trip_planning_items
  add constraint trip_planning_items_tag_check check (tag = '' or nullif(trim(tag), '') is not null);

-- Participant-set join tables mirror trip_expense_splits.
create table if not exists public.trip_place_participants (
  place_id uuid not null references public.trip_places(id) on delete cascade,
  participant_id uuid not null references public.trip_participants(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (place_id, participant_id)
);

create table if not exists public.trip_planning_item_participants (
  planning_item_id uuid not null references public.trip_planning_items(id) on delete cascade,
  participant_id uuid not null references public.trip_participants(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (planning_item_id, participant_id)
);

create index if not exists idx_trip_place_participants_participant_id
  on public.trip_place_participants (participant_id);

create index if not exists idx_trip_planning_item_participants_participant_id
  on public.trip_planning_item_participants (participant_id);

-- Cross-trip integrity triggers.
create or replace function public.assert_place_participant_matches_trip()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  item_trip_id uuid;
begin
  select p.trip_id into item_trip_id
  from public.trip_places p
  where p.id = new.place_id;

  if item_trip_id is null then
    raise exception 'place_id does not reference an existing place';
  end if;

  if not exists (
    select 1
    from public.trip_participants participant
    where participant.id = new.participant_id
      and participant.trip_id = item_trip_id
  ) then
    raise exception 'participant_id must belong to the same trip as the place';
  end if;

  return new;
end;
$$;

create or replace function public.assert_planning_item_participant_matches_trip()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  item_trip_id uuid;
begin
  select i.trip_id into item_trip_id
  from public.trip_planning_items i
  where i.id = new.planning_item_id;

  if item_trip_id is null then
    raise exception 'planning_item_id does not reference an existing planning item';
  end if;

  if not exists (
    select 1
    from public.trip_participants participant
    where participant.id = new.participant_id
      and participant.trip_id = item_trip_id
  ) then
    raise exception 'participant_id must belong to the same trip as the planning item';
  end if;

  return new;
end;
$$;

drop trigger if exists trip_place_participants_trip_check on public.trip_place_participants;
create trigger trip_place_participants_trip_check
  before insert or update on public.trip_place_participants
  for each row execute function public.assert_place_participant_matches_trip();

drop trigger if exists trip_planning_item_participants_trip_check on public.trip_planning_item_participants;
create trigger trip_planning_item_participants_trip_check
  before insert or update on public.trip_planning_item_participants
  for each row execute function public.assert_planning_item_participant_matches_trip();

alter table public.trip_place_participants enable row level security;
alter table public.trip_planning_item_participants enable row level security;

drop policy if exists "trip members can read place participants" on public.trip_place_participants;
create policy "trip members can read place participants"
on public.trip_place_participants for select
to authenticated
using (
  exists (
    select 1
    from public.trip_places p
    where p.id = trip_place_participants.place_id
      and public.is_trip_member(p.trip_id)
  )
);

drop policy if exists "trip members can create place participants" on public.trip_place_participants;
create policy "trip members can create place participants"
on public.trip_place_participants for insert
to authenticated
with check (
  exists (
    select 1
    from public.trip_places p
    where p.id = trip_place_participants.place_id
      and public.is_trip_member(p.trip_id)
  )
);

drop policy if exists "trip members can delete place participants" on public.trip_place_participants;
create policy "trip members can delete place participants"
on public.trip_place_participants for delete
to authenticated
using (
  exists (
    select 1
    from public.trip_places p
    where p.id = trip_place_participants.place_id
      and public.is_trip_member(p.trip_id)
  )
);

drop policy if exists "trip members can read planning item participants" on public.trip_planning_item_participants;
create policy "trip members can read planning item participants"
on public.trip_planning_item_participants for select
to authenticated
using (
  exists (
    select 1
    from public.trip_planning_items i
    where i.id = trip_planning_item_participants.planning_item_id
      and public.is_trip_member(i.trip_id)
  )
);

drop policy if exists "trip members can create planning item participants" on public.trip_planning_item_participants;
create policy "trip members can create planning item participants"
on public.trip_planning_item_participants for insert
to authenticated
with check (
  exists (
    select 1
    from public.trip_planning_items i
    where i.id = trip_planning_item_participants.planning_item_id
      and public.is_trip_member(i.trip_id)
  )
);

drop policy if exists "trip members can delete planning item participants" on public.trip_planning_item_participants;
create policy "trip members can delete planning item participants"
on public.trip_planning_item_participants for delete
to authenticated
using (
  exists (
    select 1
    from public.trip_planning_items i
    where i.id = trip_planning_item_participants.planning_item_id
      and public.is_trip_member(i.trip_id)
  )
);

-- Atomic participant-set replacement RPCs.
create or replace function public.set_place_participants(
  p_place_id uuid,
  p_trip_id uuid,
  p_participant_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  participant uuid;
begin
  if not public.is_trip_member(p_trip_id) then
    raise exception 'You are not a member of this trip';
  end if;

  if not exists (
    select 1
    from public.trip_places p
    where p.id = p_place_id
      and p.trip_id = p_trip_id
  ) then
    raise exception 'Place not found for trip';
  end if;

  foreach participant in array coalesce(p_participant_ids, array[]::uuid[]) loop
    if not exists (
      select 1
      from public.trip_participants tp
      where tp.id = participant
        and tp.trip_id = p_trip_id
    ) then
      raise exception 'Participant must belong to the trip';
    end if;
  end loop;

  delete from public.trip_place_participants
  where place_id = p_place_id;

  foreach participant in array coalesce(p_participant_ids, array[]::uuid[]) loop
    insert into public.trip_place_participants (place_id, participant_id)
    values (p_place_id, participant)
    on conflict do nothing;
  end loop;
end;
$$;

create or replace function public.set_planning_item_participants(
  p_planning_item_id uuid,
  p_trip_id uuid,
  p_participant_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  participant uuid;
begin
  if not public.is_trip_member(p_trip_id) then
    raise exception 'You are not a member of this trip';
  end if;

  if not exists (
    select 1
    from public.trip_planning_items i
    where i.id = p_planning_item_id
      and i.trip_id = p_trip_id
  ) then
    raise exception 'Planning item not found for trip';
  end if;

  foreach participant in array coalesce(p_participant_ids, array[]::uuid[]) loop
    if not exists (
      select 1
      from public.trip_participants tp
      where tp.id = participant
        and tp.trip_id = p_trip_id
    ) then
      raise exception 'Participant must belong to the trip';
    end if;
  end loop;

  delete from public.trip_planning_item_participants
  where planning_item_id = p_planning_item_id;

  foreach participant in array coalesce(p_participant_ids, array[]::uuid[]) loop
    insert into public.trip_planning_item_participants (planning_item_id, participant_id)
    values (p_planning_item_id, participant)
    on conflict do nothing;
  end loop;
end;
$$;

revoke all on function public.assert_place_participant_matches_trip() from public;
revoke all on function public.assert_place_participant_matches_trip() from anon;
grant execute on function public.assert_place_participant_matches_trip() to authenticated;

revoke all on function public.assert_planning_item_participant_matches_trip() from public;
revoke all on function public.assert_planning_item_participant_matches_trip() from anon;
grant execute on function public.assert_planning_item_participant_matches_trip() to authenticated;

revoke all on function public.set_place_participants(uuid, uuid, uuid[]) from public;
revoke all on function public.set_place_participants(uuid, uuid, uuid[]) from anon;
grant execute on function public.set_place_participants(uuid, uuid, uuid[]) to authenticated;

revoke all on function public.set_planning_item_participants(uuid, uuid, uuid[]) from public;
revoke all on function public.set_planning_item_participants(uuid, uuid, uuid[]) from anon;
grant execute on function public.set_planning_item_participants(uuid, uuid, uuid[]) to authenticated;
