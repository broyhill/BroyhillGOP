#!/usr/bin/env python3
"""
E49 API GATEWAY - REST Endpoints for BroyhillGOP Video/Voice Platform
Bridges frontend UI to backend processing (E47 Voice, E48 Video, Worker.py)
Author: BroyhillGOP Platform | Version: 1.0.0
"""
import os, uuid, json, logging, asyncio
from datetime import datetime
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager
from fastapi import FastAPI, File, UploadFile, Form, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from supabase import create_client, Client

class Config:
      SUPABASE_URL = os.getenv("SUPABASE_URL", "https://isbgjpnbocdkeslofota.supabase.co")
      SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY", "")
      VOICE_BUCKET = "voice-samples"
      PHOTO_BUCKET = "candidate-photos"
      VIDEO_BUCKET = "generated-videos"
      HETZNER_GPU_URL = os.getenv("HETZNER_GPU_URL", "http://gpu.broyhillgop.com:8000")
      SUPPORTED_AUDIO_FORMATS = [".mp3", ".wav", ".m4a", ".aac", ".ogg", ".webm"]
      MAX_AUDIO_SIZE_MB = 50
      SUPPORTED_IMAGE_FORMATS = [".jpg", ".jpeg", ".png", ".webp"]
      MAX_IMAGE_SIZE_MB = 10

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('e49_api_gateway')

class YouTubeSubmitRequest(BaseModel):
      youtube_url: str
      candidate_id: str
      start_time: Optional[int] = None
      end_time: Optional[int] = None
      label: Optional[str] = None

class VoiceCompileRequest(BaseModel):
      candidate_id: str
      sample_ids: Optional[List[str]] = None
      min_duration_sec: int = 30

class VideoGenerateRequest(BaseModel):
      candidate_id: str
      script: str
      template_id: Optional[str] = None
      emotion: str = "warm"
      channels: List[str] = ["email"]

def get_supabase() -> Client:
      return create_client(Config.SUPABASE_URL, Config.SUPABASE_KEY)

app = FastAPI(title="BroyhillGOP E49 API Gateway", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

@app.get("/health")
async def health_check():
      return {"status": "healthy", "service": "e49_api_gateway", "version": "1.0.0"}

@app.post("/voice/upload")
async def upload_voice_sample(file: UploadFile = File(...), candidate_id: str = Form(...), source: str = Form("cellphone")):
      content = await file.read()
      sample_id = str(uuid.uuid4())
      supabase = get_supabase()
      path = f"{candidate_id}/{sample_id}{os.path.splitext(file.filename)[1]}"
      supabase.storage.from_(Config.VOICE_BUCKET).upload(path, content)
      return {"success": True, "sample_id": sample_id, "storage_path": path}

@app.post("/youtube/submit")
async def submit_youtube_extraction(request: YouTubeSubmitRequest, background_tasks: BackgroundTasks):
      job_id = str(uuid.uuid4())
      supabase = get_supabase()
      supabase.table("voice_extraction_jobs").insert({"id": job_id, "candidate_id": request.candidate_id, "youtube_url": request.youtube_url, "status": "queued"}).execute()
      return {"success": True, "job_id": job_id, "status": "queued"}

@app.post("/photo/upload")
async def upload_candidate_photo(file: UploadFile = File(...), candidate_id: str = Form(...)):
      content = await file.read()
      photo_id = str(uuid.uuid4())
      supabase = get_supabase()
      path = f"{candidate_id}/{photo_id}{os.path.splitext(file.filename)[1]}"
      supabase.storage.from_(Config.PHOTO_BUCKET).upload(path, content)
      return {"success": True, "photo_id": photo_id, "storage_path": path}

@app.post("/video/generate")
async def generate_video(request: VideoGenerateRequest):
      job_id = str(uuid.uuid4())
      supabase = get_supabase()
      supabase.table("video_jobs").insert({"id": job_id, "job_type": "video_generation", "status": "pending", "candidate_id": request.candidate_id, "input_data": {"script": request.script}}).execute()
      return {"success": True, "job_id": job_id, "status": "queued"}

@app.get("/jobs/{job_id}/status")
async def get_job_status(job_id: str):
      supabase = get_supabase()
      result = supabase.table("video_jobs").select("*").eq("id", job_id).execute()
      if result.data:
                return result.data[0]
            raise HTTPException(status_code=404, detail="Job not found")

if __name__ == "__main__":
      import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
