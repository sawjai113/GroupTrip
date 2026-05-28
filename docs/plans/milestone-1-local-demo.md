# Milestone 1 Local Demo Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Build a one-device local demo that clearly communicates Group Trip as a shared trip hub for a realistic 6-person international trip.

**Architecture:** Extend the current SwiftUI app and local sample data before production collaboration. Add lightweight local models for places and planning items to `TripPlan`, render them on the dashboard/detail surfaces, and add simple CRUD views. Keep Supabase/auth/invite work out of this milestone except where existing code paths already exist.

**Tech Stack:** SwiftUI, ObservableObject state in `TripStore` and `TripCalculatorViewModel`, current Xcode project, existing expense calculator/test structure.

---

## Current Code Context

Existing relevant files:

- `GroupTripApp/TripModels.swift`
  - Defines `TripPlan` with destination, emoji, imageURL, startDate, endDate, and `TripCalculatorViewModel`.
- `GroupTripApp/TripStore.swift`
  - Holds `[TripPlan]`, creates local/remote trips, and includes `TripStore.sample`.
- `GroupTripApp/TripDashboardView.swift`
  - Shows trip carousel and creates trips.
- `GroupTripApp/TripSummaryView.swift`
  - Shows trip hero, expenses link, people link, and placeholder cards for chat/places/itinerary/map.
- `GroupTripApp/TripForms.swift`
  - Contains forms for new trip, people, expense, and payment.
- `GroupTripApp/ExpenseViews.swift`
  - Current expense tracker UI.
- `GroupTripApp/PeopleViews.swift`
  - Current people UI.
- `GroupTripAppTests/TripExpenseCalculatorTests.swift`
  - Existing calculator tests.

Validation command:

```sh
xcodebuild -project "/Users/sawjai/Documents/Group Trip App/GroupTripApp.xcodeproj" -scheme GroupTripApp -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```

---

# Task 1: Add local demo planning models

**Objective:** Add first-class local models for saved places and planning/itinerary items.

**Files:**

- Modify: `GroupTripApp/TripModels.swift`

**Implementation:**

Add two lightweight structs near `TripPlan`:

```swift
struct TripPlace: Identifiable, Hashable {
    let id: UUID
    var name: String
    var note: String
    var category: String

    init(id: UUID = UUID(), name: String, note: String = "", category: String = "") {
        self.id = id
        self.name = name
        self.note = note
        self.category = category
    }
}

struct TripPlanningItem: Identifiable, Hashable {
    let id: UUID
    var title: String
    var note: String
    var date: Date?
    var isDone: Bool

    init(id: UUID = UUID(), title: String, note: String = "", date: Date? = nil, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.note = note
        self.date = date
        self.isDone = isDone
    }
}
```

Extend `TripPlan` with:

```swift
var places: [TripPlace]
var planningItems: [TripPlanningItem]
```

Update `TripPlan.init(...)` with default values:

```swift
places: [TripPlace] = [],
planningItems: [TripPlanningItem] = []
```

Assign them in the initializer.

**Verification:**

Run build.

Expected: compile errors may point to initializer call sites that need the new optional arguments only if defaults were not applied correctly. Fix defaults until existing call sites compile.

---

# Task 2: Add a realistic 6-person international sample trip

**Objective:** Replace or enhance sample data so the local demo has a realistic international trip with participants, places, planning items, expenses, and payments.

**Files:**

- Modify: `GroupTripApp/TripStore.swift`
- Possibly inspect/modify: `GroupTripApp/TripCalculatorViewModel.swift`

**Implementation approach:**

Update `TripStore.sample` so the featured future/current demo trip is an international trip for around 6 people.

Suggested sample:

- Trip name: `Japan Spring 2027`
- Destination: `Tokyo & Kyoto, Japan`
- Emoji: `🌸`
- People: `Sawjai`, `Alex`, `Sam`, `Taylor`, `Jordan`, `Morgan`
- Places:
  - `Shibuya Sky` — city view / sunset idea
  - `Tsukiji Outer Market` — breakfast and street food
  - `teamLab Planets` — reserve tickets
  - `Fushimi Inari` — Kyoto morning visit
  - `Arashiyama Bamboo Grove` — Kyoto half-day
- Planning items:
  - Book pocket Wi‑Fi or eSIM
  - Reserve teamLab tickets
  - Pick Kyoto day trip date
  - Confirm shared hotel payment
  - Collect passport names for reservations
- Expenses/direct payments:
  - Shared hotel deposit
  - JR passes or train booking placeholder
  - Group dinner
  - Museum/ticket purchase
  - Direct payment example between two people

Use existing `TripCalculatorViewModel` methods where possible. If the sample helper APIs do not support this cleanly, add a small private/static sample factory in `TripStore.swift`.

**Important:** Do not remove the expense calculator tests. Keep existing sample expense math realistic but not fragile.

**Verification:**

Run build.

Open simulator if desired and confirm the dashboard shows a realistic international trip, not only an expense calculator example.

---

# Task 3: Apply Wani working name while holding broader copy changes

**Objective:** Use Wani as the working app name without over-polishing visible marketing copy before the logo/branding direction is ready.

**Files:**

- Modify: `GroupTripApp/TripDashboardView.swift`
- Search for visible strings that still say only expense tracking.

**Implementation:**

Use `Wani` where the app name is visibly shown. Hold off on broad tagline/marketing copy changes until the logo and branding direction are clearer.

Minimum copy changes for Milestone 1:

- Replace obvious old app-name labels such as `TravelSplit` with `Wani`.
- Do not force a final tagline yet.
- Only update expense-only copy when it actively misrepresents the demo; otherwise keep copy changes minimal.
- If a visible string says the app only tracks/splits expenses, soften it toward the trip-hub concept without making final brand claims.

**Verification:**

Build and visually inspect main dashboard text. Confirm the working name is `Wani` and no broad final-brand copy was introduced prematurely.

---

# Task 4: Add trip overview stats for places and planning

**Objective:** Make trip cards show that each trip has more than expenses.

**Files:**

- Modify: `GroupTripApp/TripDashboardView.swift`

**Implementation:**

In `FeaturedTripCard`, current stats show:

```swift
FeaturedStat(systemImage: "calendar", value: ...)
FeaturedStat(systemImage: "person.2.fill", value: ...)
FeaturedStat(systemImage: "dollarsign", value: ...)
```

Update this area to show a trip-hub mix. Options:

- Keep 3 stats but make them: dates, people, places.
- Or use 4 compact stats if layout still works: dates, people, places, expenses.

Recommended for first pass:

- Calendar date
- People count
- Place count
- Expense total if 4 stats fits cleanly

If 4 stats feels cramped, keep 3 and move expense total into subtitle or summary card.

**Verification:**

Build and verify the card remains readable on iPhone-sized layout.

---

# Task 5: Turn Places placeholder into a working Places screen

**Objective:** Let the local demo view, add, and delete saved places.

**Files:**

- Create: `GroupTripApp/TripPlacesView.swift`
- Modify: `GroupTripApp/TripSummaryView.swift`
- Modify Xcode project if new Swift files are not automatically included.

**Implementation:**

Create `TripPlacesView`:

```swift
struct TripPlacesView: View {
    @Binding var places: [TripPlace]
    @State private var isAddingPlace = false

    var body: some View { ... }
}
```

Minimum UI:

- Header with back button or normal navigation title.
- List/card stack of places.
- Empty state: `No places saved yet`.
- Add button.
- Delete support.

Create `AddTripPlaceView`:

Fields:

- Name, required.
- Category, optional.
- Note, optional.

Save appends `TripPlace` to binding.

Wire `TripSummaryView`:

Replace the placeholder `Places & Interests` card with a `NavigationLink` to `TripPlacesView(places: binding)`.

Because `TripSummaryView` currently receives `let trip: TripPlan`, you may need to make `TripPlan` reference-like enough for mutation, or route edits through `TripStore`. For Milestone 1, acceptable approaches:

1. Convert `TripPlan` to a class if that is low-risk.
2. Pass bindings from a store-owned detail route instead of value copy.
3. Keep places read-only for sample and add CRUD in a local `@State` copy, if full persistence would become too large.

Preferred architecture: modify navigation so detail screens can mutate the store-owned trip. If that is too much for one task, implement read-only places first and create a follow-up task for persistence.

**Verification:**

- Build succeeds.
- Places screen opens from trip summary.
- Sample places appear.
- Add/delete works for the current app session.

---

# Task 6: Turn Itinerary placeholder into a working Planning screen

**Objective:** Let the local demo view, add, complete, and delete simple planning items.

**Files:**

- Create: `GroupTripApp/TripPlanningView.swift`
- Modify: `GroupTripApp/TripSummaryView.swift`
- Modify Xcode project if new Swift files are not automatically included.

**Implementation:**

Create `TripPlanningView`:

```swift
struct TripPlanningView: View {
    @Binding var planningItems: [TripPlanningItem]
    @State private var isAddingItem = false

    var body: some View { ... }
}
```

Minimum UI:

- List/card stack of planning items.
- Empty state.
- Add button.
- Toggle/checkmark for `isDone`.
- Delete support.

Create `AddTripPlanningItemView`:

Fields:

- Title, required.
- Note, optional.
- Optional date toggle/date picker if easy. If date support makes the form too complex, skip date editing for demo and keep `date` in sample data only.

Wire `TripSummaryView`:

Replace the placeholder `Itinerary` card with a `NavigationLink` to the planning screen.

Use the same mutation/persistence approach chosen in Task 5.

**Verification:**

- Build succeeds.
- Planning screen opens from trip summary.
- Sample planning items appear.
- Add/delete/toggle works for current app session.

---

# Task 7: Add overview sections to Trip Summary

**Objective:** Make the trip summary feel like a hub before the user taps into subfeatures.

**Files:**

- Modify: `GroupTripApp/TripSummaryView.swift`

**Implementation:**

Below trip title/date/participants and above action cards, add compact preview sections:

- `Upcoming Plan` or `Planning` preview: first 2 planning items.
- `Saved Places` preview: first 2–3 places.
- `Expense Snapshot`: total expenses and suggested settlement count/summary if available.

Keep it lightweight. Do not build a complex dashboard inside the summary.

Suggested structure:

```swift
VStack(spacing: 12) {
    TripOverviewCard(...)
    PlacesPreviewCard(...)
    PlanningPreviewCard(...)
}
```

Reuse existing `ActionCard`, `EmptyFeatureCard`, `AppTheme.paper`, and typography patterns where possible.

**Verification:**

- Trip summary communicates dates, people, places, plans, and expenses without opening every screen.
- Layout remains readable.

---

# Task 8: Add simple date editing or confirm date display is enough for demo

**Objective:** Ensure trip dates are present and demo-ready.

**Files:**

- Modify: `GroupTripApp/TripSummaryView.swift` or `GroupTripApp/TripForms.swift`
- Optional create: `GroupTripApp/TripDetailsView.swift`

**Decision point:**

For Milestone 1, date display may be enough if creating a trip already supports start/end dates. If editing existing sample trip dates is important for demo, add a small edit trip details form.

Recommended minimal path:

- Keep existing New Trip date fields.
- Show trip dates prominently on summary and dashboard.
- Defer editing existing trip dates unless it blocks the demo.

**Verification:**

Trip dates are visible on dashboard and summary.

---

# Task 9: Tighten people and expense flows for the demo

**Objective:** Ensure the existing expense feature remains the strongest working feature.

**Files:**

- Inspect/modify: `GroupTripApp/PeopleViews.swift`
- Inspect/modify: `GroupTripApp/ExpenseViews.swift`
- Inspect/modify: `GroupTripApp/TripForms.swift`
- Test: `GroupTripAppTests/TripExpenseCalculatorTests.swift`

**Implementation checklist:**

- Empty states are understandable.
- Add People path is easy to find from summary and expense screen.
- Add Expense button is disabled or explained when no participants exist.
- Direct payment flow is still accessible.
- Balances/settlements are clear.
- Delete expense still works.

**Verification:**

Run existing tests if simulator is available:

```sh
xcodebuild test -project "/Users/sawjai/Documents/Group Trip App/GroupTripApp.xcodeproj" -scheme GroupTripApp -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /private/tmp/GroupTripAppDerivedData
```

If simulator is not available, run build and note that full tests require an installed simulator.

---

# Task 10: Add local demo smoke-test checklist

**Objective:** Document how to manually verify Milestone 1.

**Files:**

- Create: `docs/checklists/milestone-1-local-demo-smoke-test.md`

**Content:**

Include steps:

1. Launch app.
2. Confirm sample international trip appears.
3. Open trip summary.
4. Confirm dates, participants, places, planning, and expenses are visible.
5. Add a place.
6. Add a planning item.
7. Add a participant.
8. Add an expense involving multiple people.
9. Add a direct payment.
10. Confirm balances/settlements update.
11. Delete an expense/place/planning item.
12. Restart app and confirm demo data returns to the intended baseline sample trip.

**Verification:**

Checklist exists and matches actual UI labels.

---

# Task 11: Build and fix compile errors

**Objective:** Ensure Milestone 1 work compiles.

**Files:**

- Any files touched above.
- Xcode project file if new Swift files need inclusion.

**Command:**

```sh
xcodebuild -project "/Users/sawjai/Documents/Group Trip App/GroupTripApp.xcodeproj" -scheme GroupTripApp -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```

**Expected:**

Build succeeds.

If new Swift files are not included in the target, add them to `GroupTripApp.xcodeproj/project.pbxproj` carefully or use Xcode to add them to the GroupTripApp target.

---

# Task 12: Update docs after implementation

**Objective:** Keep docs aligned with the actual demo.

**Files:**

- Modify: `docs/product-roadmap.md`
- Modify: `docs/project-definition.md` only if product decisions changed.
- Optional modify: `README.md`

**Implementation:**

After Milestone 1 is implemented, update docs with:

- What the local demo includes.
- What is intentionally not persistent/collaborative yet.
- How to run/build.
- Known limitations.

**Verification:**

Docs accurately match the app state.

---

# Milestone 1 Done Criteria

Milestone 1 is complete when:

- App builds successfully.
- Dashboard shows a realistic 6-person international trip.
- Trip summary feels like a trip hub.
- User can view participants, dates, places, planning items, and expenses.
- User can add/edit enough data locally to demo the idea.
- Demo data intentionally resets between demo sessions where practical so each demo starts from a clean baseline sample trip.
- Expense balances and settlement suggestions still work.
- A smoke-test checklist exists.
- It is clear that production collaboration/auth/Supabase sharing are Milestone 2, not missing Milestone 1 work.

---

# Recommended Agent Assignment

- Product/UX Agent: Validate copy, flow, and demo acceptance criteria.
- Trips Agent: Own models, dashboard, summary, places, planning.
- Expenses Agent: Protect expense calculator and settlement behavior.
- Design/Figma Agent: Polish reusable cards and ensure it feels like a coherent trip hub.
- QA/Release Agent: Own build verification and smoke-test checklist.

For the first implementation pass, use the fuller team, but break work into small, resumable chunks so quota interruptions do not jeopardize the overall milestone.

## Quota-Aware Execution Rules

- Prefer small implementation chunks that leave the app in a buildable or easily recoverable state.
- Continue automatically from one chunk to the next after successful implementation, review, and verification unless the user interrupts, asks to pause, or a quota/build/blocking issue occurs.
- After each chunk, record what changed and what remains in the session todo list.
- If Codex quota/rate limits are hit, stop development work and report the interruption to the user using the configured fallback model/provider, such as DeepSeek.
- Do not automatically restart Codex-backed development after limits reset. Wait for the user to say Codex limits are cleared and explicitly ask to resume.
- If fallback quality is sufficient for communication, use it for status updates and planning only; avoid substantial code changes unless the user approves fallback-model development.
- Keep the saved plan and smoke checklist as the source of truth so work can resume cleanly after a disruption.

## Smaller Execution Chunks

Chunk 1 — Models only:
- Task 1: Add `TripPlace` and `TripPlanningItem` models to `TripModels.swift`.
- Build after the model change.

Chunk 2 — Sample data only:
- Task 2: Add the Japan Spring 2027 six-person baseline demo trip.
- Build after sample-data changes.

Chunk 3 — Minimal naming/copy:
- Task 3: Apply `Wani` as the visible working app name while avoiding final tagline/brand copy.
- Build or visually inspect changed surfaces.

Chunk 4 — Dashboard stats:
- Task 4: Add places/planning stats to the dashboard trip card.
- Build and inspect layout.

Chunk 5 — Places read path:
- Task 5a: Create the Places screen and wire the summary card so sample places are viewable.
- Build before adding mutation.

Chunk 6 — Places local mutation:
- Task 5b: Add local-session add/delete support for places.
- Build and manually verify add/delete.

Chunk 7 — Planning read path:
- Task 6a: Create the Planning screen and wire the itinerary card so sample planning items are viewable.
- Build before adding mutation.

Chunk 8 — Planning local mutation:
- Task 6b: Add local-session add/delete/toggle support for planning items.
- Build and manually verify add/delete/toggle.

Chunk 9 — Summary hub previews:
- Task 7: Add compact summary preview sections for planning, places, and expenses.
- Product/UX review after this chunk.

Chunk 10 — Date display confirmation:
- Task 8: Confirm date display is visible enough and defer full edit-trip details unless blocked.

Chunk 11 — Expense/people tightening:
- Task 9: Have the Expenses Agent verify and tighten people, expense, direct payment, balance, settlement, and delete flows.
- Run existing expense tests if available.

Chunk 12 — QA checklist:
- Task 10: Add the Milestone 1 local demo smoke-test checklist.

Chunk 13 — Build/fix pass:
- Task 11: Run the full build command and fix compile errors.

Chunk 14 — Docs update:
- Task 12: Update roadmap/project docs with the implemented local demo state and known limitations.

Chunk 15 — Final integration review:
- Product/UX, Design/Figma, Expenses, and QA/Release perform a final pass against Milestone 1 done criteria.
