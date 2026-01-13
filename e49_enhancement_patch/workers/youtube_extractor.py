#!/usr/bin/env python3
"""YouTube Extractor - Extract voice from YouTube URLs using yt-dlp"""
import os, re, uuid, tempfile, logging, subprocess
from datetime import datetime
from typing import Optional
from supabase import create_client, Client

logger = logging.getLogger('youtube_extractor')

class YouTubeExtractor:
    YOUTUBE_PATTERNS = [
        r'(?:https?://)?(?:www\.)?youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})',
        r'(?:https?://)?(?:www\.)?youtu\.be/([a-zA-Z0-9_-]{11})',
        r'(?:https?://)?(?:www\.)?youtube\.com/embed/([a-zA-Z0-9_-]{11})',
        r'(?:https?://)?(?:www\.)?youtube\.com/shorts/([a-zA-Z0-9_-]{11})'
    ]
    
    def __init__(self, config):
        self.config = config
        self.supabase = create_client(config.SUPABASE_URL, config.SUPABASE_KEY)
    
    def validate_url(self, url: str) -> bool:
        return any(re.match(pattern, url) for pattern in self.YOUTUBE_PATTERNS)
    
    def _extract_video_id(self, url: str) -> Optional[str]:
        for pattern in self.YOUTUBE_PATTERNS:
            match = re.match(pattern, url)
            if match: return match.group(1)
        return None
    
    async def extract_voice(self, job_id: str, youtube_url: str, candidate_id: str, start_time: Optional[int] = None, end_time: Optional[int] = None, label: Optional[str] = None):
        try:
            self._update_job_status(job_id, "processing", 10)
            video_id = self._extract_video_id(youtube_url)
            if not video_id: raise ValueError("Could not extract video ID")
            with tempfile.TemporaryDirectory() as tmp_dir:
                output_template = os.path.join(tmp_dir, "audio.%(ext)s")
                cmd = ["yt-dlp", "-x", "--audio-format", "wav", "--audio-quality", "0", "-o", output_template, youtube_url]
                if start_time and end_time:
                    cmd.extend(["--download-sections", f"*{start_time}-{end_time}"])
                self._update_job_status(job_id, "downloading", 30)
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
                if result.returncode != 0: raise Exception(f"yt-dlp failed: {result.stderr}")
                audio_files = [f for f in os.listdir(tmp_dir) if f.endswith('.wav')]
                if not audio_files: raise Exception("No audio file generated")
                audio_path = os.path.join(tmp_dir, audio_files[0])
                self._update_job_status(job_id, "uploading", 70)
                sample_id = str(uuid.uuid4())
                storage_path = f"{candidate_id}/{sample_id}.wav"
                with open(audio_path, 'rb') as f:
                    self.supabase.storage.from_(self.config.VOICE_BUCKET).upload(storage_path, f.read(), {"content-type": "audio/wav"})
                public_url = self.supabase.storage.from_(self.config.VOICE_BUCKET).get_public_url(storage_path)
                self._update_job_status(job_id, "completed", 100, sample_url=public_url)
                logger.info(f"YouTube extraction completed: {job_id}")
        except Exception as e:
            logger.error(f"YouTube extraction failed: {e}")
            self._update_job_status(job_id, "failed", 0, error=str(e))
    
    def _update_job_status(self, job_id: str, status: str, progress: int, sample_url: Optional[str] = None, error: Optional[str] = None):
        update_data = {"status": status, "progress": progress, "updated_at": datetime.utcnow().isoformat()}
        if sample_url: update_data["sample_url"] = sample_url
        if error: update_data["error"] = error
        self.supabase.table("voice_extraction_jobs").update(update_data).eq("id", job_id).execute()
