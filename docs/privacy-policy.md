# Wanderaid Privacy Policy (draft)

Status: Draft for TestFlight / App Store Connect submission
Last updated: 2026-08-20

> Placeholder items marked **[TBD]** must be filled in before submission.

## 1. What we collect

Wanderaid collects the minimum needed to run group trip planning:

| Data | Purpose | Linked to you? |
|---|---|---|
| Display name (profile/participant name) | Identify you and your participants to trip collaborators | Yes |
| Account identifier (UUID) | Associate trips, memberships, and expenses with your account | Yes |
| Email address | Sign-in (via Google or Apple authentication) and account recovery | Yes |
| Trip content you create (trip names, places, planning items, expenses, notes) | The core product feature — shared with your trip collaborators | Yes |

We do **not** collect precise location, contacts, photos, or advertising identifiers, and we do **not** track you across apps or websites.

## 2. How data is used

- To provide the service: trips, invitations, shared planning, and expense settlement between collaborators you choose.
- To keep your account working: authentication and session management.

We do not sell data and do not use it for advertising or profiling.

## 3. Where data is stored

- Trip and profile data is stored in a hosted **Supabase** PostgreSQL database (US region **[TBD — confirm region]**) with row-level security so collaborators only see trips they belong to.
- Your authentication session is stored in your device's **Keychain** (iOS). A read-only cache of your trip data lives in the app's local storage on your device.
- Emails are processed by our authentication provider (Supabase / Google / Apple) and are not stored in app tables or read by the app after sign-in.

## 4. Sharing

- Your display name and trip content are visible only to members of the trips you join.
- We do not share personal data with third parties, except the hosting/authentication providers listed above, which process data on our behalf.

## 5. Your controls

- You can leave or archive trips, edit or remove your display name, and delete your account data by contacting **[TBD — contact email]**.
- Sign out is available in the app (Account → Log Out).
- Requesting deletion of your account and associated data: **[TBD — process]**. Trip content you created remains visible to other members where applicable.

## 6. Children's privacy

The app is not directed at children under 13 and does not knowingly collect their data.

## 7. Changes

We'll update this policy here as the product evolves; material changes will be noted in app release notes.

## 8. Contact

Questions about this policy: **[TBD — contact email / support URL]**
