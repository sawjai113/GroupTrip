# Wani

Wani is a SwiftUI iOS app for planning group trips with your people. Places, itinerary, dates, and expenses — all in one hub.

## Current Status

Milestone 1 (Local Demo) is complete. It was implemented through chunks 1–13, documentation was updated in chunk 14, and final integration review passed in chunk 15. Use `Continue with Test Data` to open the local demo path.

The demo uses a realistic six-person sample trip, `Japan Spring 2027`, and includes a trip dashboard, trip summary hub previews, saved places add/delete, planning item add/delete/toggle, people, expense, direct payment, balance, and settlement flows.

Milestone 1 verification intentionally excludes Supabase sync/auth/invites/cloud collaboration, full trip detail editing, and durable persistence across app restart. Local session edits are for demonstration only; force quitting and relaunching the app restores the baseline sample trip.

Latest verification:

- Generic iOS build succeeded.
- iPhone 17 simulator expense calculator tests succeeded.

## Run the Local Demo

1. Open `GroupTripApp.xcodeproj` in Xcode.
2. Run the `GroupTripApp` scheme on an iOS simulator.
3. On launch, choose `Continue with Test Data`.
4. Open the `Japan Spring 2027` sample trip and use the smoke-test checklist in `docs/plans/milestone-1-local-demo.md`.

## Development

### Practice

Wani uses test-driven development as the default for behavior changes, bug fixes, and refactors. See `docs/development/tdd-practice.md`.

### Backlog

Quick TODOs, tester feedback, and rough product notes are tracked in `docs/todo-feedback.md` before they graduate into detailed plans or GitHub issues.

### Build

```sh
xcodebuild -project GroupTripApp.xcodeproj -scheme GroupTripApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

### Test

```sh
xcodebuild test -project GroupTripApp.xcodeproj -scheme GroupTripApp -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /private/tmp/GroupTripAppDerivedData
```

