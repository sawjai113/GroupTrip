# Pre-Milestone 2 Design Flexibility Plan

> **For Hermes:** Use subagent-driven-development skill for larger follow-up refactors. This prep pass is intentionally small and focused on making future layout/UX pivots safer.

**Goal:** Make Wani easier to redesign before and during Milestone 2 by centralizing common visual decisions and reducing one-off styling in feature screens.

**Architecture:** Keep feature/data logic in the existing SwiftUI screens, but move reusable presentation primitives into `AppTheme.swift` and `SharedViews.swift`. Feature screens should compose cards, section headers, icon badges, and empty states rather than hand-rolling each visual shell.

**Tech Stack:** SwiftUI, existing `TripStore`, `TripPlan`, and `TripCalculatorViewModel` state.

---

## Why This Matters

The design and UX flows are expected to change as Wani moves from a local demo toward TestFlight. A small design-system layer now reduces future hiccups by making common layout choices easier to update in one place.

## Scope for This Prep Pass

### Included

- Add shared spacing, radius, icon, and semantic feature-color tokens.
- Add reusable card, section header, icon badge, preview row, and primary action button components.
- Refactor trip details, itinerary, and places surfaces to use the shared components where straightforward.
- Preserve current behavior and visual intent.
- Keep this as a non-disruptive refactor, not a redesign.

### Not Included

- Final brand identity.
- Figma integration.
- New navigation architecture.
- Tab bar redesign.
- Supabase/Milestone 2 data work.
- Calendar/map/chat integrations.

## Design Flexibility Principles

1. **Tokenize repeated choices.** Common spacing, radii, and semantic colors should live in `AppTheme`.
2. **Compose from shared shells.** Repeated card/header/icon layouts should use `SharedViews`.
3. **Keep business logic out of visual components.** Reusable components should be mostly presentational.
4. **Prefer semantic feature colors.** Use `AppTheme.FeatureColor.people`, `.itinerary`, `.places`, `.expenses`, etc.
5. **Make future swaps cheap.** A card can become flatter, rounder, denser, or more branded by changing the shared shell.
6. **Avoid over-abstracting too early.** Only extract patterns that already repeat.

## Implementation Checklist

- [x] Expand `AppTheme.swift` with spacing, radius, icon size, and feature color tokens.
- [x] Add `WaniCard`, `WaniSectionHeader`, `WaniIconBadge`, `WaniPreviewRow`, and `WaniPrimaryActionButton` to `SharedViews.swift`.
- [x] Update `ActionCard`, `EmptyFeatureCard`, and related shared views to use tokens.
- [x] Update `TripSummaryView.swift` overview cards to use shared section/card/icon primitives.
- [x] Update `TripPlanningView.swift` calendar placeholder and item cards to use shared primitives.
- [x] Update `TripPlacesView.swift` place cards to use shared primitives.
- [x] Build and run tests.
- [x] Review for spec compliance and code quality.

## Future Follow-Up Candidates

- Extract `TripHeroHeader` from `TripSummaryView.swift`.
- Create `TripOverviewNavigationCard` as a public reusable component if dashboard and detail cards converge.
- Add SwiftUI previews backed by reusable sample fixtures.
- Create a design-token reference doc once final visual direction is clearer.
- Hide or redesign Coming Soon surfaces before TestFlight.
