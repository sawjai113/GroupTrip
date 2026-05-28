# Wani

Wani is a SwiftUI iOS app for planning group trips with your people. Places, itinerary, dates, and expenses — all in one hub.

## Current Status

Milestone 1 (Local Demo) is in progress. The app ships with a realistic 6-person Japan Spring 2027 sample trip, editable places and planning items, expense calculator with settlements, and a trip summary hub.

## Development

### Build

```sh
xcodebuild build -project GroupTripApp.xcodeproj -scheme GroupTripApp -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/GroupTripAppDerivedData
```

### Test

```sh
xcodebuild test -project GroupTripApp.xcodeproj -scheme GroupTripApp -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /private/tmp/GroupTripAppDerivedData
```

