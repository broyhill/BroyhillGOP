# 🎯 BROYHILLGOP DEMO ECOSYSTEM
## Complete AI Video Presentation System

**Version:** 2.0  
**Created:** December 11, 2025  
**Author:** BroyhillGOP Development Team

---

## 🎬 WHAT THIS SYSTEM DOES

A complete end-to-end platform for creating AI-powered video presentations:

1. **Admin Console** - Create screenplays with scripts, voices, avatars, motion
2. **Video Generation** - Automatically generate talking-head videos from photos
3. **Demo Player** - Deliver personalized video experiences to viewers
4. **Analytics** - Track engagement and conversions

### Use Cases
- 💼 **Sales Demos** - Personalized product walkthroughs
- 🖥️ **Product Tours** - Feature showcases with AI presenters
- 📚 **Training Modules** - Employee onboarding videos
- 📰 **News Presentations** - AI anchor-style reports
- 🏛️ **Political Campaigns** - Candidate fundraising demos
- 📈 **Investor Pitches** - Automated pitch presentations

---

## 📦 PACKAGE CONTENTS

```
broyhillgop-demo-ecosystem/
├── sql/
│   └── 001_demo_ecosystem_complete_schema.sql   # Database (17 tables)
├── api/
│   ├── video-generation-api.js                   # HeyGen, D-ID, Synthesia, ElevenLabs
│   ├── supabase-edge-function.ts                 # Serverless backend
│   ├── webhook-handler.ts                        # Async video callbacks
│   ├── demo-orchestration-service.ts             # Generation coordinator
│   └── frontend-client.js                        # Browser API client
├── pages/
│   ├── demo-landing.html                         # Bullseye login page
│   └── demo-player.html                          # Video playback
├── BroyhillGOP_Demo_Creator_Admin.html           # Full admin console (4,500+ lines)
└── README.md
```

---

## 🚀 DEPLOYMENT GUIDE

### Prerequisites

You'll need accounts with:
- **Supabase** (free tier works) - Database & Edge Functions
- **HeyGen** OR **D-ID** - Video generation ($24-180/mo)
- **ElevenLabs** (optional) - Premium voice synthesis ($5-22/mo)

### Step 1: Database Setup (5 minutes)

```bash
# 1. Create Supabase project at https://supabase.com

# 2. Go to SQL Editor

# 3. Copy and run: sql/001_demo_ecosystem_complete_schema.sql

# 4. Verify tables created:
SELECT COUNT(*) FROM demo_ecosystem.tones;  -- Should return 8
SELECT COUNT(*) FROM demo_ecosystem.hot_issues;  -- Should return 15
SELECT COUNT(*) FROM demo_ecosystem.motion_effects;  -- Should return 27
```

### Step 2: Configure API Keys

```bash
# In Supabase Dashboard → Settings → Edge Functions → Secrets

# Add these secrets:
HEYGEN_API_KEY=your_heygen_key
DID_API_KEY=your_did_key
ELEVENLABS_API_KEY=your_elevenlabs_key

# Get keys from:
# - HeyGen: https://app.heygen.com/settings/api
# - D-ID: https://studio.d-id.com/account/api-keys
# - ElevenLabs: https://elevenlabs.io/app/settings/api-keys
```

### Step 3: Deploy Edge Functions

```bash
# Install Supabase CLI
npm install -g supabase

# Login
supabase login

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF

# Deploy video generation function
supabase functions deploy generate-video --no-verify-jwt

# Deploy webhook handler
supabase functions deploy webhook-handler --no-verify-jwt
```

### Step 4: Deploy Frontend Files

```bash
# Option A: Supabase Storage
supabase storage create public
supabase storage cp pages/demo-landing.html storage://public/demo/index.html
supabase storage cp pages/demo-player.html storage://public/demo/player.html
supabase storage cp BroyhillGOP_Demo_Creator_Admin.html storage://public/admin/

# Option B: Vercel/Netlify
vercel deploy pages/

# Option C: Any web server
# Upload HTML files to your hosting provider
```

### Step 5: Configure Frontend Client

Edit `BroyhillGOP_Demo_Creator_Admin.html` and add before closing `</body>`:

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
<script>
window.BroyhillGOP = {
    supabase: supabase.createClient(
        'YOUR_SUPABASE_URL',
        'YOUR_SUPABASE_ANON_KEY'
    ),
    videoApiUrl: 'YOUR_SUPABASE_URL/functions/v1/generate-video'
};
</script>
<script src="api/frontend-client.js"></script>
```

---

## 🎬 HOW IT WORKS

### Flow Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  ADMIN CONSOLE  │────▶│  VIDEO APIS     │────▶│  DEMO PLAYER    │
│                 │     │                 │     │                 │
│ • Write script  │     │ • HeyGen        │     │ • Play videos   │
│ • Choose voice  │     │ • D-ID          │     │ • Show avatars  │
│ • Set motion    │     │ • ElevenLabs    │     │ • Track events  │
│ • Upload photo  │     │ • Synthesia     │     │ • Collect leads │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                      │                       │
         │                      ▼                       │
         │              ┌─────────────────┐             │
         └─────────────▶│   SUPABASE DB   │◀────────────┘
                        │                 │
                        │ • Screenplays   │
                        │ • Elements      │
                        │ • Analytics     │
                        └─────────────────┘
```

### Video Generation Process

1. **Admin creates screenplay** with script, voice, avatar selections
2. **Click "Generate"** triggers Edge Function
3. **Edge Function calls HeyGen/D-ID** with photo + script
4. **Webhook receives callback** when video is ready
5. **Video URL saved** to database
6. **Demo player loads** video segments and plays them

---

## 💰 COSTS

| Service | Free Tier | Paid Plans |
|---------|-----------|------------|
| **Supabase** | 500MB DB, 2GB storage | $25/mo Pro |
| **HeyGen** | 1 min/mo | $24-180/mo |
| **D-ID** | 5 min trial | $5.90-299/mo |
| **ElevenLabs** | 10K chars/mo | $5-330/mo |
| **Synthesia** | - | $22-67/mo |

### Estimated Monthly Cost
- **Starter**: $30-50/mo (D-ID + ElevenLabs starter)
- **Professional**: $100-200/mo (HeyGen + ElevenLabs)
- **Enterprise**: $300+/mo (All services, high volume)

---

## 🔧 API REFERENCE

### Generate Video from Photo

```javascript
const result = await fetch('YOUR_URL/functions/v1/generate-video', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
        action: 'generate-from-photo',
        photoUrl: 'https://example.com/photo.jpg',
        script: 'Hello, welcome to our demo!',
        voiceId: 'en-US-JennyNeural',
        provider: 'heygen'  // or 'did'
    })
});

// Returns: { video_id: 'abc123', status: 'processing' }
```

### Generate Audio Only

```javascript
const result = await fetch('YOUR_URL/functions/v1/generate-video', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
        action: 'generate-audio',
        text: 'Your script text here',
        voiceId: '21m00Tcm4TlvDq8ikWAM',  // ElevenLabs voice ID
        settings: {
            stability: 0.5,
            similarityBoost: 0.75
        }
    })
});

// Returns: { audio: 'base64...', format: 'mp3' }
```

### Check Generation Status

```javascript
const result = await fetch('YOUR_URL/functions/v1/generate-video', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
        action: 'check-status',
        provider: 'heygen',
        jobId: 'abc123'
    })
});

// Returns: { status: 'completed', video_url: 'https://...' }
```

### List Available Voices

```javascript
const result = await fetch('YOUR_URL/functions/v1/generate-video', {
    method: 'POST',
    body: JSON.stringify({
        action: 'list-voices',
        provider: 'elevenlabs'
    })
});

// Returns: { voices: [...] }
```

---

## 📊 DATABASE TABLES

### Core Tables
| Table | Purpose |
|-------|---------|
| `screenplays` | Demo configurations |
| `screenplay_elements` | Individual video segments |
| `pointer_movements` | Avatar pointing sequences |
| `candidates` | Viewer profiles |
| `demo_sessions` | Tracking who watched |
| `demo_analytics` | Engagement events |

### Reference Tables
| Table | Records | Purpose |
|-------|---------|---------|
| `tones` | 8 | Communication styles |
| `messaging_frameworks` | 6 | Message structures |
| `hot_issues` | 15 | Political topics |
| `campaign_channels` | 4 | Outreach channels |
| `motion_effects` | 27 | Video animations |
| `voice_library` | 10 | Voice options |
| `avatar_library` | 16 | Avatar photos |
| `music_library` | 6 | Background tracks |

---

## 🎯 ADMIN CONSOLE FEATURES

### Part 1: Screenplay Setup
- Title & inventory number
- Demo type (12 options)
- Start/end dates
- Purpose description

### Part 2: Campaign Intelligence
- 8 Communication Tones
- 6 Messaging Frameworks
- 15 Hot Issues
- 4 Campaign Channels
- Donor Intelligence settings
- 15 Ecosystem tour selector

### Part 3: Screenplay Elements
- **A. Text to Photo/Video** - AI image/video generation
- **B. Screen Avatar** - Position, size, pointer movements
- **C. Text to Voice** - Full script editor with variables
- **D. Background Music** - Royalty-free library
- **E. Photos & Videos** - Media uploads
- **F. SMS Message** - Text outreach
- **G. Email Outreach** - Email campaigns
- **H. Call Center Script** - Phone scripts

### Part 4: Motion Controls
- 9 Ken Burns effects (zoom, pan)
- 9 Screen transitions
- 10 Entrance/exit animations
- Pointer movement sequences
- 6 Continuous animations

---

## 🔒 SECURITY

### Supabase RLS Policies

```sql
-- Only authenticated users can create screenplays
CREATE POLICY "Users can create screenplays"
ON demo_ecosystem.screenplays
FOR INSERT TO authenticated
WITH CHECK (auth.uid() IS NOT NULL);

-- Users can only view their own screenplays
CREATE POLICY "Users can view own screenplays"
ON demo_ecosystem.screenplays
FOR SELECT TO authenticated
USING (created_by = auth.email());
```

### API Key Protection
- Never expose API keys in frontend code
- Use Supabase Edge Functions as proxy
- Validate all requests server-side

---

## 📞 SUPPORT

- **Documentation**: docs.broyhillgop.com
- **GitHub Issues**: github.com/broyhillgop/demo-ecosystem
- **Email**: support@broyhillgop.com

---

## ✅ DEPLOYMENT CHECKLIST

- [ ] Supabase project created
- [ ] Database schema deployed (17 tables)
- [ ] API keys configured (HeyGen/D-ID/ElevenLabs)
- [ ] Edge functions deployed (generate-video, webhook-handler)
- [ ] Frontend files hosted
- [ ] Supabase URL/keys added to frontend
- [ ] Test video generation
- [ ] Test webhook callbacks
- [ ] Test demo player
- [ ] Configure domain/SSL
- [ ] Set up monitoring

---

## 🎉 READY TO CREATE!

Your AI video presentation system is deployed. 

**Create your first demo:**
1. Open Admin Console
2. Set demo type & purpose
3. Write your script
4. Choose voice & avatar
5. Configure motion
6. Click Generate
7. Share demo link

**Total System:**
- 4,500+ lines of admin console
- 17 database tables
- 5 API modules
- 2 demo pages
- Complete video generation pipeline

🚀 **Start creating amazing AI presentations!**
