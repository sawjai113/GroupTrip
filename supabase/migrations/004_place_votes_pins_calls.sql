-- Chunk 7 / 5A: Places voting + pins + call-for-vote.

alter table public.trip_places add column if not exists pinned_at timestamptz;
alter table public.trip_places add column if not exists called_for_vote_at timestamptz;
alter table public.trip_places add column if not exists called_by uuid;

alter table public.trip_places drop constraint if exists trip_places_called_by_fkey;
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'trip_places_called_by_participant_fkey'
      and conrelid = 'public.trip_places'::regclass
  ) then
    alter table public.trip_places
      add constraint trip_places_called_by_participant_fkey
      foreign key (called_by) references public.trip_participants(id) on delete set null;
  end if;
end $$;

create or replace function public.participant_for_current_user(check_trip_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select tp.id
  from public.trip_participants tp
  where tp.trip_id = check_trip_id
    and tp.linked_user_id = auth.uid()
  limit 1;
$$;

revoke all on function public.participant_for_current_user(uuid) from public;
revoke all on function public.participant_for_current_user(uuid) from anon;
grant execute on function public.participant_for_current_user(uuid) to authenticated;

create table if not exists public.trip_place_votes (
  place_id uuid not null references public.trip_places(id) on delete cascade,
  participant_id uuid not null references public.trip_participants(id) on delete cascade,
  vote text not null,
  created_at timestamptz not null default now(),
  primary key (place_id, participant_id),
  constraint trip_place_votes_vote_check check (vote in ('yes', 'weak', 'no'))
);

create index if not exists idx_trip_place_votes_participant_id
  on public.trip_place_votes (participant_id);

alter table public.trip_place_votes enable row level security;

drop policy if exists "trip members can read place votes" on public.trip_place_votes;
create policy "trip members can read place votes"
on public.trip_place_votes for select
to authenticated
using (
  exists (
    select 1
    from public.trip_places p
    where p.id = trip_place_votes.place_id
      and public.is_trip_member(p.trip_id)
  )
);

drop policy if exists "trip members can insert own place votes" on public.trip_place_votes;
create policy "trip members can insert own place votes"
on public.trip_place_votes for insert
to authenticated
with check (
  participant_id = (
    select public.participant_for_current_user(p.trip_id)
    from public.trip_places p
    where p.id = trip_place_votes.place_id
  )
);

drop policy if exists "trip members can update own place votes" on public.trip_place_votes;
create policy "trip members can update own place votes"
on public.trip_place_votes for update
to authenticated
using (
  participant_id = (
    select public.participant_for_current_user(p.trip_id)
    from public.trip_places p
    where p.id = trip_place_votes.place_id
  )
)
with check (
  participant_id = (
    select public.participant_for_current_user(p.trip_id)
    from public.trip_places p
    where p.id = trip_place_votes.place_id
  )
);

drop policy if exists "trip members can delete own place votes" on public.trip_place_votes;
create policy "trip members can delete own place votes"
on public.trip_place_votes for delete
to authenticated
using (
  participant_id = (
    select public.participant_for_current_user(p.trip_id)
    from public.trip_places p
    where p.id = trip_place_votes.place_id
  )
);
