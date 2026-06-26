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

- TBD

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

### 9. Sign in with Apple

Status: Blocked
Area: Auth

Blocked by: Apple Developer Program enrollment still pending.

Notes:

- Hold off until enrollment is approved.
- Add as a parallel auth provider after Google + invite flow is stable.
- Should not block Milestone 2 collaboration learning.

### 10. Realtime collaboration

Status: Later
Area: Supabase realtime, Sync

Current direction:

- Keep refresh/relaunch-based sync first.
- Add realtime only after table model, RLS, and basic collaboration behavior are stable.

### 11. Google Maps deep integration

Status: Later
Area: Places, Integrations

Current direction:

- Manual place entry is enough for now.
- Later: Google Places search, map previews, external Maps handoff, saved place metadata.

### 12. Google Calendar integration

Status: Later
Area: Dates, Integrations

Current direction:

- Keep basic trip dates and planning dates first.
- Later: calendar export/sync once trip-planning behavior is proven.

### 13. Push notifications/reminders

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
