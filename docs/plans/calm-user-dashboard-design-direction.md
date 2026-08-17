# Calm User Dashboard Design Direction

Status: Selected direction for the next dashboard/home redesign
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
