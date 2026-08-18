# Calm Editorial App Design Direction

Status: Selected direction for dashboard/home and future app-wide redesign
Last updated: 2026-08-17

Implementation issue: https://github.com/sawjai113/GroupTrip/issues/1

## Source mockups

Design repo: https://github.com/sawjai113/wanderaid-designs

Review links:

- Light mode: https://sawjai113.github.io/wanderaid-designs/variants/001c-calm-user-dashboard/
- Dark mode: https://sawjai113.github.io/wanderaid-designs/variants/001d-calm-user-dashboard-dark/

## Product direction

The home page should become a **current-user dashboard**, not just a trip-centered landing page.

Trips still anchor the experience, but the first screen should answer:

1. What needs my attention?
2. What do I owe or what am I owed?
3. What is my current trip?
4. What future trips are coming up?
5. How do I get to all trips, including past trips?

## Visual direction

Use the selected **Calm Editorial** style:

- Warm paper tones in light mode.
- Warm near-black/brown surfaces in dark mode.
- Cream/ink typography.
- Forest-green accent color.
- Serif display moments for the Wanderaid wordmark and large money/trip emphasis.
- Rounded cards with soft borders and restrained shadows.
- Low-noise UI: fewer persistent buttons, more tappable surfaces.

Dark mode should preserve the same hierarchy as light mode, not become a separate layout.

## App-wide direction

The same Calm Editorial design ideas should extend across the rest of the app, not stop at the dashboard.

This means future page redesigns should feel like they belong to one Wanderaid system:

- Warm editorial tone without becoming decorative or hard to scan.
- Clear user-centered hierarchy: surface what the current user needs to know or do next.
- Large emotional anchors where useful, especially for trip-level screens.
- Compact, low-noise action placement: fewer repeated primary buttons, more tappable cards/rows and contextual menus.
- Consistent rounded cards, soft borders, restrained shadows, and semantic accent colors.
- Light and dark variants for every core pattern.
- “Future trips” wording for upcoming trips beyond the current trip.
- Destructive/removal/account-ending actions remain confirmed and visually distinct.

### Page-level implications

Apply the design direction in phases:

1. **Dashboard / Home**
   - Selected mockup source of truth for the first implementation pass.
   - Establish shared tokens, card shells, section headers, bottom navigation, profile menu, and light/dark behavior.

2. **Current Trip / Trip Detail**
   - Should feel like the focused version of the dashboard’s featured trip card.
   - Keep the trip photo/title/date as the emotional anchor.
   - Surface user-specific next actions, group decisions, balances, and key sections.
   - Avoid turning trip detail into a generic settings/list page.

3. **All Trips**
   - Should make current, future, and past trips easy to scan.
   - Use the same card/list language as the dashboard.
   - Preserve easy past-trip discovery without making history dominate the dashboard.

4. **Expenses / Balances**
   - Should prioritize what the current user owes or is owed.
   - Use drill-in cards/rows that match the dashboard money summary.
   - Keep raw group totals available but secondary to user-specific settlement clarity.

5. **People / Participants**
   - Should feel collaborative and calm, not admin-heavy.
   - Use profile/participant cards, subtle roles/statuses, and clear ownership/guest labels.

6. **Places / Itinerary / Planning**
   - Should use editorial cards for places and timeline-like groupings for days/plans.
   - Important plans or decisions should feed back into `Needs your attention`.

7. **Create / Join / Invite flows**
   - Should use the same calm card/sheet language as the profile dropdown actions.
   - Keep join/create discoverable through the profile menu and any appropriate empty states.

8. **Confirmations and destructive flows**
   - Should use the eventual Wanderaid confirmation component rather than scattered platform defaults where copy needs more space.
   - Preserve all existing confirmation safety rules.

### Design-system implications

Before or during implementation, prefer adding reusable presentational pieces only where they clearly repeat:

- App shell / bottom navigation.
- Profile menu.
- Calm card surface with light/dark tokens.
- Section header.
- Tappable hero card.
- Attention/action row.
- Money summary card and money row.
- Trip row/card.
- Empty state card.
- Confirmation component for destructive flows.

Avoid a large premature component framework; build small reusable primitives as each redesigned page needs them.

## Selected dashboard structure

Top to bottom:

1. Header
   - Wanderaid wordmark on the left.
   - Sync/greeting status below wordmark.
   - Top-right profile icon.
   - Profile dropdown contains:
     - Create trip
     - Join by invite
     - Account settings / sign out

2. Featured current/future trip card
   - Large but vertically compact photo card.
   - Whole card is tappable into the current trip.
   - No internal CTA buttons.
   - Copy surfaces the user's next relevant action for that trip.

3. Needs your attention
   - Appears above money.
   - Shows actionable cross-trip items such as decisions, expense reviews, or confirmations.
   - Should stay compact enough not to dominate the screen.

4. Your money across trips
   - Replaces trip-level total spent as the dashboard's main money concept.
   - Shows the user's net outstanding position across trips.
   - Splits drill-in rows into:
     - Owed to you
     - You owe
   - Rows should deep-link into balances/expenses filtered to the relevant trip or person.

5. User summary metrics
   - Decisions
   - Invites
   - Future trips

6. Current & future trips
   - Direct entry into current and upcoming trips.
   - Use “future trips” wording instead of “next trip” for upcoming trips beyond the current trip.

7. Past trips
   - Easy to find from the dashboard.
   - Also reachable through All Trips.

8. Bottom navigation
   - Anchored to the bottom edge.
   - Tabs:
     - Dashboard
     - Current
     - All Trips

## Behavior and data implications

This is not only visual polish. The design implies a new user-focused dashboard summary layer.

Likely derived data needed:

- Current trip, if any.
- Future trips count/list.
- Past trips count/list.
- User-specific net outstanding amount across visible trips.
- User-specific owed-to-you and you-owe breakdowns.
- Actionable items requiring the user's attention.
- Invite count or pending invite/join status if available.

Implementation should avoid showing raw trip totals where the mockup expects user-specific values.

## TDD / implementation guidance

Use test-first implementation for behavior/data changes:

- Add tests for any dashboard summary/view-model logic before production code.
- Test net outstanding calculations at the calculator/view-model layer.
- Test current/future/past trip grouping semantics before wiring SwiftUI.
- Test action item derivation if it is backed by real state rather than static placeholder copy.

Pure visual translation can be verified with build/manual review, but any new derived state, navigation behavior, or balance calculation needs tests first.

## Non-goals for the first implementation pass

- Building real notifications or a full activity system.
- Adding new backend tables for action items.
- Replacing all trip detail screens.
- Permanent design-system over-abstraction.
- Figma handoff.

## Open decisions before implementation

- Should “Current” bottom tab open only the current trip, or the current/future trip list when there is no current trip?
- How many “Needs your attention” rows should appear before requiring “View all”?
- Should net outstanding be displayed as “You’re owed $X” / “You owe $X” instead of a signed/net amount?
- Should dark mode follow system appearance only, or should Wanderaid eventually offer an app-level appearance setting?
