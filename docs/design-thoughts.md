# Wanderaid — Design Thoughts Inbox

**Capture first, structure later.** This is the raw inbox for product/design thoughts about Wanderaid. Nothing here needs to be coherent, justified, or final. Thoughts land as they come (in chat or directly here), get developed into directions, then graduate to `todo-feedback.md` or a plan.

## How to use

- Say a thought in chat anytime — Hermes files it here with a date.
- One thought per entry, however small or vague: `Date — thought`.
- Status trail: **raw** → **developed** (direction takes shape) → **decided** (moves to todo-feedback/plan) → **shipped**.
- Never delete a thought; mark it superseded if a better one replaces it.

---

## Draft: Cohesive Frame — v0.4 (2026-08-20, dashboard spec finalized)

**Working idea:** *A trip with people you like is a story you're still writing — dreamed before, lived during, told after. Wanderaid is the trip's basecamp: one collaborative space where the whole story lives — plan it, live it, remember it — and where anyone can either contribute or just stop by to see what's going on.*

### The metaphor: basecamp (adopted 2026-08-20)

The user's instinct ("merge all my tools into one place") + the wrong feel of a toolbox = **basecamp**. A toolbox is carried by one person for work; a basecamp is built by everyone, for the adventure. Everyone contributes; everyone can also just walk through and see what's happening.

The sections as camp:

| Section | Camp room | Answers |
|---|---|---|
| Home / Dashboard | The camp overview / front of camp | "What's going on?" |
| Current Trip | The camp itself | "What is this trip?" |
| Places | The map wall / shortlist board | "Where should we go?" |
| Itinerary / Planning | The schedule board | "What are we doing, when?" |
| People | The crew | "Who's in this?" |
| Money | The kitty / the pot | "Who owes what?" |
| Invite / Join | The welcome desk | "Come along." |
| Memories (new) | The journal / campfire stories | "Remember when…?" |

### The two participation modes (the big insight)

A basecamp works for two kinds of people, and so must every screen:

1. **Contributors** — add places, move plans, log expenses. The action layer.
2. **Lurkers / keep-up-to-speed** — don't want to contribute, just want to know what's going on. The **glance layer**: every section shows its state at a glance before asking anything of you.

**Design principle: glance first, contribute second.** Every screen should communicate "here's where things stand" in the top moments, and only then offer actions. The dashboard is the lurker's home.

### Room spec: The Map Wall (Places) — v0.2 (2026-08-20, decisions resolved)

**The job:** Replaces the user's current workflow — a shared Google Map where everyone drops points of interest for the trip. Wanderaid's map wall does that *better*, with signal.

**The current workflow being replaced:**
1. Find interesting places → add as POIs on a shared map for the trip.
2. Share the map → everyone adds their own POIs.
3. During the trip: pull up the map, see what's nearby, hit places up; also use the map to decide which area to go to for the day.
4. **The pain:** POIs have no priority or weight. Any point can go on, but there's no signal for how much anyone actually wants to go.

**The vision (user's words, developed):**
- **Weight on every POI** — "I can put a weight on it so others know if I really want to go to it or not. Then others can vote or put their own weight on it as well — that way we get a more prioritized list of places that people are interested in."
- **Pinning** — "a way to pin certain POIs so they become more of a must-go even without any voting."
- **Google Maps relationship:** not a full replacement — "hooked up to Google map if possible."

**Resolved decisions (2026-08-20):**
- **Voting scale — 3 states + abstain.** Yes / a middle that is *slightly more weight than abstaining* / No. Key principle: **abstaining (no vote) is null; the middle is a weak yes, not neutral.** Proposed weights: yes = +1, middle = +0.5, no = −1, abstain = 0 (null, not counted). Prioritized list = aggregate weight; vote counts shown separately so one strong yes ≠ group consensus.
- **Pinning — anyone can pin.** Pinned ≠ must-go; it means "should be on everyone's radar" (attention tier).
- **Committed tier (new concept, user-raised):** things that are *really* must-go — e.g., **prepurchased tickets**. Distinct from pinned. Open: does it live in the map wall as a special marker, or a separate area? (Also connects to itinerary — a ticket is a date-bound commitment.)
- **Maps — in-room map view + tap-through.** The room shows a map; tapping a POI opens actual Google Maps for directions/info. **Decided (2026-08-20): MapKit** for the in-room view — free, native, iOS-only for now; tap-through to Google Maps for directions/info. Revisit Google Maps SDK if Android or richer map features arrive.

**Staging thought:** list + open-in-Maps already exists (M4 polish). Weight/vote/pin is the differentiated core — build it as a proper M4/M5 workstream (TDD: weight model, aggregation, RLS on votes).

### Room spec: The Crew (People) — v0.1 (2026-08-20)

**The job:** The crew wing of the basecamp — a dorm hall. The landing page is the **hall**: a list of everyone on the trip, plus a way to add more people. Each person gets a **room** with their details.

**The vision (user's words, developed):**
- **The hall** — list all trip people + add-people affordance. Glance-first: who's in, who's new.
- **Each room (person detail page):**
  - Name
  - Bring up the user's **profile**
  - **Message the user directly**
  - **Their places** — the POIs they've added to the map wall (connects to Map Wall)
  - **Their expenses** — what they've paid / what they owe (connects to the Kitty)
  - **Their calendar** — flights and hotels they've booked (connects to Schedule Board + the committed tier)
  - **Their votes on places** — which map-wall POIs they want/would/no (connects to Map Wall voting)
  - **Their role** — organizer / traveler (connects to M4 "clarify members vs participants")
  - **Money status at a glance** — "owes $42 · gets back $18" (connects to Kitty)
  - **Arrival / departure windows** — when they get in and leave (connects to Schedule Board)

**Chat (decided: IN first release, 2026-08-20):** basic in-app chat is part of the first release — **one common chat per trip** (trip channel) + **direct chats between users that span across trips** (user-level DMs). Text-only MVP on Supabase Realtime (messages + conversations tables, RLS, postgres_changes subscription).

**First-release scope (what we WILL build):**
- Trip channel (one per trip, members only) + cross-trip DMs
- Text messages, realtime delivery while app is open
- Unread indication (badge/dot) — minimal
- Entry points: trip detail (Trip Chat card becomes real), Crew room (message a person), chat list

**Deferred (explicitly NOT first release):** push notifications (APNs + relay — separate workstream), typing indicators, read receipts, photos/media in chat, message editing/threads.

**Milestone note:** chat joins first-release scope — land it before/alongside M5 (Real Trip Readiness / TestFlight dogfood). Roadmap file is the user's in-flight uncommitted doc — update its "Trip Chat placeholder" + milestone scope there when it's committed.

**The insight:** a person's room is their **footprint across the whole basecamp** — the cross-cutting view of one person's contribution to the trip. The crew room is what makes the basecamp feel like one place instead of five features.

**Design questions (parked, not blocking):**
- **Profile depth:** what's in a profile? Account-linked users (Google/Apple): name, email, photo. Guests: display name only. Is there an editable profile page? (M4 already has "account upgrade/link flow for guests" — this connects.)
- **Messaging scope:** in-app chat is a big feature (roadmap: Trip Chat is a placeholder; user's groups live on Discord/WhatsApp). MVP option: "message" = handoff (open SMS/WhatsApp/Discord or contact sheet) vs in-app DM. Decide later.
- **Bookings placement:** per-person flights/hotels — cross-listed in the person's room AND on the schedule board (a booking is date-bound), or room-only?
- **What else could live in a room:** their votes on places, their role (organizer/traveler), money status at a glance, contact info, arrival/departure windows.

**Current state vs vision:** today People = flat list (edit/delete) + balances + settlements. The hall exists in skeleton; rooms are new.

### Dashboard first-open experience (user spec, finalized 2026-08-20)

1. **Upcoming trip + live countdown** — future trips only (current/past trips show no countdown). Days, hours, minutes, seconds — **live ticking** (seeing it tick is more fun than a static banner). The emotional number: large serif hero. "Excited to go," literal.
2. **Updates feed** — an activity feed on the dashboard (not per-trip badges). "Sam added a place to Kyoto · Maya settled up." Leans into the story/basecamp feel. Implication: needs a real activity log — new `trip_activity` table (RLS, attribution, service-layer writes), or derive from existing `updated_at` + attribution where possible. MVP feed = recent events across the user's trips.
3. **No separate lurker mode** — resolved: if the app is well designed to surface info, lurkers see everything easily while actionable items stay visible and usable. Glance-first in-place is enough; no browse/observer posture needed.

### The trip lifecycle (from v0.2, still standing)

| Phase | The trip | Wanderaid's job | The feeling to create |
|---|---|---|---|
| **Before** | A story being dreamed | Planning together is *fun* — shortlists, timelines, people, money decisions as shared excitement | Excited to go |
| **During** | A story being lived | Keep it organized and easy to track so nobody does logistics-stress | Free to enjoy |
| **After** | A story being told | Close out the logistics easily + a place to share memories and thoughts | Proud / warm closure |

**Principle: the trip is the star, not the app.** The user should feel excited *about the trip* — the app gets out of the way.

**Personality (draft):** "Keeps the trip on track, but fun and collaborative." The friend who's got the plan AND makes planning feel like part of the fun — organized, warm, playful-but-calm.

### Cohesion rules (standing)

1. One question per screen — a screen answering two questions splits.
2. One voice — calm, plain, warm; no jargon; consistent rhythm.
3. One visual grammar — editorial small-caps headers, forest actions, hairline cards, serif only for emotional numbers (money, names, dates — and now the countdown).
4. One time-posture per section (dashboard = now, places = maybe, itinerary = sequence, money = fair, people = together).
5. The story thread — dashboard = cover, trip = chapter, section = page; the reader always knows where they are.
6. Excited about the trip, never about the app.
7. **NEW: glance first, contribute second — every screen works for lurkers and contributors.**

---

## Inbox

- 2026-08-20 — DECIDED: **basic chat is in first-release scope** — trip channel + cross-trip DMs, text-only realtime MVP, minimal unread indication. Deferred: push notifications, typing indicators, read receipts, media, threads. Land before/alongside M5. (raw → decided)

- 2026-08-20 — CREW room additions: accepted the four candidates — votes on places, role (organizer/traveler), money status at a glance, arrival/departure windows. Also: wants **basic in-app chat** (one trip-wide channel per trip + cross-trip DMs). Feasibility noted: text chat on Supabase Realtime = standard pattern, doable; push notifications = the hard part, defer; typing/read-receipts/media defer. (raw → developed)

- 2026-08-20 — CREW vision: dorm-hall landing page (list of everyone + add people); each person has a "room": name, profile, direct message, their places (POI list), their expenses, their calendar (flights/hotels booked) — "not sure what else." → developed into Room spec: The Crew v0.1. Key insight: a person's room = their footprint across the whole basecamp. (raw → developed)

- 2026-08-20 — Map Wall maps decision: use **Apple MapKit** for the in-room map view (free, native, iOS-only for now); tap-through to Google Maps for directions/info stays. Revisit Google Maps SDK only if Android/richer maps arrive. (raw → decided)

- 2026-08-20 — MAP WALL decisions: (1) voting = yes / weak-yes / no, abstain is null (middle is slightly above abstaining, not neutral); (2) anyone can pin — pinned = "on everyone's radar," NOT must-go; (3) committed tier for real must-gos (prepurchased tickets) — separate area open; (4) in-room map view preferred via Google Maps integration, tap-through to Google Maps for directions/info. → developed into Room spec: Map Wall v0.2. (raw → developed)
- 2026-08-20 — MAP WALL vision (detailed): replaces the shared-Google-Map workflow; POIs with per-person weight + votes → prioritized list; pinning = must-go without voting; during-trip modes (nearby, pick an area); hooked up to Google Maps where possible. → developed into Room spec: Map Wall v0.1. (raw → developed)
- 2026-08-20 — "Countdown should only be for future trips. Days, hours, minutes, seconds — seeing it tick can be more fun than a static '5 days until' banner." → developed: live ticking countdown, future trips only, serif hero. (raw → developed)
- 2026-08-20 — "A feed is a more fitting feel" (for updates) → developed: dashboard activity feed adopted (needs `trip_activity` data layer). (raw → developed)
- 2026-08-20 — "No need for a lurker mode — if the app is well designed to surface info, a lurker can see everything easily while the actionable items are still there and easy to use." → developed: no separate browse mode; glance-first in-place design is sufficient. (raw → developed)

- 2026-08-20 — "I think the basecamp analogy best fits what I'm looking for. It should be a collaborative space that everyone can contribute to and also get an idea of what's going on if they don't want to contribute but just want to keep up to speed." → developed: basecamp adopted as THE metaphor; sections map to camp rooms; two participation modes (contributor + lurker) → "glance first, contribute second" principle. (raw → developed)
- 2026-08-20 — "When the user first opens the app: see if they have an upcoming trip and how far away it is (a countdown clock might be fun and exciting), and see if there are any updates to any of the trips." → developed: dashboard first-open spec (countdown = emotional serif moment; updates-at-a-glance = per-trip change signal). M4 dashboard scope. (raw → developed)
- 2026-08-20 — "I'm not sure what object it would be, I'm trying to merge all the tools that I use to plan a trip into one place. So maybe a toolbox, but that's the wrong feel." → developed: unification is core job; toolbox feel is wrong (work-like). Object metaphor unresolved — candidates in frame above. (raw → developed)
- 2026-08-20 — "I want them to feel excited. Not about the app, but about the trip. Excited before (planning together should be fun), during (keep it organized and easy to track so they enjoy the trip), after (easy to close out logistics + a place to share trip memories and thoughts)." → developed: the before/during/after lifecycle spine + "the trip is the star" principle. (raw → developed)
- 2026-08-20 — "I want the user dashboard to feel right first because it's the landing page for the app." → developed: dashboard = priority #1 in M4. (raw → developed)
- 2026-08-20 — "The app should keep the trip on track, but it should be fun and collaborative." → developed: personality draft — the friend who's got the plan AND makes planning fun; fun matters as much as calm. (raw → developed)
- 2026-08-20 — (from #2, flagging) "A place to share trip memories and thoughts" after the trip → NEW section direction: Memories / after-story. Undeveloped — what would this be? Photos? Recap? Notes? (raw)
