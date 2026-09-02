# Wanderaid — Lessons Learned Register

**Purpose:** Every notable failure or near-miss gets an entry here: what failed, the root cause, what absorbed it (why the workflow didn't break), and the durable rule added. The register makes failures reusable knowledge — reviewed at milestone retrospectives so the same class of issue doesn't recur.

**Standing rule (from 2026-09-01):** after any notable failure during work, file an entry in this register AND add/confirm the durable rule (AGENTS.md, skill, or plan doc) in the same turn or at the next natural checkpoint. If the issue is unavoidable (e.g. token quotas), the entry must name the robust mechanism that keeps the workflow working through it.

---

## 2026-09-01 — Codex quota exhaustion (5h rolling limit)

- **What failed:** User's Codex quota ran dry mid-work. Symptoms: @review HTTP 429 ×2 (both Chunk 2/3 gates died), @design 429 ×1 (Chunk 3 chip handoff never produced), @coding session degraded (message_agent missing from toolset).
- **Root cause:** Codex-backed profiles (coding, review) share the user's Codex quota, which resets on a ~5h rolling window. No quota check before dispatch.
- **What absorbed it (why the workflow didn't break):** Scope + design decisions lived in `docs/plans/` (durable channel, survives lane death); orchestrator (general) ran the QA checklist inline as fallback when @review died; work resumed from the last committed state, nothing was lost; quota pause was used for non-Codex lanes (@architect scoping, @design handoff).
- **Durable rule added:** AGENTS.md "Quota-aware dispatch" (commit `193e9ad`): record scope first, check quota before Codex-lane dispatch, resume-from-committed-state on 429, use quota pauses for non-Codex lanes.
- **Recurrence risk:** HIGH — guaranteed (rolling quota). Mitigation now encoded; the workflow is designed to degrade gracefully, not stall.

## 2026-09-01 — `target_busy` delivery race (design corrections bounced)

- **What failed:** Two `message_agent` deliveries to @coding bounced with `target_busy` because @coding was mid-long-turn. The Chunk 3 UI was wired against the stale interim spec; four @design corrections (pencil tint, filter header, icon, maps hint) landed late.
- **Root cause:** Orchestrator sent a follow-up to a profile that was actively running its turn; deliveries queue ~120s then fail.
- **What absorbed it:** The corrections were ALSO recorded in the plan doc (durable channel), and the orchestrator inspected the final diff against @design's verdict at review time — catching the deviations (incl. the red-pencil bug) despite the delivery failure.
- **Durable rule added:** Decisions go in `docs/plans/` FIRST (chat delivery is best-effort); orchestrator verifies diffs against design verdicts, not just test results.
- **Recurrence risk:** MEDIUM — avoidable by checking the target profile's busy state or relying on the plan doc. Mitigation: plan doc is authoritative for every implementation brief.

## 2026-09-01 — Test-gap bug: case-sensitive tag filtering

- **What failed:** Chunk 3's `filtered(by:)` compared tags case-sensitively ("food" vs legacy "Food"). Places migrated from the chunk-2 category→tag rename (title-case) or demo data would silently vanish under filter chips. @review FAILED the gate.
- **Root cause:** Tests only covered lowercase canonical tags; the migration preserved old casing, a path no test exercised.
- **What absorbed it:** The QA gate ran BEFORE commit (standing rule) and caught the class of bug unit tests missed. Fix was small and well-prescribed: read-side trim + lowercase normalization + regression test ("Food", " Museum ", "food"). 118/118 green after.
- **Durable rule added:** QA gate must run before every commit (already standing — this validated it); schema/migration changes need a "legacy data path" test.
- **Recurrence risk:** LOW for this exact bug (regression test now pins it); MEDIUM for the class (data-shape changes without legacy-path tests) — gate + register keep it visible.

## 2026-09-01 — Interim-spec drift (design lane died mid-handoff)

- **What failed:** @design's Chunk 3 handoff died on the 429; orchestrator drafted an interim chip spec from the prototype; @coding built against it before @design's corrections arrived.
- **Root cause:** Chain of two quota-era failures (design 429 → interim draft → coding started before review).
- **What absorbed it:** Orchestrator diff inspection against @design's verdict caught all four deviations in one revision pass; design corrections recorded permanently in the plan doc.
- **Durable rule added:** When a design/scope lane dies, mark its deliverable as INTERIM in the plan doc and schedule a review pass before the dependent work finalizes (the review catches drift).
- **Recurrence risk:** MEDIUM — mitigated by the interim-spec marker + review-pass convention.

---

## 2026-09-02 — Interim-spec drift RECURRED (Chunk 4: UI wired before @design handoff landed)

- **What failed:** Same class as the 2026-09-01 interim-spec entry. Chunk 4's UI wiring was done against the scope bullet points only — @coding's single turn ran start-to-finish while @design's visual handoff was still in flight. Three deviations found at review: dated rows as standalone cards (vs one shared per-day container), day headers via EditorialSectionHeader (uppercase small-caps vs the serif date moment), backlog label "Backlog" (vs "Undated backlog").
- **Root cause:** Dispatching @coding while the design handoff was "in flight" assumes the handoff lands DURING the logic phase — but @coding's turn runs continuously and can't receive mid-turn deliveries (target_busy lesson). The handoff landed after their turn finished.
- **What absorbed it:** Scope + the eventual handoff were in the plan doc (durable channel); orchestrator diff inspection against @design's verdict caught all three deviations; one focused revision pass closed them.
- **Durable rule (ESCALATED — previous rule insufficient):** A design-dependent chunk's UI wiring must NOT be dispatched until the @design handoff is ALREADY IN the plan doc. Two options: (a) sequential — dispatch @coding only after the handoff lands; (b) split dispatch — send @coding the pure-logic half first, and dispatch the UI-wiring half as a SEPARATE follow-up turn AFTER the handoff is recorded. Never dispatch "logic now, UI when handoff arrives" as one turn — the handoff cannot reach a running turn.
- **Recurrence risk:** Was MEDIUM; now LOW if the escalated rule is followed. This is the second occurrence of the same class — the register's escalation clause applies.

---

## 2026-09-02 — Per-chunk full pipeline has diminishing returns (process decision)

- **What failed (process inefficiency, not an incident):** Five chunks ran the full pipeline (architect scope → design handoff → coding → @review gate) regardless of risk. Cost: 2+ Codex-lane activations per chunk, quota hit 3–4 times. Value analysis: BOTH real review catches (chunk 3 case-sensitivity, chunk 4 time-dropped) lived in data-touching work; pure-UI chunks had nothing for review to find (visual risk is caught best by the user's device review).
- **Decision adopted:** RISK-TIERED pipeline. Tier 2 = schema/RLS/DTO/store-rebuild/persistence/novel-SDK → full pipeline + @review per commit (review reads wiring, not just tests). Tier 1 = pattern-following UI on established data → thin scope → design only if new surface → coding → user visual checkpoint → orchestrator verification → commit; @review batched to milestone closeout. Milestones get one comprehensive closeout audit.
- **Durable rule:** AGENTS.md "Risk-tiered pipeline" section. Unit tests passing is NOT sufficient for Tier 2 — the two real bugs both passed unit tests.
- **Recurrence risk:** N/A (process decision) — monitor at next retrospective whether Tier 1 chunks ship clean without per-commit review.

---

## Review cadence

- The register is reviewed at every milestone retrospective (AGENTS.md "Milestone Retrospectives").
- Entries are never deleted; superseded mitigations are marked, not removed (mirrors design-thoughts.md convention).
- If the same incident class recurs despite a durable rule, the rule itself was insufficient — escalate it to a skill or workflow change, not a longer AGENTS.md note.
