# Rooms → Milestones Mapping (draft for roadmap adjustment)

**Date:** 2026-08-20 · **Source:** docs/design-thoughts.md (room specs) + docs/product-brief.md · **Status:** proposal — apply into docs/product-roadmap.md when its in-flight changes are committed

## Adjusted milestone ladder

The room specs add real scope beyond the current M4–M6, so one milestone is inserted:

| # | Milestone | One-liner | Gate |
|---|---|---|---|
| M1 | Local Demo | ✅ done | — |
| M2 | Collaborative MVP | ✅ done | — |
| M3 | Design Implementation | ✅ done (Calm Editorial rollout shipped) | — |
| **M4** | **Feature Usability + Room Foundations** | Existing features become understandable + the shared grammar (tags/participants) + quick wins | Usable without explanation |
| **M5** | **The Basecamp Comes Alive** (NEW) | The differentiated core: weighted voting, bookings + schedule coordination, feeds + action-needed, basic chat, in-room map | First-release feature set complete |
| **M6** | **Real Trip Readiness / TestFlight** (was M5) | Dogfood with close friends/family — chat in action, journal guest book, closeout, real-feedback polish | TestFlight release |
| **M7** | **v1 Candidate** (was M6) | Broader release prep: push, photo hosting decision, journal polish | Semi-public beta |

## Room → workstream → milestone

### Home
| Workstream | Milestone | Notes |
|---|---|---|
| Live ticking countdown hero (next trip) | M4 | Quick win; serif emotional number |
| User money glance polish | M4 | Mostly exists |
| Activity feed + grouped events (`trip_activity` data layer) | M5 | Needs schema + RLS + service writes, TDD |
| Action-needed section | M5 | Consumes call-for-vote/input |

### Welcome Desk (trip lobby)
| Workstream | Milestone | Notes |
|---|---|---|
| Lobby reframe of trip landing (countdown, who's going, chat entry, feed, invite) | M4 | Mostly UI restructure of TripSummaryView |
| Invite/join polish | M4 | Already in M4 scope |

### Map Wall
| Workstream | Milestone | Notes |
|---|---|---|
| Tag vocabulary (cross-cutting foundation) | M4 | One taxonomy everywhere |
| Tap-through to Google Maps | M4 | Trivial (URL scheme) |
| Voting + weights (yes +1 / weak-yes +0.5 / no −1, abstain null) + pins | M5 | Core differentiated feature; schema + RLS + TDD |
| MapKit in-room map view | M5 | New SDK integration |
| Locked-in markers (link to bookings) | M5 | Depends on bookings |

### Schedule Board
| Workstream | Milestone | Notes |
|---|---|---|
| Day-grouped timeline + optional times | M4 | Already in M4 scope |
| Bookings (flights/stays/activities) + participant sets + coordination overlay | M5 | The coordination spine; connects to committed tier |

### Crew
| Workstream | Milestone | Notes |
|---|---|---|
| Person rooms (aggregated footprint: places, expenses, bookings, votes, role, money) | M4 | Aggregation views over existing data |
| Account upgrade/link flow + member-vs-participant clarity | M4 | Already in M4 scope |
| Message handoff (contact sheet / WhatsApp / Discord) | M4 | Pre-chat MVP |
| Arrival/departure windows | M5 | Derived from bookings |

### Kitty
| Workstream | Milestone | Notes |
|---|---|---|
| Quick-add expense (3-tap) | M4 | Speed, not new math |
| User-first "what I owe" framing | M4 | Mirrors dashboard money |
| Repayment guidance view ("pay Sam $42 → done") | M4 | Settlement + direct payment loop exists |

### Journal
| Workstream | Milestone | Notes |
|---|---|---|
| Guest book MVP (one-liners to paragraphs, no ratings) | M6 | After real trips exist (dogfood) |
| Album links + chat tie-in | M6 | |
| Photo hosting decision | M7 | Deferred; Supabase Storage available |

### Chat (first-release commitment)
| Workstream | Milestone | Notes |
|---|---|---|
| Trip channel + cross-trip DMs, text realtime MVP | M5 | Supabase Realtime pattern; TDD + RLS |
| Unread indicators | M5 | |
| Push notifications | M7 | Deferred workstream (APNs + relay) |

### Cross-cutting
| Workstream | Milestone | Notes |
|---|---|---|
| Item tags + participant sets on every item type | M4 | Foundation; schema refactor of item models |
| Feed grouping (one line per actor+action) | M5 | |
| Call-for-vote / action-needed mechanism | M5 | |
| Wanderaid confirmation component | M4 | Already in M4 scope |

## Notes

- **Chat first-release commitment honored:** basic chat lands in M5, so TestFlight (M6) ships with it.
- **Explicit deferrals:** push notifications, photo hosting, typing indicators, read receipts, media, ratings.
- **M4 is the "everything existing feels good" milestone**; M5 is where Wanderaid becomes *distinctive*. TestFlight waits for both.
- **Roadmap integration:** this proposal folds into docs/product-roadmap.md (currently the user's in-flight uncommitted file) when it's committed — apply milestone sections M4–M7 + scope deltas.
