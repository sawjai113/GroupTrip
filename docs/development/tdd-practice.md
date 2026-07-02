# Wanderaid Test-Driven Development Practice

Wanderaid uses test-driven development as the default practice for new behavior, bug fixes, and refactors.

## Core Rule

No production behavior change without a failing test first.

The expected cycle is:

1. **RED** — write one focused test for the desired behavior.
2. Run that specific test and confirm it fails for the expected reason.
3. **GREEN** — write the smallest implementation needed to pass.
4. Run the specific test and confirm it passes.
5. Run the broader relevant test suite to catch regressions.
6. **REFACTOR** — clean up while keeping tests green.

## Cloud Sync Tests

For cloud persistence tests, use the `wanderaid-tdd-sync-boilerplate` skill. It covers:

- `FakeTripSyncService` request-recording pattern
- UUID conventions to prevent test coupling
- `makeTrip()` helper for test setup
- Success/failure patterns for create, update, and delete
- Running targeted and full-suite tests

Load it before implementing any new cloud sync entity:

```text
/skill wanderaid-tdd-sync-boilerplate
```

## What Must Be Tested First

Use TDD for:

- new model behavior
- expense logic changes
- trip/member/participant rules
- invite and guest identity rules
- Supabase DTO mapping/serialization
- cloud persistence create/update/delete flows
- cloud persistence failure handling (no local mutation on error)
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

## Pre-Commit Verification Sequence

Before marking any non-trivial change complete, run these in order:

```sh
# 1. Full test suite
xcodebuild test -project "GroupTripApp.xcodeproj" -scheme GroupTripApp -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO

# 2. Generic build
xcodebuild -project "GroupTripApp.xcodeproj" -scheme GroupTripApp -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build

# 3. Whitespace check
git diff --check

# 4. Secret scan (see wanderaid-build-test-commands skill for the Python script)
```

## How to Test

```sh
# Full suite
xcodebuild test -project "GroupTripApp.xcodeproj" -scheme GroupTripApp -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO

# Targeted test
xcodebuild test -project "GroupTripApp.xcodeproj" -scheme GroupTripApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GroupTripAppTests/TripStoreCloudSyncTests/testCloudStorePersistsAddedExpenseAndUpdatesLocalTrip CODE_SIGNING_ALLOWED=NO

# Sub-suite
xcodebuild test -project "GroupTripApp.xcodeproj" -scheme GroupTripApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GroupTripAppTests/TripStoreCloudSyncTests CODE_SIGNING_ALLOWED=NO

# Generic build
xcodebuild -project "GroupTripApp.xcodeproj" -scheme GroupTripApp -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```

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
- [ ] git diff --check passes
- [ ] secret scan on modified files passes
- [ ] reviewers confirm no untested behavior was added
