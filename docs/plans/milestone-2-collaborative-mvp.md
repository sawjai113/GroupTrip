# Milestone 2 Collaborative MVP / TestFlight Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task. Use test-driven-development skill for every behavior/data/auth change.

**Goal:** Build a confident TestFlight-ready collaborative MVP where a trip organizer can create a cloud-backed trip, invite at least one participant, and shared trip data persists across devices/sessions.

**Architecture:** Extend the existing SwiftUI app and Supabase groundwork into a clearly separated Demo Mode and Signed-in Mode. Model collaboration around trips, members, expense participants, invites, and synced feature tables. Start with persistence plus refresh rather than realtime; add realtime only after the core data model and RLS behavior are stable.

**Tech Stack:** SwiftUI, Supabase Swift, Supabase Postgres/RLS, XCTest, existing Wani design tokens/components, existing `TripStore`, `TripPlan`, `TripCalculatorViewModel`, and `SupabaseTripService`.

---

## Starting Checkpoint

Milestone 1 is complete and manually smoke-tested by the user as good enough to move forward.

Recent prep work already completed:

- UI/design flexibility prep.
- TDD practice documented in `docs/development/tdd-practice.md`.
- Existing Supabase files:
  - `supabase/schema.sql`
  - `GroupTripApp/SupabaseConfig.swift`
  - `GroupTripApp/SupabaseTripService.swift`

Current Supabase groundwork includes:

- `trips` table.
- `trip_members` table.
- basic RLS policies.
- basic trip load/create service.

This milestone should evolve that groundwork rather than duplicate it.

## Product Scope

### Must Have

- Organizer can sign in.
- Organizer can create a cloud-backed trip.
- Organizer can see their cloud trips after app restart.
- Organizer can invite at least one collaborator through an invite code/link flow.
- Invited collaborator can join with low friction.
- Guest collaborator has a display name and stable internal ID.
- Shared trip data persists in Supabase.
- At least one meaningful collaborative action works from another session/device:
  - recommended first: add place or planning item
  - later in milestone: add expense/payment
- Expense balances/settlements remain correct after synced data loads.
- Demo Mode remains available for quick local exploration.

### Should Have

- Clear loading and error states.
- Basic refresh behavior after foreground/app relaunch.
- Simple role labels: owner/member/guest.
- Basic no-data states for cloud trips.
- Manual smoke-test checklist for two sessions/devices.

### Non-Goals

- Full realtime collaboration.
- Rich offline mode and conflict resolution.
- Granular permissions.
- Google Maps integration.
- Google Calendar integration.
- Chat implementation.
- Push notifications.
- Payment processing.
- Android.

## Key Product/Data Decisions to Confirm

These are the remaining decisions before implementation should start.

### Decision 1: Members vs Participants

**Recommended default:** Keep them separate.

- `trip_members`: people who can access/collaborate on the trip.
- `trip_participants`: people represented in the trip and expense calculations.

Why:

- Someone can be part of expenses but not use the app.
- Someone can collaborate in the app but not be part of every expense.
- Historical expenses should keep attribution even if access changes later.

### Decision 2: First Auth Method

**Selected direction:** Start with Supabase email magic link / OTP, using the user's Gmail account as a temporary SMTP sender if Supabase's built-in email limits are not enough.

Why:

- Lower setup complexity than Sign in with Apple.
- Good enough for close friends/family TestFlight.
- Works naturally with Supabase.
- Gmail SMTP can be replaced later with a production sender such as Resend, Postmark, SendGrid, AWS SES, or a custom domain email provider.

Important constraints:

- Gmail SMTP credentials must be configured in the Supabase dashboard or another secure secrets store, never committed to the iOS app or repository.
- Use a Gmail app password if required; never paste the password into source code or chat logs.
- Gmail sending limits and deliverability are acceptable for small private testing but not a production launch.
- Replace Gmail SMTP before broader external release.

Sign in with Apple can be added later when the collaboration model is proven.

### Decision 3: Guest Invite Model

**Recommended default:** Google Docs-style lightweight guest flow.

- Organizer creates a trip.
- Organizer creates/shares invite code or link.
- Guest enters display name.
- App creates a stable guest identity for that trip.
- Guest can later connect/upgrade to an account.
- Duplicate display names are allowed; internal IDs remain unique.

### Decision 4: Realtime vs Refresh

**Recommended default:** Start with persistence + refresh, not realtime.

- Load cloud trips on sign-in/app launch.
- Save mutations to Supabase.
- Refresh on foreground/manual trigger.

Realtime can be added after the table model and RLS policies are stable.

### Decision 5: Demo Mode

**Recommended default:** Keep Demo Mode separate from Signed-in Mode.

- Demo Mode: local sample trips, resets to baseline.
- Signed-in Mode: Supabase-backed real trips.

## Proposed Supabase Model

Milestone 2 likely needs these tables or equivalents:

- `profiles`
  - user profile for account-backed users
- `trips`
  - existing table; may need updated fields
- `trip_members`
  - access/collaboration records
- `trip_participants`
  - people represented in trip planning and expense calculations
- `trip_invites`
  - invite code/link records
- `trip_places`
  - saved places
- `trip_planning_items`
  - itinerary/planning list items
- `trip_expenses`
  - expense headers
- `trip_expense_splits`
  - participants included in each expense
- `trip_direct_payments`
  - person-to-person payments outside app

Security requirements:

- RLS enabled for all shared-trip tables.
- Client uses only safe public/publishable/anon Supabase key.
- No service-role key in iOS app.
- Access to trip data is based on trip membership/invite rules.

## Testing Strategy

Use strict TDD for behavior/data/auth changes.

First tests should cover:

- trip member and expense participant are separate concepts
- organizer is represented as both owner member and participant when creating a trip
- duplicate guest display names remain distinct through internal IDs
- local model to Supabase DTO mapping round-trips dates and identifiers safely
- loading synced participants preserves expense-calculation behavior
- expense balances remain correct after persistence-shaped data reconstruction

Prefer testing below the SwiftUI view layer first:

- DTO mapping
- stores
- services with injectable clients/protocols
- validators
- membership/invite rules
- expense reconstruction logic

## Proposed Implementation Chunks

### Chunk 1: Finalize Milestone 2 decisions and update plan

**Objective:** Confirm the five key decisions above and patch this plan before coding.

**Files:**

- Modify: `docs/plans/milestone-2-collaborative-mvp.md`
- Possibly modify: `docs/project-definition.md`
- Possibly modify: `docs/product-roadmap.md`

**Verification:** Plan reflects user decisions and has no unresolved blockers for Chunk 2.

### Chunk 2: Add membership/participant domain tests

**Objective:** Introduce tests for the core collaboration model before database/code changes.

**Files:**

- Create/modify tests under `GroupTripAppTests/`
- Likely create small domain helpers/models in `GroupTripApp/` as needed after RED.

**TDD:** Required.

### Chunk 3: Expand Supabase schema draft

**Objective:** Extend `supabase/schema.sql` for participants, invites, places, planning, expenses, splits, and payments.

**Files:**

- Modify: `supabase/schema.sql`
- Add docs comments or migration notes if needed.

**TDD:** Schema itself may not be unit-tested, but model/DTO mapping must be.

### Chunk 4: Add DTO mapping tests and minimal DTOs

**Objective:** Add test-first local/remote mapping for trips, participants, places, planning items, expenses, splits, and payments.

**Files:**

- Modify/create: `GroupTripApp/SupabaseTripService.swift`
- Possibly create: `GroupTripApp/SupabaseTripDTOs.swift`
- Tests: `GroupTripAppTests/*`

**TDD:** Required.

### Chunk 5: Separate Demo Mode and Signed-in Mode entry paths

**Objective:** Keep local demo behavior while making cloud-backed mode explicit.

**Files:**

- Likely modify app launch/root views and `TripStore`.

**TDD:** Required for state/routing logic where practical; visual verification also required.

### Chunk 6: Implement account sign-in baseline

**Objective:** Support organizer sign-in using the confirmed first auth method.

**Files:**

- Existing auth-related views/view model should be inspected before implementation.

**TDD:** Required for validation/state behavior; manual simulator verification required for actual Supabase auth flow.

### Chunk 7: Cloud trip create/load flow

**Objective:** Organizer can create a cloud trip and see it after app restart.

**Files:**

- `TripStore`
- `SupabaseTripService`
- trip creation/root views

**TDD:** Required for service/store behavior with injectable test doubles.

### Chunk 8: Invite and guest/member join flow

**Objective:** Organizer can share an invite code/link and a collaborator can join with low friction.

**TDD:** Required for invite validation and membership creation rules.

### Chunk 9: Cloud places and planning items

**Objective:** First meaningful collaborative actions: add/view places and planning items from cloud-backed trip data.

**TDD:** Required for service/store mapping and mutation behavior.

### Chunk 10: Cloud expenses/payments and synced balances

**Objective:** Persist expenses, splits, direct payments, and reconstruct calculator state from cloud-backed rows.

**TDD:** Required and high priority.

### Chunk 11: Reliability and UX states

**Objective:** Add loading/error/empty states and safe retry/refresh behavior.

**TDD:** Required for state transitions where practical; visual review required.

### Chunk 12: TestFlight readiness review

**Objective:** Confirm close friends/family can use core flows without developer explanation.

**Verification:**

- full build
- full tests
- manual two-session smoke test
- Product/UX review
- Code Quality review
- QA/Release review

## Smoke-Test Checklist Draft

- Launch app.
- Confirm Demo Mode still works.
- Sign in as organizer.
- Create cloud trip.
- Quit/relaunch; confirm cloud trip remains.
- Create invite.
- Join from another session/device as guest or second account.
- Confirm joined trip is visible.
- Add a place from one session; refresh and confirm visible from the other.
- Add a planning item from one session; refresh and confirm visible from the other.
- Add expense with selected participants.
- Add direct payment.
- Confirm balances/settlements match expected values.
- Confirm no service-role credentials or secrets are present in client code.

## Open Questions for User

1. Confirm members and participants should be separate concepts?
2. Confirm first auth method should be Supabase email magic link / OTP?
3. Confirm guest invite should allow display-name-only guests at first?
4. Confirm realtime can wait until after persistence is stable?
5. Confirm Demo Mode should remain separate from Signed-in Mode?

Once these are confirmed, implementation can start with Chunk 2 using TDD.
