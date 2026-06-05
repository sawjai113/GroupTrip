# Wani Test-Driven Development Practice

Wani should use test-driven development as the default practice for new behavior, bug fixes, and refactors.

## Core Rule

No production behavior change without a failing test first.

The expected cycle is:

1. **RED** — write one focused test for the desired behavior.
2. Run that specific test and confirm it fails for the expected reason.
3. **GREEN** — write the smallest implementation needed to pass.
4. Run the specific test and confirm it passes.
5. Run the broader relevant test suite to catch regressions.
6. **REFACTOR** — clean up while keeping tests green.

## Current Test Baseline

The current test target has expense-calculation coverage in:

- `GroupTripAppTests/TripExpenseCalculatorTests.swift`

These tests cover:

- splitting expenses across selected participants
- direct payments reducing balances
- settlement suggestions

Milestone 2 should expand coverage before adding cloud collaboration, auth, invites, and persistence.

## What Must Be Tested First

Use TDD for:

- new model behavior
- expense logic changes
- trip/member/participant rules
- invite and guest identity rules
- Supabase mapping/serialization
- persistence/load/save flows
- bug fixes
- refactors that change behavior

## What Can Be Handled More Lightly

Some UI-only visual changes may not need strict unit-test-first coverage if they do not change app behavior.

Examples:

- spacing changes
- color changes
- card shape/radius changes
- purely presentational layout experiments

For these, use:

- build verification
- manual simulator smoke test
- Product/UX review
- Design review

If a visual change changes behavior, navigation, state, filtering, validation, or data mutation, add tests first.

## Recommended Milestone 2 Test Areas

Before or during Milestone 2, add tests for:

### Trip membership and participants

- members and expense participants can be represented separately
- organizer is included as a member
- guest display names are tracked with stable internal IDs
- removing a member does not accidentally erase historical expense attribution

### Invite flow

- invite link/code can create a guest collaborator
- guest can later be associated with an account
- duplicate display names are allowed but internal IDs remain unique
- invalid/expired invite behavior is defined

### Supabase mapping

- local models encode/decode correctly to Supabase row DTOs
- missing optional fields are handled safely
- server IDs and local IDs are mapped consistently

### Persistence/sync behavior

- creating a trip persists required fields
- adding places/planning items/expenses persists expected rows
- loading a trip reconstructs the same local model shape
- failed saves surface recoverable errors instead of silently losing data

### Expense behavior under collaboration

- splits remain correct when synced participants are loaded from backend
- direct payments still reduce balances after persistence round-trip
- deleted or inactive participants do not corrupt historical calculations

## Test Command

Use the current simulator test command:

```sh
xcodebuild test \
  -project GroupTripApp.xcodeproj \
  -scheme GroupTripApp \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO
```

For generic build verification:

```sh
xcodebuild \
  -project GroupTripApp.xcodeproj \
  -scheme GroupTripApp \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Agent Workflow

When Hermes or subagents implement behavior changes:

1. The plan must identify testable behaviors first.
2. Implementation agents must write the failing test before production code.
3. Agents must report the RED failure output.
4. Agents must report the GREEN passing output.
5. Reviewers should reject behavior changes that do not include appropriate tests.

For UI/UX exploration:

- design-only prototypes can be implemented with build/review/manual smoke testing
- once a UX behavior is accepted, add tests around the state/logic it depends on

## Practical SwiftUI Testing Guidance

Prefer testing logic below the view layer first:

- model methods
- stores
- DTO mapping
- view models
- validators
- calculators
- invite/membership rules

Avoid fragile tests that assert exact view hierarchy unless the behavior cannot be tested elsewhere.

Good tests describe user/business behavior, not implementation details.

Example:

- Good: `testGuestInviteCreatesStableMemberIdentity()`
- Fragile: `testInviteButtonIsThirdSubviewInVStack()`

## Definition of Done for Behavior Changes

A behavior-changing task is done only when:

- [ ] at least one new/updated test was written before production code
- [ ] the new test was observed failing for the expected reason
- [ ] the implementation made the test pass
- [ ] the relevant full test suite passes
- [ ] build verification passes when app code changed
- [ ] reviewers confirm no untested behavior was added
