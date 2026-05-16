# Group Trip

Group Trip is a SwiftUI iOS app starter based on the Google Sheets group expense calculator template.

The first slice ports the template's core workflow:

- Add trip participants.
- Track expenses by item, payer, cost, and participating people.
- Include direct payments between people.
- Calculate each person's outstanding balance.
- Suggest payments that settle the group.

## Current Status

The app currently ships with sample data so the calculator screen is immediately visible. The next practical step is replacing the sample data with editable forms for participants, expenses, and payments.

## Validation

The app target builds with DerivedData outside the Documents folder:

```sh
xcodebuild build -project GroupTripApp.xcodeproj -scheme GroupTripApp -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/GroupTripAppDerivedData
```

Tests run against an installed simulator:

```sh
xcodebuild test -project GroupTripApp.xcodeproj -scheme GroupTripApp -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /private/tmp/GroupTripAppDerivedData
```
