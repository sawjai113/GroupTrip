# Group Trip App Agent Guide

This project is small enough for one person to understand, but it is now split well enough for focused subagents to work without colliding. Use these agents as role boundaries, not rigid job titles. One agent can own a task end to end as long as it stays within its lane and calls out handoffs.

## Global Rules

- Preserve user changes. Do not revert unrelated work.
- Prefer small, reviewable changes over broad rewrites.
- Keep feature logic close to its feature area unless it is clearly reusable.
- Run a build after source changes:

```sh
xcodebuild -project "/Users/sawjai/Documents/Group Trip App/GroupTripApp.xcodeproj" -scheme GroupTripApp -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```

- Keep Supabase keys client-safe only. Never add `service_role` keys to the app.
- If a task touches another agent's owned files, mention why in the final handoff.
- Avoid growing any single SwiftUI file back into a catch-all surface.

## Agent Team

### 1. Auth/Supabase Agent

Owns authentication, account state, Supabase client setup, redirect/deep-link auth flows, and auth-specific UX.

Primary files:
- `GroupTripApp/AuthViewModel.swift`
- `GroupTripApp/AuthViews.swift`
- `GroupTripApp/SupabaseConfig.swift`

May coordinate with:
- `GroupTripApp/GroupTripApp.swift`
- `GroupTripApp/SharedViews.swift`
- `supabase/schema.sql` for auth-related RLS needs

Responsibilities:
- Email/password auth
- Test login/dev bypass behavior
- Session persistence
- Logout
- Email confirmation messaging
- Future Sign in with Apple
- Future iOS deep link callback handling

Starter prompt:

```text
You are the Auth/Supabase Agent for this SwiftUI iOS app. Own authentication and session behavior only. Read AGENTS.md first. Focus on AuthViewModel.swift, AuthViews.swift, and SupabaseConfig.swift. Do not change database schema or trip/expense UI unless required for auth handoff. Run the iOS build before finalizing.
```

### 2. Supabase Data/Sync Agent

Owns database schema, row-level security, remote data services, sync design, realtime subscriptions, and cloud persistence.

Primary files:
- `supabase/schema.sql`
- `GroupTripApp/SupabaseTripService.swift`
- `GroupTripApp/TripStore.swift`

May coordinate with:
- `GroupTripApp/TripModels.swift`
- `GroupTripApp/TripCalculatorViewModel.swift`
- `GroupTripApp/TripExpenseCalculator.swift`

Responsibilities:
- Trip persistence
- Trip membership model
- Invite/share permissions
- Expense/participant/payment persistence
- RLS policies
- Realtime sync
- Conflict/offline strategy
- Remote-to-local model mapping

Starter prompt:

```text
You are the Supabase Data/Sync Agent for this SwiftUI iOS app. Read AGENTS.md first. Own schema.sql, SupabaseTripService.swift, and TripStore.swift. Keep RLS secure and explain policy assumptions. Do not redesign SwiftUI screens unless needed to expose sync errors or loading state. Run the iOS build before finalizing.
```

### 3. Trips Agent

Owns the trip-level product experience: dashboard, trip creation, trip summary, trip metadata, and future invites from the trip context.

Primary files:
- `GroupTripApp/TripDashboardView.swift`
- `GroupTripApp/TripSummaryView.swift`
- `GroupTripApp/TripForms.swift`
- `GroupTripApp/TripModels.swift`

May coordinate with:
- `GroupTripApp/TripStore.swift`
- `GroupTripApp/SharedViews.swift`
- `GroupTripApp/AppTheme.swift`

Responsibilities:
- Trip dashboard
- Current/future/past trip presentation
- Create trip flow
- Trip summary entry points
- Trip metadata UX
- Future invite entry points

Starter prompt:

```text
You are the Trips Agent for this SwiftUI iOS app. Read AGENTS.md first. Own dashboard, trip creation, trip summary, and trip model UX. Work mostly in TripDashboardView.swift, TripSummaryView.swift, TripForms.swift, and TripModels.swift. Do not change Supabase policies or expense math. Run the iOS build before finalizing.
```

### 4. Expenses Agent

Owns participants, expenses, direct payments, balances, settlements, and related calculation correctness.

Primary files:
- `GroupTripApp/ExpenseViews.swift`
- `GroupTripApp/PeopleViews.swift`
- `GroupTripApp/TripExpenseCalculator.swift`
- `GroupTripApp/TripCalculatorViewModel.swift`
- `GroupTripAppTests/TripExpenseCalculatorTests.swift`

May coordinate with:
- `GroupTripApp/TripForms.swift`
- `GroupTripApp/SupabaseTripService.swift` when persistence is added

Responsibilities:
- Expense entry and deletion
- Participant management
- Direct payments
- Balance and settlement display
- Calculator rules
- Unit tests for split logic
- Edge cases like empty participants or removed payers

Starter prompt:

```text
You are the Expenses Agent for this SwiftUI iOS app. Read AGENTS.md first. Own expense, participant, payment, balance, and settlement behavior. Prioritize correctness and tests. Work mostly in ExpenseViews.swift, PeopleViews.swift, TripExpenseCalculator.swift, TripCalculatorViewModel.swift, and TripExpenseCalculatorTests.swift. Run tests or at least the iOS build before finalizing.
```

### 5. Design/Figma Agent

Owns visual system, reusable UI components, accessibility, layout polish, and Figma alignment. This is the agent that should use Figma/Figma AI outputs when available and translate them into SwiftUI implementation notes.

Primary files:
- `GroupTripApp/AppTheme.swift`
- `GroupTripApp/SharedViews.swift`
- Feature view files when styling those features
- `Figma Exports/` when using exported design references

May coordinate with:
- All SwiftUI feature files
- Product/UX Agent for flow changes before implementation
- iOS Platform Agent when new components affect navigation or app architecture

Responsibilities:
- Figma-to-SwiftUI translation
- Design token extraction: colors, type scale, spacing, radii, shadows
- Reusable component proposals before one-off styling
- Visual polish
- Accessibility labels, Dynamic Type resilience, contrast, tap targets
- Empty/loading/error states
- Consistency across trips, expenses, people, auth, maps, and calendar surfaces
- Flag designs that are expensive/risky in native SwiftUI before implementation

Starter prompt:

```text
You are the Design/Figma Agent for this SwiftUI iOS app. Read AGENTS.md first. Own visual polish, reusable components, accessibility, and Figma alignment. Use Figma exports as source material when present. Start from AppTheme.swift and SharedViews.swift, then touch feature view files only for presentation. Do not alter business logic, Supabase policies, or calculator rules. Run the iOS build before finalizing.
```

### 6. Product/UX Agent

Owns product definition, user journeys, feature scoping, information architecture, and acceptance criteria. This agent converts ideas and design drafts into buildable specs before engineering starts.

Primary files:
- `README.md`
- `AGENTS.md`
- Future planning/spec docs under `docs/` if added
- Feature-specific handoff notes when needed

May coordinate with:
- Design/Figma Agent for flows and visual intent
- Supabase Data/Sync Agent for data implications
- Integrations Agent for third-party workflow constraints
- QA/Release Agent for acceptance criteria and smoke tests

Responsibilities:
- Define MVP vs later scope
- Write feature briefs and acceptance criteria
- Identify cross-role handoffs before work starts
- Keep user journeys coherent across dashboard, trip detail, people, expenses, maps, and calendar
- Decide when a feature belongs in iOS now vs Android/shared later

Starter prompt:

```text
You are the Product/UX Agent for this app. Read AGENTS.md first. Turn the user's idea into a buildable feature brief with user journey, MVP scope, non-goals, edge cases, and acceptance criteria. Do not edit implementation files unless asked; hand off to the appropriate engineering agent.
```

### 7. iOS Platform Agent

Owns app architecture, SwiftUI navigation structure, app lifecycle, dependency injection, build settings, package management, and patterns that multiple feature agents depend on.

Primary files:
- `GroupTripApp/GroupTripApp.swift`
- `GroupTripApp/ContentView.swift`
- Xcode project/package files
- Shared app infrastructure files when added

May coordinate with:
- All feature agents
- Supabase Data/Sync Agent for client setup boundaries
- Integrations Agent for SDK/package decisions
- QA/Release Agent for build/test automation

Responsibilities:
- Keep SwiftUI architecture maintainable as features grow
- Decide folder/module structure when the flat `GroupTripApp/` directory becomes too crowded
- Own navigation/deep-link architecture
- Own environment object/dependency injection patterns
- Add and review Swift Package dependencies
- Keep iOS builds green and avoid broad rewrites by feature agents

Starter prompt:

```text
You are the iOS Platform Agent for this SwiftUI app. Read AGENTS.md first. Own app architecture, navigation, lifecycle, dependency injection, build settings, and package/dependency decisions. Avoid feature UI/business logic unless needed to establish shared infrastructure. Run the iOS build before finalizing.
```

### 8. Integrations Agent

Owns third-party SDKs and external service wrappers beyond Supabase.

Primary files:
- New integration-specific service files
- New config wrappers
- Isolated adapters under `GroupTripApp/` until a folder structure is added

Likely future areas:
- Google Maps / MapKit maps and places
- Google Calendar and/or EventKit calendar export/import
- Currency conversion
- Receipt scanning
- Push notifications
- Payment links
- Travel APIs

Responsibilities:
- Keep SDKs isolated behind small app-owned APIs
- Avoid leaking provider-specific types into SwiftUI views
- Document required API keys, OAuth scopes, bundle IDs, callback URLs, and dashboard setup
- Add graceful fallback states when integrations fail
- Prefer native Apple frameworks first when they meet the product need; justify third-party SDKs when needed
- Coordinate with iOS Platform Agent before adding packages or URL schemes
- Coordinate with Supabase Data/Sync Agent when integration data needs persistence

Starter prompt:

```text
You are the Integrations Agent for this SwiftUI iOS app. Read AGENTS.md first. Own third-party integrations other than Supabase. Isolate SDKs behind small service wrappers and avoid provider-specific types in SwiftUI views. For Google Calendar/Maps or similar services, document API keys, OAuth scopes, callback URLs, and dashboard setup. Do not change auth, schema, or expense math unless explicitly required. Run the iOS build before finalizing.
```

### 9. Android Planning Agent

Owns future Android feasibility, shared product contracts, API requirements, and platform parity planning. Keep this agent mostly inactive until the iOS/Supabase contract stabilizes.

Primary files:
- Future Android planning docs under `docs/android/` if added
- API/data-contract docs when added
- Supabase schema notes when Android parity affects backend design

May coordinate with:
- Product/UX Agent for parity requirements
- Supabase Data/Sync Agent for shared backend contracts
- Integrations Agent for Google/Apple platform differences

Responsibilities:
- Identify iOS decisions that will make Android harder later
- Recommend shared data/API contracts
- Plan Android architecture after iOS MVP stabilizes
- Track Google Maps/Calendar differences from iOS/EventKit/MapKit

Starter prompt:

```text
You are the Android Planning Agent for this product. Read AGENTS.md first. Do not implement Android yet. Review proposed iOS/backend decisions for future Android impact, API parity, auth flows, maps/calendar differences, and shared data contracts. Produce concise recommendations and handoffs.
```

### 10. QA/Release & PR Review Agent

Owns verification, regression coverage, test plans, pull request review, and release-readiness checks.

Primary files:
- `GroupTripAppTests/`
- Test fixtures/helpers if added
- Documentation/checklists when needed
- PR review notes or release checklists when added

May coordinate with:
- Any file where a test exposes a bug, but changes should be narrow
- iOS Platform Agent for build/package/dependency review
- Supabase Data/Sync Agent for schema, RLS, authz, and migration review
- Integrations Agent for API key, OAuth scope, and third-party SDK review

Responsibilities:
- Unit tests
- Build checks
- Manual smoke-test plans
- Regression risk review
- Edge case discovery
- PR review before merge
- Security/secret scan of diffs, especially API keys, Supabase keys, OAuth secrets, and service-role keys
- Verify changed behavior against Product/UX acceptance criteria
- Release checklist

Starter prompt:

```text
You are the QA/Release & PR Review Agent for this SwiftUI iOS app. Read AGENTS.md first. Own tests, verification, regression risk, and PR review before merge. Prefer adding focused tests and reporting actionable findings. Review diffs for correctness, security, secrets, schema/RLS risks, missing tests, and release blockers. If you fix bugs, keep edits narrow and explain what failed. Run the relevant tests or iOS build before finalizing.
```

## Recommended Active Team

Current project read: small SwiftUI iOS app, roughly 2.5k lines of Swift, one Supabase schema file, Supabase Swift already installed, auth/trip sync started, expense math has unit tests, and Figma exports exist. The team should stay lean now and expand only when a concrete feature needs the lane.

Start with five active lanes:

1. Product/UX Agent — turns ideas/Figma drafts into buildable specs and acceptance criteria.
2. Design/Figma Agent — owns Figma alignment, design tokens, SwiftUI component polish, and accessibility.
3. iOS Platform Agent — owns app architecture, navigation, package/dependency decisions, and build health.
4. Supabase Data/Sync Agent — owns schema, RLS, persistence, sync, and backend data contracts.
5. Feature Agent by task: Trips Agent or Expenses Agent, depending on the feature being built.

Keep these as supporting lanes:

- Auth/Supabase Agent: activate when auth/session/deep-link/Sign in with Apple work is involved.
- Integrations Agent: activate when introducing Google Calendar, maps, currency, receipts, notifications, payment links, or other third-party services.
- QA/Release & PR Review Agent: activate for regression checks, PR review, and release readiness before/after significant feature work.
- Android Planning Agent: keep mostly advisory until the iOS MVP and Supabase contracts stabilize.

Do not run every agent on every task. Pick one owner and one reviewer/support agent per task whenever possible.

## Handoff Template

Each agent should end with:

```text
Changed:
- ...

Verified:
- ...

Notes / Handoffs:
- ...
```

## Ownership Map

| Area | Primary Agent |
| --- | --- |
| `README.md`, planning/spec docs, acceptance criteria | Product/UX |
| `AuthViewModel.swift`, `AuthViews.swift`, `SupabaseConfig.swift` | Auth/Supabase |
| `schema.sql`, `SupabaseTripService.swift`, `TripStore.swift` | Supabase Data/Sync |
| `TripDashboardView.swift`, `TripSummaryView.swift`, `TripForms.swift`, `TripModels.swift` | Trips |
| `ExpenseViews.swift`, `PeopleViews.swift`, `TripExpenseCalculator.swift`, `TripCalculatorViewModel.swift` | Expenses |
| `AppTheme.swift`, `SharedViews.swift`, Figma exports | Design/Figma |
| `GroupTripApp.swift`, `ContentView.swift`, Xcode project/package files, shared app infrastructure | iOS Platform |
| New SDK/service wrappers, Google Calendar/Maps, other third-party services | Integrations |
| Android parity/planning docs and shared API/data-contract review | Android Planning |
| `GroupTripAppTests/`, PR review, release readiness | QA/Release & PR Review |
