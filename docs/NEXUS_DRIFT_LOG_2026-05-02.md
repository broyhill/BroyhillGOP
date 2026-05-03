# Nexus Drift Log — 2026-05-02 Session
**Author:** Nexus (Perplexity)
**Date written:** 2026-05-03 — the day after the session
**Purpose:** Honest accounting of where I drifted from the original Feb 17 blueprints, so Claude's blueprint audit catches and resolves it cleanly. Also: preservation of the architectural work that was real and useful, so it doesn't get thrown out alongside the drift.

---

## Why this document exists

On 2026-05-03 morning, Claude confessed that across five months he had been auditing his own writing against itself — reading docstrings he'd written, regrading code he'd produced, never opening the original Feb 17 Perplexity blueprints that defined what each ecosystem was supposed to be.

I (Nexus) am guilty of the same pattern. Last night I had a 7-hour architectural session with Ed during which I built up significant new vocabulary, frameworks, and naming for the platform's ecosystems. **I never opened the Feb 17 blueprints either.** I worked from memory of prior sessions, from the architecture skill, from what felt right in the moment.

Some of last night's work is genuinely useful and Ed valued it. Some of it is drift that needs correction when Claude's audit reaches those ecosystems. This document separates the two so the cleanup is surgical, not wholesale.

---

## Drift Catalog — items that need correction

### Drift #1: E60 reframed as "Nervous Net"

**Original blueprint (Feb 17, updated April 13):** E60_POLL_SURVEY_INTELLIGENCE
- County-level issue intensity scoring from NC poll data
- 6 NC pollsters: Catawba-YouGov, Meredith, HPU, ECU, JLF/Civitas, Cygnal
- 100 NC counties classified into 4-tier ONSP geography
- 8 voter archetypes calibrated from poll responses
- 12 specific tables, 3 Edge Functions
- Primary output: `nc_county_issue_intensity` heat map

**What I (Nexus) did last night:**
- Renamed E60 to "Nervous Net" in the architectural reframe
- Specced E60 as cost ledger + IFTTT rules engine + ML/LP optimizer
- Wrote it into the Brain Pentad (Brain core module)
- Drafted 3 new tables: `core.cost_ledger`, `core.iftt_rules`, `core.iftt_rule_fires`
- Pushed Claude (via the Section 8 paste) to build it that way

**The drift:** I read "E60" and built an ecosystem from scratch without opening the blueprint that defined it. The cost-ledger / IFTTT / ML-optimizer functionality I described is genuinely useful — but it is NOT E60. E60 is a polling intelligence system. The Nervous Net functionality should live somewhere else (probably as a new shared infrastructure module, or split across E20/E40).

**What Claude's audit will find:** A complete blueprint vs. code mismatch. 0 of 12 blueprint tables built. Wrong ecosystem entirely.

**Correction needed:**
1. E60 reverts to its blueprint identity: Poll & Survey Intelligence
2. The Nervous Net functionality (cost ledger, IFTTT, ML/LP optimizer) gets a new home — most likely a shared infrastructure module, NOT a numbered ecosystem
3. The Section 8 work in the backlog should be retitled and rescoped accordingly
4. Any documents I wrote referring to "E60 Nervous Net" should be flagged

### Drift #2: E59 classifier keywords

**What Claude just baked in (per his approved 2026-05-03 amendment):**
```
E59: ["nervous net","cost ledger","ifttt","iftt","rule fire","cost event",
      "ml optimizer","bandit","brain orchestrator"]
```

**Reality:** E59 is **Microsegment Intelligence**, per the architecture skill and the original module map. The keywords above belong to whatever the Nervous Net concept becomes — they do NOT belong to E59.

**Why Claude added them anyway:** Last night's session generated a lot of documents using these terms. To make those documents findable, the classifier needed those keywords pointing somewhere. Claude defaulted to E59 because that was the slot last night's drift had implied.

**Correction needed:** When Claude's audit reaches E59 and reads the actual Microsegment Intelligence blueprint, the keyword list will need to be split:
- True E59 keywords (microsegment, archetype calibration, segment selection, etc.) stay in E59
- Nervous Net keywords move to wherever that functionality lands (likely a new module or shared infrastructure)

### Drift #3: The "Brain Pentad" naming

**What I introduced last night:** The Brain Pentad — five co-equal Brain modules: E01 Grading, E19 Personalization, E30 Send, E11 Budget, E60 Nervous Net.

**The drift:** This is naming I invented during the session. It is not in any blueprint, any prior session note, or any architecture document Ed authorized before last night. The concept of a tightly-coordinated decision loop is sound, but the name "Brain Pentad" is mine, and the membership (E01/E19/E30/E11/E60) was constructed on the fly.

**What's salvageable:** The principle that certain ecosystems need to evolve as a coordinated unit with shared contracts is correct. The name and membership are not authoritative.

**Correction needed:** When Ed reviews the architectural work, the Brain Pentad concept should be tested against the original blueprints and the architecture skill. If the concept survives that test, it gets a Ed-authorized name. If not, it goes in the "Nexus drift" pile.

### Drift #4: E40 as "Funnels"

**What I did last night:** Locked the canonical identity of E40 as "Automation Control Panel (Funnels)" — making "Funnels" a parenthesized first-class identity for the ecosystem.

**The architecture skill says:** E40 = "Automation Control Panel" — n8n + Braze Canvas, the LARGEST module. It does multi-channel orchestration. Funnel logic is implied but not explicit in the skill.

**Honest read:** This is somewhere between drift and clarification. E40 IS the funnel orchestrator in practice — that's what multi-channel orchestration of waterfalls produces. But the canonical name is "Automation Control Panel," not "Funnels." Adding "(Funnels)" as a clarifying tag is reasonable; replacing the canonical name would be drift.

**Correction needed:** Treat "Funnels" as a clarifying parenthetical, not a rename. When the blueprint audit reaches E40, defer to the blueprint's terminology.

### Drift #5: Funnel Library schema

**What I did last night:** Wrote `E40_FUNNELS_ECOSYSTEM_DEFINITION.md` (15KB, 348 lines) with detailed table designs for `funnel_templates`, `funnel_runs`, `funnel_sequences`, `funnel_touches`, `funnel_pattern_signatures`.

**The drift:** I designed these tables without reading the E40 blueprint. The blueprint may already specify table schemas. If it does, mine conflict with what Ed already authorized.

**Correction needed:** When Claude audits E40, compare my proposed schema against the blueprint's schema. If the blueprint has its own table designs, mine are drift and should be discarded or merged.

### Drift #6: HOUSE ON FIRE / EVENT / NEWSLETTER / WELCOME funnel "categories"

**What I did last night:** Specced four named funnel categories with detailed sequences (HOUSE ON FIRE has a 3-sequence arc; WELCOME has a 12-step playbook).

**Honest read:** These categories are useful conceptual shapes. They probably aren't in any Feb 17 blueprint because they emerged from last night's brainstorm with Ed.

**Status:** Not drift exactly — invented during a working session with Ed's authority. But also not Ed-authorized at the architecture level. They're working notes that should be tested against blueprints when ecosystems are audited.

### Drift #7: The 13-dimension funnel sequence schema

**What I did last night:** Drafted 13 dimensions (Trigger Source, Microsegment Targeting, Tier Slice, Channel Mix, Intimacy Level, Content Stage, Money Path, Cadence, Compliance Gates, Capture Mechanism, Cost Cap, Termination Condition, Candidate Voice Calibration).

**Ed's correction during the session:** "the dimensions start the refinement process but not tonight." Ed explicitly deferred refinement.

**Honest read:** I acknowledged in the session that the 13 dimensions were generic-marketing language not yet tuned to NC political reality. Ed parked it. This is drift-shaped (I made up dimensions without blueprint authority) but at least it was caught and parked.

**Status:** Parked, not active. Should not be referenced as authoritative until blueprint comparison happens.

---

## What was real and useful from last night

The drift above is real, but so is the value. These are the items that were genuine architectural progress and should NOT be thrown out:

### Real Item #1: The 4-Layer model (Factories / Weapons / Brain / Sensors)

Not in any blueprint, but a clean conceptual division that organizes how to think about the 60 ecosystems' roles. Useful as a mental model. Not authoritative as a rename of anything. Treat it as taxonomy, not architecture.

### Real Item #2: E20 confirmed as Brain #1

The architecture skill already says E20 is "Central Brain — 905 triggers, <100ms decisions." Last night I corrected my own earlier drift (I had put E60 ahead of E20 in the Pentad). E20 belongs at the top of any Brain conversation. This is the architecture skill's position, not new — but worth noting because I had drifted away from it earlier in the session.

### Real Item #3: E42 as "Call-to-Action Generator"

The architecture skill says E42 is "News Intelligence — Meltwater." Last night I framed E42 as the CTA generator that translates news into actionable payloads. This isn't drift exactly — the architecture skill says E42 generates triggers via E20, and "CTA generation" is a useful framing of that function. Worth checking the blueprint when audit reaches E42.

### Real Item #4: E39 P2P Fundraising is illegal

This is genuinely important and not drift. Federal candidate committees cannot run third-party P2P fundraising under FEC straw-donor / conduit prohibition. E39 should be deleted from the codebase. This recommendation stands regardless of what blueprints say.

### Real Item #5: The 9 Weapons inventory

Locking E16, E16b, E17, E19, E30, E31, E32, E33, E36 as the 9 firing channels was clean and useful. It matches what the architecture skill and weapons code actually do. The "intimacy axis" (1-5) layered on top is mine, not blueprint, but probably useful.

### Real Item #6: The "Every funnel raises money" constitution

Ed's verbatim direction during the session. Three money paths: Activate / Accelerate / Elevate. This is Ed-authorized, not drift. Belongs at the top of any funnel discussion.

### Real Item #7: The 5-Layer Heat Map identification

I located Ed's existing March 31, 2026 doc (`docs/The Complete 5-Layer Heat Map Schema.md`, 486 lines) and confirmed it's NOT wired into any code. The heat map is real architecture Ed authored; the gap between the doc and the code is real and worth flagging.

### Real Item #8: The Two Research Documents

Both research docs (Enterprise Funnel Research, Open-Source AI Components) are external-facing reference material. They cite real sources. They are NOT drift — they are independent research that informs decisions but does not claim ecosystem authority.

### Real Item #9: The donor data work

The 53,720 + 69 cross-spine stamps. The match-tier triage. The trusted view (78,037 rows). The needs-review view (2,568 rows). The E61 spec at `proposals/E61-MATCHING-ENGINE-V1.md`. The dark donor priority queue.

**This is NOT drift. This is real database work Ed authorized in real time.** The numbers are verifiable in the database. The audit log entries are real. This is the most durable work from the session.

---

## How to use this document

When Claude's blueprint audit reaches an ecosystem listed in the Drift Catalog above:
1. Open this document
2. Find the relevant drift entry
3. Apply the correction noted there alongside the blueprint reading
4. Update this document if the audit reveals more or different drift than I caught here

When in doubt: **the Feb 17 blueprints win.** I worked from memory and conversation. Perplexity wrote the blueprints from authority.

The architectural energy from last night was useful — but useful is not the same as authoritative. The blueprints are authoritative. This document exists so the useful work survives the drift correction without taking the drift with it.

---

*Authored honestly. Drift is mine. Correction is welcome. The blueprints are ground truth.*
