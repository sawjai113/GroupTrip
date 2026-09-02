# 005 Calm Trip Design — App Implementation Brief (M4 + M5)

**Status:** Chunk 1 SHIPPED (`026773a`) · Chunk 2 SHIPPED (`ac0a3d9`, live schema applied + smoke green, 108/108 tests) — CLOSED OUT 2026-09-01 17:19 PDT for Codex quota reset (resume ~21:00 PDT). Next: Chunk 3.
**Date:** 2026-09-01
**Approved design:** `wanderaid-designs/variants/005-calm-prototype/` (commits `f2190a0` → `b1ab181` → `58ca81f`, pushed by @design)
**Sources:** docs/design-thoughts.md (room specs), docs/plans/rooms-to-milestones.md, docs/product-roadmap.md (M4/M5), docs/todo-feedback.md

## Goal

Implement the approved 005 prototype into the SwiftUI app: the user-facing room pages (Home, Trip Overview, Places, Itinerary, People, Money, Memories, Chat) with the basecamp room behaviors agreed in the specs. M4 delivers the *foundations + quick wins*; M5 delivers the *differentiated core* (voting, bookings, feeds/action-needed, chat).

## Design principles to honor (durable, from docs/design-thoughts.md)

1. **Internal names ≠ user-facing names.** Rooms are internal language (Map Wall, Schedule Board, Crew, Kitty, Welcome Desk, Journal). Users see: Places, Itinerary, People, Money/Expenses, Trip Overview, Memories, Home.
2. **Photo hero per trip.** Trip page leads with a cover image (upload or image URL — NewTripView already supports both). Home mirrors the same hero.
3. **Sections own their items.** One shared container with hairline dividers per section; no per-item card islands.
4. **Glance first, contribute second.** Every screen states where things stand before asking anything.
5. **Serif = emotional moments only.** Countdown numbers, trip names, money amounts. Everything else system fonts.
6. **Countdown:** live ticking (days/hours/min/sec), future trips only, serif hero. Reusable component used on Home + Trip Overview.

## Execution model (team delegation)

| Chunk | Owner (implementation) | Support | QA gate |
|---|---|---|---|
| All chunks | @coding (Codex lane) | @design (visual handoff), @architect (scope) | @review before commit/push |

- Planning/scope: `general` (this session) + @architect.
- Design handoff notes: @design (knows the prototype — they built/pushed it).
- Implementation: @coding with TDD; build + tests green per chunk.
- QA: @review (diff review, secret scan, whitespace, tests) before each commit/push.

## Chunk plan (proposed sequencing — @architect to triage)

### Chunk 1 — Home countdown hero + Welcome Desk lobby reframe (M4 quick wins)
**Status: SHIPPED 2026-09-01 (commit `026773a`, @review PASS, 100/100 tests).** User visual checkpoint on device in progress.
- New reusable `CountdownView` (TimelineView ticker, serif numerals, glass panel variant for photo overlay, future-trips-only).
- Home (TripDashboardView): FeaturedTripsCarousel hero → photo hero + "Current/Next" pill + live countdown overlay (future trips only), tappable into the trip. Matches prototype v3.1/v3.2.
- Trip Overview (TripSummaryView): reframe as lobby — photo hero + compact countdown + place/date + who's-going (AvatarCluster) + trip sections grid (Places/Itinerary/People/Money + Memories/Chat placeholder entries) + activity feed TRUE empty state (no fake feed rows — trip_activity is M5) + "Open group chat" placeholder card (existing PlaceholderActionCard behavior).
- Move invite code creation off the trip landing → People page (todo item 24; prototype shows invite row on People; `usesExternalPersistence` gates demo mode).

**Chunk 1 acceptance criteria (@architect):**
- Countdown math (days/hours/min/sec + rollover) as pure logic with unit tests; TimelineView ticker per second; serif numerals; ONE compact 4-unit box (not four cards).
- Hero: photo hero + Current/Next pill + countdown overlay, tap preserves existing navigation into TripSummaryView.
- Lobby: photo hero + compact countdown + place/date + AvatarCluster + sections grid + feed empty state + chat placeholder card.
- Invite move: People page owns create/copy/copied-feedback; Trip Summary no longer shows InvitePeopleCard; demo mode shows no invite controls; behavior byte-identical.
- Behavior-preserving: TripStore/SupabaseTripService/models/viewmodels untouched; 8 confirmation flows byte-identical; all existing NavigationLinks preserved.
- Accessibility: ticking countdown needs a stable VoiceOver label (e.g. "3 days, 4 hours, 12 minutes until Japan Spring 2027") — raw ticking text is an a11y hazard.
- Build + full suite green (baseline 97/97).
- User visual checkpoint (simulator, light+dark) after Chunk 1 before Chunk 2.
- @review gate passed before commit.

### Chunk 2 — Cross-cutting foundation: tags + participant sets (M4, schema + TDD)
**Status: SHIPPED 2026-09-01 (commit `ac0a3d9`; migration applied live + idempotent; extended two-account RLS smoke GREEN; 108/108 tests; build green).** QA run by orchestrator fallback (@review was rate-limited on provider quota — formal @review sign-off can be re-run at resume if desired).
- One `tag` column on places + planning items (rename `trip_places.category` → `tag`, values preserved); no lookup table/CHECK — vocabulary is a client-side `TripTag` type (custom tags spec'd). One tag per item.
- Participant sets = join tables `trip_place_participants` + `trip_planning_item_participants` mirroring `trip_expense_splits` (composite PK, cascade FKs, participant_id index for M5 "their calendar"). NOT uuid[] (no FK integrity, full-row replace, no per-person RLS).
- Migration: `supabase/migrations/002_item_tags_participant_sets.sql` + schema.sql append; apply live via `npx supabase db query --linked --file`, re-run proves idempotency (guarded DO block for the rename).
- RLS: split-mirror policies on join tables; cross-trip integrity triggers; narrow security-definer RPCs `set_place_participants` / `set_planning_item_participants` (atomic replace, member-gated); tags ride existing UPDATE policies.
- Expenses: participants already exist; expense tags deferred (zero consumer in M4/M5 — explicit scope decision).
- **Hard gate: two-account rollback RLS smoke on LIVE Supabase (schema-first: apply + smoke green BEFORE Swift).**
- Sequencing: schema-first → Swift six-file pattern (models + TripTag → DTOs/assembly → service → store → fake+tests) → verification rollup → @review gate.
- Risk flags: create+link two-call window (syncError, no local mutation); rename touches view files mechanically (compile-only); participant-set persistence has no M4 UI consumer (exercised by tests + smoke until M5).

### Chunk 3 — Places (M4): tags UI + Google Maps tap-through
- Category/tag chips in add/edit place (todo 14: one-tap common categories + custom).
- "Open in Maps" tap-through (URL scheme) on place rows (M4).
- Consistent edit affordance on place rows (todo 14a).
- (Voting/weights/pins/MapKit = M5, chunk 6.)

### Chunk 4 — Itinerary (M4): day grouping + optional times
- Day-grouped timeline (date headers, serif accents) + optional time fields; undated backlog section.
- (Calendar view + bookings + coordination = M5, chunk 7.)

### Chunk 5 — People (M4): person rooms + message handoff
- Organizer/Travelers grouping (from 004 spec).
- Person detail view: aggregated footprint (their places, expenses, bookings, votes, role, money status at a glance) — derived from existing data where possible.
- Message handoff (contact sheet / WhatsApp / Discord) as pre-chat MVP.
- Invite code row at top of People (from chunk 1).

### Chunk 6 — Money (M4): user-first + quick add + repayment guidance
- User-first "what I owe / you get back" balance summary at top of expenses (needs currentAccountID threading — existing follow-up).
- Quick-add expense (3 taps: amount, who paid, equal split default).
- Repayment guidance view (todo 19: settlements → pre-filled payment).

### Chunk 7 — M5 core: voting, bookings, feeds/action-needed, chat, MapKit
- Places voting: yes +1 / weak +0.5 / no −1, abstain null; pins; locked-in markers linking to Itinerary.
- Itinerary calendar + bookings (flights/stays/activities, participant sets, coordination overlay).
- trip_activity data layer + grouped feeds + call-for-vote → action-needed on Home.
- Chat: trip channel + cross-trip DMs, text realtime MVP on Supabase Realtime, unread dots.
- MapKit in-room map view.
- Journal/Memories guest book = M6 (not in this pass; keep placeholder entry).

## Out of scope (explicit deferrals)
- Push notifications, typing indicators, read receipts, media, threads (chat).
- Photo hosting decision (M7).
- Google Maps SDK (tap-through URL is enough for M4; MapKit in M5).

## Verification
- Build: `xcodebuild -project "/Users/sawjai/Documents/Group Trip App/GroupTripApp.xcodeproj" -scheme GroupTripApp -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build`
- Tests: full suite green per chunk; TDD for schema/model logic.
- Behavior-preserving rule: design diffs must never touch TripStore/SupabaseTripService/models/viewmodels logic; confirmation flows byte-identical (8 flows).
- @review gate before each commit/push.
