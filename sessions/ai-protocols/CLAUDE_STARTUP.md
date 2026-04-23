# 🚀 CLAUDE (ANTHROPIC) — BROYHILLGOP SESSION STARTUP PROTOCOL
**AI Agent:** Claude (Anthropic) — claude.ai or API  
**Trigger:** Type `nexus` at the start of any session  
**Last Updated:** 2026-04-23  

---

⚠️ READ THIS ENTIRE DOCUMENT BEFORE WRITING ANY CODE ⚠️

This platform has 55 integrated ecosystems with 905 automated triggers.  
**Writing code without reviewing existing architecture WILL break things.**

---

## STEP 1: BOOT SEQUENCE (Required Every Session)

When the user types `nexus`, you MUST:

1. **Read the Master Plan** — ask user to paste `sessions/ai-protocols/MASTER_PLAN.md` content OR access via project knowledge if available
2. **Search your project knowledge** for: COMPLETE_ECOSYSTEM_REFERENCE.md, BroyhillGOP-Master-Overview, READ_FIRST
3. **Identify the current phase and next task**
4. **Present boot summary:**

```
🔴 NEXUS ONLINE — CLAUDE — [Date]
Platform: BroyhillGOP | 55 Ecosystems | 905 Triggers
Last Known Session: [date from Master Plan]
Current Phase: [Phase X]
Next Queued Task: [specific task]
Blockers: [list or NONE]
Awaiting orders.
```

---

## STEP 2: MANDATORY PRE-CODE PROTOCOL

Before writing ANY code, creating ANY files, or designing ANY architecture:

### The Problem (What Claude Does Wrong)
- Immediately summarizes what it thinks the user wants → then starts coding
- Creates new tables without checking what exists
- Designs architectures that conflict with existing ecosystems
- Duplicates functionality that already exists
- Breaks integration points between ecosystems

**THIS DESTROYS WEEKS OF WORK.**

### What Claude MUST Do FIRST

```
MANDATORY CHECKLIST:
□ Search project knowledge for related ecosystems
□ Identify which E# ecosystems this task affects
□ Verify tables/functions do not already exist
□ Check column names in affected tables
□ Confirm E20 (Intelligence Brain) integration points
□ Ask Eddie to clarify if anything is unclear
□ Understand how changes fit the existing 55-ecosystem architecture
```

### Template Before Coding
> "Before I write any code, let me check the existing architecture:
> - This task affects ecosystems: [E1, E6, E20, etc.]
> - I found existing [table/function] that handles [X]
> - I need to integrate with [specific integration points]
> - Can you confirm [specific question about current state]?"

---

## STEP 3: NEXUS SLEEP PROTOCOL

When the user types `nexus sleep`:

1. **Summarize all work done** this session — decisions, SQL written, architecture designed, issues found
2. **Produce a complete session file** in this format → to be committed to GitHub as `sessions/SESSION_[MONTH]_[DAY]_[YEAR]_CLAUDE.md`
3. **Produce updated MASTER_PLAN.md section** — add to SESSION LOG, update phase status and NEXT SESSION tasks
4. **Provide the user with both documents** ready to paste into GitHub or upload to project knowledge

### NEXUS SLEEP File Template:
```markdown
# SESSION LOG — Claude (Anthropic)
**Date:** [YYYY-MM-DD]  
**Time:** [HH:MM EDT]  
**Agent:** Claude  

## WORK COMPLETED THIS SESSION
- [item 1: SQL / design / analysis]

## KEY DECISIONS MADE
- [decision 1 + rationale]

## SQL / CODE PRODUCED
- [description of code + where it should be committed]

## ARCHITECTURE FINDINGS
- [anything discovered about existing system state]

## OPEN ISSUES / BLOCKERS
- [issue or NONE]

## NEXT SESSION TASKS
1. [task 1]
2. [task 2]
3. [task 3]
```

---

## PLATFORM ARCHITECTURE: 55 Ecosystems

### TIER 1: Core Infrastructure (E0-E7)
- E0: DATA HUB — PostgreSQL/Supabase + Redis event bus
- E1: DONOR INTELLIGENCE — 21-tier grading (A++ to U-), dual state/county grades
- E2: DONATION PROCESSING — FEC-compliant, Stripe/WinRed
- E3: CANDIDATE PROFILES — 273 fields per candidate
- E4: ACTIVIST NETWORK — 52+ conservative organizations
- E5: VOLUNTEER MANAGEMENT — 56 activity types
- E6: ANALYTICS ENGINE — 403+ metrics
- E7: ISSUE TRACKING — 60+ issues with intensity scoring

### TIER 2: Content & AI (E8-E15)
- E8-E15: Comms Library, Content AI, FEC Compliance, Budget, Training LMS, Campaign Ops, AI Hub, Print, Contacts

### TIER 3: Media & Advertising (E16-E21)
- E16: TV/RADIO AI — $8 vs $2,700 traditional
- E16b: ULTRA VOICE — 99.4% cost savings
- E17-E21: RVM, VDP Composition, Social Media, Intelligence Brain (905 triggers), ML Clustering

### TIERS 4-8: Portals, Channels, Advanced, Video, Special
- E22-E29: A/B Testing, 3D Assets, Portals, Dashboards
- E30-E36: Email (SendGrid), SMS (Twilio), Phone Banking, Direct Mail, Events
- E37-E44: Event Mgmt, P2P Fundraising, Automation, Campaign Builder, Advocacy
- E45-E48: Video Studio, Broadcast Hub, AI Scripts, Communication DNA
- E49, E51: Interview System, NEXUS (8 AI agents) — NOTE: E50 does not exist

---

## KEY EXISTING COMPONENTS (Do Not Recreate)

### Database Tables
- `donors` — 1,030+ fields, dual grading
- `persons` — unified contact table
- `voice_generations`, `voice_models`, `voice_queue` — ULTRA Voice (E16b)
- `nc_legislators` — 101 NC GOP legislators
- `candidates` — 273 fields per candidate
- `core.person_spine` — 337K+ rows, unified donor identity
- `core.contribution_map` — 4M+ rows

### Grading Algorithm (Already Implemented)
- `donor_grade_state` + `donor_grade_county`
- `donor_rank_state` + `donor_rank_county`
- `donor_percentile_state` + `donor_percentile_county`
- Grades: A++ (top 0.1%) through D (bottom 30%)

### Python Files
- Location: `/backend/python/ecosystems/`
- Naming: `ecosystem_##_[name].py`

---

## RULES THAT NEVER CHANGE

1. Eddie approves all destructive operations
2. Read RFC-001 and CLAUDE_GUARDRAILS.md every session
3. `voter_rncid` is the universal anchor
4. Never destroy donation records
5. Run large operations on Hetzner (Supabase 2-min timeout)
6. Every session ends with NEXUS SLEEP

---
*BroyhillGOP Platform | $3,520,000+ Development Value | 55 Ecosystems | 905 Triggers*  
*Claude — Primary SQL Architect & Intelligence Designer*
