# BROYHILLGOP Formal Development Process
## From Concept to Launch — Industry-Standard Backend & Platform Build

**Document Type:** Master Process Specification  
**Audience:** Non-technical stakeholders, AI assistants, developers  
**Purpose:** Define the formal step-by-step process professionals follow when building a platform of this scale  
**Reference:** NC FIRST (BROYHILLGOP) 1A Platform Architecture (March 12, 2026)  
**Last Updated:** March 12, 2026

---

## Executive Summary

This document translates your conceptual architecture into the **formal software development lifecycle (SDLC)** that enterprise teams use. Each phase has industry jargon, deliverables, and gates. Following this process reduces risk, prevents rework, and ensures the backend is built in the right order before the front-end and AI layers are added.

---

## Industry Jargon Quick Reference

| Term | Plain English |
|------|---------------|
| **SDLC** | Software Development Life Cycle — the full process from idea to live product |
| **BRD** | Business Requirements Document — what the business needs, in business language |
| **FRS** | Functional Requirements Specification — what the system must do, step by step |
| **TRD** | Technical Requirements Document — how it will be built (tech stack, constraints) |
| **SDD** | System Design Document — architecture, data flows, component diagrams |
| **DDD** | Domain-Driven Design — organizing code by business domain (e.g., Donor, Volunteer, Campaign) |
| **ETL** | Extract, Transform, Load — moving data from source systems into your database |
| **API** | Application Programming Interface — how different systems talk to each other |
| **Schema** | Database structure — tables, columns, relationships |
| **Migration** | A script that changes the database structure in a controlled, reversible way |
| **CI/CD** | Continuous Integration / Continuous Deployment — automated build and deploy |
| **UAT** | User Acceptance Testing — real users testing before launch |
| **MVP** | Minimum Viable Product — smallest version that delivers value |
| **ADR** | Architecture Decision Record — why a technical choice was made |

---

## The Full Process — 12 Phases

```
PHASE 0: Discovery & Scoping          →  PHASE 1: Requirements
PHASE 2: Architecture & Design        →  PHASE 3: Data Foundation
PHASE 4: Core Backend                  →  PHASE 5: Integration Layer
PHASE 6: Event & Orchestration         →  PHASE 7: Admin Panel (UI)
PHASE 8: Candidate Interface           →  PHASE 9: AI & Brain
PHASE 10: Testing & QA                 →  PHASE 11: Launch & Operations
```

---

## PHASE 0: Discovery & Scoping

**Jargon:** Stakeholder alignment, scope definition, feasibility study

**What It Is:**  
Before writing code, you lock down what you're building, for whom, and what "done" looks like. This prevents scope creep and ensures everyone (you, AI assistants, future developers) shares the same picture.

**Deliverables:**
- [ ] **Vision document** — One-page summary: BroyhillGOP serves ~3,900 NC Republican candidates with 57 ecosystems, AI Brain, 13+ weapons, cost accounting, LP optimization
- [ ] **Scope boundaries** — What is in v1 vs. future phases (e.g., v1 = Donor Intelligence + Admin + one weapon; v2 = full Wizard)
- [ ] **Stakeholder list** — Who approves what (Eddie = final approval on data, architecture, launch)
- [ ] **Success criteria** — "Launch" means: X candidates onboarded, Y ecosystems live, Z data sources flowing

**BroyhillGOP Status:** ✅ Largely complete (NC FIRST doc, GOD FILE, ecosystem catalog)

**Gate to Phase 1:** Vision and scope signed off; no major unknowns.

---

## PHASE 1: Requirements Gathering

**Jargon:** BRD, FRS, use cases, user stories

**What It Is:**  
Translate the vision into specific, testable requirements. "We need donor intelligence" becomes: "System shall display donor lifetime value by candidate_id," "System shall filter by donation date range," etc.

**Deliverables:**
- [ ] **Business Requirements Document (BRD)** — Business goals, success metrics, constraints (FEC compliance, NCBOE rules, budget)
- [ ] **Functional Requirements Specification (FRS)** — For each ecosystem: what it does, inputs, outputs, rules (e.g., "E01 Donor Intelligence shall show top 50 donors by candidate")
- [ ] **Use cases** — Step-by-step flows: "Candidate logs in → sees Command Center → clicks Donor Intelligence → sees newsfeed → clicks Call to Action"
- [ ] **Non-functional requirements** — Performance (page load < 2 sec), security (auth, encryption), scalability (5,000 candidates)

**BroyhillGOP Status:** ⚠️ Partial — conceptual in NC FIRST doc; needs formal FRS per ecosystem

**Gate to Phase 2:** FRS reviewed; each ecosystem has a requirements section.

---

## PHASE 2: Architecture & Design

**Jargon:** SDD, ADR, system design, data model

**What It Is:**  
Design the technical blueprint before building. This is where you decide: Supabase for DB, Kafka vs. Redis for events, how the Brain talks to ecosystems.

**Deliverables:**
- [ ] **System Design Document (SDD)** — High-level architecture diagram (Brain → Factories → Weapons), component responsibilities
- [ ] **Data model** — Entity-relationship diagram: person_spine, donor_master, contribution_map, etc.
- [ ] **API design** — Which endpoints exist, request/response formats (REST or GraphQL)
- [ ] **Architecture Decision Records (ADRs)** — "We chose Supabase because…" "We chose event bus because…"
- [ ] **Ecosystem dependency map** — Which ecosystems depend on which (E01 depends on E00 DataHub)

**BroyhillGOP Status:** ✅ Strong — NC FIRST doc, RFC-001, NEXUS spec, Control Plane design

**Gate to Phase 3:** Architecture approved; data model matches RFC-001 and ecosystem catalog.

---

## PHASE 3: Data Foundation (Backend Layer 0)

**Jargon:** ETL, schema migration, data normalization, identity resolution

**What It Is:**  
Build the database and load clean data. Nothing else works without this. This is your current focus.

**Deliverables:**
- [ ] **Schema DDL** — SQL scripts creating raw, norm, core schemas (RFC-001)
- [ ] **ETL pipelines** — NCBOE, FEC, WinRed, DataTrust ingestion scripts
- [ ] **Identity resolution** — Multi-pass blocking, person_spine population, golden record linkage
- [ ] **Data validation** — Queries proving match rates, dedup stats, referential integrity
- [ ] **Migration scripts** — Versioned, reversible (e.g., 001_core_schema.sql, 002_norm_tables.sql)

**BroyhillGOP Status:** 🟡 In progress — person_spine 333K, NCBOE/FEC loaded; G2 enrichment, spine collapse, WinRed link pending

**Gate to Phase 4:** core.person_spine validated; norm tables populated; RFC-001 validation queries pass.

---

## PHASE 4: Core Backend (APIs & Business Logic)

**Jargon:** API development, service layer, business logic, CRUD

**What It Is:**  
Build the server-side code that reads/writes the database and exposes APIs. No UI yet — just the engine.

**Deliverables:**
- [ ] **API endpoints** — e.g., `GET /api/donors?candidate_id=X`, `POST /api/campaigns`
- [ ] **Service layer** — Python or TypeScript functions that implement business rules
- [ ] **Database access layer** — Supabase client, connection pooling, query optimization
- [ ] **Authentication & authorization** — Who can access what (candidate vs. admin vs. campaign manager)
- [ ] **Error handling & logging** — Consistent error responses, audit logs

**BroyhillGOP Status:** ⚠️ Partial — Supabase RLS, some Edge Functions; full REST/GraphQL API TBD

**Gate to Phase 5:** Core APIs for E01 (Donor Intelligence) working; can query donors by candidate_id.

---

## PHASE 5: Integration Layer (Event Bus & Connectors)

**Jargon:** Event-driven architecture, message queue, pub/sub, idempotency

**What It Is:**  
Build the nervous system — the event bus (Kafka/Redis) and connectors that let ecosystems talk to each other and the Brain.

**Deliverables:**
- [ ] **Event schema** — Standard event format (event_id, timestamp, source, payload, candidate_ids)
- [ ] **Event producers** — Each ecosystem publishes events when something happens
- [ ] **Event consumers** — Brain, Cost Accounting, LP Optimizer subscribe to relevant events
- [ ] **Connectors** — Integrations to external systems (SendGrid, Twilio, print vendors)
- [ ] **Idempotency** — Same event processed twice = same result (no double-charges)

**BroyhillGOP Status:** 📋 Planned — E08 Communications Library / Event Bus in design; not yet built

**Gate to Phase 6:** Event bus live; at least one ecosystem publishing and one consuming.

---

## PHASE 6: Event Orchestration & Brain (Backend Layer 2)

**Jargon:** Orchestration, workflow engine, state machine, decision engine

**What It Is:**  
Build the Brain's four components (INTAKE, CORTEX, MEMORY, CONDUCTOR) and the Control Plane (toggles, timers).

**Deliverables:**
- [ ] **INTAKE** — Ingests events, validates, tags, queues
- [ ] **CORTEX** — Classifies, routes, scores (topic + geography + urgency)
- [ ] **MEMORY** — Vector store + PostgreSQL for candidate context per ecosystem
- [ ] **CONDUCTOR (NEXUS)** — Attention budget, prioritization, dispatch to ecosystem queues
- [ ] **Control Plane** — Toggle registry, timer logic, AI recommendation escalation
- [ ] **Cost Accounting Bus** — Every operation logs cost, ROI, variance

**BroyhillGOP Status:** 📋 Designed in NC FIRST; NEXUS spec exists; implementation TBD

**Gate to Phase 7:** Brain components stubbed; Control Plane toggles functional; Cost Accounting logging.

---

## PHASE 7: Admin Panel (First UI)

**Jargon:** CRUD UI, dashboard, data tables, admin interface

**What It Is:**  
Build the Inspinia-based admin interface where campaign managers see raw data, run reports, configure settings. This is the "back office" — not the candidate-facing addictive interface.

**Deliverables:**
- [ ] **Admin layout** — Inspinia template, sidebar nav, topbar
- [ ] **Data tables** — Donors, volunteers, donations (DataTables with Supabase backend)
- [ ] **Dashboards** — Charts (ApexCharts/ECharts), KPIs, drill-down
- [ ] **Forms** — Create/edit campaigns, segments, settings
- [ ] **Ecosystem directory** — One admin view per ecosystem (E01, E05, E06, etc.)
- [ ] **Toggle/Control Panel** — UI for the Control Plane (on/off/timer per ecosystem)

**BroyhillGOP Status:** 📋 Inspinia template in repo; wiring to Supabase in progress

**Gate to Phase 8:** Admin can view donors, run basic reports, toggle one ecosystem.

---

## PHASE 8: Candidate Interface (Second UI)

**Jargon:** User experience (UX), newsfeed, call-to-action, gamification

**What It Is:**  
Build the candidate-facing interface — Command Center, ecosystem homepages, newsfeeds, AI recommendations, one-tap actions. This is the "addictive" interface from the NC FIRST doc.

**Deliverables:**
- [ ] **Command Center** — Default homepage, aggregated alerts across ecosystems
- [ ] **Ecosystem homepages** — One per ecosystem (Donor Intelligence, Volunteer, etc.)
- [ ] **Newsfeed** — Infinite scroll, real-time updates, priority-ranked cards
- [ ] **Call-to-action buttons** — "Call donor," "Post response," "Launch campaign"
- [ ] **AI advisor UI** — Chat or inline recommendations per ecosystem
- [ ] **Mobile-responsive** — Works on phone (candidates are on the go)

**BroyhillGOP Status:** 📋 Designed; not built

**Gate to Phase 9:** Candidate can log in, see Command Center, open one ecosystem, act on one alert.

---

## PHASE 9: AI & Brain Integration

**Jargon:** LLM integration, fine-tuning, agent orchestration, RAG (Retrieval-Augmented Generation)

**What It Is:**  
Wire the AI advisors, content generation, and Brain decision logic. This is where the platform becomes "intelligent."

**Deliverables:**
- [ ] **Ecosystem advisors** — One AI agent per ecosystem (or shared with context switching)
- [ ] **Content generation** — Email drafts, SMS, social posts, scripts (via LLM API)
- [ ] **RAG pipeline** — AI retrieves from Memory (candidate context) before generating
- [ ] **AI Wizard** — Multi-stage campaign builder (Q&A → channel mix → audience → content → deploy)
- [ ] **Ecosystem theater handoffs** — Wizard opens E30 Email theater, E31 SMS theater, etc.
- [ ] **LP Optimizer integration** — AI recommendations informed by LP output

**BroyhillGOP Status:** 📋 Fully specified in NC FIRST; implementation TBD

**Gate to Phase 10:** AI can draft one email; Wizard can complete one campaign type (e.g., fundraising email).

---

## PHASE 10: Cost Accounting, LP & Variance

**Jargon:** Cost ledger, budget vs. actual, variance reporting, linear programming

**What It Is:**  
Build the financial backbone — every action logs cost; LP optimizer allocates budget; variance alerts when actual diverges from plan.

**Deliverables:**
- [ ] **Cost ledger** — Table: action_id, cost, roi_projected, roi_actual, candidate_id, ecosystem_id
- [ ] **LP optimizer** — SciPy or OR-Tools; runs daily + on-demand; outputs optimal channel allocation
- [ ] **Variance reporting** — Dashboard: budget vs. actual by ecosystem, channel, candidate
- [ ] **Alert rules** — Variance > 15% triggers notification
- [ ] **Integration with Brain** — Cost Accounting Bus receives events from all layers

**BroyhillGOP Status:** 📋 Designed in NC FIRST, NEXUS; implementation TBD

**Gate to Phase 11:** Cost ledger populated; LP runs; variance report viewable in Admin.

---

## PHASE 11: Testing & Quality Assurance

**Jargon:** Unit tests, integration tests, E2E tests, UAT, load testing

**What It Is:**  
Verify everything works before real users depend on it. Catch bugs in code, not in production.

**Deliverables:**
- [ ] **Unit tests** — Each function/component tested in isolation
- [ ] **Integration tests** — API + database + event bus together
- [ ] **End-to-end (E2E) tests** — Simulate user flow: login → view donor → click action
- [ ] **User Acceptance Testing (UAT)** — Eddie + 2–3 pilot candidates use the system
- [ ] **Load testing** — Can it handle 5,000 candidates? 100 concurrent users?
- [ ] **Security audit** — Auth, encryption, SQL injection, XSS

**BroyhillGOP Status:** 📋 Not started

**Gate to Phase 12:** All critical paths pass tests; UAT sign-off from Eddie.

---

## PHASE 12: Launch & Operations

**Jargon:** Go-live, deployment, monitoring, incident response, change management

**What It Is:**  
Deploy to production, monitor, and operate. Launch is not the end — it's the start of ongoing operations.

**Deliverables:**
- [ ] **Deployment pipeline** — Vercel for frontend, Supabase for DB, automated migrations
- [ ] **Environment separation** — Dev, staging, production (no testing in prod)
- [ ] **Monitoring** — Uptime, error rates, latency, cost (Supabase dashboard, Vercel analytics)
- [ ] **Incident response plan** — Who gets paged when something breaks
- [ ] **Backup & recovery** — Supabase backups; documented restore procedure
- [ ] **Change management** — How new features get deployed (branch → PR → merge → deploy)
- [ ] **Documentation** — Runbooks for common tasks; handoff doc for new developers

**BroyhillGOP Status:** 🟡 Partial — Vercel deploy exists; full ops playbook TBD

**Gate to "Launch Complete":** System live; monitoring active; first 10 candidates onboarded successfully.

---

## Recommended Build Order (Aligned to Your Ambitions)

Based on the NC FIRST doc and your current state:

| Order | Phase | Focus | Est. Effort |
|-------|-------|-------|-------------|
| 1 | **Phase 3** | Finish data foundation (G2, spine collapse, WinRed, FEC voter match) | 2–4 weeks |
| 2 | **Phase 4** | Core APIs for E01 Donor Intelligence | 1–2 weeks |
| 3 | **Phase 7** | Admin Panel — E01 donor tables, basic dashboards | 2–3 weeks |
| 4 | **Phase 5** | Event bus (start small: Supabase Realtime or Redis) | 1–2 weeks |
| 5 | **Phase 8** | Candidate Command Center + E01 ecosystem homepage | 2–3 weeks |
| 6 | **Phase 6** | Brain stubs (INTAKE, CORTEX, MEMORY, CONDUCTOR) | 2–4 weeks |
| 7 | **Phase 9** | AI Wizard — one campaign type (email) | 2–3 weeks |
| 8 | **Phase 10** | Cost Accounting + LP optimizer | 2–3 weeks |
| 9 | **Phase 11** | Testing & UAT | 1–2 weeks |
| 10 | **Phase 12** | Launch & pilot | Ongoing |

**Total to first launch:** ~4–6 months with focused effort.

---

## Process Discipline Rules

1. **No skipping phases** — Data before APIs, APIs before UI, UI before AI.
2. **Gate before next phase** — Don't start Phase 7 until Phase 3 gate is met.
3. **Document decisions** — When you choose a technology or approach, write an ADR.
4. **Version everything** — Schema migrations, API versions, docs. No "just change it."
5. **Eddie approval for writes** — Per your rule: show read-only results first; explicit approval for INSERT/UPDATE/DELETE/DROP.
6. **One ecosystem at a time** — Build E01 perfect, then replicate the pattern. Don't spread thin.

---

## Document Hierarchy (What to Create When)

```
Phase 0–1:  Vision → BRD → FRS
Phase 2:    SDD → Data Model → ADRs
Phase 3:    DDL scripts → ETL scripts → Validation queries
Phase 4:    API spec → Service code → Auth design
Phase 5:    Event schema → Connector specs
Phase 6:    Brain component specs → Control Plane schema
Phase 7–8:  UI wireframes → Component specs
Phase 9:    AI integration spec → Wizard flow
Phase 10:   Cost ledger schema → LP spec
Phase 11:   Test plan → UAT checklist
Phase 12:   Runbook → Incident plan
```

---

## Appendix: Mapping NC FIRST Concepts to Formal Phases

| NC FIRST Concept | Formal Phase | Deliverable |
|------------------|--------------|-------------|
| Data layer (NCBOE, FEC, WinRed, DataTrust) | Phase 3 | ETL, person_spine, norm tables |
| Event Bus, INTAKE | Phase 5, 6 | Event schema, Kafka/Redis, INTAKE service |
| CORTEX, MEMORY, CONDUCTOR | Phase 6 | Classification model, vector store, orchestration logic |
| Control Plane (toggles, timers) | Phase 6 | Toggle registry, escalation logic |
| Cost Accounting, LP Optimizer | Phase 10 | Cost ledger, LP job, variance reports |
| Admin Panel (Inspinia) | Phase 7 | Admin UI, data tables, dashboards |
| Candidate Command Center | Phase 8 | Command Center UI, ecosystem homepages |
| AI Wizard (8 stages) | Phase 9 | Wizard flow, ecosystem theater handoffs |
| Ecosystem Advisors | Phase 9 | AI agents per ecosystem |
| 57 Ecosystems | Phases 4–9 | One at a time; E01 first |

---

*This document is the formal process companion to the conceptual NC FIRST Platform Architecture. Use it as the checklist for every development session.*
