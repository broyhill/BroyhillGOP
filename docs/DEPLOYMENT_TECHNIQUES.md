# BroyhillGOP Platform - Deployment Techniques
## Quick Reference for Future Sessions
### Created: December 19, 2025

---

# 🔐 GITHUB ACCESS

## Repository Location
```
/Users/Broyhill/Library/CloudStorage/GoogleDrive-ed@broyhill.net/My Drive/BroyhillGOP/BroyhillGOP-COMPLETE-PLATFORM
```

## Git Configuration
The repo has credentials embedded in `.git/config` - token is stored in the remote URL.
Check the file directly to see the token: `cat .git/config`

## Push Commands (Run via osascript)
```applescript
-- Check status
do shell script "cd '/Users/Broyhill/Library/CloudStorage/GoogleDrive-ed@broyhill.net/My Drive/BroyhillGOP/BroyhillGOP-COMPLETE-PLATFORM' && git status"

-- Stage all changes
do shell script "cd '/Users/Broyhill/Library/CloudStorage/GoogleDrive-ed@broyhill.net/My Drive/BroyhillGOP/BroyhillGOP-COMPLETE-PLATFORM' && git add -A"

-- Commit with message
do shell script "cd '/Users/Broyhill/Library/CloudStorage/GoogleDrive-ed@broyhill.net/My Drive/BroyhillGOP/BroyhillGOP-COMPLETE-PLATFORM' && git commit -m 'Your commit message here'"

-- Push to GitHub
do shell script "cd '/Users/Broyhill/Library/CloudStorage/GoogleDrive-ed@broyhill.net/My Drive/BroyhillGOP/BroyhillGOP-COMPLETE-PLATFORM' && git push origin main"
```

## Full Push Sequence
```applescript
do shell script "cd '/Users/Broyhill/Library/CloudStorage/GoogleDrive-ed@broyhill.net/My Drive/BroyhillGOP/BroyhillGOP-COMPLETE-PLATFORM' && git add -A && git commit -m 'Update' && git push origin main"
```

---

# 🗄️ SUPABASE DEPLOYMENT TECHNIQUE

## The Solution: Clipboard Trick
Claude can't access Supabase directly, so:
1. Use AppleScript to copy SQL to user's clipboard
2. Open Supabase dashboard in Chrome
3. User pastes (Cmd+V) into SQL Editor and clicks Run

## Step-by-Step

### Step 1: Copy SQL to Clipboard
```applescript
set the clipboard to "CREATE TABLE example (id UUID PRIMARY KEY);"
```

### Step 2: Open Supabase
```
Control Chrome:open_url with url "https://supabase.com/dashboard"
```

### Step 3: Tell User
"SQL copied to clipboard! Paste in SQL Editor and click Run."

## Supabase SQL Notes
- Use `gen_random_uuid()` not `uuid_generate_v4()`
- Use `TIMESTAMPTZ` for timestamps
- Add `ON CONFLICT DO NOTHING` for idempotent inserts
- End with SELECT to confirm: `SELECT 'Done!' as status;`

---

# 📁 FILE CREATION

## Via Filesystem tools
```
/Users/Broyhill/Library/CloudStorage/GoogleDrive-ed@broyhill.net/My Drive/BroyhillGOP/...
```

## Via osascript
```applescript
do shell script "cat > '/path/to/file.html' << 'EOF'
content
EOF"
```

---

# 📋 QUICK REFERENCE

| Task | Method |
|------|--------|
| Create file | `Filesystem:write_file` or osascript |
| Git operations | osascript shell script |
| Push to GitHub | Token in .git/config |
| Deploy to Supabase | Clipboard trick |
| Open browser | `Control Chrome:open_url` |

---

*Claude session continuity doc - December 19, 2025*
