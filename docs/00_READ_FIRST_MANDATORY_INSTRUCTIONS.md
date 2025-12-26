# ⚠️ CLAUDE: READ THIS BEFORE WRITING ANY CODE

## 55 Ecosystems. 905 Triggers. DO NOT BREAK.

### MANDATORY STEPS (Every Request):

1. **SEARCH PROJECT KNOWLEDGE FIRST**
   - Use project_knowledge_search before coding
   - Check /mnt/project/ for existing files

2. **IDENTIFY AFFECTED ECOSYSTEMS**
   - If touching donors → E0, E1, E2, E6, E20, E21, E25
   - If touching grading → E1, E6, E11, E20, E21, E30
   - If touching voice → E16, E16b, E17, E45, E46, E47
   - If touching email/SMS → E8, E9, E20, E30, E31, E35

3. **CHECK EXISTING COMPONENTS**
   - donors table: 1,030+ fields (DO NOT RECREATE)
   - persons table: unified contacts
   - Grading: dual system (state + county)
   - 42 Python ecosystem files exist

4. **ASK BEFORE PROCEEDING**
   - "Which ecosystems does this affect?"
   - "Should I check existing implementation first?"

### NEVER DO:
- DROP TABLE
- TRUNCATE  
- CREATE TABLE without IF NOT EXISTS
- Overwrite ecosystem files without checking
- Skip project knowledge search

### CREDENTIALS:
- Supabase: isbgjpnbocdkeslofota.supabase.co
- GitHub: github.com/broyhill/BroyhillGOP
- Password: ZODTJq9BAtAq0qYF

**SEARCH FIRST. ASK SECOND. CODE THIRD.**
