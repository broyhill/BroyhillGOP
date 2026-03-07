# BroyhillGOP Ecosystem → Inspinia Build Plan
**How to fit 50+ ecosystems into the Inspinia template**

---

## 1. Inspinia template location

| Reference | Actual path |
|-----------|-------------|
| `.cursorrules` says `inspinia-full/` | Template lives at `frontend/inspinia/Inspinia HTML/Full/` |
| `vercel.json` rewrites reference `inspinia-full/` | **Fix:** Update vercel.json to use correct path, or add symlink |

**Action:** Align `vercel.json` rewrites with the real Inspinia location before deployment.

---

## 2. Ecosystem → Inspinia page mapping

### Tier 1: Core data (E0–E7)

| Ecosystem | Inspinia source | BroyhillGOP page | Supabase tables |
|-----------|-----------------|------------------|-----------------|
| E0 DataHub | (backend) | — | All |
| E1 Donor Intelligence | `index.html`, `tables-datatables-*.html`, `widgets.html` | Donors, donor search, grading | donor_golden_records, donor_master_v2 |
| E2 Donation Processing | `ecommerce-order-details.html`, `invoice-details.html` | Donations, receipts | donor_contribution_map, fec_*, nc_boe_* |
| E3 Candidate Profiles | `clients.html`, `pages-profile.html` | Candidates | candidate_profiles |
| E4 Activist Network | `companies.html`, DataTables | Activist orgs, members | (custom) |
| E5 Volunteer Management | `contacts.html`, `calendar.html`, `chat.html` | Volunteers | volunteers_master |
| E6 Analytics Engine | `dashboard-2.html`, `dashboard-3.html`, `metrics.html` | Analytics, ROI | (aggregated) |
| E7 Issue Tracking | `issue-tracker.html` | Issues, positions | (custom) |

### Tier 2: Content & AI (E8–E15)

| Ecosystem | Inspinia source | BroyhillGOP page | Notes |
|-----------|-----------------|------------------|-------|
| E8 Communications Library | `email.html`, form components | Templates, merge fields | Tables in E8 schema |
| E9 Content Creation AI | `email-compose.html`, forms | AI content generation | Calls E13 |
| E10 Compliance Manager | `form-validation.html`, alerts | FEC/state compliance | Compliance tables |
| E11 Budget Management | `dashboard-2.html`, `ecommerce-*.html` | Budget hierarchy | budget_* |
| E11b Training LMS | `form-wizard.html`, `pages-profile.html` | Training, certs | training_* |
| E12 Campaign Operations | `projects.html`, `project-kanban.html`, `pages-timeline.html` | Tasks, milestones | campaigns, tasks |
| E13 AI Hub | (backend) | — | AI routing, costs |
| E14 Print Production | `form-fileuploads.html`, tables | VDP, print jobs | print_* |
| E15 Contact Directory | `contacts.html`, DataTables | Unified contacts | contacts, unified_* |

### Tier 3: Media & advertising (E16–E21)

| Ecosystem | Inspinia source | BroyhillGOP page | Notes |
|-----------|-----------------|------------------|-------|
| E16 TV/Radio AI | `form-wizard.html`, `form-fileuploads.html` | Script, voice, video | Media assets |
| E17 RVM | `form-elements.html`, tables | Voicemail drops | phone_* |
| E18 VDP Composition | `form-wizard.html`, preview | Direct mail composition | (E33) |
| E19 Social Media | `blog.html`, `pin-board.html`, `article.html` | Social posting | social_* |
| E20 Intelligence Brain | `dashboard-2.html`, widgets, alerts | GO/NO-GO, triggers | (backend) |
| E21 ML Clustering | `charts-echart-*.html`, DataTables | Segments, predictions | ml_* |

### Tier 4: Dashboards & portals (E22–E29)

| Ecosystem | Inspinia source | BroyhillGOP page | Notes |
|-----------|-----------------|------------------|-------|
| E22 A/B Testing | `tables-datatables-*.html`, charts | Test management | (E6) |
| E23 Creative Asset 3D | `form-fileuploads.html`, galleries | Asset library | assets_* |
| E24 Candidate Portal | `index.html` + role filter | Candidate dashboard | RLS by candidate_id |
| E25 Donor Portal | `ecommerce-customers.html`, profile | Donor self-service | Donor-facing |
| E26 Volunteer Portal | `contacts.html` + role filter | Volunteer self-service | Volunteer-facing |
| E27 Realtime Dashboard | `dashboard-2.html`, live widgets | Big-screen live view | Real-time |
| E28 Financial Dashboard | `dashboard-2.html`, `ecommerce-*.html` | Budget, cash, variance | financial_* |
| E29 Analytics Dashboard | `dashboard-3.html`, `metrics.html` | Deep analytics | E6 views |

### Tier 5: Communication channels (E30–E36)

| Ecosystem | Inspinia source | BroyhillGOP page | Notes |
|-----------|-----------------|------------------|-------|
| E30 Email | `email.html`, `outlook.html`, `email-compose.html` | Email sends | email_* |
| E31 SMS | `chat.html`, forms | SMS campaigns | sms_* |
| E32 Phone Banking | `contacts.html`, dialer UI | Phone bank | call_* |
| E33 Direct Mail | `form-wizard.html`, `invoice-details.html` | Mail production | mail_* |
| E34 Events | `calendar.html`, `form-wizard.html` | Events, RSVPs | events, event_rsvps |
| E35 Interactive Comm Hub | `chat.html`, unified inbox | Multi-channel inbox | (unified) |
| E36 Messenger | `chat.html` | Messenger/WhatsApp | messenger_* |

### Tier 6–8: Advanced (E37–E51)

| Ecosystem | Inspinia source | BroyhillGOP page |
|-----------|-----------------|------------------|
| E37 Event Management | `calendar.html`, `form-wizard.html`, `invoices.html` | Full event lifecycle |
| E38–E44 | `projects.html`, `issue-tracker.html`, `form-*.html` | Per-ecosystem UIs |
| E45–E49 Video/Broadcast | `form-wizard.html`, `form-fileuploads.html`, preview | Video, scripts, DNA |
| E50–E51 GPU/NEXUS | (backend + dashboard widgets) | AI orchestration |

---

## 3. Build strategy: fit, don’t reproduce

1. **Start from Inspinia source** — Open the Inspinia HTML file for each ecosystem.
2. **Keep layout and markup** — Preserve Bootstrap structure, classes, plugin setup.
3. **Swap content only:**
   - Replace sample data with Supabase `.select()` / RPC calls.
   - Replace logos/favicons with BroyhillGOP branding.
   - Use `.cursorrules` column names (e.g. `canonical_name`, `phone1`, `zip5`).
4. **Wire Supabase** — Each page uses `supabase.from('table').select()` with the correct tables.
5. **Do not remove or simplify** — Keep all 43 plugins and layouts as in Inspinia.

---

## 4. Suggested build order

| Phase | Ecosystems | Inspinia pages | Deliverable |
|-------|------------|----------------|-------------|
| 1 | E1, E5 | index.html, contacts.html, DataTables | Donor + volunteer views |
| 2 | E3, E24 | clients.html, pages-profile.html | Candidate directory + portal |
| 3 | E2, E28 | ecommerce-*.html, dashboard-2 | Donations, financial dashboard |
| 4 | E30, E31, E34 | email.html, chat.html, calendar.html | Email, SMS, events |
| 5 | E6, E27, E29 | dashboard-2, dashboard-3, metrics | Analytics dashboards |
| 6 | E12, E20 | projects.html, project-kanban | Campaign ops, Brain view |
| 7 | E8–E11, E37+ | Remaining forms, wizards | Content, compliance, events |

---

## 5. Vercel routing (update for actual paths)

Current `vercel.json` uses `inspinia-full/` which may not exist. Example fix:

```json
{
  "rewrites": [
    { "source": "/", "destination": "/broyhillgop-homepage.html" },
    { "source": "/donors", "destination": "/frontend/inspinia/Inspinia HTML/Full/src/index.html" },
    { "source": "/volunteers", "destination": "/frontend/inspinia/Inspinia HTML/Full/src/contacts.html" },
    { "source": "/candidates", "destination": "/frontend/inspinia/Inspinia HTML/Full/src/clients.html" },
    { "source": "/analytics", "destination": "/frontend/inspinia/Inspinia HTML/Full/dist/dashboard-2.html" },
    { "source": "/email", "destination": "/frontend/inspinia/Inspinia HTML/Full/src/email.html" },
    { "source": "/calendar", "destination": "/frontend/inspinia/Inspinia HTML/Full/src/calendar.html" },
    { "source": "/settings", "destination": "/frontend/inspinia/Inspinia HTML/Full/src/roles.html" }
  ]
}
```

Or add `inspinia-full` as a symlink to the Full src/dist folder so existing rewrites work.

---

## 6. Data dependency note

Ecosystem pages expect clean donor/candidate/volunteer data. Identity and dedup issues in `donor_golden_records` will affect E1/E2/E24. Build the UI against the schema; fix the data layer separately.

---

## 7. File reference

| Resource | Path |
|----------|------|
| Inspinia Full source | `frontend/inspinia/Inspinia HTML/Full/src/` |
| Inspinia Full dist | `frontend/inspinia/Inspinia HTML/Full/dist/` |
| App CSS | `frontend/inspinia/Inspinia HTML/Full/src/assets/css/app.css` |
| App JS | `frontend/inspinia/Inspinia HTML/Full/src/assets/js/app.js` |
| Page scripts | `frontend/inspinia/Inspinia HTML/Full/src/assets/js/pages/` |
| Ecosystem docs | `docs/COMPLETE_ECOSYSTEM_REFERENCE.md` |
| Ecosystem inventory | `docs/BROYHILLGOP_COMPLETE_ECOSYSTEM_INVENTORY.md` |
