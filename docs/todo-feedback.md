# Wanderaid TODO / Feedback Backlog

Last updated: 2026-07-08

This is the lightweight git-tracked backlog for feedback, rough TODOs, and manual testing notes before they are promoted into detailed implementation plans or GitHub issues.

Use this file for quick capture. When an item becomes ready to build, move it into `docs/plans/` or a GitHub issue with acceptance criteria.

Safety rule: any future action that deletes, removes, revokes, logs out, leaves, or otherwise destroys/access-removes something must include a confirmation step before it completes.

## Status Key

- `Now`: next practical work
- `Next`: soon, after current milestone path is stable
- `Later`: deferred until prerequisite/product fit is clearer
- `Blocked`: cannot proceed yet because of account, platform, or external dependency
- `Done`: completed and kept here temporarily for context

---

## Now

### 1. Join Trip entry point polish

Status: Done
Area: Dashboard, Invites, UX

Resolution:

- Signed-in empty dashboard now offers both creating a first trip and joining with an invite code.
- Join sheet clarifies this is a signed-in/account join and that cloud trips refresh after accepting.
- Invite preview, checking, joining, success, missing-code, and error states are explicit.
- Store clears stale invite errors/previews for blank codes and returns success/failure from invite accept.
- Successful invite accept reloads cloud trips before dismissing.

Deferred notes:

- Guest join without mandatory signup remains a later product/auth flow; current polish is for signed-in joins.

### 2. Confirmations for logout and destructive/removal actions

Status: Now
Area: Data safety, Auth, Dashboard, Trips, Membership, UX

Feedback:

- Add confirmation dialogs before logout and deletions.
- Treat this as the default rule for all future destructive/removal flows: deleting, removing, revoking, leaving, archiving, or signing/logging out should require confirmation before completing.

Acceptance notes:

- Logout asks for confirmation before ending the current session.
- Delete/remove actions clearly name what will be removed and whether the action affects only the current user or everyone on the trip.
- Canceling the confirmation leaves state unchanged.
- Confirmation copy distinguishes local/demo-only changes from cloud/shared changes.
- VoiceOver labels and destructive button roles are clear.

### 3. Loading and empty states review

Status: Done
Area: UX, QA

Review signed-in/cloud screens for:

- Empty dashboard with no trips.
- Loading cloud trips.
- Failed cloud load.
- Failed trip create.
- Failed invite lookup/accept.
- Offline or network timeout behavior.

Feedback notes:

- 2026-07-22 Milestone 2 testing reported complete. No loading/empty/error-state blocker identified for Milestone 2 closeout; keep any future copy/polish issues as tester feedback.

### 4. Milestone 2 trip management and editing expansion

Status: Done
Area: Dashboard, Trips, Membership, Cloud sync, UX, Data safety

Decision:

- Add leave trip, archive/delete trip, and edit existing trip items to Milestone 2 scope before TestFlight readiness.
- Treat these as core collaborative MVP safety and correction flows, not post-milestone polish.

Acceptance notes:

- Leaving a trip removes the current user's access but does not delete the trip for everyone.
- Owner/last-owner behavior must be explicit before implementation.
- Cloud trip delete should prefer archive/soft-delete semantics unless a permanent owner-only delete rule is intentionally defined.
- Existing places, planning items, expenses, payments, and safe person details can be edited after creation.
- Failed cloud edits must not appear locally as successfully saved.
- All leave/delete/archive flows require confirmation copy that says who is affected.

Resolution:

- 2026-07-22 Milestone 2 manual testing reported complete and passed, including collaborative item editing and trip management/safety flows.
- Remaining UX consistency notes are tracked below as Later items rather than Milestone 2 blockers.

---

## Regression Checklists

### Signed-in collaboration smoke test

Status: Regression checklist
Area: Auth, Supabase, Invites, Cloud trips

Goal: Re-run before TestFlight or after invite/auth/sync changes to prove the core collaborative promise with two signed-in Google accounts or two sessions/devices.

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

- Core two-user collaboration smoke passed on 2026-06-29. Keep as a regression checklist.

### Signed-in auth smoke checklist

Status: Regression checklist
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
- Google login should force an account chooser / ephemeral browser session so QA can switch between two test accounts.

---

## Next

### 5. Collaborative editing smoke: add a place or planning item

Status: Done
Area: Supabase sync, Places, Planning

Goal: After invite join works reliably, prove one meaningful collaborative action from a second account/session.

Candidate first action:

- User B adds a saved place or planning item.
- User A refreshes/reopens and sees it.
- Data remains after app restart.

Feedback notes:

- 2026-07-08 manual smoke passed: two-session collaborative place/planning flow works well enough for now.
- Hold off on UI changes while visual direction is still undecided; current flow is acceptable as a functional baseline.
- Continue capturing future TODO items as rough backlog notes when UI/flow issues appear during testing.

### 6. Collaborative expense smoke

Status: Done
Area: Expenses, Supabase sync, Calculation correctness

Goal: Prove expenses can be added/loaded from synced data without breaking balances.

Checklist:

- Add expense from signed-in cloud trip.
- Select payer and participants.
- Reload cloud trip.
- Balances and settlements remain correct.
- Two-session smoke confirms the other account can see the expense after refresh/relaunch.

Feedback notes:

- 2026-07-22 Milestone 2 manual testing reported complete and passed, including collaborative expenses, direct payments, edits, balances/settlements, and refresh/relaunch persistence.

### 7. README/status cleanup after Google auth

Status: Done
Area: Documentation

Resolution:

- README now says Wanderaid.
- Google OAuth is documented as the current primary sign-in path.
- Apple login remains deferred pending Apple Developer Program enrollment.
- Magic link can remain available as backup/dev path if desired.

Feedback notes:

- Completed in workflow/process documentation checkpoint.

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

Status: Now
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

Status: Now
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

### 14. One-tap common place categories with custom option

Status: Later
Area: Places, Create Place, UX

Feedback:

- When creating a new place, show common category/tag chips so users can select a category in one tap instead of typing it every time.
- Include a custom field for custom tags/categories.

Acceptance notes:

- Common category suggestions are visible in the add-place flow.
- Tapping a suggestion fills/selects the category immediately.
- Users can still type a custom category/tag when none of the suggestions fit.
- Custom values should be saved with the place the same way typed categories work today.
- Suggested category list should be easy to adjust as we learn common trip use cases.

### 14a. Saved place edit affordance consistency

Status: Later
Area: Places, Editing, UX

Feedback:

- Saved places can currently be edited by tapping the place row, but this differs from other editable items that expose a pencil icon.
- During smoke testing, this made the edit affordance less obvious even though the function works.

Acceptance notes:

- Decide whether saved places should keep tap-to-edit, add a visible pencil/edit icon, or align with a broader editing pattern once the UI direction is clearer.
- If tap-to-edit remains, add enough visual/copy affordance that users understand the row is editable.
- Preserve existing cloud-backed edit behavior; this is primarily a UX consistency item.

### 15. Wanderaid password login setup after OAuth signup

Status: Later
Area: Auth, Account setup, UX

Feedback:

- After a user signs up or signs in with Google, and eventually Apple, ask whether they want to create a Wanderaid username/email and password login too.
- This gives users a normal Wanderaid email/username + password fallback in addition to OAuth.

Acceptance notes:

- OAuth login remains the fastest path and should not be blocked by password setup.
- The app should clearly explain that adding a Wanderaid password lets the same account be accessed without Google/Apple later.
- Avoid creating duplicate accounts when the same email is already attached to an OAuth identity.
- Account linking behavior should be tested before launch, especially Google/Apple plus password for the same email.
- Password setup should follow Supabase auth best practices and avoid exposing credentials in logs, files, or chat.

### 16. Sign in with Apple

Status: Done
Area: Auth

Resolution:

Notes:

- Sign in with Apple is implemented as a parallel auth provider alongside Google.
- `GroupTripApp.entitlements` includes the Apple Sign In capability and linted successfully on 2026-07-22.
- App Store/TestFlight submission should still verify Apple Developer team signing and the App Store Connect capability state during archive/upload.

### 17. Planning/itinerary date ranges

Status: Later
Area: Planning, Itinerary, Dates, UX

Feedback:

- Itinerary/planning items should support date ranges, not only single dates.
- This should allow items like hotel stays, multi-day activities, and “who is in what area at what time.”

Acceptance notes:

- A planning item can represent either a single date or a start/end date range.
- Date range display is clear in list/card views.
- The add/edit planning item flow supports selecting a range without making single-date items cumbersome.
- Cloud persistence and reload preserve both single-date and range-based items.
- Future participant/location association should be considered so the app can answer who is staying/located where during overlapping date ranges.

### 18. Edit existing trip items

Status: Now
Area: Expenses, Planning, Places, People, Cloud sync, UX

Feedback:

- Make existing expenses editable.
- More broadly, support editing existing items instead of only creating/deleting them.

Acceptance notes:

- Existing expenses can be edited after creation, including title, amount, payer, and split participants.
- Existing planning items can be edited after creation, including title, note, date, and completion state.
- Existing places can be edited after creation, including name, category, and notes.
- Existing people/participants can be renamed where safe, without breaking existing expense references.
- Cloud-backed edits persist to Supabase and are readable by another signed-in trip member after refresh/relaunch.
- Demo/local mode keeps equivalent local edit behavior.
- Failed cloud edits should not leave the UI showing unsaved changes as if they succeeded.
- Editing shared items should make it clear that changes affect everyone on the trip.

### 19. Move record payment into suggested settlements

Status: Later
Area: Expenses, Settlements, Payments, UX

Feedback:

- Remove the standalone “Record Payment” button.
- Move payment-recording functionality into the Suggested Settlements area.
- Each suggested settlement should open a pre-populated payment form for that payer/payee/amount.

Acceptance notes:

- Suggested settlement rows expose a clear action to record that exact payment.
- Tapping a suggested settlement opens the existing payment form pre-filled with payer, recipient, and amount.
- The user can still edit the pre-filled values before saving.
- Saving creates the same direct payment record as the current Record Payment flow.
- Canceling leaves state unchanged.
- The old standalone Record Payment button is removed once the suggested-settlement flow covers the same capability.
- The interaction should be accessible via VoiceOver and should make clear that recording a payment affects trip balances for everyone.

### 20. Realtime collaboration

Status: Later
Area: Supabase realtime, Sync

Current direction:

- Keep refresh/relaunch-based sync first.
- Add realtime only after table model, RLS, and basic collaboration behavior are stable.

### 21. Google Maps deep integration

Status: Later
Area: Places, Integrations

Current direction:

- Manual place entry is enough for now.
- Later: Google Places search, map previews, external Maps handoff, saved place metadata.

### 22. Google Calendar integration

Status: Later
Area: Dates, Integrations

Current direction:

- Keep basic trip dates and planning dates first.
- Later: calendar export/sync once trip-planning behavior is proven.

### 23. Push notifications/reminders

Status: Later
Area: Platform, Notifications

Current direction:

- Defer until collaboration and planning flows are stable.

### 24. Move invite code flow into People page

Status: Later
Area: People, Invites, Navigation, UX

Feedback:

- Move the “Invite People” / create invite code functionality out of the top-level trip summary page and into the People page.
- The trip page should stay focused on trip overview and section navigation; people/member management should own inviting collaborators.

Acceptance notes:

- Cloud-backed trips expose invite-code creation from the People page.
- Existing invite-code behavior is preserved: create code, copy code, show creation/loading/error feedback.
- Top-level trip summary no longer shows the invite card once the People page owns the flow.
- The People page makes the distinction clear between expense participants and app collaborators/members if both concepts appear there.
- Demo/local mode does not show cloud invite controls.

---

## Done / Recently Resolved

### Invite sharing affordance polish

Status: Done
Area: Trip detail, Invites, UX

Resolution:

- Invite codes now show a dedicated Copy button in the trip summary invite card.
- Tapping Copy writes the invite code to the iOS pasteboard.
- The button temporarily changes to Copied with a checkmark for visible feedback.
- The copy action has an accessibility label.

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
