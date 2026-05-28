# Group Trip App Project Definition

## Working Summary

Group Trip is a mobile app for planning and managing shared trips with friends, family, or groups. The first practical product slice focuses on group expense tracking: add people, track shared expenses and direct payments, calculate balances, and suggest settlement payments.

Longer term, the app can become a shared trip hub: itinerary, maps, calendar events, collaboration, invitations, packing/travel details, and cross-platform access.

## Current Product Stage

Stage: early MVP / product definition.

The codebase already contains a SwiftUI iOS app with:

- Trip dashboard and summary surfaces.
- Trip models and local store structure.
- Expense, participant, payment, balance, and settlement logic.
- Supabase client/config/service files.
- Auth-related views/view model.
- Figma exports/design material.
- Unit tests for expense calculation.

The product is not yet fully defined enough to scale features safely, so the next step is to clarify the user, MVP, core flows, non-goals, and release criteria.

## Target User

Primary user:

The first target audience is the creator of the app and their close friends and family. This is intentionally a personal, real-world product first rather than a generic App Store audience. The project is also a learning vehicle for going from idea to released app using AI-assisted development.

The initial user group currently coordinates trips with several separate tools:

- Discord for group chat and coordination.
- Google Calendar for tracking dates individually.
- Google Maps for saving places to visit.
- A custom expense spreadsheet for tracking costs and calculating who owes whom.

The app should eventually consolidate those workflows into one shared trip hub.

Possible early groups:

- Close friend trips.
- Family trips.
- Weekend getaways.
- International trips where multiple people pay for shared costs.
- Any recurring travel group that already coordinates through chat, calendar, maps, and spreadsheets.

## Core Problem

Group trips create scattered coordination problems:

- Expenses are paid by different people at different times.
- Not every expense applies to every participant.
- Direct payments happen outside the app.
- People forget who owes what.
- Planning info lives across texts, calendars, maps, notes, and spreadsheets.

The first problem to solve is expense clarity: everyone should know what was spent, who participated, who paid, and what settlement payments are needed.

## Differentiation

The app is not trying to beat Splitwise, Tricount, Google Calendar, Google Maps, Discord, or spreadsheets at each of their individual specialties on day one.

The initial differentiation is consolidation for a specific use case: small and medium-sized group trips.

Current belief:

- A standalone expense calculator may be hard to justify because Splitwise and similar tools already exist.
- The app becomes more compelling when expenses are one part of a broader trip hub.
- The value is having trip-specific coordination in one place: people, dates, places, itinerary/planning, expenses, balances, settlement, and eventually collaboration.
- The first audience is not comparing feature checklists against every existing app; they are people already juggling Discord, Google Calendar, Google Maps, and a spreadsheet for the same trip.

Potential advantage:

- Easier for a small/medium group trip than maintaining several separate tools.
- More focused than a generic chat, map, calendar, or finance app.
- More personal and trip-context-aware than a generic expense splitter.
- Built around the creator's real workflow and friend/family use cases first.

## Product Promise

Draft:

Group Trip helps travel groups coordinate shared trip costs and, later, trip plans in one simple collaborative app.

Shorter version:

A shared trip hub for expenses, plans, and coordination.

## Product Complexity Strategy

Decision:

Use progressive complexity.

The app should start simple with the core trip hub features already identified, then add richer planning features only when they clearly help the real workflow.

Principles:

- Small trips should feel lightweight and easy.
- Medium trips should have room to use more structure without forcing that structure on everyone.
- Do not add features just because travel apps often have them.
- Avoid overwhelming users with planning tools before the core flows are useful.
- Add capabilities like reminders, notifications, richer itinerary tools, or advanced integrations only after the basic product proves where they are needed.

Practical implication:

The MVP should expose a small number of obvious surfaces: trip dashboard, people, dates, places, itinerary/list, and expenses. Later versions can deepen each surface based on actual usage.

## MVP Scope

The first MVP should be a hybrid trip hub. It should include working versions of the main trip workflows, even if several of them are intentionally basic and missing polish. The goal is to make the app feel like the beginning of the full product rather than only an isolated expense calculator.

### Must Have

- Create or open a trip.
- Add/edit/remove trip participants.
- Add/edit/remove expenses.
- Select who participated in each expense.
- Track direct payments between people.
- Show each person's balance.
- Suggest settlement payments.
- Add or view core trip dates.
- Add or view places the group wants to check out.
- Show a simple trip dashboard that connects people, dates, places, and expenses.
- Support collaboration without making traditional account creation the first mandatory step.
- Persist trip data through Supabase/cloud storage for shared trips.
- Support account creation for users who want persistent identity, ownership, cross-device access, and recovery.

### Should Have

- Basic itinerary/planning surface, even if it is only a simple list at first.
- Clear empty states.
- Basic trip dashboard.
- Basic trip summary screen.
- Loading/error states for Supabase operations.
- Simple invite/share concept, even if manual at first.
- Design consistency with Figma direction.

### Later

- Deep Google Maps integration.
- Google Calendar export/sync.
- Rich itinerary planning.
- Realtime collaboration.
- Offline conflict handling.
- Receipt scanning.
- Currency conversion.
- Push notifications.
- Android app.
- Web app/admin surface.

## Non-Goals for First MVP

- Full travel planning platform.
- Complex realtime multi-device collaboration unless basic persistence is stable.
- Payments processing.
- Booking flights/hotels.
- Complex social network features.
- Android implementation before iOS and backend contracts stabilize.
- Supporting every possible split rule on day one.

## Collaboration Requirement

Decision:

Development can start with single-device/local flows where useful, but the product MVP requires collaboration.

This means:

- It is acceptable to build and test early feature slices locally while the UI, data model, and expense logic are still evolving.
- The first real MVP should not be considered complete unless multiple people can access or collaborate on the same trip through invite-based sharing.
- Supabase/cloud persistence is part of the product path, not just a later optional enhancement.
- The app can have development/demo data or temporary local behavior, but that should not define the product architecture.

Practical rule:

Build pragmatically, but design for shared trips from the start.

## First Design Scenario

Decision:

Design the first serious product scenario around an international trip with around 6 people.

Why this scenario:

- It represents a realistic small-to-medium group trip for the initial audience.
- It is complex enough to need coordination across people, dates, places, itinerary, and expenses.
- It avoids designing only for a trivial weekend trip while still staying smaller than a large group tour.

Scenario assumptions:

- Around 6 participants.
- One trip creator/organizer with an account.
- Other participants can join through invite links as guests or account-backed users.
- The group needs shared dates, places to visit, basic itinerary planning, and expense tracking.
- Several people may pay for shared costs during the trip.
- Some participants may not use the app heavily but still need to be represented in expenses.

Important later scenario:

Camping trips are another recurring real use case, but the underlying feature should be broader than camping. A future feature area should support shared bring/responsibility lists for any group event or trip where people need to coordinate who is responsible for bringing what, such as food, drinks, gear, supplies, shared equipment, decorations, or party items. This could apply to camping trips, staycations, parties, and other group plans. It should be kept out of the first MVP unless it naturally fits into a simple checklist/planning surface.

## Auth and Collaboration Strategy

Decision direction:

The app should support collaboration, so shared trips should live in Supabase/cloud storage rather than being purely local-only. However, traditional account creation should not be the first mandatory step if it can be avoided, because signup friction is a major adoption hurdle.

Preferred model:

- Use a Google Docs-style collaboration model.
- A trip creator needs an account to create, own, and manage a trip.
- Invited participants can join and collaborate through an invite link without creating an account or logging in first.
- Non-account participants still need a lightweight trip identity: a display name plus an internal unique ID that is not necessarily visible to users.
- Track non-account participant activity within the trip, such as adding expenses, editing places, or making comments/updates, using that internal ID.
- Support account creation later, but reserve it for moments where it clearly provides value: creating/owning a trip, recovering access, syncing across devices, managing identity, or protecting edit permissions.
- Avoid designing the MVP around fully anonymous local-only trips, because collaboration is central to the product.

Open implementation question:

The exact auth model still needs technical validation against Supabase options. Possible approaches include invite tokens, guest collaborators, anonymous/temporary Supabase users upgraded later, magic-link auth, Sign in with Apple, or a mix. The important product requirement is that invited collaborators should not hit a traditional signup wall before they can contribute.

## Collaboration and Member Identity

Decision:

A trip can include both account-backed users and guest collaborators.

- Trip creator: must have an account. This person owns/manages the trip, invite settings, and recovery path.
- Account-backed participant: optional. A participant can create/sign into an account if they want stable identity, cross-device access, notifications, or to create their own trips.
- Guest collaborator: can join from an invite link without traditional signup/login. They provide or receive a display name and get an internal unique ID for that trip/session.
- Non-collaborating participant: a person represented in expenses who may not use the app directly, similar to a row in the current spreadsheet.

Guest collaborators should not be treated as fully anonymous. Even without an account, their actions should be attributable inside the trip through an internal collaborator/member ID.

Important product behavior:

- The UI can show human-readable names like “Sawjai”, “Alex”, or “Guest: Alex”.
- The system should store stable internal IDs so edits, expenses, and activity can be tracked reliably.
- A guest should be able to upgrade/link to a real account later if they want to keep access.
- The MVP should avoid overcomplicating permissions, but it should not paint the data model into a corner.

## Core User Journey: Expense MVP

1. User opens the app from the home screen or a trip invite link.
2. User can preview/join with minimal friction, ideally by entering a display name or using a low-friction auth method.
3. User creates or opens a trip.
4. User adds participants.
5. User adds expenses with payer, amount, and participants.
6. User optionally records direct payments.
7. User views balances and settlement suggestions.
8. User shares or uses the settlement plan with the group.
9. User is prompted to create/sign into an account when it unlocks clear value, such as saving ownership, syncing, inviting others, or recovering access.

## Key Product Questions

These need your decisions before the project can be considered well-defined:

1. Who is the first real user: you personally, your friend group, couples/families, or general App Store users?
2. Is the MVP mainly an expense splitter, or should it include itinerary/planning from the start?
3. Should users be required to sign in, or can a trip be local/anonymous first?
4. Do all trip members need accounts, or can one organizer manage everyone?
5. What makes this better than Splitwise, Tricount, a spreadsheet, or a group chat?
6. Should the app optimize for simplicity or rich trip-planning features?
7. Is collaboration required for MVP, or can the first version be single-device?
8. What is the first trip/scenario we should design around?
9. What does “done enough to show someone” mean?
10. What does “done enough to ship/TestFlight” mean?

## Demo Milestone

Definition of “good enough to show someone”:

A local working demo is enough to show the idea of the app.

For this milestone, the app does not need production collaboration, polished auth, or full Supabase sharing. It should be good enough to hand the phone to someone and communicate the product concept clearly.

Demo should support:

- Create/open a sample trip.
- Show a trip dashboard.
- Show participants.
- Show core trip dates.
- Show places the group wants to check out.
- Show a basic itinerary/planning list.
- Add or view expenses.
- Show balances/settlement suggestions.
- Feel understandable without a long explanation.

Success criteria:

- A friend or family member can understand what the app is for.
- The app feels like a trip hub, not just a calculator screen.
- The main flows can be demonstrated on one device.
- Rough edges are acceptable if the product idea is clear.

## Suggested First Release Definition

Definition of “good enough for TestFlight”:

Use a confident TestFlight bar. The app can still be imperfect, but it should not feel fragile, confusing, or embarrassing to send to close friends/family.

A good first TestFlight target:

A user can create a trip, invite participants, collaborate through the invite model, add/view core trip details, add places, manage basic planning items, track shared expenses, and understand who owes whom.

Must work reliably enough:

- Account-backed trip creation for the organizer.
- Invite-based access for participants.
- Guest collaboration without mandatory signup, if technically feasible for this release.
- Shared trip data persists through Supabase/cloud storage.
- Trip dashboard is understandable.
- Participants, dates, places, basic planning, expenses, balances, and settlement flows work.
- No crashes in the main flows.
- Expense math is covered by unit tests.
- The UI is understandable without explanation.
- Supabase keys are safe and no service-role secrets are in the client.
- Build succeeds with the documented xcodebuild command.

Acceptable for TestFlight:

- Some visual rough edges.
- Some missing advanced features.
- Limited settings.
- Limited notification/reminder support.
- Basic permission model, as long as it is safe enough for invited trip collaborators.

Not acceptable for TestFlight:

- Losing trip or expense data.
- Broken invite flow.
- Major expense calculation errors.
- Requiring every invited participant to create a traditional account before they can even understand the app.
- Main flows that require developer explanation to use.

## Team/Lane Ownership

For project definition work, use:

- Product/UX Agent: owns this document, user journeys, MVP scope, acceptance criteria.
- Design/Figma Agent: turns product flows into screens/components and checks Figma alignment.
- Supabase Data/Sync Agent: validates data model implications.
- iOS Platform Agent: validates architecture/build implications.
- QA/Release Agent: converts definition into test plan and release checklist.

## Immediate Next Steps

1. Answer the key product questions above.
2. Convert the answers into a sharper MVP brief.
3. Create a feature roadmap: MVP, v1, later.
4. Create acceptance criteria for each MVP flow.
5. Align Figma screens to those MVP flows.
6. Then implement in small, reviewable tasks.
