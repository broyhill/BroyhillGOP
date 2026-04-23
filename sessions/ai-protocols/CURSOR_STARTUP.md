# 🚀 CURSOR — BROYHILLGOP SESSION STARTUP PROTOCOL
**AI Agent:** Cursor (Claude-powered IDE)  
**Trigger:** Type `nexus` at the start of any session  
**Last Updated:** 2026-04-23  

---

## STEP 1: BOOT SEQUENCE (Required Every Session)

When the user types `nexus`, you MUST:

1. **Pull and read the Master Plan** → `sessions/ai-protocols/MASTER_PLAN.md`
2. **Read the most recent session transcript** from `sessions/` folder
3. **Check current git status** and verify you're on `main` branch
4. **Scan for any incomplete migrations** — look in `supabase/migrations/` for any `.sql` files not yet applied
5. **Present boot summary:**

```
🔴 NEXUS ONLINE — CURSOR — [Date]
Repo: broyhill/BroyhillGOP (main branch)
Last Session: [date] — [summary]
Current Phase: [Phase X]
Pending Migrations: [list or NONE]
Next Build Task: [specific task]
Ready for orders.
```

---

## STEP 2: PRE-CODE MANDATORY CHECKLIST

⚠️ DO NOT WRITE A SINGLE LINE OF CODE until you complete this checklist:

```
BEFORE I PROCEED:
□ Read MASTER_PLAN.md — know the current phase
□ Read BROYHILLGOP_DEVELOPMENT_CONSTITUTION_v1.0.md
□ Read CLAUDE_GUARDRAILS.md
□ Identified which E# ecosystems this task affects
□ Verified no duplicate tables/functions will be created
□ Confirmed integration points with E20 (Intelligence Brain)
□ Eddie has approved any destructive operations
```

---

## STEP 3: NEXUS SLEEP PROTOCOL

When the user types `nexus sleep`:

1. **Summarize all code written** this session — files created, functions added, migrations run
2. **Commit all open changes** to git with message: `[date] - [brief description] - nexus sleep`
3. **Create a dated session file** → `sessions/SESSION_[MONTH]_[DAY]_[YEAR]_CURSOR.md`
4. **Update MASTER_PLAN.md** — add to SESSION LOG, update phase status and NEXT SESSION tasks
5. **Confirm all commits pushed** to GitHub

### NEXUS SLEEP File Template:
```markdown
# SESSION LOG — Cursor AI
**Date:** [YYYY-MM-DD]  
**Time:** [HH:MM EDT]  
**Agent:** Cursor  

## CODE WRITTEN THIS SESSION
- [file path]: [what it does]

## MIGRATIONS RUN
- [migration file]: [result — rows affected]

## TESTS PASSING
- [test name]: PASS/FAIL

## OPEN ISSUES / BLOCKERS
- [issue or NONE]

## GIT COMMITS
- [commit SHA]: [message]

## NEXT SESSION TASKS
1. [task 1]
2. [task 2]
```

---

## PLATFORM ARCHITECTURE RULES

### ❌ FORBIDDEN
- Create new tables without checking if they exist
- Design architectures that conflict with existing ecosystems  
- Start coding immediately — ALWAYS review architecture first
- Modify GitHub code without understanding its role in the 55-ecosystem system
- Run destructive SQL without Eddie's explicit approval

### ✅ REQUIRED
- Check existing `/backend/python/ecosystems/` before creating new files
- Use naming convention: `ecosystem_##_[name].py`
- All new UI must use Inspinia Bootstrap Admin templates
- All database operations go through Supabase (small) or Hetzner psql (large)
- Every PR must reference the ecosystem(s) it affects

---

## INTEGRATION RULES

| If You Touch... | Check These Ecosystems |
|---|---|
| Donor Data | E0, E1, E2, E6, E20, E21, E25, E30, E31, E33 |
| Grading/Scoring | E1, E6, E11, E20, E21, E30 |
| Voice/Audio | E16, E16b, E17, E45, E46, E47, E48 |
| Email/SMS | E8, E9, E20, E30, E31, E35, E40, E41 |
| AI/Content | E9, E13, E20, E41, E47, E48, E51 |
| Database Tables | E0 — all data flows through DataHub |

---

## KEY EXISTING TABLES (Do Not Recreate)

- `donors` — 1,030+ fields, dual grading columns
- `persons` / `core.person_spine` — unified contact/voter identity
- `voice_generations`, `voice_models`, `voice_queue` — ULTRA Voice (E16b)
- `nc_legislators` — 101 NC GOP legislators
- `candidates` — 273 fields per candidate
- `core.contribution_map` — 4M+ rows, all donation sources

---

## KEY REFERENCES

| Resource | Location |
|---|---|
| Master Plan | `sessions/ai-protocols/MASTER_PLAN.md` |
| Constitution | `BROYHILLGOP_DEVELOPMENT_CONSTITUTION_v1.0.md` |
| Guardrails | `CLAUDE_GUARDRAILS.md` |
| Inspinia UI | `/frontend/inspinia/` |
| Python Ecosystems | `/backend/python/ecosystems/` |
| Supabase Migrations | `supabase/migrations/` |

---
*BroyhillGOP Platform | $3,520,000+ Development Value | 55 Ecosystems | 905 Triggers*  
*Cursor — Primary Code Builder & Migration Executor*
