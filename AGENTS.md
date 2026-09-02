# Group Trip App Agent Guide

This project is small enough for one person to understand, but it is now split well enough for focused subagents to work without colliding. Use these agents as role boundaries, not rigid job titles. One agent can own a task end to end as long as it stays within its lane and calls out handoffs.

## When to Delegate

The main session handles straightforward inline work. Subagents are reserved for tasks that benefit from isolation:

**Delegate to a subagent when:**
- Multi-file pattern with an established wanderaid-* skill
- Cross-cutting work spanning layers (schema + service + store + tests)
- Research / design proposal (read several files, synthesize)
- Any implementation touching 4+ files or non-trivial logic
- QA review pass after any non-trivial change

**Do NOT delegate (work inline) when:**
- Single-file mechanical change (rename, typo fix, single button)
- Trivial one-line fixes
- Quick exploration where fast iteration matters

**QA gate after implementation (before commit):**
- For inline work touching 2+ files or containing logic changes: spawn the QA/Release & PR Review Agent to review the diff before committing.
- For delegated work: always run the QA/Release & PR Review Agent after the implementation subagent finishes.
- The QA agent reviews the diff, runs security and whitespace checks, and confirms tests pass.
- Skip QA gate only for typo fixes, docs-only changes, whitespace fixes, and single-line trivial fixes.

## Model Routing / Token Efficiency

Use the cheaper `general` profile / DeepSeek lane for planning and research, and reserve the `coding` profile / Codex lane for implementation and code review.

**Prefer DeepSeek (`general`) for:**
- Product/UX briefs, acceptance criteria, scope cuts, and roadmap thinking.
- Android planning and platform-parity advice.
- Design/Figma critique, visual direction, accessibility checklists, and implementation notes that do not edit code.
- Integrations research and setup planning before code or SDK changes.
- Admin tasks, retrospectives, cron/VPS guidance, and non-coding chat.

**Prefer Codex (`coding`) for:**
- Any agent that edits Swift, SQL, Xcode project files, tests, or scripts in the repo.
- Auth/Supabase, Supabase Data/Sync, Trips, Expenses, iOS Platform, and QA/Release work.
- Design/Figma or Integrations tasks once they move from planning into implementation.
- QA/release/code-review agents that inspect diffs, reason about tests, or validate security-sensitive changes.

Default workflow: start cheap in `general` for discovery/specification. Spawn or switch to `coding` for implementation and QA. If unsure, do a short DeepSeek scoping pass first, then spend Codex on the smallest well-defined coding task.

**Quota-aware dispatch (learned 2026-09-01):** the Codex-backed lanes (`coding` implementation, `review` gates) share the user's Codex quota, which resets on a ~5h rolling window. When exhausted, those profiles fail with HTTP 429 mid-run and messages to a mid-turn profile bounce `target_busy` until it finishes. Rules: (1) never start a chunk without its scope + design decisions recorded in `docs/plans/` first — that file is the durable channel that survives quota kills and bounced deliveries; (2) before dispatching a Codex-lane chunk, confirm quota is available; (3) if a lane dies mid-chunk (429), resume from the last committed state rather than restarting; (4) use the quota pause for non-Codex lanes (@architect scoping, @design handoff) so work is queued when quota returns. **Escalated 2026-09-02 (drift recurred):** a design-dependent chunk's UI wiring must NOT be dispatched until the @design handoff is ALREADY IN the plan doc — a running @coding turn cannot receive mid-turn deliveries, so "logic now, UI when the handoff arrives" as one dispatch WILL wire against stale spec. Either dispatch @coding after the handoff lands (sequential), or split: pure-logic dispatch first, then a separate UI-wiring dispatch after the handoff is recorded.

## Global Rules

- Preserve user changes. Do not revert unrelated work.
- Prefer small, reviewable changes over broad rewrites.
- Keep feature logic close to its feature area unless it is clearly reusable.
- **No overlapping interactive elements**: when layering views in a ZStack (buttons over heroes, pills over photos, dots over rows), never place a tappable control on top of a label/pill/badge/another tappable target in the same region — same-corner pins with similar paddings are the classic failure (BackButton over the hero status pill, todo-feedback #27). The QA gate (Step 5b) checks this on every UI diff.
- **Capture failures, don't just fix them**: after any notable failure or near-miss (quota kill, delivery bounce, test-gap bug, design drift), file an entry in `docs/lessons-learned.md` (what failed / root cause / what absorbed it / durable rule / recurrence risk) AND confirm the durable rule exists in AGENTS.md, a skill, or the plan doc — same turn or next natural checkpoint. Unavoidable issues (token quotas) must name the robust mechanism that keeps the workflow working through them. Review the register at milestone retrospectives.
- Run a build after source changes:

```sh
xcodebuild -project "/Users/sawjai/Documents/Group Trip App/GroupTripApp.xcodeproj" -scheme GroupTripApp -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```

- Keep Supabase keys client-safe only. Never add service-role keys to the app.
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
You are the QA/Release & PR Review Agent for this SwiftUI iOS app. Read AGENTS.md first. You are the QA gate — review this implementation after a feature subagent finishes. Check the diff for correctness, security, secrets, schema/RLS risks, missing tests, and release blockers. Run the relevant tests or iOS build. If you fix bugs, keep edits narrow and explain what failed. Report a pass/fail verdict with the verification evidence.
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

## Milestone Retrospectives

After every major milestone or large multi-session push, run a short retrospective before moving to the next milestone. Include:

- What shipped / what changed.
- What slowed us down or caused rework.
- Which AI workflows helped most: inline agent, subagent, spawned profile, skill, cron, or manual smoke test.
- Token/model efficiency: did we use DeepSeek/general for planning and admin, and reserve Codex/coding for implementation and code review?
- For major retrospectives or high-stakes process decisions, consider running the `general` profile's `/moa` retrospective preset once to get a concise Codex engineering perspective while keeping DeepSeek as the aggregator.
- **Review `docs/lessons-learned.md`**: check each entry's durable rule still holds, mark superseded mitigations, and confirm no incident class recurred since the last review. If one did, the rule was insufficient — escalate to a skill or workflow change. This is the standing failure-review step of every retrospective.
- Whether any tasks should have started with a cheaper scoping pass before Codex work.
- Whether any new process should become a skill, memory, or AGENTS.md rule.
- One concrete workflow adjustment for the next milestone.

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
