# 005 Calm Trip Design — App Implementation Brief (M4 + M5)

**Status:** Chunks 1–6 SHIPPED (`026773a`…`7c9e135`) — Chunk 6 (Money) awaiting user visual checkpoint. Chunk 7 (M5 core) scoping in progress (@architect decomposition dispatched 2026-09-02). Offline-pickup test in progress: pipeline continues autonomously while the user reviews Chunk 6; all decisions recorded here as the durable channel.
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
**Status: SCOPE APPROVED 2026-09-01 (@architect) — full spec below. @design chip handoff in flight (parallel, quota pause). Logic-first TDD at resume.**
- (a) Tag chips in add/edit sheet (todo #14): replace Category text field with chip row from `TripTag.subset(for: .place)` (food/hotel/show/museum) + Custom chip revealing a text field. Precedence: custom text wins over chip; tap-again deselects; prefill correct (canonical → chip, custom → Custom+field, empty → none). Save writes via existing TripPlace.tag (chunk 2 persistence — store untouched).
- (b) Filter chips on list (client-side): All + food/hotel/show/museum above the list; single-select exact-match; no-match → EmptyFeatureCard; no Custom filter chip (entry mode, not filter); no Pinned/Calls (M5).
- (c) Google Maps tap-through (todo #21 M4 step): pure URL builders (TDD) — `comgooglemaps://?q=<encoded name>` app URL + `https://www.google.com/maps/search/?api=1&query=` web fallback, built via URLComponents (correct %-encoding for &, ?, unicode; test "D&D Diner", "Café"). Open: `@Environment(\.openURL)` async-Bool, fallback to web on failure; NO canOpenURL/LSApplicationQueriesSchemes; NO confirm (non-destructive). Row body tap = Open in Maps (additive — no current tap action), pencil = edit, trash = delete.
- (d) #14a resolution: visible pencil icon replaces mappin as edit affordance (mappin reads "location"; matches other editable items). Row tap = maps is additive.
- **Out of scope:** voting/weights/pins/locked-in markers, MapKit + map-card visual, notes enrichment, Places search/autocomplete/previews, lat/lng threading (all M5/Later).
- **TDD (pure Foundation):** PlaceTagInput (resolvedTag precedence, prefill mapping), filter `filtered(by:)`, PlaceMapsLink (app/web shapes, percent-encoding, nil for empty), TripTag subset pin test. UI-only: chip visuals/filter row/row layout (needs @design).
- **Files:** TripModels.swift (+PlaceTagInput, filtered(by:), PlaceMapsLink — Foundation-pure, no pbxproj churn); TripPlacesView.swift (filter row + row redesign + AddTripPlaceView chip row + openURL env); tests in TripCollaborationModelsTests.swift (new TripPlacesLogicTests class).
- **Sequencing:** logic-first at resume (zero design dep) → @design handoff lands in parallel → UI wiring → build + full suite + @review gate.
- **Handoff notes for @coding:** chips row = separate section above list (no row overlays — QA 5b); confirm async openURL-Bool fallback compiles on iOS target (iOS 15+).

**Interim chip UI spec (drafted by @general from approved prototype + design-system skill; @design REVIEWED 2026-09-02 — APPROVE WITH CORRECTIONS, relayed to @coding; corrections below supersede the draft where they differ):**
- Chip language from prototype (`variants/005-calm-prototype/index.html` `.chips`/`.chip`): horizontal scroll row, capsule chips, `.chip.active` = forest fill + white text. SwiftUI: `ScrollView(.horizontal, showsIndicators: false)` + HStack; capsule via `Capsule()` clip; chip = `Text` + `.padding(.horizontal, 11).padding(.vertical, 8)` + `.font(.caption.weight(.bold))` (prototype 11.5px/850); active: `AppTheme.Editorial.forest` bg + white text; inactive: `Editorial.card` bg + `Editorial.border` stroke + `Editorial.secondaryText`.
- Tag chip row in AddTripPlaceView: chips from `TripTag.subset(for: .place)` + a `Custom` chip; custom chip selected → reveal `EditorialTextField` below the row; tap target ≥44pt; active custom chip shows forest fill while field is visible.
- Filter chip row on list: same chip component, own section above list (`EditorialSectionHeader(title: "Filter")` optional — prototype uses plain chip row); All = no selection state.
- Place row redesign: `HStack` — `WaniIconBadge(systemImage: "mappin", tint: FeatureColor.places)` thumb, name (`.body.weight(.semibold)`, primaryText), tag pill (`.pill`-style: capsule, `Editorial.border`, secondaryText, caption), trailing controls: pencil (`pencil` icon, forest) + trash (destructive). Row body `.contentShape(Rectangle())` + `.onTapGesture` → maps; `.buttonStyle(.plain)` on icon buttons (no nested Buttons inside the tap row).
- Empty filter state: `EmptyFeatureCard`-style ("No places match this tag") with `Editorial.card` surface.
- Contrast check (light+dark): forest-on-card active chip meets 4.5:1; secondaryText on card verified in existing tokens.

**@design corrections (2026-09-02, apply to UI wiring — supersede draft where they differ):**
1. Chips: h-pad 11 / v-pad 8 / gap 8 / capsule; `.frame(minHeight: 44)` for tap target without bulk; `.font(.caption.weight(.bold))`; TITLE-CASE labels (no all-caps).
2. Active = Editorial.forest + white text + forest border. Inactive = Editorial.card + Editorial.border + Editorial.secondaryText. NEVER FeatureColor.places as active fill. Dark = same semantic tokens.
3. Custom chip: selects + reveals EditorialTextField below (spacing 8–12, "Custom tag" label, placeholder e.g. "bakery"). Custom active while field visible; typed value only in field (NOT duplicated as second chip). Canonical tap while custom active → deselect custom, resolve canonical. Custom trimmed text wins. Tap active canonical again = no tag.
4. Filter rail: plain chip row in own section between page header and list — NO "Filter" header, NOT sticky, never overlaid on rows.
5. ROW (most important): row body tap = Maps BUT mappin thumb reads NON-INTERACTIVE identity (display only). Thumb `mappin.and.ellipse` FeatureColor.places. Main: name (.body.weight(.semibold) primaryText) + tag pill + note. Tag pill inline after title only if no crowding, else second line. Trailing: pencil (forest, 44pt) then trash (destructive, 44pt). Maps affordance: subtle "Open in Maps" caption + arrow.up.right.square ONLY when no note.
6. Tag pill QUIET: Editorial.card/raisedCard fill + Editorial.border stroke + Editorial.secondaryText, caption2 semibold, h8 v4 capsule — NOT places red/orange (competes with trash). Canonical labels title case; custom shows trimmed text as-is.
7. Empty-filter: EmptyFeatureCard "No places match this tag" / "Try All or choose another tag." — only when places exist + filter matches none; places.isEmpty keeps existing "No places saved yet".
8. A11y: row "Open <place> in Maps"; pencil "Edit <place>"; trash "Delete <place>". No nested Buttons — row onTapGesture + separate trailing Buttons.
- (Voting/weights/pins/MapKit = M5, chunk 6.)

### Chunk 4 — Itinerary (M4): day grouping + optional times
**Status: SCOPE APPROVED 2026-09-02 (@architect) — full spec below. NOT UI-only (migration 003). @design handoff in flight.**
- Day grouping: client-side pure logic `PlanningTimeline.sections(from:)` → chronological day sections + undated bucket. Rules (test-pinned): sections ascending; within-day timed-first by time asc, untimed trailing; ties stable; **done items stay in their day group** (strikethrough/badge carries done state — no bottom Done section); day headers = absolute date (e.g. "Tuesday, September 2"), serif accent; NO "Day 1/2/3" numbering (needs trip-date plumbing for zero M4 benefit).
- Optional times: new nullable `scheduled_time time` column (migration 003) — additive sibling, NOT timestamptz (preserves date-only semantics/backfills). Model `time: Date? = nil`; DTO `scheduledTime` String? + `SupabaseTimeFormatter` ("HH:mm", fixed reference day). Form: "Add time" toggle under "Add date" (disabled unless hasDate); resolution guard pure + tested (date nil ⇒ time nil). Card display: per-card date label replaced by optional time label (clock + "8:20") inside dated sections (day header carries the date); backlog cards show neither.
- Undated backlog: bottom section, own EditorialSectionHeader (label: @design — "Undated"/"Backlog"), one shared hairline container; hidden when empty (absence = none); whole-list empty state unchanged.
- **Fake calendar placeholder REMOVED** — CalendarPreviewGrid ("Sample Month", hardcoded highlightedDays [6,9,13,17]) is misleading fake data; M5 builds the real calendar. ~40 lines removed.
- **Deferred to M5:** planning-item tag chips (todo #14 was Places-scoped; no M4 consumer), date ranges (#17), bookings + coordination, participant chips, calendar grid.
- TDD (pure): PlanningTimeline.sections (empty/dated/undated/mixed/unsorted/done-in-group/time-asc/stable/idempotent), SupabaseTimeFormatter round-trip, date+time guard, DTO round-trip. UI-only: day header typography, container treatment, backlog header, time label, add-sheet toggle (@design).
- Files: `supabase/migrations/003_planning_item_time.sql` (ADD COLUMN IF NOT EXISTS scheduled_time time — idempotent, no backfill) + schema.sql append; TripModels.swift (time + sections logic + guard); SupabaseTripService.swift (DTO + formatter + assembly); TripStore verify-only (likely NO change); TripPlanningView.swift (remove placeholder, day groups + backlog, time label, "Add time" toggle); tests; live smoke extended (planning insert gains '08:20', User B reads it — hard gate).
- Sequencing: model/logic/DTO TDD first (no DB) → migration 003 apply live + idempotent re-run + extended smoke green → UI wiring (needs @design) → full suite + build + re-smoke → @review gate.
- Handoff notes for @coding: EditorialDateField needs hourAndMinute variant (or small EditorialTimeField sibling); card needs showsDate=false/showsTime=true flag (keep card dumb); confirm '08:20' literal casts with date-only inserts in smoke.

**@design handoff (2026-09-02 — approved scope; full notes relayed to @coding):**
- Day headers: absolute readable date "Tuesday, September 2" (no Day 1/2/3). Section marker NOT a card: serif `.system(size: 20, weight: .semibold, design: .serif)`, `.tracking(-0.3)`, primaryText. Right meta "3 items" caption semibold secondaryText. Spacing 22–24pt above new day, 8–10pt header→container, first section 4–8pt below screen header. No heavy divider per day; hairline under header only if needed (Editorial.border.opacity(0.7)).
- Per-day container: ONE shared rounded container per day with hairline dividers (sections-own-items) — lighter `PlanningDayGroupCard` list shell, NOT full WaniCard per row. Card bg + border 1pt + radius xLarge/20; row padding h14–16/v12–14; divider Editorial.border.opacity(0.75) with leading inset after the icon. Reuse TripPlanningItemCard internals in a "grouped/list row" mode (no own card bg/border inside a group). Actions unchanged (check/toggle, title/status, note, pencil, trash); done stays in group.
- Time label: dated cards REPLACE the per-card date Label with optional clock time only — `Label("8:20", systemImage: "clock")`, caption medium, secondaryText, below note (or under title if no note), in the text stack not trailing. No time → no date/time metadata in dated sections (day header carries it). Backlog cards show neither. A11y: include time in row label ("8:20, Fushimi Inari sunrise, to do").
- Backlog header: "Undated backlog" (visible), serif 18 semibold, primaryText (or secondaryText if too prominent); meta "Needs a day" or count; same shared hairline container; hidden when empty.
- Add/Edit sheet: `EditorialToggleRow("Add date")` → date field → `EditorialToggleRow("Add time")` (HIDDEN until date on, not visible-disabled — quiet sheet) → time field when both on. Date off ⇒ resolve time nil/hasTime false. **Recommend sibling `EditorialTimeField`** (not hourAndMinute on EditorialDateField — date and time are separate semantics; match EditorialDateField styling; internal `DatePicker(displayedComponents: .hourAndMinute)`, label "Time", minHeight 44). Save: date nil ⇒ time nil.
- Empty state: whole-list empty unchanged; day groups render only when they have items; backlog hidden when empty.
- Token map: group surface Editorial.card; borders Editorial.border 1pt (dividers 0.7–0.8 opacity); headers primaryText; secondary/time/note secondaryText; serif ONLY day headers (row titles stay system body semibold); FeatureColor.itinerary only for existing icon/status accents — do NOT flood timeline with yellow/orange. New tokens: none (optional local constants groupRadius 20, rowVerticalPadding 13).
- Caution: do NOT use the M5 calendar prototype as M4 UI; keep card component dumb (flags showsDate/showsTime or split TripPlanningItemRow from Card).

### Chunk 5 — People (M4): person rooms + message handoff
**Status: SCOPE APPROVED 2026-09-02 (@architect) — full spec below. Pure Swift (NO schema/migration). @design handoff in flight — @coding dispatch waits for handoff in this doc (escalated rule).**
- **Three structural findings (shape the scope):** (F1) Participant model has NO isOrganizer — DTO reads is_organizer but drops it (SupabaseTripService.swift:909) — threading required (model + DTO both directions + demo fixture). (F2) NO app path ever sets is_organizer=true (createTrip makes owner trip_members only; createParticipant defaults false) — M4 = display grouping + demo fixture demonstration; organizer ASSIGNMENT/transfer is an RLS/RPC follow-up (todo #8/#25), flagged to user, NOT auto-included. (F3) Places/plans participant sets exist (chunk 2) but NOTHING populates them (no picker shipped) → person-room "their places/plans" would be permanently empty = dead feature → Chunk 5 INCLUDES the minimal multi-select participant picker on place + planning add/edit sheets (persistence already wired; picker only sets participantIDs).
- Person room data (M4-available only): header card (avatar/name + Organizer badge if isOrganizer + trip-relative money headline from Balance.net: net>0 "Gets back $X" / net<0 "Owes $X" / 0 "Settled" — NOT user-relative; user-first framing stays on Home/Money per todo #26); metrics grid Places + Expenses ONLY (bookings/votes omitted — M5 features, zero cells mislead); their places = participantIDs contains them (participating semantics — NOT added_by); their expenses = paidBy them (list) + "shared in N" count (participants set, paidBy != them); their plans = participantIDs contains them; sections shown ONLY when non-empty; NO recency claims (models carry no dates — label by type); NO votes/bookings/arrival sections, NO settlement action (chunk 6).
- List grouping (004): "Organizer" section (isOrganizer) + "Travelers" (rest), alphabetical within; header hidden when empty; rows gain money-status glance in meta line (color-coded forest/error); pencil + delete confirmation preserved. Demo fixture: Sawjai isOrganizer.
- Message handoff = **iOS SHARE SHEET** (NOT deep links — participants have no phone/email handles, links-to-nowhere; NOT "coming soon"). Prefilled "Join <Trip name> on Wanderaid — invite code <CODE>"; cloud-only (auto-create code if missing); demo hidden; label must NOT say "Message <name>" (promises M5 chat — @design picks honest copy like "Share trip invite"). No chat.
- Navigation: List row → NavigationLink push → PersonDetailView in NEW FILE PersonDetailViews.swift (PeopleViews.swift is 469 lines — split per catch-all rule; **pbxproj registration explicit task** — xcode-pbxproj-file-registration skill). Row tap = detail, pencil = edit sheet, swipe = delete (List handles coexistence; QA 5b clean). New params threaded from TripSummaryView: places, planningItems, tripName, createdInvite/createInvite/usesExternalPersistence.
- Participant-set picker (enabler sub-scope): reusable multi-select (avatar+name checkmarks or chip toggles — @design) in AddTripPlaceView + AddTripPlanningItemView ("Who's in?" optional section); populates participantIDs; edit prefill; NO store/service changes.
- TDD (pure): isOrganizer DTO round-trip; organizer/travelers grouping + empty-group handling; PersonFootprint aggregation (paidExpenses/sharedExpenses/places/plans counts+lists, money phrase as ENUM not Color — Foundation-only); picker set resolution (toggle membership on [UUID]); share text builder. UI-only (@design): hall rows/sections, detail layout, metrics grid, serif headline, picker UI, share copy/icon, role badge.
- Files: TripModels.swift (isOrganizer + PersonFootprint + share text builder — Foundation-only); SupabaseTripService.swift (isOrganizer DTO both directions); TripStore.swift (demo fixture); PeopleViews.swift (grouping + money glance); NEW PersonDetailViews.swift (+pbxproj); TripPlacesView.swift + TripPlanningView.swift (participant picker in sheets); TripSummaryView.swift (thread new params); tests.
- Out of scope: votes/bookings/arrival (M5), organizer assignment RPC + participant-claim (#8/#25 security follow-up), chat (M5), repayment (chunk 6), added_by threading, PeopleTabView asymmetry (flag as later-consistency note).
- Sequencing (new gate): scope + @design handoff in plan doc FIRST → @coding: model/threading + pure-logic TDD → picker wiring → hall grouping + detail UI + pbxproj → demo fixture → full suite/build (no schema change — no migration/smoke beyond standing regression) → @review gate.
- Handoff notes for @coding: PersonDetailView receives plain snapshot arrays (no bindings — aggregation only); money phrase/color as enum mapped in view layer (TripStatus.tint precedent); verify List row + NavigationLink + onDelete coexist; share text = pure builder (TDD), not inline in button.

**@design handoff (2026-09-02 — approved with M4 corrections; full notes relayed to @coding):**
- Hall: invite card top (cloud) → Organizer + Travelers sections via EditorialSectionHeader ("Organizer" / "Travelers" with count meta — NOT "Message anyone", promises M5 chat). List rows keep card background, no system-gray chrome. Money glance in meta ONLY (Gets back = forest / Owes = Editorial.owed preferred / Settled = secondaryText); pencil 44pt forest; delete swipe.
- Person detail (PersonDetailViews.swift, snapshots not bindings — read-only M4): order = header card → serif money headline → metrics grid → Share trip invite → non-empty sections. Header: AvatarInitial 58–64, name .title3 semibold system (reserve serif for money), Organizer quiet pill. Money headline serif 28 semibold tracking(-0.8) ("Gets back $128"/"Owes $42"/"Settled"), forestDeep/owed/secondaryText, INSIDE header card. Metrics grid: TWO cells (Places, Expenses) only, raisedCard + border + radius 18, serif 23–24 value forestDeep, caption2 label secondaryText. Sections (non-empty only, shared hairline containers): "Places they're part of", "Expenses paid" (+ "Shared in N"), "Plans they're part of". All empty → quiet EmptyFeatureCard "No trip activity yet".
- Share button: "Share trip invite" + square.and.arrow.up, forest fill white text full-width radius 16, after metrics grid; nil-code state may read "Create invite to share"; demo hidden.
- Participant picker ("Who's in?"): avatar+name ROWS with checkmarks (NOT chips — 2–8 people, chips wrap/crowd). Placement after identity fields before Notes; selected = checkmark.circle.fill forest (+ optional faint forest 0.08 tint); unselected = circle stroke border; row minHeight 44 contentShape; edit prefill checked; empty participants → hide section or quiet "Add people before assigning this item" (never block save); a11y "Sawyer, selected"/"Maya Chen, not selected".
- Organizer badge: quiet forest pill (capsule h8/v4 caption2 bold, text forestDeep/forest, fill forest 0.10–0.12, optional stroke 0.20) — NOT FeatureColor.people purple (role = trust, not branding).
- Tokens: Editorial.* only; new tokens none (optional locals personHeaderAvatarSize 62, metricRadius 18, groupedRowVerticalPadding 13). FeatureColor.people OK for generic icon badges only.
- Caution: no "Message", no M5-data sections, no settlement action; if List NavigationLink + pencil + swipe fight, prefer accessory edit outside the link label or custom row with explicit nav tap area.

### Chunk 6 — Money (M4): user-first + quick add + repayment guidance
**Status: TIER 1 CONFIRMED 2026-09-02 (@architect — lean scope). No schema/DTO/store changes — all view-layer over existing data. @design handoff rate-limited → INTERIM spec below (from prototype + shipped conventions; @design reviews when quota clears).**
- (a) User-first money (todo #26): thread currentAccountID (UUID?) AuthViews → TripDashboardView → TripSummaryView → ExpenseTrackerView (two-hop, pure param passing). Per-trip resolver: participant where accountID == currentAccountID → Balance.net → "You owe $X" / "You get back $X" / "All settled". HONEST FALLBACK (dashboard precedent): nil/unmapped → keep trip-relative framing; demo must not break. Pure resolver, no store changes.
- (b) Quick-add (3 taps: amount → who paid → confirm; equal split = ALL trip participants incl. payer, deterministic): new sheet calling EXISTING saveExpense (cloud+demo branches exist). WRINKLE: saveExpense guards non-empty title + prototype has no title → auto-title policy (pure, testable: "Expense · Sep 2" from date). Do NOT relax store guard. Placement: ExpenseTrackerView header (Money room) — NOT TripSummary.
- (c) Repayment guidance (todo #19): suggested-settlement rows open EXISTING AddPaymentView pre-filled (from/to/amount from Settlement — pure mapping, editable); standalone "Record Payment" (ExpenseViews:362) removed once covered. Confirmations untouched.
- TDD (pure): account resolver (accountID → participant → balance phrase + nil fallback); quick-add default split set equality (edge 0/1 participants); auto-title builder; settlement→payment prefill mapping. UI-only: hero, quick-add sheet, settlement row action, repayment placement.
- Acceptance: account-aware hero on TripSummary Money + ExpenseTrackerView when mapped, existing framing otherwise (demo intact); 3-tap quick-add persists cloud+demo with auto-title; settlement rows open pre-filled payment, standalone Record Payment gone, edit allowed + cancel leaves state; full suite green; build green; diff --check; secret scan. No migration/smoke.
- Integration: currentAccountID source AuthViews → dashboard → lobby NavLink → TripSummary → ExpenseTracker (TripSummary hosts Money hero too). Quick-add = ExpenseTracker header; repayment = settlements section. Check EVERY TripSummaryView → ExpenseTrackerView presentation site (lobby card + legacy entries) so the param threads everywhere.
- **INTERIM @design handoff (drafted by @general from 005 prototype kitty screen + chunk-5 money conventions; @design review pending quota):** user-first hero atop ExpenseTrackerView — two metric cells (You owe forest/owed / You get back forestDeep) in the chunk-5 two-cell grid style (raisedCard + border + radius 18, serif 23–24 value), honest fallback keeps existing trip-relative BalanceCards below; quick-add card = compact non-formy sheet: amount EditorialTextField (decimal), who-paid EditorialMenuField (default self), caption "Split equally among all N travelers", primary forest "Add Expense" → saveExpense + auto-title; repayment: SettlementCards rows gain explicit action ("Pay Maya $42" pill/button) opening pre-filled AddPaymentView; remove standalone Record Payment button; expense list rows keep status pills. Tokens: Editorial.* + PersonBalancePhrase colors (Gets back forest / Owes owed / Settled secondaryText); no new tokens expected.

### Chunk 7 — M5 core: voting, bookings, feeds/action-needed, chat, MapKit
**Status: DECOMPOSED 2026-09-02 (@architect) — full spec in `docs/plans/005-chunk7-scope.md`. Tier 2 (full pipeline, @review per sub-chunk commit). Dispatch order: 5A → 5B-1 → 5C → 5D-1 → 5E → 5D-2 → 5B-2.**
- Sub-chunks: 5A Places voting + pins + call-for-vote (first — proves the participant-identity RLS helper that 5C/5D reuse); 5B-1 bookings data + timeline coordination; 5B-2 calendar view (DEFERRABLE to M6 per D4 — design-heavy, user checkpoint); 5C trip_activity feed + action-needed; 5D-1 chat infra (schema/RLS/RPCs/service, no UI); 5D-2 chat UI (design-heavy, user checkpoint); 5E MapKit in-room map (user checkpoint).
- Proceed WITHOUT user: 5A, 5B-1, 5C, 5D-1 (offline-pickup test). User visual checkpoints gate: 5B-2, 5D-2, 5E.
- **Hard decisions D1–D7 pending user sign-off (each blocks its sub-chunk):** D1 chat identity = authenticated trip members only, DM only to account-linked participants (guests keep share handoff); D2 trip_activity write path = DB triggers (automatic, drift-proof) over service-layer writes; D3 booking model = NEW trip_bookings table (not planning-item reuse) + vocabulary extension flag ('activity'/'custom' not in TripTag today — UI-visible); D4 calendar scope = M5 ships bookings-on-timeline first, month grid deferrable to M6; D5 MapKit coords = thread lat/lng + geocode-on-save via CLGeocoder (adds network to save path); D6 action-needed MVP = place vote calls only; D7 realtime ops = project-level enablement (NOT in SQL file) + manual two-account checklist for verification.
- Places voting: yes +1 / weak +0.5 / no −1, abstain null; pins; locked-in markers linking to Itinerary.
- Feed grouping + action-needed: activity log (trip_activity data layer) + grouped feed events; call-for-vote on items → Home action-needed.
- Crew: arrival/departure windows derived from bookings (5B-1).

## Out of scope (explicit deferrals)
- Push notifications, typing indicators, read receipts, media, threads (chat).
- Photo hosting decision (M7).
- Google Maps SDK (tap-through URL is enough for M4; MapKit in M5).

## Verification
- Build: `xcodebuild -project "/Users/sawjai/Documents/Group Trip App/GroupTripApp.xcodeproj" -scheme GroupTripApp -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build`
- Tests: full suite green per chunk; TDD for schema/model logic.
- Behavior-preserving rule: design diffs must never touch TripStore/SupabaseTripService/models/viewmodels logic; confirmation flows byte-identical (8 flows).
- @review gate before each commit/push.
