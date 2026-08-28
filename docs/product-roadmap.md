# Group Trip App Product Roadmap

## Roadmap Philosophy

Group Trip should grow from a clear, useful local demo into a collaborative trip hub for small and medium group trips.

The roadmap should follow progressive complexity:

- Start with the few flows that explain the product clearly.
- Make the app useful for a real 6-person international trip.
- Deepen features only when the real workflow needs them.
- Keep expenses, places, dates, planning, and collaboration connected through the trip context.

## Reference Scenario

The first serious product scenario is an international trip with around 6 people.

Assumptions:

- One organizer creates and manages the trip.
- Participants join through invite links.
- Some participants may use accounts; others may join as tracked guests.
- The group needs dates, places, basic plans, expenses, balances, and settlement.
- The product should be easy enough for close friends/family to use without developer explanation.

---

# Milestone 1: Local Demo

Status: Milestone 1 local demo is complete. Implementation/build/test finished through chunks 1–13, documentation was updated in chunk 14, and final integration review passed in chunk 15. The demo is accessed with `Continue with Test Data` and uses the working app name `Wani`.

## Goal

Create a local working demo that clearly communicates the product idea on one device.

This milestone is for showing the concept to friends/family and validating the direction. It does not need production collaboration, polished auth, invites, cloud collaboration, or final Supabase sharing.

Current sample trip: `Japan Spring 2027`, a six-person trip to Tokyo & Kyoto, Japan.

## Product Scope

### Trip Dashboard and Summary Hub

Implemented:

- Dashboard shows trip name, destination, trip dates, participant count, saved-place count, and total expenses.
- Trip summary shows trip dates, people/traveler count, and lightweight previews for planning, saved places, and expenses.
- Clear navigation from the dashboard/summary to each major area.

### People

Implemented:

- View participants.
- Add participant.
- Remove participant if safe.
- Use participants in expenses.

### Dates

Implemented:

- Show trip start date and end date.
- Creating a trip supports start/end dates.

Full trip detail editing is deferred.

### Places

Implemented:

- Add a place manually by name.
- Optional notes/category.
- View saved places for the trip.
- Delete a place for the current local session.

No deep Google Maps integration yet.

### Planning / Itinerary

Implemented:

- Basic list of planning items or itinerary items.
- Add/remove simple item.
- Toggle done state.
- Optional date support for newly added planning items.

No reminders or calendar sync yet.

### Expenses

Implemented:

- Add expense.
- Select payer.
- Select participants included in the expense.
- Add direct payment.
- Show balances.
- Show settlement suggestions.
- Keep existing expense math tested.

### Demo Data

Implemented:

- A realistic 6-person international trip sample: `Japan Spring 2027`.
- Several places.
- Several planning items.
- Several expenses and payments.
- A local-demo smoke-test checklist.

## Acceptance Criteria

- A friend/family member can understand the app concept in under a few minutes.
- The app feels like a trip hub, not just an expense calculator.
- The main screens work on one device.
- Expense calculations remain correct.
- The app builds successfully. Chunk 13 generic iOS build succeeded.
- iPhone 17 simulator expense calculator tests succeeded in Chunk 13.

## Non-Goals

- Production auth.
- Production invite links.
- Full Supabase sync.
- Cloud collaboration for Milestone 1 verification.
- Full trip detail editing.
- Durable persistence of local demo edits across app restart.
- Google Calendar integration.
- Google Maps SDK integration.
- Push notifications.
- Android.
- Polished App Store-level UI.

---

# Milestone 2: Collaborative MVP / TestFlight

## Goal

Create a confident TestFlight version that close friends/family can install and use on their own phones for a real or realistic trip.

The app can still be imperfect, but it should not be fragile, confusing, or embarrassing to send to people.

## Product Scope

### Accounts and Trip Ownership

Must support:

- Account-backed trip creator/organizer.
- Organizer can create a trip.
- Organizer can manage core trip details.
- Organizer can invite participants.

Preferred auth:

- Low-friction sign-in such as email magic link and/or Sign in with Apple.

### Invite-Based Collaboration

Must support:

- Invite link or invite code for a trip.
- Participant can join with minimal friction.
- Guest collaborator can join without traditional signup if technically feasible.
- Guest collaborator has display name plus internal unique ID.
- Guest activity can be attributed inside the trip.

### Supabase Persistence

Must support:

- Shared trip data persists in Supabase/cloud storage.
- Basic row-level security or equivalent access control.
- No service-role keys in the client.
- Safe enough permission model for invited collaborators.

### Shared Trip Data

Must support cloud-backed versions of:

- Trip details.
- Participants/members.
- Dates.
- Places.
- Basic planning/itinerary items.
- Expenses.
- Direct payments.
- Balance/settlement calculations.

### Reliability

Must support:

- No crashes in main flows.
- No known data-loss bugs in core trip/expense flows.
- Reasonable loading/error states.
- Build succeeds with documented command.
- Expense math is covered by unit tests.

## Acceptance Criteria

- Organizer can create a trip and invite at least one participant.
- Invited participant can access the trip from another device/account/session.
- Participant can contribute to at least one meaningful collaborative action, such as adding an expense or place.
- Trip data remains visible after app restart.
- Expense balances/settlements remain correct after synced changes.
- The UI is understandable without developer explanation.

## Non-Goals

- Full granular permissions.
- Realtime conflict resolution beyond basic safe behavior.
- Rich offline support.
- Google Maps deep integration.
- Google Calendar sync.
- Notifications/reminders.
- Payments processing.
- Android.

---

# Milestone 3: Design Implementation

Status: Complete — Calm Editorial app-wide rollout shipped 2026-08-20 (phases 1–8 + closeout; build green, 97/97 tests). Remaining design follow-ups tracked in docs/todo-feedback.md.

## Goal

Implement the selected Calm Editorial / Calm User Dashboard direction deeply enough that Wanderaid feels like one coherent app rather than a collaborative MVP with a redesigned home screen.

This milestone is not only visual polish. It should translate the chosen design language into real navigation, account/menu behavior, light/dark appearance behavior, user-level dashboard summaries, and the first reusable UI patterns that future screens can share.

## Product Scope

### Dashboard and App Shell

- Implement the selected Calm User Dashboard home screen.
- Keep the dashboard user-centered instead of trip-specific.
- Surface all-trip `Needs your attention` and user-specific `Your money` summaries.
- Keep trip lists behind bottom navigation / All Trips rather than duplicating them on the home page.
- Use a top header/profile menu that matches the design direction.

### Appearance and Design System

- Support first-class light and dark modes with a manual Auto / Light / Dark toggle.
- Use semantic color tokens instead of separate duplicated light/dark views.
- Establish calm editorial cards, section headers, hero treatment, account/menu surfaces, and confirmation styling patterns where they repeat naturally.
- Avoid a premature large component framework; extract reusable pieces only when repetition is real.

### Account and Header Experience

- Move create/join/account actions into the top-right profile menu.
- Route logout through Account rather than exposing direct sign-out in the dropdown.
- Keep destructive/session-ending actions confirmed.
- Stage or wire account profile/security settings according to backend readiness.

### App-Wide Extension

- Begin carrying the same visual language into current trip, all trips, expenses, people, places, planning, create/join/invite, and confirmation surfaces.
- Prioritize consistency and information hierarchy over decorative redesign.

## Acceptance Criteria

- The selected light/dark dashboard mockups are represented by one SwiftUI implementation using semantic colors.
- Dashboard money is account-aware and never substitutes total trip spend for personal balances.
- The header/profile/account menu matches the new design semantics.
- The app has a coherent visual direction across the main shell and the highest-traffic dashboard/account paths.
- Remaining per-feature redesign work is explicitly tracked for the next milestone rather than mixed into this one.

---

# Milestone 4: Feature Usability Upgrade

## Goal

Bring each core feature beyond its current bare-minimum implementation so the app feels usable for real planning, not just technically complete.

Milestone 2 proved the collaborative data model works. Milestone 3 establishes the design direction. Milestone 4 should make the individual feature areas feel understandable, forgiving, and useful enough for close friends/family to use without explanation.

## Product Scope

### Cross-Feature Usability

- Improve onboarding copy, empty states, loading states, and error states.
- Make create/join/invite flows easier to understand.
- Make trip setup clearer and less form-like.
- Replace confusing or cramped native confirmations where a Wanderaid-specific component would improve clarity.
- Keep all destructive/removal/access-ending flows confirmed.

### People / Participants / Account Identity

- Clarify the distinction between app collaborators/members and expense participants.
- Improve guest identity continuity.
- Add account upgrade/link flow for guests if needed.
- Make participant/account linking explicit enough that user-specific dashboard money remains reliable.

### Places

- Add richer place notes where useful.
- Add common category/tag chips with custom options if useful.
- Add map links or open-in-Google-Maps support before full SDK integration.
- Make saved-place edit affordances consistent and discoverable.

### Planning / Itinerary

- Add day grouping for itinerary/planning items.
- Add optional time fields.
- Add date ranges for stays or multi-day activities.
- Add simple checklist-style planning items if camping/trip preparation starts to matter.

### Expenses / Balances / Settlements

- Improve settlement explanation.
- Move payment recording closer to suggested settlements if that proves clearer.
- Handle edge cases around removed participants, deleted expenses, partial participation, and account-linked participants.
- Keep expense math and cloud-edit behavior test-backed.

### Trip Management

- Add or refine safe leave/archive/delete behavior for current, future, and past trips.
- Make owner/last-owner behavior explicit before allowing access-removing actions.
- Improve trip detail editing and setup flows where they are still too bare.

### Room Foundations and Quick Wins (added 2026-08-20, from the basecamp room specs)

- Home: live ticking countdown to the next trip (days/hours/min/sec) + quick access to the next/current trip.
- Welcome Desk: reframe the trip landing as the trip lobby — per-trip countdown, who's going, group chat entry, trip activity feed, invite.
- Cross-cutting foundation: one tag vocabulary (food/hotel/flight/show/museum/custom) + participant sets on every item type.
- Crew: person rooms (aggregated footprint — places, expenses, bookings, votes, role, money status) + message handoff (contact sheet / WhatsApp / Discord).
- Kitty: quick-add expense (3 taps), user-first "what I owe" framing, repayment guidance view.
- Map Wall: tap-through to Google Maps (map links).

## Acceptance Criteria

- Each core feature area has clear empty/loading/error states.
- Users can understand how to join, contribute, edit, settle, and leave without developer explanation.
- The creator can use Wanderaid without falling back to a spreadsheet for basic expense settlement.
- Close friends/family feedback identifies polish issues more than fundamental confusion.
- The room map from the basecamp frame is visible in navigation (Home, Welcome Desk, Map Wall, Schedule Board, Crew, Kitty).

---

# Milestone 5: The Basecamp Comes Alive (added 2026-08-20)

## Goal

Build the differentiated core from the basecamp room specs (docs/design-thoughts.md, docs/plans/rooms-to-milestones.md) — the features that make Wanderaid feel like a living shared basecamp rather than a set of usable features. Completes the first-release feature set.

## Product Scope

### Chat (first-release commitment)

- One common chat per trip (trip channel) + direct chats between users that span across trips.
- Text-only realtime MVP on Supabase Realtime (messages + conversations tables, RLS).
- Minimal unread indicators.
- Deferred: push notifications, typing indicators, read receipts, media.

### Map Wall

- POI voting with weights: yes +1 / weak-yes +0.5 / no −1; abstain = null (not counted).
- Pinning — anyone can pin; pinned means "on everyone's radar."
- Locked-in markers linking to Schedule Board bookings (committed tier).
- MapKit in-room map view (tap-through to Google Maps already in M4).

### Schedule Board

- Bookings as first-class items: flights, hotel stays, prebooked activities, each with participant sets.
- Coordination overlay: everyone's commitments on one day-grouped timeline (arrival windows, who's on which flight).

### Feeds and Action-Needed

- Activity log (trip_activity data layer) + grouped feed events (one line per actor + action).
- Call-for-vote / call-for-input on items; unanswered calls surface in Home's action-needed area.

### Crew

- Arrival/departure windows derived from bookings.

## Acceptance Criteria

- Two people can coordinate around each other's flights/stays without leaving the app.
- A group can build a prioritized place list via votes and settle a hotel-room question via call-for-input.
- Basic chat works in-app for a trip channel and DMs.

---

# Milestone 6: Real Trip Readiness / TestFlight

## Goal

Make the app useful enough for the creator's actual friend/family group to try on a real trip or real planning cycle.

This milestone is the close-friends dogfood/TestFlight readiness gate after the design system, feature usability pass, and the basecamp core features (M4 + M5).

## Product Scope

### Usability Improvements

- Validate onboarding, empty states, error states, invite/join, and trip setup with real testers.
- Resolve the highest-friction issues found during feature-usability testing.
- Polish the dashboard and main trip flows based on actual use rather than speculative depth.

### Places Improvements

- Confirm manual place entry, notes/categories, and map handoff are enough for real trip planning.
- Defer deep Google Places SDK work unless real testers need it.

### Planning Improvements

- Confirm day/date/time planning surfaces are useful enough for the reference trip scenario.
- Add only the planning depth needed for a realistic 6-person trip.

### Expense Improvements

- Confirm settlements can replace the spreadsheet for the reference trip scenario.
- Address high-impact money-flow confusion found during dogfooding.

### Collaboration Improvements

- Validate guest/account identity, attribution, refresh behavior, and invite flows with real participants.
- Add basic activity attribution only where it helps explain shared changes.

### Journal (guest book)

- Guest book MVP: one-liners to short paragraphs from each person; no ratings (friends, not reviews).
- External album links (Google Photos etc.); chat tie-in for after-trip conversations.
- Photo hosting decision deferred to M7.

## Acceptance Criteria

- The app is useful for planning a realistic 6-person international trip.
- The creator can use it without needing to fall back to the spreadsheet for basic expense settlement.
- Participants can understand how to join and contribute.
- Feedback from close friends/family identifies polish issues more than fundamental confusion.

---

# Milestone 7: v1 Candidate

## Goal

Prepare the app for a broader public or semi-public release after the close-friends TestFlight proves the workflow.

## Product Scope

- Stronger onboarding.
- Better account recovery/sign-in flows.
- Better privacy/security review.
- More polished visual design.
- Better settings and trip management.
- More robust permissions.
- Better analytics/feedback loop if desired.
- App Store metadata, screenshots, and privacy labels.
- Push notifications (APNs + relay edge function — deferred workstream from chat).
- Journal photo-hosting decision (in-app hosting vs albums-only).

## Possible Feature Additions

Only add these if they clearly support real usage:

- Google Maps integration.
- Google Calendar export/sync.
- Notifications/reminders.
- Shared bring-list coordination for trips, staycations, parties, camping, or any group event where people need to coordinate who is responsible for bringing what.
- Currency conversion.
- Receipt scanning.

---

# Later / Future Ideas

## Integrations

- Google Maps places search/saved locations.
- Google Calendar sync/export.
- Discord bridge or share links into Discord.
- Apple Calendar support.

## Trip Planning

- Rich itinerary builder.
- Day-by-day schedule.
- RSVP/availability.
- Polls/voting for places or activities.
- Packing lists.
- Shared bring/responsibility lists: who brings food, drinks, gear, supplies, shared equipment, decorations, party items, or other group-needed items.

## Money

- Multi-currency support.
- Receipt scanning.
- Payment app handoff links.
- Export settlement summary.

## Platforms

- Android app.
- Web app or lightweight web viewer.

---

# Recommended Build Order

Milestone 1 local demo and Milestone 2 collaborative MVP are complete. The next implementation focus should be Milestone 3 design implementation, followed by a dedicated usability upgrade before treating the app as real-trip ready.

1. Finish Milestone 3 dashboard/design implementation: selected Calm Editorial dashboard, semantic light/dark tokens, Auto/Light/Dark setting, account-aware dashboard summaries, top header/profile menu, and account entry point.
2. Extend the Calm Editorial language to the highest-traffic app surfaces without overbuilding a component framework.
3. Define Milestone 4 feature-usability plans by feature area: people/account identity, places, planning, expenses/settlements, trip management, create/join/invite, and confirmations.
4. Bring each feature area beyond bare-minimum usability with TDD for behavior/data changes and QA review for non-trivial UI/navigation changes.
5. Run a close-friends / TestFlight smoke pass for Milestone 5 Real Trip Readiness.
6. Prepare Milestone 6 v1 Candidate work only after real-trip/TestFlight feedback confirms the core workflow.

# Agent Ownership

## Product/UX Agent

Owns roadmap, milestone definitions, acceptance criteria, and feature briefs.

## Design/Figma Agent

Owns visual direction, Figma alignment, reusable components, and accessibility.

## iOS Platform Agent

Owns SwiftUI architecture, navigation, app lifecycle, dependency injection, and build health.

## Supabase Data/Sync Agent

Owns schema, RLS/access control, persistence, invite model, and sync behavior.

## Trips Agent

Owns trip dashboard, trip metadata, dates, places, and planning surfaces.

## Expenses Agent

Owns participants, expenses, payments, balances, settlement logic, and tests.

## QA/Release Agent

Owns build verification, unit/regression tests, smoke plans, and TestFlight readiness.
