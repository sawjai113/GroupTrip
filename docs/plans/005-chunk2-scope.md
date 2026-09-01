# Chunk 2 Scope — Item Tags + Participant Sets (M4 cross-cutting)

**Status:** Approved by @architect 2026-09-01 · Folded into 005 implementation brief
**Owner:** @coding (implementation) · **QA gate:** @review

# CHUNK 2 SCOPE — Cross-cutting foundation: item tags + participant sets (M4)

## 1. Data model decisions

### (a) Tag storage → single free-text `tag` column, no vocabulary CHECK

**Decision:** One `tag text not null default ''` column on both `trip_places` and `trip_planning_items`, standardized under one column name. `trip_places.category` is renamed to `tag` (values preserved). No lookup table, no `text[]`.

**Why not a lookup/constrained table:**
- The spec explicitly allows custom tags ("custom, plus others (extensible)"). A vocabulary CHECK constraint or FK lookup table would reject custom values at the DB — the vocabulary is a UI/client concept, not a data-integrity constraint.
- M5 consumers are all single-value filters: voting UI filter chips (`WHERE tag = 'food'`), booking types (flight/hotel/activity — one type per booking), per-item-type chip subsets (a client-side map). None need multi-tag.
- **One tag per item, not many** — the spec says "A tag (item type)" (singular). `text[]` would be YAGNI and complicates the DTO/query/assembly for zero consumer.

**Why rename `category` → `tag` now:**
- "One vocabulary" should be expressed coherently in the schema: one column name across item types (and the future M5 bookings table). Doing it in the foundation chunk is cheapest — later it has more consumers (chunk 3 chip UI, chunk 5 footprint).
- Existing `trip_places.category` values need NO backfill transformation: old free-text categories are valid custom tags. Rename preserves data.
- **Boundary flag:** the rename ripples mechanically into view files (TripPlacesView, TripForms — `place.category` → `place.tag`). Compile-only, zero behavior/visual change; I'm treating "no UI changes" as *behavioral*, and doing the rename now keeps chunk 3's diff clean. If the team wants literally zero UI-file churn, the fallback is keeping the Swift property name `category` and mapping it via `CodingKeys` — workable but leaves the incoherent split naming; not recommended.

**Not adding to expenses:** expenses already carry participant sets (splits); expense **tags** have zero consumer in M4 or M5 (Kitty spec never filters expenses by type; no room spec asks for it). Roadmap says "every item type," but YAGNI wins — add expense tags only when a consumer exists. Record as an explicit scope decision.

### (b) Participant sets → join tables (mirror `trip_expense_splits`), not arrays

**Decision:** Two join tables — `trip_place_participants (place_id, participant_id)` and `trip_planning_item_participants (planning_item_id, participant_id)` — with composite PKs, exactly like the proven splits pattern.

**Why not `uuid[]` on the item table:**
- **RLS:** join tables get the same per-row membership policies as splits (proven pattern, security-passed). An array column rides on the parent row's RLS and writes become full-row replacement — a participant-set edit would rewrite the whole item row, risking concurrency clobbering on shared trips.
- **Referential integrity:** FK per participant with `on delete cascade` (matching splits). An array column can't FK to `trip_participants`, so deleting a participant would leave dangling UUIDs and no cleanup.
- **M5 derived queries:** "their calendar / things Sam is part of" = `select item_id from ..._participants where participant_id = X` — trivially indexed (index on `participant_id` per table). Array + GIN is awkward and non-relational.
- **Preserves history semantics:** like splits, `on delete cascade` on the participant FK means removing a person cleans their participation links (consistent with the existing People delete flow). Trip deletion cascades via the item FK (`on delete cascade` on `place_id`/`planning_item_id`).

**Semantics:** `participantIDs` empty = unset (item stands alone; appears in group lists, in nobody's personal calendar). This is the "participating ≠ added-by" rule: added_by stays on the item row (existing triggers), participation lives in the join table.

### (c) Tags/participants on expenses → participants only (already exists), tags deferred

Covered above. Chunk 2 touches places + planning items only.

## 2. Migration strategy (LIVE Supabase)

**One new file + schema.sql stays source of truth:**
- Create `supabase/migrations/002_item_tags_participant_sets.sql` (first file in a new migrations dir) containing ONLY this chunk's delta — clean review + clean apply.
- Append the identical section to `supabase/schema.sql` (repo convention: single source of truth for bootstraps). Statements are idempotent, so applying the delta file to the live DB and later re-running schema.sql don't conflict.

**Apply + verify commands:**
```sh
# Apply the delta to the live project
npx supabase db query --linked --file supabase/migrations/002_item_tags_participant_sets.sql

# Prove idempotency: re-run must succeed with zero errors
npx supabase db query --linked --file supabase/migrations/002_item_tags_participant_sets.sql

# Verify the schema landed
npx supabase db query --linked -c "select column_name from information_schema.columns where table_name in ('trip_places','trip_planning_items') and column_name='tag'; select count(*) from public.trip_place_participants;"
```
Fallback if CLI query is unavailable: paste the file into the Supabase dashboard SQL editor (same content).

**Non-idempotent flag:** `alter table trip_places rename column category to tag` fails on second run — it MUST be wrapped in a `DO $$` block guarded by an `information_schema.columns` existence check (same style as the existing `trip_members` pkey-upgrade DO block). This is the single non-idempotent statement; everything else is `create table if not exists` / `add column if not exists` / `drop policy if exists` + `create policy` / `create or replace function` / `revoke`+`grant`.

**Backfill:** none needed. Renamed column keeps values (old categories = valid custom tags); new `trip_planning_items.tag` defaults `''` (untagged) for existing rows.

## 3. SQL DDL sketch

```sql
-- ============================================================
-- CHUNK 2: ITEM TAGS + PARTICIPANT SETS (M4 cross-cutting)
-- ============================================================

-- (1) One tag vocabulary column on both item tables
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'trip_places' and column_name = 'category'
  ) then
    alter table public.trip_places rename column category to tag;
  end if;
end $$;

alter table public.trip_planning_items add column if not exists tag text not null default '';

-- optional polish, matches repo check style:
alter table public.trip_places drop constraint if exists trip_places_tag_check;
alter table public.trip_places add constraint trip_places_tag_check check (tag = '' or nullif(trim(tag),'') is not null);
alter table public.trip_planning_items drop constraint if exists trip_planning_items_tag_check;
alter table public.trip_planning_items add constraint trip_planning_items_tag_check check (tag = '' or nullif(trim(tag),'') is not null);

-- (2) Participant-set join tables (mirror trip_expense_splits)
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
create index if not exists idx_trip_place_participants_participant_id on public.trip_place_participants (participant_id);
create index if not exists idx_trip_planning_item_participants_participant_id on public.trip_planning_item_participants (participant_id);

-- (3) Cross-trip integrity triggers (mirror assert_expense_split_participant_matches_trip)
create or replace function public.assert_place_participant_matches_trip()
returns trigger language plpgsql set search_path = public as $$
declare item_trip_id uuid;
begin
  select trip_id into item_trip_id from public.trip_places where id = new.place_id;
  if item_trip_id is null then raise exception 'place_id does not reference an existing place'; end if;
  if not exists (select 1 from public.trip_participants p where p.id = new.participant_id and p.trip_id = item_trip_id) then
    raise exception 'participant_id must belong to the same trip as the place';
  end if;
  return new;
end; $$;
-- assert_planning_item_participant_matches_trip(): identical shape against trip_planning_items
drop trigger if exists trip_place_participants_trip_check on public.trip_place_participants;
create trigger trip_place_participants_trip_check before insert or update on public.trip_place_participants
  for each row execute function public.assert_place_participant_matches_trip();
-- same trigger for trip_planning_item_participants

-- (4) RLS — read/insert/delete for trip members; NO update (replace = delete+insert via RPC)
alter table public.trip_place_participants enable row level security;
alter table public.trip_planning_item_participants enable row level security;
-- read: exists(select 1 from trip_places p where p.id = place_id and public.is_trip_member(p.trip_id))
-- insert: same membership subquery (with check)
-- delete: same membership subquery (using)
-- (mirror the splits policies exactly, swapping the parent lookup)

-- (5) Atomic replace RPCs (mirror update_trip_expense's split replacement)
create or replace function public.set_place_participants(
  p_place_id uuid, p_trip_id uuid, p_participant_ids uuid[]
) returns void language plpgsql security definer set search_path = public as $$
declare split_participant_id uuid;
begin
  if not public.is_trip_member(p_trip_id) then raise exception 'You are not a member of this trip'; end if;
  if not exists (select 1 from public.trip_places where id = p_place_id and trip_id = p_trip_id) then
    raise exception 'Place not found for trip';
  end if;
  foreach split_participant_id in array p_participant_ids loop
    if not exists (select 1 from public.trip_participants p where p.id = split_participant_id and p.trip_id = p_trip_id) then
      raise exception 'Participant must belong to the trip';
    end if;
  end loop;
  delete from public.trip_place_participants where place_id = p_place_id;
  foreach split_participant_id in array p_participant_ids loop
    insert into public.trip_place_participants (place_id, participant_id) values (p_place_id, split_participant_id);
  end loop;
end; $$;
-- set_planning_item_participants: identical shape against planning items

-- (6) ACL: revoke both RPCs from public/anon, grant to authenticated;
--     revoke the two trigger functions from public/anon, grant to authenticated (FUNCTION ACL LOCKDOWN section)
```

**RLS/safety answers:** trip members read/write (mirror splits); added_by stays on the item rows (existing triggers untouched); participant delete → cascade cleans links (matches splits; the M5 person-room footprint is derived data and self-heals); tags are plain columns on tables that already have trip-member UPDATE policies — no narrow RPC needed for tags; participant-set replacement DOES get a narrow RPC (atomic delete+insert, member-gated, cross-trip validation server-side) mirroring `update_trip_expense` — same reasoning: replace-whole-set in one transaction, single deterministic call for tests + live smoke. Direct INSERT/DELETE policies remain on the join tables for defense-in-depth parity with splits.

## 4. TDD plan — Swift file-by-file (six-file pattern)

**TripModels.swift**
- `TripPlace`: `category` → `tag`, add `var participantIDs: [UUID] = []` (defaulted — existing call sites keep compiling).
- `TripPlanningItem`: add `var tag: String = ""`, `var participantIDs: [UUID] = []`.
- New `TripTag` data type: canonical vocabulary constant (food/hotel/flight/show/museum/custom, raw-string extensible) + `subset(for:)` map for place vs planning-item chip subsets — data-only, unit-testable, consumed by chunk 3's chips. Lives in TripModels.swift (repo model convention).

**SupabaseTripService.swift**
- Protocol `TripSyncServicing`: add `setPlaceParticipants(_ participantIDs: [UUID], for placeID: UUID, in tripID: UUID) async throws` + planning-item twin.
- DTOs: `SupabaseTripPlaceDTO` (CodingKeys `tag`; participantIDs NOT on the insert DTO), `SupabaseTripPlanningItemDTO` (+tag), new `SupabasePlaceParticipantDTO` + `SupabasePlanningItemParticipantDTO` (place_id/item_id + participant_id) for fetch/decode.
- `loadTrips`: add the two link-table fetches (trip-filtered); `assembleTrips`: build `[UUID: [UUID]]` maps, attach to models (empty when none).
- Service impls: `createPlace`/`updatePlace` include tag in the row DTO; participant links go through the new protocol methods calling the RPCs (array param encoded like `SupabaseUpdateExpenseDTO.p_participant_ids`).

**TripStore.swift**
- `savePlace(place, to:)` cloud path: `createPlace` → on success `setPlaceParticipants(place.participantIDs)` → `addEntity(saved)`; either failure → `syncError`, **no local mutation**. Demo path unchanged.
- `updatePlace`: `updatePlace` → replace links → local replace.
- `savePlanningItem` / `updatePlanningItem`: same shape.
- `removePlace` / `removePlanningItem`: unchanged (links cascade server-side).

**View files (compile-only):** TripPlacesView.swift, TripForms.swift, TripPlanningView.swift — `category`→`tag` renames. No behavior/visual change.

**TripCollaborationModelsTests.swift**
- Fake: `setPlaceParticipantsRequest` / `setPlanningItemParticipantsRequest` captures + error injection.

## 5. Test list

New:
1. DTO round-trip: place DTO encodes tag; link DTOs decode place_id/participant_id.
2. assembleTrips: place + planning item gain tag and participantIDs from fetched links; empty set when no links.
3. Store savePlace cloud: createPlace called with tag; setPlaceParticipants called with the place's participantIDs; local place added with participants.
4. Store savePlace failure: createPlace throws → no local mutation, syncError set.
5. Store savePlace link-failure: createPlace succeeds, setPlaceParticipants throws → local unchanged, syncError set.
6. Store updatePlace: row update + link replacement.
7. Store demo path: no service → local-only add, no cloud calls.
8. TripTag vocabulary: canonical list correct; `subset(for:)` returns the right per-item-type sets.

Must stay green (compile-fix fixtures only): all `TripStoreCloudSyncTests`, `TripExpenseCalculatorTests`, `DashboardSummaryTests`, `TripCollaborationModelsTests`, chunk 1 tests. **Baseline: confirm full suite green before kickoff (97 at M3 closeout + chunk 1).**

## 6. Acceptance criteria (definition of done)

1. Migration SQL written (idempotent; guarded rename) as `supabase/migrations/002_item_tags_participant_sets.sql` + appended to schema.sql.
2. Applied to LIVE Supabase via `npx supabase db query --linked --file ...`; **re-run succeeds** (idempotency proven).
3. Extended `live_cross_user_smoke.sql` passes: User A creates a tagged place + planning item with participant links + calls both replace-RPCs; User B reads tag + links through normal RLS; rollback leaves zero fixture rows (verified count).
4. Swift changes per the six-file pattern; targeted + full suite green.
5. Generic build green; `git diff --check` clean; secret scan clean.
6. **No UI behavior changes:** no tag chips, no participant picker, no filter UI, no person-room footprint UI. (View files touched only by the mechanical rename.)
7. @review pre-commit gate passed.
8. **The two-account RLS smoke is a hard gate — confirmed:** this is the riskiest live schema change; cross-account read of the new tables, triggers, and RPCs must be proven by the rollback smoke before the chunk is done.

## 7. Sequencing within the chunk

**Schema-first, then Swift.** Rationale: the live apply is the risky step and it's independently provable with SQL alone (the smoke file IS the contract spec — column names, RPC signatures, RLS behavior). Proving it first means Swift is written against a verified contract with zero rework risk; Swift unit tests use fakes, so they never need the live DB anyway.

1. **Prove the gap** (skill checkpoint): confirm no tag/participant columns or tables exist (verified in this review — gap is real).
2. Write migration file + extend smoke file.
3. **Apply to live + run extended smoke green** (schema proven before any Swift).
4. Swift TDD in the six-file order: models (+TripTag) → DTOs/assembly → service protocol+impl → store → fake+tests.
5. Verification rollup: targeted tests → cloud suite → full suite → generic build → re-run live smoke → verify zero fixture rows → secret scan → `git diff --check`.
6. @review gate; then chunk 3 can start (tag chips UI will be a clean diff).

**Risk flags:** (a) create+link is two calls with a small non-atomic window — a failed link leaves an untagged/unlinked item row; recoverable on next edit, consistent with "failed cloud edits don't appear saved locally" (store sets syncError, no local mutation); (b) the rename touches UI files mechanically — flagged above; (c) participant-set persistence has NO M4 UI consumer (first real consumer is chunk 5/M5 person-room + voting) — the chunk is roadmap-correct (M4 foundation) but the honest framing is: tags get their consumer in chunk 3, participant sets are exercised by tests + smoke until M5.

---
