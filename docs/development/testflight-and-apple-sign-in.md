# Wanderaid TestFlight and Sign in with Apple Setup

Last updated: 2026-07-01

This checklist covers the non-code setup needed to run Wanderaid on a physical iPhone and distribute it through TestFlight.

## Current Code State

Implemented in the app:

- Native Sign in with Apple button in the signed-in login screen.
- Apple ID token handoff to Supabase via `signInWithIdToken(provider: .apple, idToken: ..., nonce: ...)`.
- Raw nonce generation + SHA-256 nonce hashing for Apple's request.
- `GroupTripApp.entitlements` with `com.apple.developer.applesignin` enabled.
- Xcode project points Debug and Release builds at the entitlements file.

Still required outside the repo:

- Select your Apple Developer Team in Xcode signing settings.
- Register/confirm the bundle ID in Apple Developer.
- Enable Sign in with Apple for that bundle ID.
- Enable/configure Apple provider in Supabase Auth.
- Create the app record in App Store Connect before TestFlight upload.

## Bundle ID

Current bundle ID:

```text
com.sawjai.GroupTripApp
```

Keep this stable once TestFlight builds begin. Changing it later creates a different app identity.

## Xcode Signing Setup

In Xcode:

1. Open `GroupTripApp.xcodeproj`.
2. Select target `GroupTripApp`.
3. Open `Signing & Capabilities`.
4. Check `Automatically manage signing`.
5. Select your Apple Developer Team.
6. Confirm Bundle Identifier is `com.sawjai.GroupTripApp`.
7. Confirm the `Sign in with Apple` capability is present.
8. If Xcode asks to repair provisioning/capabilities, allow it.

Do not commit personal provisioning profiles or private signing files.

## Apple Developer Portal

In Apple Developer > Certificates, Identifiers & Profiles:

1. Open or create the App ID for `com.sawjai.GroupTripApp`.
2. Enable `Sign in with Apple`.
3. Save the App ID.
4. If Xcode automatic signing does not repair profiles, regenerate the development and distribution provisioning profiles for this App ID.

## Supabase Apple Provider

In Supabase Dashboard > Authentication > Providers > Apple:

1. Enable Apple provider.
2. Use `com.sawjai.GroupTripApp` as the native app/client identifier where Supabase asks for the app/client ID.
3. If the dashboard requires Apple Team ID, Key ID, or private key for Apple provider setup, create those in Apple Developer and paste them only into Supabase Dashboard — never into this repo or chat.
4. Save the provider settings.

Native app sign-in does not use a custom app callback URL the way Google OAuth does. The app receives an Apple identity token from iOS and passes it to Supabase.

## Local Device Smoke Test

After Xcode signing is configured:

1. Connect your iPhone by cable or pair it wirelessly.
2. Select your iPhone as the run destination.
3. Build and run from Xcode.
4. Choose `Sign in / Create account`.
5. Tap `Continue with Apple`.
6. Complete Apple's sheet.
7. Confirm Wanderaid enters cloud mode and loads the trip dashboard.
8. Create a small test trip.
9. Force quit and reopen the app.
10. Confirm the session persists and the cloud trip reloads.

## TestFlight Upload Checklist

In App Store Connect:

1. Create a new app record for Wanderaid.
2. Platform: iOS.
3. Bundle ID: `com.sawjai.GroupTripApp`.
4. SKU: any stable internal value, e.g. `wanderaid-ios`.
5. Add required app metadata placeholders if prompted.

In Xcode:

1. Select `Any iOS Device` or a real device destination.
2. Product > Archive.
3. Open Organizer when archive finishes.
4. Validate App.
5. Distribute App > App Store Connect > Upload.
6. Wait for processing in App Store Connect.
7. Add yourself as an internal tester in TestFlight.
8. Install the build from the TestFlight app.

## CLI Archive Command

Once signing/team is configured, this should archive locally:

```sh
xcodebuild archive \
  -project "GroupTripApp.xcodeproj" \
  -scheme GroupTripApp \
  -destination "generic/platform=iOS" \
  -archivePath "build/archives/Wanderaid.xcarchive" \
  -allowProvisioningUpdates
```

If it fails with `No Accounts`, `No signing certificate`, or `No profiles`, finish the Xcode account/team steps above first.

## Verification Notes

The current local simulator is blocked by an Xcode/CoreSimulator version mismatch. Physical-device testing and generic iOS builds can still work because they use the iPhoneOS SDK, not the broken simulator service.
