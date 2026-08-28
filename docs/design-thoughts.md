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
| Home / Dashboard | The camp overview / front of camp | "What's going on across my trips?" |
| Welcome Desk (per trip) | The trip's lobby — the front door | "What is this trip? What's happening in it?" |
| Map Wall | The map wall / shortlist board | "Where should we go?" |
| Schedule Board | The schedule board | "What are we doing, when?" |
| Crew | The dorm hall + rooms | "Who's in this?" |
| Kitty | The kitty / the pot | "Who owes what?" |
| Journal (new) | The journal / campfire stories | "Remember when…?" |

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
- **Committed tier (resolved 2026-08-20):** things that are *really* must-go — e.g., **prepurchased tickets**. Distinct from pinned. **Resolved: bookings live on the Schedule Board** (they're date-bound); the map wall shows a "locked in" marker on committed POIs linking to the schedule board.
- **Maps — in-room map view + tap-through.** The room shows a map; tapping a POI opens actual Google Maps for directions/info. **Decided (2026-08-20): MapKit** for the in-room view — free, native, iOS-only for now; tap-through to Google Maps for directions/info. Revisit Google Maps SDK if Android or richer map features arrive.

**Staging thought:** list + open-in-Maps already exists (M4 polish). Weight/vote/pin is the differentiated core — build it as a proper M4/M5 workstream (TDD: weight model, aggregation, RLS on votes).

### Cross-cutting layer: item tags + participation (2026-08-20)

**Every item in the basecamp carries two pieces of shared metadata:**

1. **A tag (item type) from one common vocabulary** — food, hotel, flight, show, museum, custom, plus others (extensible). Purpose: instant recognition ("see what they are quickly and easily") and one set of filters that works across all rooms. The UI offers the relevant subset per item type (a place: food/show/museum…; a booking: flight/hotel/activity…), but it's ONE vocabulary, not per-room categories.
2. **A participant set — who is participating (or has participated).** Generalizes the pattern expenses already require (participants are necessary for calculating splits). Enables: filtering by person everywhere, per-person calendar views ("things Sam is part of"), and the Crew room's "their calendar" as *derived data* (items where they participate, not just items they added).

**Key principle: participating ≠ added-by.** A person's calendar shows everything they're part of, regardless of who added it.

**Cross-room effects:**
- Map Wall: place categories become the shared vocabulary (presets + custom).
- Schedule Board: booking types use the same tags; bookings carry participant sets.
- Crew: "their calendar" = items they participate in (flights, stays, activities, places).
- Journal (later): "has participated" past tense feeds the after-trip story.

### Room spec: The Schedule Board (Itinerary) — v0.1 (2026-08-20)

**The job:** The trip's coordination spine — a day-grouped timeline where **everyone's commitments are overlaid** so the group can see how schedules line up and coordinate their own around them.

**The vision (user's words, developed):**
- **Group + individual at once** — "everyone can see how each other's schedule line up and the overall schedule for the group." One unified timeline; each item attributed to who it belongs to (avatar chip).
- **Flights are visible** — "if someone has booked a flight, others can use it to coordinate their own." The killer coordination loop: Sam books a flight → Maya sees it and books hers to match.
- **Hotel stays** — same treatment (date ranges, who's staying).
- **Prebooked activities** — tickets/committed activities (the Map Wall's "committed tier") appear here as date-bound bookings.

**Resolved (from this vision): the committed-tier placement.** The Map Wall's open question ("does committed live on the map wall or elsewhere?") answers itself: **bookings live on the schedule board** — they're date-bound. The map wall shows a "locked in" marker on committed POIs that links to the schedule board.

**Cross-links:** a person's Crew room shows "their calendar" — the bookings they added (same records, second door). Arrival/departure windows on the Crew room feed from flights here.

**Open questions (parked):**
- **Who adds a booking?** Self-serve (each person adds their own) vs anyone-can-add-anyone (trip-wide trust). Lean: self-serve + organizer can add for others.
- **Detail depth per booking:** flight = airline + number + times + confirmation? hotel = name + check-in/out? or light (who + when)?
- **Coordination affordances:** pure visibility first ("Sam arrives 15:40"), or also tap-to-copy flight info / open booking in Maps? MVP = visibility + details.

**Current state vs vision:** today Itinerary = flat checklist (title, note, optional date, done toggle). Day grouping, bookings, and attribution are new.

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

### Room spec: The Journal (Memories) — v0.1 (2026-08-20)

**The job:** The after-story — the basecamp's guest book. Close out the trip's logistics (kitty handles money) and give the group a place to share memories and thoughts. The room that makes the trip feel *complete* instead of abandoned at the airport.

**The vision (user's words, developed):**
- **Like a hotel guest book** — quick one-liners to short paragraphs, each person leaving feedback/memories on the trip. Low-friction, personal, chronological.
- **No rating system** — decided: ratings are for public review platforms; this is friends with each other. (A star rating would be weird between people who were on the trip together.)
- **Pictures:** a place to share photos. **External album links (Google Photos etc.) are the MVP** — hosting albums in-app is uncertain ("not sure us hosting the albums makes any sense right now"), but in-app hosting *would* enable fast, easy image sharing. Open decision, deferred; Supabase Storage exists if we ever want it.
- **Conversations:** mirror the trip chat or link back to it — the group's after-trip conversation lives in the trip chat; the journal links to it.

**Open questions (parked):**
- Guest book prompts? (e.g., "favorite moment", "one word for the trip") — light structure vs pure freeform.
- In-app photo hosting: defer until real need (storage cost + moderation vs convenience).
- Journal entry visibility: whole trip reads all entries (guest book = public to the group). Confirmed friends-only framing.

**Cross-links:** "has participated" past-tense data (cross-cutting tags/participation) feeds entries; kitty "settled up" closeout; trip chat link for conversations.

### Room spec: The Kitty (Money) — v0.1 (2026-08-20)

**The job:** The fair ledger — a place where a user AND the group can quickly see all expenses for the trip, add expenses quickly on the go, and at the end see what they owe and how to repay easily. **The existing expense calculator is the backbone** — "most of this should already be in the existing expense page."

**The vision (user's words, developed):**
- Quick group + user overview of all expenses (exists: expense list, balances, settlements).
- **Add expenses quickly and easily ON THE GO** — the gap: current add flow is form-y; on-the-go quick-add = minimal fields (amount, who paid, split) with smart defaults (equal split already the default).
- **End of trip: what I owe + how to repay easily** — user-first: "You owe Sam $42 · Maya owes you $18" + a clean repayment view (settlements exist; make repayment steps explicit — who to pay, how much, mark as paid → direct payment).
- User-first framing ties to dashboard money (account-aware, honest fallback when unmapped).

**Existing coverage (validated):** expense CRUD, participant splits, balances, suggested settlements, direct payments, cloud sync. Remaining work = speed (quick-add), user-first "what you owe" framing in-trip, repayment guidance view.

**Cross-links:** tags + participant sets (already native to expenses — the pattern's origin); Crew room "their expenses" = person's expense footprint; Journal (after): "settled up" closeout.

### Room spec: The Welcome Desk (per-trip landing / lobby) — v0.1 (2026-08-20)

**The job:** The trip's front door — a gathering lobby that IS the trip's dashboard. The central glance place before moving into specific rooms (map wall, schedule, crew, kitty). **Absorbs the old "Current Trip" anchor and the invite/join threshold.**

**The vision (user's words, developed):**
- "The welcome desk is the dashboard of the whole trip and should feel like a gathering lobby for the group, as well as serve as the central place for the user to get a quick glance of the trip before moving into specific parts to find out more."
- **Top: the trip's countdown clock** (per-trip — connects to the home dashboard countdown, but this one is THIS trip) + obvious basics: place, date.
- **Quick-glance items:** who's going on this trip (crew preview), the group chat for the trip (entry point), and the trip's activity feed.
- **Invite/join lives here too** — the lobby is where people are welcomed in (create/copy invite code, see who's coming).

**Current state vs vision:** today the trip landing = TripSummaryView (photo hero, name/dates, trip sections, invite card). The lobby reframes it: countdown + basics + who's going + chat + feed as the glance layer, with the rooms as the "walk further in" layer. Glance-first, embodied.

### Cross-cutting: feed grouping + action-needed calls (2026-08-20)

1. **Grouped feed.** Feed events batch by actor + action so one person adding 15 POIs shows as ONE line — "Sam added 15 places" — instead of flooding the feed. Applies to the trip feed (welcome desk) and the home dashboard feed.
2. **Call-for-vote / call-for-input on items.** When adding an item (POI, hotel booking, etc.), the adder can **call for feedback** — "want the group's take on this" or "confirming: does anyone else need to be in this hotel room?" Unanswered calls surface in the **action-needed area** on the user's home dashboard ("items you need to address"). Generalizes to any item type; the Map Wall vote UI is one instance. Open: what else lands in action-needed (invite confirmations? settlement approvals?).

### Dashboard first-open experience (user spec, finalized 2026-08-20)

**Simplification (2026-08-20): Home = the USER's lens; Welcome Desk = the TRIP's lens.** Home is user-specific at a quick glance, with quick access to the next/current trip. Trip-level detail lives in the welcome desk. No overlap: home answers "what's going on with ME and my trips," welcome desk answers "what's happening in THIS trip."

1. **Upcoming trip + live countdown** — future trips only (current/past trips show no countdown). Days, hours, minutes, seconds — **live ticking** (seeing it tick is more fun than a static banner). The emotional number: large serif hero. "Excited to go," literal. **Quick access to the next/current trip from here.**
2. **Updates feed** — an activity feed on the dashboard (not per-trip badges). "Sam added a place to Kyoto · Maya settled up." Leans into the story/basecamp feel. Implication: needs a real activity log — new `trip_activity` table (RLS, attribution, service-layer writes), or derive from existing `updated_at` + attribution where possible. MVP feed = recent events across the user's trips. **Feed events are GROUPED** (see cross-cutting: "Sam added 15 places" = one line).
3. **Action-needed area** — calls for your input: votes called on POIs, hotel-inclusion confirmations, anything awaiting a decision. Feeds into the existing "Needs your attention" dashboard section.
4. **User money glance** — "you owe $42 · you get back $18" (user-specific, existing dashboard money section).
5. **No separate lurker mode** — resolved: if the app is well designed to surface info, lurkers see everything easily while actionable items stay visible and usable. Glance-first in-place is enough; no browse/observer posture needed.

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

### Prototype feedback (2026-08-20) — durable principles

1. **Internal names ≠ user-facing names.** The rooms (Map Wall, Schedule Board, Crew, Kitty, Welcome Desk, Journal) are designer language. Users see plain page names: Places, Itinerary, People, Money/Expenses, Trip Overview (or the trip name), Memories, Home. Keep the rooms concept internal.
2. **Each trip gets a photo hero.** The trip page leads with a cover image (upload or online-image URL — the app already supports both in NewTripView) — it gives each trip its own feel. The design rollout removed the hero from the trip landing; the Welcome Desk spec must restore it.
3. **Sections own their items.** A section header must clearly own everything under it: items live in ONE shared container with hairline dividers, not individual standout cards. Applies to Needs your attention, grouped feeds, and any multi-item section.

## Inbox

- 2026-08-20 — JOURNAL vision: like a hotel guest book — one-liners to short paragraphs of trip feedback; NO rating system (friends, not reviews); a place to share pictures (external album links = MVP; hosting in-app uncertain but would enable fast easy sharing); mirror/link the trip chat for conversations. → developed into Room spec: The Journal v0.1. THE FRAME IS NOW COMPLETE — all 7 rooms specced. (raw → developed)

- 2026-08-20 — HOME vs WELCOME DESK resolved: overlap is OK because home = user lens, welcome desk = trip lens. SIMPLIFY home to user-specific quick glance + quick access to next/current trip. KITTY: mostly mapped — calculator is the backbone; needs quick on-the-go expense add, user-first "what I owe," and easy end-of-trip repayment; most already exists in the expense page. → developed: dashboard simplification note + Room spec: The Kitty v0.1. (raw → developed)

- 2026-08-20 — WELCOME DESK reframe: it IS the trip's dashboard — a gathering lobby; central glance place before moving into rooms. Top: per-trip countdown + basics (place/date). Quick glances: who's going, group chat, trip activity feed. ABSORBS the old Current Trip anchor + invite/join. Also: feeds should be GROUPED ("Sam added 15 places" = one line); item adders can CALL FOR VOTE/INPUT (POI feedback, hotel inclusion confirm) → unanswered calls surface in an ACTION-NEEDED area on the home dashboard. → developed into Welcome Desk room spec + cross-cutting: feed grouping + action-needed calls. (raw → developed)

- 2026-08-20 — CROSS-CUTTING: items should have common tags (food, hotel, flight, show, museum, custom, + others) for quick recognition, and a "who is participating / has participated" field for filtering and per-person calendars. Noted: expenses already require participant sets. → developed into Cross-cutting layer: item tags + participation. Key principle: participating ≠ added-by. (raw → developed)

- 2026-08-20 — SCHEDULE BOARD vision: everyone sees how each other's schedules line up + the overall group schedule; individual flights show up so others can coordinate their own; same for hotel stays and prebooked activities. → developed into Room spec: The Schedule Board v0.1. Also RESOLVED the Map Wall committed-tier question: bookings live on the schedule board (date-bound), map wall shows a locked-in marker. (raw → developed)

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
