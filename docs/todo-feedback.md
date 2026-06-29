# Wani TODO / Feedback Backlog

Last updated: 2026-06-26

This is the lightweight git-tracked backlog for feedback, rough TODOs, and manual testing notes before they are promoted into detailed implementation plans or GitHub issues.

Use this file for quick capture. When an item becomes ready to build, move it into `docs/plans/` or a GitHub issue with acceptance criteria.

## Status Key

- `Now`: next practical work
- `Next`: soon, after current milestone path is stable
- `Later`: deferred until prerequisite/product fit is clearer
- `Blocked`: cannot proceed yet because of account, platform, or external dependency
- `Done`: completed and kept here temporarily for context

---

## Now

### 1. Signed-in collaboration smoke test

Status: Now
Area: Auth, Supabase, Invites, Cloud trips

Goal: Prove the core collaborative promise with two signed-in Google accounts or two sessions/devices.

Checklist:

- User A signs in with Google.
- User A creates or opens a cloud-backed trip.
- User A creates/copies an invite code.
- User B signs in with Google.
- User B enters the invite code.
- User B sees the joined trip in the signed-in dashboard.
- Both users can relaunch the app and still see the cloud trip.
- Note any confusing copy, loading state, failure message, or missing affordance.

Feedback notes:

- TBD

### 2. Join Trip entry point polish

Status: Now
Area: Dashboard, Invites, UX

Current direction:

- Make the signed-in dashboard clearly support joining a trip by invite code.
- Include loading, success, and error states.
- Reload cloud trips after a successful join.
- Keep Demo Mode separate from Signed-in Mode.

Feedback notes:

- TBD

### 3. Invite sharing affordance polish

Status: Now
Area: Trip detail, Invites, UX

Current direction:

- Make it easy for an organizer/member to find or generate an invite code from the trip context.
- Consider a simple copy/share action before any fancy native share sheet work.
- Ensure invite state is understandable: created, copied, expired/invalid, accepted.

Feedback notes:

- Add a dedicated copy button for the invite code so users do not have to manually select/copy the text.

### 4. Signed-in auth smoke checklist

Status: Now
Area: Auth, QA

Checklist:

- Fresh install opens mode picker.
- Demo Mode still works without sign-in.
- Signed-in mode opens login.
- Google login completes and returns to the app, not Safari/localhost.
- Signed-in dashboard appears.
- Relaunch preserves the session.
- Sign out returns to login/mode flow.
- Auth errors are understandable enough for early testers.

Feedback notes:

- Google login works after adding the app callback URL to Supabase redirect settings.

---

## Next

### 5. Collaborative editing smoke: add a place or planning item

Status: Next
Area: Supabase sync, Places, Planning

Goal: After invite join works reliably, prove one meaningful collaborative action from a second account/session.

Candidate first action:

- User B adds a saved place or planning item.
- User A refreshes/reopens and sees it.
- Data remains after app restart.

Feedback notes:

- TBD

### 6. Collaborative expense smoke

Status: Next
Area: Expenses, Supabase sync, Calculation correctness

Goal: Prove expenses can be added/loaded from synced data without breaking balances.

Checklist:

- Add expense from signed-in cloud trip.
- Select payer and participants.
- Reload cloud trip.
- Balances and settlements remain correct.
- Two-session smoke confirms the other account can see the expense after refresh/relaunch.

Feedback notes:

- TBD

### 7. Loading and empty states review

Status: Next
Area: UX, QA

Review signed-in/cloud screens for:

- Empty dashboard with no trips.
- Loading cloud trips.
- Failed cloud load.
- Failed trip create.
- Failed invite lookup/accept.
- Offline or network timeout behavior.

Feedback notes:

- TBD

### 8. README/status cleanup after Google auth

Status: Next
Area: Documentation

Update top-level docs so they reflect the current state:

- App is now Wanderaid in the UI, though README still says Wani.
- Google OAuth works as the current primary sign-in path.
- Apple login is deferred pending Apple Developer Program enrollment.
- Magic link can remain available as backup/dev path if desired.

Feedback notes:

- TBD

---

## Later

### 9. Dashboard overflow menu for primary actions

Status: Later
Area: Dashboard, Navigation, UX

Feedback:

- Move the `New Trip`, `Join Trip`, and `Logout` buttons into a dropdown/overflow menu in the upper right.
- Goal is to free horizontal space so the app name in the top left does not wrap onto two lines.
- Preserve quick discoverability for the main trip actions despite moving them out of the main button row.

Acceptance notes:

- App title stays on one line on common iPhone widths.
- Upper-right menu clearly exposes New Trip, Join Trip, and Logout.
- Logout remains visually/destructively distinguished enough to avoid accidental taps.
- VoiceOver labels and tap targets are preserved.

### 10. Past trip swipe-to-delete with confirmation

Status: Later
Area: Dashboard, Trips, Data safety

Feedback:

- Add swipe-to-delete for past trips.
- Require a confirmation step before the trip is actually deleted.

Acceptance notes:

- Swipe action is available only where deletion is appropriate, starting with past trips.
- Confirmation copy clearly names the trip being deleted.
- Deletion does not happen if the user cancels.
- Cloud-backed deletion must respect Supabase permissions and should not orphan related data.
- Consider soft-delete/archive semantics before permanent deletion for shared trips.

### 11. Leave current/future trip

Status: Later
Area: Dashboard, Trips, Membership, Supabase

Feedback:

- Add the ability for a user to leave a current or future trip.

Acceptance notes:

- Leaving a trip removes the user’s membership/access but should not delete the trip for everyone.
- Clarify organizer/owner behavior: the last owner should not be able to leave without transferring ownership or deleting/archiving the trip.
- Historical participant/expense identity should remain intact after a member leaves.
- Show a confirmation before leaving.
- Reload the dashboard after leaving so the trip disappears from the user’s active list.

### 12. More intuitive trip date range picker

Status: Later
Area: Create Trip, Dates, UX

Feedback:

- In the create new trip page, the start and end date picker should be linked.
- Tapping a second date should automatically use that as the end date.
- Clicking multiple dates should adjust the start date and end date intuitively.

Acceptance notes:

- First date tap selects the start date.
- Second date tap selects the end date when it is after the start date.
- Tapping an earlier date adjusts the start date rather than creating an invalid range.
- Tapping a date inside or outside an existing range has predictable behavior that feels like common travel/hotel date pickers.
- The selected range is visually clear.
- Behavior should be covered by tests at the date-range selection logic level before SwiftUI polish.

### 13. Cover image upload from device photos

Status: Later
Area: Create/Edit Trip, Media, Supabase Storage, UX

Feedback:

- Allow the user to upload pictures for the trip cover image from their device.

Acceptance notes:

- User can pick an image from their photo library.
- App requests the minimum needed photo permissions.
- Image is resized/compressed before upload to avoid huge storage costs.
- Cloud trips store a durable cover image URL/path.
- Demo/local trips can either use local-only images or keep sample/static images until cloud behavior is proven.
- Add loading/error states for upload failures.
- Avoid committing any user images or generated media fixtures to the repo.

### 14. Sign in with Apple

Status: Blocked
Area: Auth

Blocked by: Apple Developer Program enrollment still pending.

Notes:

- Hold off until enrollment is approved.
- Add as a parallel auth provider after Google + invite flow is stable.
- Should not block Milestone 2 collaboration learning.

### 15. Realtime collaboration

Status: Later
Area: Supabase realtime, Sync

Current direction:

- Keep refresh/relaunch-based sync first.
- Add realtime only after table model, RLS, and basic collaboration behavior are stable.

### 16. Google Maps deep integration

Status: Later
Area: Places, Integrations

Current direction:

- Manual place entry is enough for now.
- Later: Google Places search, map previews, external Maps handoff, saved place metadata.

### 17. Google Calendar integration

Status: Later
Area: Dates, Integrations

Current direction:

- Keep basic trip dates and planning dates first.
- Later: calendar export/sync once trip-planning behavior is proven.

### 18. Push notifications/reminders

Status: Later
Area: Platform, Notifications

Current direction:

- Defer until collaboration and planning flows are stable.

---

## Done / Recently Resolved

### Google OAuth callback redirect

Status: Done
Area: Auth

Resolution:

- App now passes a valid Google OAuth callback redirect to Supabase Swift.
- Xcode URL scheme uses the reversed Google callback scheme.
- Supabase dashboard redirect settings were updated so auth no longer falls back to localhost.
- Commit: `021d87e fix: configure Google OAuth callback redirect`

Follow-up:

- Keep this in the backlog temporarily as context for auth troubleshooting.
- Remove from this file once Google auth has been stable through the next milestone.
