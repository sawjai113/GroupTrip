# Wanderaid

Wanderaid is a SwiftUI iOS app for planning group trips with your people. Places, itinerary, dates, and expenses — all in one hub.

## Current Status

Milestone 2 (Collaborative MVP) is complete. Core cloud CRUD is wired and tested for Places, Planning Items, and Expenses (with splits/direct payments). The app uses Supabase for auth (Google OAuth primary, email/password backup) and data persistence. A manual two-user smoke test has passed — User A creates trip → invite → User B joins → cloud collaboration works.

Latest verification:

- 66 tests passing across 6 suites (as of 2026-07-22).
- Generic iOS build succeeded.
- iPhone 17 simulator tests succeeded.
- Live rollback Supabase cross-user smoke succeeded.
- Archiveability check succeeded with `CODE_SIGNING_ALLOWED=NO`.
- Secret scan and whitespace check passed.

## Run the App

1. Open `GroupTripApp.xcodeproj` in Xcode.
2. Run the `GroupTripApp` scheme on an iOS simulator.
3. On launch, sign in with Google to create cloud-backed trips, or choose `Continue with Test Data` for the local demo.

For the full two-user smoke test checklist, see the `wanderaid-manual-smoke-test` skill or run a manual test per `docs/plans/milestone-2-collaborative-mvp.md`.

## Development

### Practice

Wanderaid uses test-driven development as the default for behavior changes, bug fixes, and refactors. See `docs/development/tdd-practice.md`.

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

