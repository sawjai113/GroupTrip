# Wani / Group Trip App Supabase Security Baseline

Review date: 2026-06-11
Scope: Supabase schema/RLS, user-info/privacy implementation, client Supabase configuration, and current smoke-test coverage for Milestone 2 collaborative MVP.

## Executive summary

The current Supabase baseline is in a good MVP state: all app tables declared in `supabase/schema.sql` have RLS enabled, table policies are scoped to the `authenticated` role, anonymous table reads are not intentionally opened, service-role credentials were not found in tracked app code, and membership checks are centralized in security-definer helpers with an explicit `search_path`.

The main security issue is an authorization gap around mutable ownership/audit columns. In particular, `trip members can update trips` lets any trip member update the whole `trips` row, including `created_by`. Because trip deletion is allowed when `created_by = auth.uid()`, a non-owner member can likely update `created_by` to themselves and then delete the trip. This should be fixed before broader TestFlight use.

The next-largest risks are invite lookup/enumeration hardening, over-broad profile visibility, and incomplete negative smoke tests for ownership-only actions and spoof attempts.

## Current strengths

- RLS is enabled for every app table in the schema:
  - `profiles`
  - `trips`
  - `trip_members`
  - `trip_participants`
  - `trip_invites`
  - `trip_places`
  - `trip_planning_items`
  - `trip_expenses`
  - `trip_expense_splits`
  - `trip_direct_payments`
- Policies target `authenticated`; no table-level anon policies were found.
- `trip_members` recursion is avoided through `public.is_trip_member()` and `public.is_trip_owner()` security-definer helpers.
- Security-definer functions reviewed have `set search_path = public`:
  - `is_trip_member`
  - `is_trip_owner`
  - `handle_new_user`
  - `lookup_active_trip_invite`
- `lookup_active_trip_invite()` avoids granting anonymous `SELECT` on `trip_invites` and returns only a narrow result set.
- Expense integrity triggers enforce that expense payers, split participants, and direct-payment participants belong to the relevant trip.
- `.gitignore` excludes local `.env`, `.env.*`, `.supabase/`, and `supabase/.temp/` material.
- Tracked-file secret scan did not find a service-role key, database URL, JWT secret, access token, or password. The committed Supabase client value appears to be a publishable client key, which is expected for a mobile app when RLS is the enforcement boundary.
- The transactional live smoke test covers basic owner/member/stranger/anon RLS behavior and cross-trip expense participant rejection.

## Findings by severity

### Critical

None found in the reviewed files.

### High

#### H-1: Non-owner trip members can likely escalate to trip deletion by changing `trips.created_by`

Evidence:
- `trips` update policy:
  - `using (public.is_trip_member(id))`
  - `with check (public.is_trip_member(id))`
- `trips` delete policy:
  - `using (created_by = auth.uid() or public.is_trip_owner(id))`
- `created_by` is a normal writable column in `public.trips` and the update policy does not prevent changes to it.

Impact:
- A non-owner trip member may be able to update `created_by` to their own user id, then satisfy the delete policy and delete the trip.

Recommended fix:
- Prefer one or both of:
  1. Make trip updates owner-only for sensitive fields, or split mutable trip metadata into an RPC/function that does not accept `created_by`.
  2. Add a trigger that makes `trips.created_by` immutable after insert.
- Also consider changing trip delete policy to owner membership only, or keep `created_by` only if immutability is enforced.

Recommended smoke test:
- As an account member who is not owner:
  - attempt to update `trips.created_by` to self and expect rejection/no change;
  - attempt to delete the trip and expect rejection.

### Medium

#### M-1: Audit/attribution columns can be spoofed or changed after insert

Evidence:
- Some insert policies validate `created_by`/`added_by` when present, but update policies generally only check trip membership.
- `trip_participants` insert policy does not check `created_by = auth.uid()`.
- `trip_members` owner insert/update policies do not constrain `created_by`.
- Updates can likely change `created_by`, `added_by`, `linked_user_id`, and similar attribution columns on several tables.

Impact:
- Members can misattribute places, planning items, expenses, direct payments, participants, or membership changes.
- Future moderation/audit, notifications, and accountability features could become untrustworthy.

Recommended fix:
- Set attribution columns server-side where possible, or require `created_by = auth.uid()` / `added_by = auth.uid()` in insert policies.
- Add immutable-column triggers for `created_by`, `added_by`, and original ownership columns where they are intended as audit data.
- For updates, either reject attribution-column changes or expose narrowly scoped RPCs.

Recommended smoke tests:
- Member tries to insert participant with another user's `created_by`; expect rejection or server rewrite to auth user.
- Member tries to update place/planning/expense/direct-payment `added_by`/`created_by`; expect rejection/no change.

#### M-2: Owner membership management can create or modify powerful roles without guardrails

Evidence:
- `trip owners can add memberships` allows insert when `public.is_trip_owner(trip_id)` and does not restrict `role`.
- `trip owners can update memberships` allows full row updates when old and new trip satisfy `is_trip_owner(trip_id)`.
- `trip owners can delete memberships` allows deleting any membership for the trip.

Impact:
- This may be acceptable for an owner model, but the schema currently allows accidental demotion/deletion of the last owner and owner promotion without explicit product guardrails.
- If owner accounts are compromised, recovery is harder because membership state can be fully rewritten.

Recommended fix:
- Add database protections for minimum one owner per trip.
- Decide whether owner promotion should be allowed from the client; if yes, make it explicit in the product and smoke tests.
- Consider restricting membership update fields or implementing owner/member role changes through RPCs with validations.

Recommended smoke tests:
- Owner cannot delete/demote the last owner.
- Member cannot insert/update/delete memberships.
- Owner can add a guest/member only within intended role limits.

#### M-3: Invite lookup leaks trip name to anyone with a valid active code and depends on code entropy/rate limiting

Evidence:
- `lookup_active_trip_invite(invite_code text)` is security definer and returns `invite_id`, `trip_id`, `trip_name`, `role`, and `expires_at` for active, unexpired, not-maxed invites.
- This design intentionally supports low-friction join screens.

Impact:
- If invite codes are short, predictable, reused, or not rate-limited, attackers could enumerate valid codes and learn trip names and ids.
- Even with high-entropy codes, returning trip metadata before authentication/acceptance is a privacy tradeoff.

Recommended fix:
- Generate high-entropy, unguessable invite codes; avoid short sequential or human-word-only codes for production.
- Consider returning only minimal preview data before join, e.g. trip name only after user is authenticated or after code verification UX accepts the tradeoff.
- Add rate limiting at the edge/API layer if invite lookup becomes public at scale.
- Consider adding an RPC for accepting an invite that increments `use_count` atomically and creates membership in one transaction.

Recommended smoke tests:
- Expired invite lookup returns zero rows.
- Max-use invite lookup returns zero rows.
- Inactive invite lookup returns zero rows.
- Wrong/random code returns zero rows and does not expose table-level invite rows.

#### M-4: Profiles are globally readable by all authenticated users

Evidence:
- `profiles` select policy is `to authenticated using (true)`.

Impact:
- Any signed-in user can read every profile row, including display names and avatar URLs. That may be too broad once the app has non-test users.

Recommended fix:
- Restrict profile reads to users who share a trip, or to self plus trip co-members through a helper/RPC.
- If global search/discovery is a future feature, document the privacy expectation and expose only intended public profile fields.

Recommended smoke test:
- Authenticated stranger with no shared trips cannot list unrelated profiles, if privacy is tightened.

### Low

#### L-1: Client config is committed directly rather than environment/build-setting injected

Evidence:
- `SupabaseConfig.swift` contains the Supabase project URL and publishable client key.

Impact:
- This is not a service-role secret and is normal for client apps, but it makes environment separation and key rotation less clean.

Recommended fix:
- For TestFlight/production, consider moving the URL and publishable key into build settings, `.xcconfig`, or generated config files excluded from git, while keeping a checked-in example.
- Continue to rely on RLS as the primary enforcement boundary.

#### L-2: Auth product plan and implementation differ

Evidence:
- The milestone plan says the first auth method is Supabase email magic link / OTP.
- Current `AuthViewModel` and `AuthViews` implement email/password sign-in and sign-up.

Impact:
- Not directly a database security vulnerability, but it affects expected auth UX and password-policy/security assumptions.

Recommended fix:
- Update the plan or implementation so the selected auth method is explicit.
- If email/password remains, define minimum password policy, confirmation behavior, and account recovery expectations in the security lane.

#### L-3: Anonymous invite lookup function execute privileges should be made explicit

Evidence:
- The schema creates `lookup_active_trip_invite()` but does not explicitly `grant execute`/`revoke execute` for roles in this file.

Impact:
- Effective privileges depend on default function privileges/project settings. The live smoke test indicates anon could execute it once, but the intended permission should be explicit and reviewable.

Recommended fix:
- Add explicit grants/revokes for invite lookup and helper functions.
- Example policy intent: allow anon/authenticated execute on `lookup_active_trip_invite`; avoid public execute on internal membership helpers unless needed by PostgREST policies.

### Informational

#### I-1: `set_updated_at()` does not set `search_path`

Evidence:
- `set_updated_at()` is not security definer and only assigns `new.updated_at = now()`.

Impact:
- Low risk because it is not security definer and does not query objects, but setting `search_path` consistently on functions is a useful hardening convention.

Recommended fix:
- Optionally add `set search_path = public` to all functions for consistency.

#### I-2: Expense split policies have no update policy

Evidence:
- `trip_expense_splits` has select/insert/delete policies but no update policy.

Impact:
- This is likely intentional: clients replace splits by delete+insert. Document this to avoid confusion.

Recommended fix:
- Document delete+insert behavior or add an explicit update policy if partial split updates become a product requirement.

## Stored user-sensitive data and privacy notes

Data currently modeled or implied by reviewed files:

- Supabase Auth users:
  - email addresses and auth metadata live in `auth.users`.
  - `handle_new_user()` derives default display names from metadata or email local-part.
- `profiles`:
  - display names and avatar URLs.
- `trips`:
  - trip names, descriptions, destinations, emojis, image URLs, dates, creator ids.
- `trip_members`:
  - account user ids, guest member ids, display names, roles, member kind, creator ids.
- `trip_participants`:
  - display names, links to members/users, organizer flag, creator ids.
- `trip_invites`:
  - invite codes, role granted, expiration, active flag, max/use counts, creator ids.
- `trip_places`:
  - place names, notes, categories, Google place ids, latitude/longitude, added-by ids.
- `trip_planning_items`:
  - titles, notes, scheduled dates, completion state, added-by ids.
- `trip_expenses` / `trip_expense_splits` / `trip_direct_payments`:
  - payment/expense titles, payer/payee participant ids, split participants, amounts, currencies, dates, creator ids.

Data minimization/privacy recommendations:

- Treat trip destinations, dates, locations, expense amounts, and direct payments as sensitive personal/group information.
- Avoid storing precise latitude/longitude unless needed for a user-visible feature.
- Avoid deriving public display names from email local-parts without allowing users to change them quickly.
- Keep invite codes out of logs and analytics where possible.
- Add a future account deletion/export plan covering profiles, memberships, trips, places, planning items, and expense records.

## Recommended security fixes/tests

Immediate schema/code fixes recommended before broader external testing:

1. Fix `trips.created_by` mutability / non-owner delete escalation.
2. Add smoke tests for member attempts to change `trips.created_by` and delete trips.
3. Add immutable/validated attribution handling for `created_by` and `added_by` columns.

Concrete additional smoke tests for `supabase/live_smoke_test.sql`:

- Invite validity:
  - expired invite lookup returns zero rows;
  - max-use invite lookup returns zero rows;
  - inactive invite lookup returns zero rows;
  - random invite lookup returns zero rows.
- Owner-only actions:
  - member cannot delete trip;
  - member cannot insert/update/delete trip memberships;
  - owner cannot delete/demote the last owner, if that rule is adopted.
- Spoof attempts:
  - non-owner/member cannot update `trips.created_by`;
  - member cannot insert or update `created_by` / `added_by` as another user;
  - member cannot set `linked_user_id` to another auth user unless explicitly allowed.
- Membership constraints:
  - stranger cannot read any trip-scoped tables, not only `trips` and `trip_invites`;
  - anon cannot read any app table;
  - guest/account identity constraints reject malformed `trip_members` rows.
- Cross-trip integrity:
  - expense split participant from another trip is rejected;
  - direct payment participant from another trip is rejected.

## Suggested cadence for this security lane

- Every schema/RLS change:
  - Run the transactional live smoke test or a local Supabase equivalent before merge.
  - Add at least one negative RLS test for every new positive permission.
- Every invite/auth change:
  - Review code entropy, expiry/max-use behavior, and data returned before membership is created.
- Weekly during Milestone 2:
  - Review all new Supabase policies/functions/RPCs.
  - Run a tracked-file secret scan.
  - Re-check that no service-role keys or DB URLs are in client code or docs.
- Before TestFlight:
  - Complete a two-account/manual RLS smoke test.
  - Review Auth settings in Supabase dashboard: email confirmation, password policy if applicable, redirect URLs, and disabled sign-up policy if needed.
  - Confirm recovery process for accidental owner loss.
- Before public launch:
  - Add production SMTP, abuse/rate-limit strategy for invite lookup, privacy policy/data deletion workflow, and monitoring for failed RLS/write attempts.

## Verification performed

Commands/files reviewed locally; no credentials were requested and no live Supabase queries were run.

- Read and reviewed:
  - `supabase/schema.sql`
  - `supabase/live_smoke_test.sql`
  - `GroupTripApp/SupabaseTripService.swift`
  - `GroupTripApp/SupabaseConfig.swift`
  - `GroupTripApp/AuthViewModel.swift`
  - `GroupTripApp/AuthViews.swift`
  - `GroupTripApp/TripCollaborationModels.swift`
  - `GroupTripAppTests/TripCollaborationModelsTests.swift`
  - `docs/plans/milestone-2-collaborative-mvp.md`
  - `.gitignore`
- Ran `git status --short`:
  - no pre-existing working tree changes were reported before this document was created.
- Ran tracked-file secret scan with `git grep` for service-role keys, database URLs, JWT secrets, tokens, passwords, and Supabase key markers:
  - found only the project guidance warning about service-role keys and the client publishable Supabase key in `SupabaseConfig.swift`.
  - no service-role key, DB URL, JWT secret, token, or password was found in tracked files by this scan.
- Ran local schema summary script:
  - confirmed all 10 app tables declared in `schema.sql` have `alter table ... enable row level security`.
  - listed policies and confirmed all table policies target `authenticated`.
- Ran local function summary script:
  - confirmed security-definer functions reviewed have `set search_path = public`.
