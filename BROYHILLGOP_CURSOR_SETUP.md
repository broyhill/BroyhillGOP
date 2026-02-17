# BroyhillGOP — Cursor + Vercel Setup Guide
**Updated:** February 16, 2026

## What's Been Created For You

Five files are ready to drop into your Cursor project:

### 1. `.cursorrules` (project root)
Tells Cursor's AI everything about BroyhillGOP:
- EXACT Inspinia reproduction mandate (not "inspired by")
- All 43 plugins, CSS variables, font stacks, theme configs
- Supabase table names and tricky column names
- Ecosystem-to-page mapping (10 ecosystems)
- Vercel deployment commands and GitHub repo info
- Coding rules: always reference inspinia-full/ source first

### 2. `.cursor/mcp.json` (enables Supabase in Cursor)
Connects Cursor's AI directly to your Supabase database so it can:
- Query table schemas while writing code
- See real column names and data types
- Generate correct API calls against your 60M+ row database

### 3. `vercel.json` (project root)
Routes for the Vercel deployment:
- `/` → BroyhillGOP homepage (live Supabase data)
- `/donors` → DataTables page
- `/volunteers` → Contacts page
- `/candidates` → Clients page
- `/analytics` → Dashboard page
- `/email` → Email page
- `/calendar` → Calendar page
- `/settings` → Roles/permissions page

### 4. `INSPINIA_TEMPLATE_SPECIFICATION.docx`
16-section specification covering every page, component, chart, form, and plugin.

### 5. `broyhillgop-homepage.html`
Working homepage with live Supabase data — 8 KPI cards, charts, unified search, dark mode.

---

## Setup Steps

### Step 1: Open Project in Cursor
Open Cursor → File → Open Folder → select your BroyhillGOP project folder

### Step 2: Copy These Files In
```
Your project root/
├── .cursorrules                              ← DROP IN
├── .cursor/
│   └── mcp.json                              ← DROP IN
├── vercel.json                               ← DROP IN
├── broyhillgop-homepage.html                 ← DROP IN
├── INSPINIA_TEMPLATE_SPECIFICATION.docx      ← DROP IN
└── inspinia-full/                            ← SHOULD ALREADY EXIST
    ├── index.html (+ 219 more pages)
    ├── assets/css/app.css
    ├── assets/js/app.js
    └── assets/plugins/ (43 libraries)
```

### Step 3: Set Your Tokens
In your terminal (inside Cursor), set your Vercel and GitHub tokens as environment variables:
```bash
export VERCEL_TOKEN="<your-vercel-token>"
export GITHUB_TOKEN="<your-github-token>"
```

Or add them permanently to your shell profile (~/.zshrc or ~/.bash_profile):
```bash
echo 'export VERCEL_TOKEN="<your-vercel-token>"' >> ~/.zshrc
echo 'export GITHUB_TOKEN="<your-github-token>"' >> ~/.zshrc
```

**Tokens are stored in BROYHILLGOP_CREDENTIALS_MASTER.md (local only, not in this repo)**

### Step 4: Restart Cursor
So it picks up .cursorrules and MCP config.
- Open Cursor Settings → MCP
- You should see "supabase" listed as a server

### Step 5: Deploy to Vercel
From the Cursor terminal:
```bash
npx vercel --prod --yes --token=$VERCEL_TOKEN
```

Your site goes live at: https://broyhill-gop.vercel.app

### Step 6: Start Building
Tell Cursor:
> "Build the Donor Intelligence dashboard using index.html from inspinia-full/ as the template. Connect it to donor_master_v2 and donor_donations_v2 tables in Supabase."

Cursor will:
- Read .cursorrules for full context
- Open inspinia-full/index.html for exact layout
- Query Supabase MCP for real table schemas
- Generate code matching Inspinia exactly with live data

---

## Architecture

```
Eddie
  │
  ├── Claude Cowork ──→ Supabase backend, data ops, specs, strategy
  │                      (all 60M rows, dedup, enrichment, tagging)
  │
  ├── Cursor IDE ────→ Frontend code, Inspinia reproduction
  │                      (reads Supabase via MCP, builds UI)
  │
  └── Vercel ────────→ Hosts the live site
                        (auto-deploys from GitHub or manual CLI deploy)

Data Flow:
  Cursor writes code → pushes to GitHub → Vercel auto-deploys
  OR
  Cursor writes code → `vercel --prod` → direct deploy
```

---

## All Credentials (Quick Reference)

| Service | Key | Value |
|---------|-----|-------|
| Supabase URL | SUPABASE_URL | https://isbgjpnbocdkeslofota.supabase.co |
| Supabase Anon Key | SUPABASE_ANON_KEY | (in .cursor/mcp.json) |
| Supabase Service Key | SUPABASE_SERVICE_ROLE_KEY | (in .cursor/mcp.json) |
| Vercel Token | VERCEL_TOKEN | See CREDENTIALS_MASTER.md (local) |
| Cursor API | CURSOR_API_KEY | See CREDENTIALS_MASTER.md (local) |
| GitHub Repo | — | github.com/broyhill/BroyhillGOP |
| GitHub Token | GITHUB_TOKEN | See CREDENTIALS_MASTER.md (local) |

---

## DNS Fix Needed (GoDaddy)
To make broyhillgop.com work with Vercel:
1. Login to GoDaddy DNS management
2. Add A Record: `@` → `76.76.21.21`
3. Add CNAME: `www` → `cname.vercel-dns.com`
4. Wait 5-10 minutes for propagation

---

## Pending Items
- [x] Generate new GitHub PAT ✅ (ghp_sF3SmyVM... — Feb 16, 2026)
- [ ] Fix GoDaddy DNS → Vercel
- [ ] Connect Apollo.io for contact enrichment
- [ ] Replace all static Inspinia sample data with live Supabase queries
