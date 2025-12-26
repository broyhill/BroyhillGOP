# CLAUDE DEPLOYMENT GATE
## MANDATORY: Read Before ANY Deployment

### BLOCKED COMMANDS (Require Validation):
- git push
- git commit  
- supabase db push
- CREATE TABLE / DROP TABLE / ALTER TABLE
- Any SQL on production

### HARD STOPS (Do NOT Proceed):
- DROP TABLE statements
- TRUNCATE statements
- CREATE TABLE without IF NOT EXISTS on existing tables
- Overwriting E0, E1, E20 ecosystems
- Modifying grading algorithm

### VALIDATION CHECKLIST:
1. [ ] Searched project knowledge first
2. [ ] Identified affected ecosystems
3. [ ] Checked existing tables/functions
4. [ ] Asked user before proceeding

**55 ecosystems. 905 triggers. Check before you deploy.**
