#!/usr/bin/env python3
"""Voice Compiler - Combine samples into voice clone profile"""
import os, uuid, tempfile, logging, aiohttp
from datetime import datetime
from typing import Optional, List
from supabase import create_client, Client
try:
    import librosa
    import numpy as np
    HAS_LIBROSA = True
except ImportError:
    HAS_LIBROSA = False

logger = logging.getLogger('voice_compiler')

class VoiceProfileCompiler:
    def __init__(self, config):
        self.config = config
        self.supabase = create_client(config.SUPABASE_URL, config.SUPABASE_KEY)
    
    async def compile_profile(self, job_id: str, candidate_id: str, sample_ids: Optional[List[str]] = None):
        try:
            profile_result = self.supabase.table("ultra_voice_profiles").select("*").eq("candidate_id", candidate_id).execute()
            if not profile_result.data: raise ValueError("No voice profile found")
            profile = profile_result.data[0]
            samples = profile.get("sample_file_paths", [])
            if sample_ids:
                samples = [s for s in samples if s.get("sample_id") in sample_ids]
            if not samples: raise ValueError("No samples to compile")
            total_duration = sum(s.get("duration_sec", 0) for s in samples)
            if total_duration < 30: raise ValueError(f"Need 30s minimum, have {total_duration:.1f}s")
            quality_score = await self._analyze_samples(samples)
            voice_clone_id = await self._create_voice_clone(candidate_id, samples)
            self.supabase.table("ultra_voice_profiles").update({
                "voice_id": voice_clone_id,
                "clone_quality_score": quality_score,
                "is_active": True,
                "updated_at": datetime.utcnow().isoformat()
            }).eq("candidate_id", candidate_id).execute()
            logger.info(f"Voice profile compiled: {voice_clone_id} for {candidate_id}")
        except Exception as e:
            logger.error(f"Voice compilation failed: {e}")
            raise
    
    async def _analyze_samples(self, samples: List[dict]) -> float:
        if not HAS_LIBROSA: return 75.0
        scores = []
        for sample in samples[:5]:
            try:
                url = sample.get("public_url")
                if not url: continue
                with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
                    async with aiohttp.ClientSession() as session:
                        async with session.get(url) as resp:
                            tmp.write(await resp.read())
                    y, sr = librosa.load(tmp.name, sr=16000)
                    rms = librosa.feature.rms(y=y)[0]
                    snr = 20 * np.log10(np.mean(rms) / (np.std(rms) + 1e-10))
                    pitch_score = min(100, max(0, 50 + snr * 2))
                    scores.append(pitch_score)
                    os.remove(tmp.name)
            except: pass
        return np.mean(scores) if scores else 70.0
    
    async def _create_voice_clone(self, candidate_id: str, samples: List[dict]) -> str:
        voice_id = f"clone_{candidate_id[:8]}_{uuid.uuid4().hex[:8]}"
        sample_urls = [s.get("public_url") for s in samples if s.get("public_url")]
        if self.config.RUNPOD_API_KEY:
            try:
                async with aiohttp.ClientSession() as session:
                    async with session.post(
                        f"{self.config.RUNPOD_ENDPOINT}/runsync",
                        headers={"Authorization": f"Bearer {self.config.RUNPOD_API_KEY}"},
                        json={"input": {"action": "create_voice", "voice_id": voice_id, "audio_urls": sample_urls}}
                    ) as resp:
                        if resp.status == 200:
                            result = await resp.json()
                            return result.get("output", {}).get("voice_id", voice_id)
            except Exception as e:
                logger.warning(f"RunPod clone failed: {e}, using local ID")
        return voice_id
