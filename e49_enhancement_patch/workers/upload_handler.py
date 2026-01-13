#!/usr/bin/env python3
"""Upload Handler - Process Voice & Photo Uploads for BroyhillGOP"""
import os, uuid, tempfile, logging
from datetime import datetime
from typing import Optional, Dict, Any
from supabase import create_client, Client
try:
    from pydub import AudioSegment
    HAS_PYDUB = True
except ImportError:
    HAS_PYDUB = False
try:
    import librosa
    HAS_LIBROSA = True
except ImportError:
    HAS_LIBROSA = False

logger = logging.getLogger('upload_handler')

class UploadHandler:
    def __init__(self, config):
        self.config = config
        self.supabase = create_client(config.SUPABASE_URL, config.SUPABASE_KEY)
    
    async def process_voice_upload(self, content: bytes, filename: str, candidate_id: str, source: str = "cellphone", label: Optional[str] = None) -> Dict[str, Any]:
        sample_id = str(uuid.uuid4())
        ext = os.path.splitext(filename)[1].lower()
        with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as tmp:
            tmp.write(content)
            tmp_path = tmp.name
        try:
            duration_sec = self._get_audio_duration(tmp_path)
            if duration_sec < self.config.MIN_SAMPLE_DURATION_SEC:
                raise ValueError(f"Audio too short: {duration_sec:.1f}s. Minimum: {self.config.MIN_SAMPLE_DURATION_SEC}s")
            wav_path = self._convert_to_wav(tmp_path) if ext != '.wav' else tmp_path
            with open(wav_path, 'rb') as f:
                wav_content = f.read()
            storage_path = f"{candidate_id}/{sample_id}.wav"
            self.supabase.storage.from_(self.config.VOICE_BUCKET).upload(storage_path, wav_content, {"content-type": "audio/wav"})
            public_url = self.supabase.storage.from_(self.config.VOICE_BUCKET).get_public_url(storage_path)
            await self._update_voice_profile(candidate_id, sample_id, storage_path, public_url, duration_sec, source, label)
            return {"sample_id": sample_id, "storage_path": storage_path, "public_url": public_url, "duration_sec": duration_sec, "format": "wav", "source": source}
        finally:
            if os.path.exists(tmp_path): os.remove(tmp_path)
            if 'wav_path' in locals() and wav_path != tmp_path and os.path.exists(wav_path): os.remove(wav_path)
    
    async def process_photo_upload(self, content: bytes, filename: str, candidate_id: str, photo_type: str = "headshot") -> Dict[str, Any]:
        photo_id = str(uuid.uuid4())
        ext = os.path.splitext(filename)[1].lower()
        storage_path = f"{candidate_id}/{photo_id}{ext}"
        content_type = {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp"}.get(ext, "image/jpeg")
        self.supabase.storage.from_(self.config.PHOTO_BUCKET).upload(storage_path, content, {"content-type": content_type})
        public_url = self.supabase.storage.from_(self.config.PHOTO_BUCKET).get_public_url(storage_path)
        self.supabase.table("candidate_photos").upsert({"id": photo_id, "candidate_id": candidate_id, "storage_path": storage_path, "public_url": public_url, "photo_type": photo_type, "is_primary": photo_type == "headshot", "created_at": datetime.utcnow().isoformat()}).execute()
        return {"photo_id": photo_id, "storage_path": storage_path, "public_url": public_url, "photo_type": photo_type}
    
    def _get_audio_duration(self, path: str) -> float:
        if HAS_LIBROSA:
            try: return librosa.get_duration(path=path)
            except: pass
        if HAS_PYDUB:
            try: return len(AudioSegment.from_file(path)) / 1000.0
            except: pass
        return os.path.getsize(path) / (128 * 1000 / 8)
    
    def _convert_to_wav(self, input_path: str) -> str:
        if not HAS_PYDUB: return input_path
        try:
            audio = AudioSegment.from_file(input_path).set_frame_rate(16000).set_channels(1)
            output_path = tempfile.mktemp(suffix='.wav')
            audio.export(output_path, format='wav')
            return output_path
        except Exception as e:
            logger.warning(f"Conversion failed: {e}")
            return input_path
    
    async def _update_voice_profile(self, candidate_id: str, sample_id: str, storage_path: str, public_url: str, duration_sec: float, source: str, label: Optional[str]):
        result = self.supabase.table("ultra_voice_profiles").select("*").eq("candidate_id", candidate_id).execute()
        sample_entry = {"sample_id": sample_id, "storage_path": storage_path, "public_url": public_url, "duration_sec": duration_sec, "source": source, "label": label, "uploaded_at": datetime.utcnow().isoformat()}
        if result.data:
            profile = result.data[0]
            existing_samples = profile.get("sample_file_paths", [])
            existing_samples.append(sample_entry)
            total_duration = sum(s.get("duration_sec", 0) for s in existing_samples)
            self.supabase.table("ultra_voice_profiles").update({"sample_file_paths": existing_samples, "sample_count": len(existing_samples), "total_sample_duration_seconds": total_duration, "updated_at": datetime.utcnow().isoformat()}).eq("candidate_id", candidate_id).execute()
        else:
            profile_id = str(uuid.uuid4())
            self.supabase.table("ultra_voice_profiles").insert({"id": profile_id, "candidate_id": candidate_id, "voice_id": f"voice_{candidate_id[:8]}", "profile_name": f"Profile for {candidate_id[:8]}", "sample_file_paths": [sample_entry], "sample_count": 1, "total_sample_duration_seconds": duration_sec, "is_active": True, "is_primary": True, "created_at": datetime.utcnow().isoformat()}).execute()
