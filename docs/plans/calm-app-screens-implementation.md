# Calm App Screens — App-Wide Implementation Plan

Status: In progress
Last updated: 2026-08-20
Source mockup: https://sawjai113.github.io/wanderaid-designs/variants/004-calm-app-screens/ (variant 004, direction sketches)
Base direction: docs/plans/calm-user-dashboard-design-direction.md (page-level implications §)

## Goal

Convert every existing Wanderaid page from the legacy shell to the Calm Editorial system established by the dashboard (warm paper / warm dark, serif display moments, forest-green actions, amber/terracotta accents, rounded cards, low-noise tappable rows). Light + dark variants everywhere. Preserve ALL behavior, confirmations, and safety rules.

## Current state (2026-08-20)

- Converted: TripDashboardView (header, hero carousel, attention, money, bottom nav, account) — still has 11 legacy-token refs to sweep.
- Legacy: TripSummaryView, ExpenseViews, PeopleViews, TripPlacesView, TripPlanningView, AuthViews, TripForms, SharedViews primitives (WaniCard etc.), AllTripsSheet.
- Shared primitives to build/extend: Editorial card shell, section header, trip row, money row, attention row, empty-state card, confirmation component.

## Phases

### Phase 1 — Shared primitives (design-system layer)

Extend `SharedViews.swift`/`AppTheme.swift` so every page reuses one language:

- [ ] `WaniCard` (or new `CalmCard`) → Editorial card surface (`Editorial.card` light/dark, `Radius.large`, hairline `Editorial.border`).
- [ ] `SectionHeader` — small-caps/label-style header with optional action (used by attention/money/sections).
- [ ] `EditorialTripRow` — tappable trip row: emoji/cover thumb, name, date range, status badge, compact meta (decisions · money · travelers).
- [ ] `MoneyRow` — "You owe / Owed to you" drill-in row with terracotta/forest accents (extend dashboard's money rows for reuse).
- [ ] `EditorialEmptyState` — calm empty-state card (icon, title, subtitle, optional action).
- [ ] **Confirmation component** — replace scattered `.confirmationDialog`/`.alert` destructive flows with a shared `WaniConfirmationDialog` matching 004: title, safety copy ("removes X from trip for everyone in the shared cloud trip"), cancel-first, `.destructive` confirm. Keep every existing confirmation present.
- [ ] Sweep remaining `AppTheme.paper`/`primary`/`.regularMaterial` refs in TripDashboardView.

### Phase 2 — Current Trip / Trip Detail (TripSummaryView)

004 spec: focused version of the dashboard hero — emotional photo anchor, current-user next actions, compact section entry points, "Today at a glance".

- [ ] Hero: cover image + trip name/date (serif moment), status badge, sync state.
- [ ] "Today at a glance": compact user-specific summary (decisions due, balances, today's plan items) — reuse DashboardSummary logic where sensible.
- [ ] Trip sections as tappable editorial rows/cards: Places, Itinerary, People, Money — compact entry points (no duplicate page bodies).
- [ ] Invite/join affordances stay reachable (existing copy-invite behavior preserved).

### Phase 3 — Expenses / Balances (ExpenseViews)

004 spec: user-first money — "what do I owe or get back?" before group totals.

- [ ] User-first balance summary card at top (owed-to-you / you-owe), falling back honestly when account unmapped (existing dashboard money rules).
- [ ] Recent expenses as editorial rows (payer, amount, participants, status).
- [ ] Group totals secondary; drill-in rows preserved.
- [ ] Edit sheets (AddExpenseView/AddPaymentView in ExpenseViews/TripForms) adopt calm card/sheet language.

### Phase 4 — People / Participants (PeopleViews)

004 spec: collaborative + calm, not admin-heavy — profile cards, subtle roles, owner/guest labels.

- [ ] Organizer/Travelers grouping with participant cards (avatar initial, name, role/status badge).
- [ ] Guest display-name clarity ("account linking stays visible but not mandatory").
- [ ] Add/edit person sheets adopt calm language; destructive delete keeps confirmation.

### Phase 5 — Places (TripPlacesView)

004 spec: editorial cards for saved places — Shortlist grouping, "food / sights / maybe-laters".

- [ ] Group saved places by category as shortlist sections; editorial place cards.
- [ ] Edit/add place sheet calm; delete keeps confirmation.

### Phase 6 — Itinerary / Planning (TripPlanningView)

004 spec: calm timeline — daily plan groups + planning backlog.

- [ ] Timeline-like grouping by day (date headers, serif accents); planning backlog section for undated items.
- [ ] Item cards with done state; edit/add sheet calm; destructive keeps confirmation.

### Phase 7 — Create / Join / Invite (AuthViews, TripForms, NewTripView, JoinTripInviteView)

004 spec: profile-menu actions as fuller calm sheets/forms.

- [ ] NewTripView / JoinTripInviteView adopt calm card/sheet language (already sheet-hosted from dashboard).
- [ ] Create-trip form and join form match 004 copy/tones; validation unchanged.
- [ ] Auth screens (sign-in/mode picker) match the same warm tokens.

### Phase 8 — All Trips (AllTripsSheet)

004 spec: current/future/past scannable archive in the same card language.

- [ ] Current / Future / Past groupings with `EditorialTripRow`; past-trip archive/delete swipe keeps existing confirmation rules.

### Phase 9 — Verification & closeout

- [ ] Full simulator suite green (97+ tests), generic build green.
- [ ] `git diff --check`, secret scan.
- [ ] QA/release review (per skill) + security quick-pass (Phase 6 skill) if auth flows touched.
- [ ] Light/dark/auto visual review on simulator; log follow-ups to docs/todo-feedback.md.
- [ ] Commits per phase; push when each phase is verified.

## Non-goals (this pass)

- No new features (decisions/votes UI is future work; "Today at a glance" uses existing data only).
- No map integration for Places (004 mentions "enough map context" — future).
- No component framework explosion — build primitives as pages need them (per base direction §).

## Out of scope / tracked elsewhere

- Participant-claim/link UX (security WARN #2).
- kv_store_e2e444bd drop (awaiting confirmation).
- Privacy manifest Xcode wiring (pending in-flight M3 pbxproj commit).
