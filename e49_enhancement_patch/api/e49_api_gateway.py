#!/usr/bin/env python3
"""
============================================================================
E49 API GATEWAY - REST Endpoints for BroyhillGOP Video/Voice Platform
============================================================================
This bridges frontend UI to backend processing (E47 Voice, E48 Video).
Author: BroyhillGOP Platform | Version: 1.0.0
============================================================================
"""
import os, uuid, json, logging, tempfile, asyncio
from datetime import datetime
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager
from fastapi import FastAPI, File, UploadFile, Form, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
import aiohttp
from supabase import create_client, Client
from youtube_extractor import YouTubeExtractor
from voice_compiler import VoiceProfileCompiler
from upload_handler import UploadHandler

class Config:
    SUPABASE_URL = os.getenv("SUPABASE_URL", "https://isbgjpnbocdkeslofota.supabase.co")
    SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY", "")
    VOICE_BUCKET = "voice-samples"
    PHOTO_BUCKET = "candidate-photos"
    VIDEO_BUCKET = "generated-videos"
    RUNPOD_API_KEY = os.getenv("RUNPOD_API_KEY", "")
    RUNPOD_ENDPOINT = os.getenv("RUNPOD_ENDPOINT", "")
    HETZNER_GPU_URL = os.getenv("HETZNER_GPU_URL", "http://gpu.broyhillgop.com:8000")
    SUPPORTED_AUDIO_FORMATS = [".mp3", ".wav", ".m4a", ".aac", ".ogg", ".webm"]
    MAX_AUDIO_SIZE_MB = 50
    MIN_SAMPLE_DURATION_SEC = 10
    OPTIMAL_SAMPLE_DURATION_SEC = 30
    SUPPORTED_IMAGE_FORMATS = [".jpg", ".jpeg", ".png", ".webp"]
    MAX_IMAGE_SIZE_MB = 10

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger('e49_api_gateway')

class YouTubeSubmitRequest(BaseModel):
    youtube_url: str = Field(..., description="YouTube video URL")
    candidate_id: str = Field(..., description="Candidate UUID")
    start_time: Optional[int] = Field(None, description="Start time in seconds")
    end_time: Optional[int] = Field(None, description="End time in seconds")
    label: Optional[str] = Field(None, description="Label for this sample")

class VoiceCompileRequest(BaseModel):
    candidate_id: str = Field(..., description="Candidate UUID")
    sample_ids: Optional[List[str]] = Field(None, description="Specific sample IDs to include")
    min_duration_sec: int = Field(30, description="Minimum combined duration")

class VideoGenerateRequest(BaseModel):
    candidate_id: str = Field(..., description="Candidate UUID")
    script: str = Field(..., description="Script text to speak")
    template_id: Optional[str] = Field(None, description="E50 template ID")
    emotion: str = Field("warm", description="Voice emotion preset")
    duration_target: Optional[int] = Field(None, description="Target duration")
    channels: List[str] = Field(["email"], description="Distribution channels")
    ab_variants: Optional[Dict] = Field(None, description="A/B test variants")

class JobStatusResponse(BaseModel):
    job_id: str
    status: str
    progress: int
    created_at: str
    updated_at: str
    result_url: Optional[str] = None
    error: Optional[str] = None

class VoiceProfileResponse(BaseModel):
    profile_id: str
    candidate_id: str
    voice_id: Optional[str]
    sample_count: int
    total_duration_sec: float
    clone_quality_score: Optional[float]
    is_ready: bool
    samples: List[Dict]

def get_supabase() -> Client:
    return create_client(Config.SUPABASE_URL, Config.SUPABASE_KEY)

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("E49 API Gateway starting...")
    yield
    logger.info("E49 API Gateway shutting down...")

app = FastAPI(title="BroyhillGOP E49 API Gateway", description="REST API for Voice/Video Platform", version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
upload_handler = UploadHandler(Config)
youtube_extractor = YouTubeExtractor(Config)
voice_compiler = VoiceProfileCompiler(Config)

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "e49_api_gateway", "timestamp": datetime.utcnow().isoformat(), "version": "1.0.0"}

@app.post("/voice/upload")
async def upload_voice_sample(file: UploadFile = File(...), candidate_id: str = Form(...), source: str = Form("cellphone"), label: Optional[str] = Form(None), background_tasks: BackgroundTasks = None):
    try:
        if not file.filename: raise HTTPException(status_code=400, detail="No file provided")
        ext = os.path.splitext(file.filename)[1].lower()
        if ext not in Config.SUPPORTED_AUDIO_FORMATS: raise HTTPException(status_code=400, detail=f"Unsupported format. Use: {Config.SUPPORTED_AUDIO_FORMATS}")
        content = await file.read()
        if len(content) / (1024*1024) > Config.MAX_AUDIO_SIZE_MB: raise HTTPException(status_code=400, detail=f"File too large. Max: {Config.MAX_AUDIO_SIZE_MB}MB")
        result = await upload_handler.process_voice_upload(content=content, filename=file.filename, candidate_id=candidate_id, source=source, label=label)
        logger.info(f"Voice sample uploaded: {result['sample_id']} for candidate {candidate_id}")
        return {"success": True, "sample_id": result["sample_id"], "storage_path": result["storage_path"], "duration_sec": result["duration_sec"], "format": result["format"], "message": f"Voice sample uploaded successfully ({result['duration_sec']:.1f}s)"}
    except HTTPException: raise
    except Exception as e: logger.error(f"Voice upload failed: {e}"); raise HTTPException(status_code=500, detail=str(e))

@app.post("/youtube/submit")
async def submit_youtube_extraction(request: YouTubeSubmitRequest, background_tasks: BackgroundTasks):
    try:
        if not youtube_extractor.validate_url(request.youtube_url): raise HTTPException(status_code=400, detail="Invalid YouTube URL")
        job_id = str(uuid.uuid4())
        background_tasks.add_task(youtube_extractor.extract_voice, job_id=job_id, youtube_url=request.youtube_url, candidate_id=request.candidate_id, start_time=request.start_time, end_time=request.end_time, label=request.label)
        supabase = get_supabase()
        supabase.table("voice_extraction_jobs").insert({"id": job_id, "candidate_id": request.candidate_id, "youtube_url": request.youtube_url, "status": "queued", "created_at": datetime.utcnow().isoformat()}).execute()
        logger.info(f"YouTube extraction queued: {job_id}")
        return {"success": True, "job_id": job_id, "status": "queued", "message": "YouTube extraction started."}
    except HTTPException: raise
    except Exception as e: logger.error(f"YouTube submission failed: {e}"); raise HTTPException(status_code=500, detail=str(e))

@app.post("/voice/compile")
async def compile_voice_profile(request: VoiceCompileRequest, background_tasks: BackgroundTasks):
    try:
        supabase = get_supabase()
        profile_result = supabase.table("ultra_voice_profiles").select("*").eq("candidate_id", request.candidate_id).execute()
        if not profile_result.data: raise HTTPException(status_code=404, detail="No voice profile found")
        profile = profile_result.data[0]
        sample_paths = profile.get("sample_file_paths", [])
        if not sample_paths: raise HTTPException(status_code=400, detail="No voice samples uploaded yet")
        total_duration = profile.get("total_sample_duration_seconds", 0)
        if total_duration < request.min_duration_sec: raise HTTPException(status_code=400, detail=f"Not enough audio. Have {total_duration:.1f}s, need {request.min_duration_sec}s")
        job_id = str(uuid.uuid4())
        background_tasks.add_task(voice_compiler.compile_profile, job_id=job_id, candidate_id=request.candidate_id, sample_ids=request.sample_ids)
        logger.info(f"Voice compilation queued: {job_id}")
        return {"success": True, "job_id": job_id, "status": "compiling", "samples_count": len(sample_paths), "total_duration_sec": total_duration, "message": "Voice profile compilation started."}
    except HTTPException: raise
    except Exception as e: logger.error(f"Voice compilation failed: {e}"); raise HTTPException(status_code=500, detail=str(e))

@app.post("/photo/upload")
async def upload_candidate_photo(file: UploadFile = File(...), candidate_id: str = Form(...), photo_type: str = Form("headshot")):
    try:
        if not file.filename: raise HTTPException(status_code=400, detail="No file provided")
        ext = os.path.splitext(file.filename)[1].lower()
        if ext not in Config.SUPPORTED_IMAGE_FORMATS: raise HTTPException(status_code=400, detail=f"Unsupported format. Use: {Config.SUPPORTED_IMAGE_FORMATS}")
        content = await file.read()
        if len(content) / (1024*1024) > Config.MAX_IMAGE_SIZE_MB: raise HTTPException(status_code=400, detail=f"File too large. Max: {Config.MAX_IMAGE_SIZE_MB}MB")
        result = await upload_handler.process_photo_upload(content=content, filename=file.filename, candidate_id=candidate_id, photo_type=photo_type)
        logger.info(f"Photo uploaded: {result['photo_id']} for candidate {candidate_id}")
        return {"success": True, "photo_id": result["photo_id"], "storage_path": result["storage_path"], "public_url": result["public_url"], "message": "Photo uploaded successfully"}
    except HTTPException: raise
    except Exception as e: logger.error(f"Photo upload failed: {e}"); raise HTTPException(status_code=500, detail=str(e))

@app.post("/video/generate")
async def generate_video(request: VideoGenerateRequest, background_tasks: BackgroundTasks):
    try:
        supabase = get_supabase()
        profile_result = supabase.table("ultra_voice_profiles").select("*").eq("candidate_id", request.candidate_id).eq("is_active", True).execute()
        if not profile_result.data: raise HTTPException(status_code=400, detail="No active voice profile.")
        profile = profile_result.data[0]
        voice_clone_id = profile.get("voice_id")
        if not voice_clone_id: raise HTTPException(status_code=400, detail="Voice profile not compiled.")
        photo_result = supabase.table("candidate_photos").select("*").eq("candidate_id", request.candidate_id).eq("is_primary", True).execute()
        if not photo_result.data: raise HTTPException(status_code=400, detail="No candidate photo.")
        photo_url = photo_result.data[0].get("public_url")
        job_id = str(uuid.uuid4())
        job_data = {"id": job_id, "job_type": "video_generation", "status": "pending", "candidate_id": request.candidate_id, "input_data": {"script": request.script, "voice_clone_id": voice_clone_id, "image_url": photo_url, "emotion": request.emotion, "template_id": request.template_id, "duration_target": request.duration_target, "channels": request.channels, "ab_variants": request.ab_variants}, "created_at": datetime.utcnow().isoformat()}
        supabase.table("video_jobs").insert(job_data).execute()
        logger.info(f"Video generation queued: {job_id}")
        return {"success": True, "job_id": job_id, "status": "queued", "estimated_time_sec": len(request.script.split()) * 2, "message": "Video generation started."}
    except HTTPException: raise
    except Exception as e: logger.error(f"Video generation failed: {e}"); raise HTTPException(status_code=500, detail=str(e))

@app.get("/jobs/{job_id}/status", response_model=JobStatusResponse)
async def get_job_status(job_id: str):
    try:
        supabase = get_supabase()
        result = supabase.table("video_jobs").select("*").eq("id", job_id).execute()
        if result.data:
            job = result.data[0]
            return JobStatusResponse(job_id=job_id, status=job.get("status", "unknown"), progress=job.get("progress", 0), created_at=job.get("created_at", ""), updated_at=job.get("updated_at", ""), result_url=job.get("output_data", {}).get("video_url"), error=job.get("error"))
        result = supabase.table("voice_extraction_jobs").select("*").eq("id", job_id).execute()
        if result.data:
            job = result.data[0]
            return JobStatusResponse(job_id=job_id, status=job.get("status", "unknown"), progress=job.get("progress", 0), created_at=job.get("created_at", ""), updated_at=job.get("updated_at", ""), result_url=job.get("sample_url"), error=job.get("error"))
        raise HTTPException(status_code=404, detail="Job not found")
    except HTTPException: raise
    except Exception as e: logger.error(f"Job status check failed: {e}"); raise HTTPException(status_code=500, detail=str(e))

@app.get("/voice/profiles/{candidate_id}", response_model=VoiceProfileResponse)
async def get_voice_profiles(candidate_id: str):
    try:
        supabase = get_supabase()
        result = supabase.table("ultra_voice_profiles").select("*").eq("candidate_id", candidate_id).execute()
        if not result.data: raise HTTPException(status_code=404, detail="No voice profile found")
        profile = result.data[0]
        return VoiceProfileResponse(profile_id=profile["id"], candidate_id=candidate_id, voice_id=profile.get("voice_id"), sample_count=profile.get("sample_count", 0), total_duration_sec=float(profile.get("total_sample_duration_seconds", 0)), clone_quality_score=profile.get("clone_quality_score"), is_ready=profile.get("voice_id") is not None, samples=profile.get("sample_file_paths", []))
    except HTTPException: raise
    except Exception as e: logger.error(f"Profile fetch failed: {e}"); raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
