# Wanderaid Test Plan

Status: Active
Last updated: 2026-08-17

## Purpose

This document describes the automated test coverage currently included in the Wanderaid iOS project and mirrors the Xcode test plan in `GroupTripApp.xctestplan`.

The Xcode test plan runs the `GroupTripAppTests` unit-test target against the `GroupTripApp` app target.

## Xcode test plan

- File: `GroupTripApp.xctestplan`
- Shared scheme: `GroupTripApp.xcodeproj/xcshareddata/xcschemes/GroupTripApp.xcscheme`
- Test target: `GroupTripAppTests`
- Default configuration: `Default Test Configuration`
- Target for variable expansion: `GroupTripApp`

## Automated test suites

### `TripExpenseCalculatorTests`

Covers local expense-splitting correctness:

- Expenses split across selected participants.
- Direct payments reduce outstanding balances.
- Settlement suggestions produce minimal payments to creditors.

### `TripCollaborationModelsTests`

Covers collaboration/auth/sync model behavior, including:

- OAuth redirect/query configuration.
- Supabase DTO decoding and snake-case mapping.
- Cloud trip assembly from trips, members, participants, places, planning items, expenses, splits, and direct payments.
- Invite/member/guest collaboration model behavior.
- Cloud store persistence behavior covered by existing fake/service tests in this suite.

### `DashboardSummaryTests`

Covers the selected Calm User Dashboard data foundation:

- Current trips sort ascending by start date.
- Future trips sort ascending by start date.
- Past trips sort descending by start date.
- Featured trip chooses the first current trip, otherwise first future trip.
- Incomplete planning items become attention rows.
- Completed planning items are excluded from attention rows.
- Attention list is capped at three rows.
- Known positive participant balances contribute to `owedToYou`.
- Known negative participant balances contribute to `youOwe`.
- Unknown participant identity produces no personal money summary instead of showing raw trip totals.
- `TripStore.dashboardSummary(currentParticipantID:)` delegates to the summary builder.

## Commands

### Run the full Xcode test plan

```sh
xcodebuild test \
  -project "GroupTripApp.xcodeproj" \
  -scheme GroupTripApp \
  -testPlan GroupTripApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO
```

### Run the full test target without naming the test plan

```sh
xcodebuild test \
  -project "GroupTripApp.xcodeproj" \
  -scheme GroupTripApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO
```

### Run only the dashboard summary tests

```sh
xcodebuild test \
  -project "GroupTripApp.xcodeproj" \
  -scheme GroupTripApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:GroupTripAppTests/DashboardSummaryTests
```

### Simulator fallback

If the named simulator is wedged or install fails with a transient Xcode/CoreSimulator error, create a temporary iPhone 17 simulator, run the test plan by device ID, then delete the temporary simulator.

```sh
DEVICE_ID=$(xcrun simctl create WanderaidTestTemp \
  com.apple.CoreSimulator.SimDeviceType.iPhone-17 \
  com.apple.CoreSimulator.SimRuntime.iOS-26-5)

xcodebuild test \
  -project "GroupTripApp.xcodeproj" \
  -scheme GroupTripApp \
  -testPlan GroupTripApp \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  CODE_SIGNING_ALLOWED=NO

STATUS=$?
xcrun simctl delete "$DEVICE_ID" || true
exit $STATUS
```

## Pre-commit verification

Before committing changes that affect source or tests:

1. Run the relevant targeted test.
2. Run the full Xcode test plan.
3. Run the generic iOS build:

   ```sh
   xcodebuild -project "GroupTripApp.xcodeproj" \
     -scheme GroupTripApp \
     -destination "generic/platform=iOS" \
     CODE_SIGNING_ALLOWED=NO build
   ```

4. Run whitespace check:

   ```sh
   git diff --check
   ```

5. Secret-scan modified text files before commit.

## Current manual follow-ups

The automated test plan does not replace manual smoke testing for:

- Google OAuth and Sign in with Apple flows.
- Invite acceptance across two real users.
- Supabase realtime/sync behavior against live data.
- Visual review of the Calm User Dashboard in light, dark, and auto appearance modes.
- Destructive confirmation flows such as sign-out and archive/remove trip.
