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

## Goal

Create a local working demo that clearly communicates the product idea on one device.

This milestone is for showing the concept to friends/family and validating the direction. It does not need production collaboration, polished auth, or final Supabase sharing.

## Product Scope

### Trip Dashboard

Must show:

- Trip name.
- Trip dates.
- Participant count/list preview.
- Places preview.
- Planning/itinerary preview.
- Expense/balance summary.
- Clear navigation to each major area.

### People

Must support:

- View participants.
- Add participant.
- Remove participant if safe.
- Use participants in expenses.

### Dates

Must support:

- Show trip start date and end date.
- Edit dates locally or through simple form.

### Places

Must support:

- Add a place manually by name.
- Optional notes/category if simple.
- View saved places for the trip.

No deep Google Maps integration yet.

### Planning / Itinerary

Must support:

- Basic list of planning items or itinerary items.
- Add/edit/remove simple item.
- Optional date/time field if easy.

No reminders or calendar sync yet.

### Expenses

Must support:

- Add expense.
- Select payer.
- Select participants included in the expense.
- Add direct payment.
- Show balances.
- Show settlement suggestions.
- Keep existing expense math tested.

### Demo Data

Should include:

- A realistic 6-person international trip sample.
- Several places.
- Several planning items.
- Several expenses and payments.

## Acceptance Criteria

- A friend/family member can understand the app concept in under a few minutes.
- The app feels like a trip hub, not just an expense calculator.
- The main screens work on one device.
- Expense calculations remain correct.
- The app builds successfully.

## Non-Goals

- Production auth.
- Production invite links.
- Full Supabase sync.
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

# Milestone 3: Real Trip Readiness

## Goal

Make the app useful enough for the creator's actual friend/family group to try on a real trip or real planning cycle.

## Product Scope

### Usability Improvements

- Improve onboarding copy.
- Improve empty states.
- Improve error states.
- Make invite/join flow easier.
- Add clearer trip setup flow.
- Polish the dashboard.

### Places Improvements

- Add richer place notes.
- Add categories or tags, if useful.
- Add map links or open-in-Google-Maps support before full SDK integration.

### Planning Improvements

- Add day grouping for itinerary/planning items.
- Add optional time fields.
- Add simple checklist-style planning item if camping/trip preparation starts to matter.

### Expense Improvements

- Improve edit/delete flows.
- Add clearer settlement explanation.
- Add edge-case handling around removed participants, deleted expenses, and partial participation.

### Collaboration Improvements

- Improve guest identity continuity.
- Add account upgrade/link flow for guests if needed.
- Add basic activity attribution in the UI where useful.

## Acceptance Criteria

- The app is useful for planning a realistic 6-person international trip.
- The creator can use it without needing to fall back to the spreadsheet for basic expense settlement.
- Participants can understand how to join and contribute.
- Feedback from close friends/family identifies polish issues more than fundamental confusion.

---

# Milestone 4: v1 Candidate

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

## Possible Feature Additions

Only add these if they clearly support real usage:

- Google Maps integration.
- Google Calendar export/sync.
- Notifications/reminders.
- Shared bring-list coordination for trips, staycations, parties, camping, or any group event where people need to coordinate who is responsible for bringing what.
- Currency conversion.
- Receipt scanning.
- Comments/activity feed.

---

# Later / Future Ideas

## Integrations

- Google Maps places search/saved locations.
- Google Calendar sync/export.
- Discord bridge or share links into Discord.
- Apple Calendar support.
- Push notifications.

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

1. Update data models for hybrid trip hub: dates, places, planning items.
2. Build local demo dashboard around sample 6-person international trip.
3. Add local CRUD for places and planning items.
4. Tighten people/expense flows and tests.
5. Validate local demo with friend/family feedback.
6. Design Supabase schema for collaborative trip hub.
7. Implement account-backed trip creation.
8. Implement invite/guest collaborator model.
9. Move shared trip data to Supabase.
10. Prepare confident TestFlight build.

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
