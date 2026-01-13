# E49 Enhancement Patch

REST API layer for BroyhillGOP Video/Voice Platform. Bridges existing frontend UI to backend processing (E47 Voice, E48 Video).

## Deployment

### Step 1: Supabase (Database & Storage)
```sql
-- Run 002_storage_buckets.sql in Supabase SQL Editor
```

### Step 2: Hetzner GPU Server
```bash
cd /opt/broyhillgop/workers
pip install -r requirements.txt
cp e49_api_gateway.py upload_handler.py youtube_extractor.py voice_compiler.py .
uvicorn e49_api_gateway:app --host 0.0.0.0 --port 8080
```

### Step 3: Frontend Integration
Add to candidate_portal/index.html:
```html
<script>window.E49_API_BASE = 'http://gpu.broyhillgop.com:8080';</script>
<script src="portal_integration.js"></script>
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/voice/upload` | POST | Upload voice sample |
| `/youtube/submit` | POST | Extract voice from YouTube |
| `/voice/compile` | POST | Create voice clone |
| `/photo/upload` | POST | Upload candidate photo |
| `/video/generate` | POST | Generate AI video |
| `/jobs/{id}/status` | GET | Check job status |
| `/voice/profiles/{id}` | GET | Get voice profile |

## Environment Variables
```
SUPABASE_URL=https://isbgjpnbocdkeslofota.supabase.co
SUPABASE_ANON_KEY=your_key
RUNPOD_API_KEY=your_key
RUNPOD_ENDPOINT=your_endpoint
HETZNER_GPU_URL=http://gpu.broyhillgop.com:8000
```

## Integration Points
- E47 Voice Engine (Chatterbox TTS)
- E48 Video Engine (Hallo/Wav2Lip)  
- Worker.py (job queue polling)
- Ultra Voice Schema
- E51 Media Library

Created: January 2026
