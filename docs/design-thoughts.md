# Wanderaid — Design Thoughts Inbox

**Capture first, structure later.** This is the raw inbox for product/design thoughts about Wanderaid. Nothing here needs to be coherent, justified, or final. Thoughts land as they come (in chat or directly here), get developed into directions, then graduate to `todo-feedback.md` or a plan.

## How to use

- Say a thought in chat anytime — Hermes files it here with a date.
- One thought per entry, however small or vague: `Date — thought`.
- Status trail: **raw** → **developed** (direction takes shape) → **decided** (moves to todo-feedback/plan) → **shipped**.
- Never delete a thought; mark it superseded if a better one replaces it.

---

## Draft: Cohesive Frame — v0.3 (2026-08-20, basecamp adopted)

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

### Dashboard first-open experience (user spec, 2026-08-20)

1. **Upcoming trip + countdown** — see if there's an upcoming trip and how far away it is. A **countdown clock** ("might be fun and exciting") — this is the emotional number, a serif moment. The "excited to go" feeling, literal.
2. **Updates at a glance** — see if there are any updates to any of the trips, without opening them. (Needs an updates/activity signal — minimal version: per-trip "what changed since I last looked" using updated_at + a last-seen marker; richer version: an activity log.)

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

- 2026-08-20 — "I think the basecamp analogy best fits what I'm looking for. It should be a collaborative space that everyone can contribute to and also get an idea of what's going on if they don't want to contribute but just want to keep up to speed." → developed: basecamp adopted as THE metaphor; sections map to camp rooms; two participation modes (contributor + lurker) → "glance first, contribute second" principle. (raw → developed)
- 2026-08-20 — "When the user first opens the app: see if they have an upcoming trip and how far away it is (a countdown clock might be fun and exciting), and see if there are any updates to any of the trips." → developed: dashboard first-open spec (countdown = emotional serif moment; updates-at-a-glance = per-trip change signal). M4 dashboard scope. (raw → developed)
- 2026-08-20 — "I'm not sure what object it would be, I'm trying to merge all the tools that I use to plan a trip into one place. So maybe a toolbox, but that's the wrong feel." → developed: unification is core job; toolbox feel is wrong (work-like). Object metaphor unresolved — candidates in frame above. (raw → developed)
- 2026-08-20 — "I want them to feel excited. Not about the app, but about the trip. Excited before (planning together should be fun), during (keep it organized and easy to track so they enjoy the trip), after (easy to close out logistics + a place to share trip memories and thoughts)." → developed: the before/during/after lifecycle spine + "the trip is the star" principle. (raw → developed)
- 2026-08-20 — "I want the user dashboard to feel right first because it's the landing page for the app." → developed: dashboard = priority #1 in M4. (raw → developed)
- 2026-08-20 — "The app should keep the trip on track, but it should be fun and collaborative." → developed: personality draft — the friend who's got the plan AND makes planning fun; fun matters as much as calm. (raw → developed)
- 2026-08-20 — (from #2, flagging) "A place to share trip memories and thoughts" after the trip → NEW section direction: Memories / after-story. Undeveloped — what would this be? Photos? Recap? Notes? (raw)
