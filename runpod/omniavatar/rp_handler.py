#!/usr/bin/env python3
"""
============================================================================
OMNIAVATAR RUNPOD SERVERLESS HANDLER
BroyhillGOP E48 ULTRA VIDEO ENGINE - Full-Body Avatar
Replaces: HeyGen, D-ID, Synthesia at 95/100 quality
============================================================================
"""
import runpod
import os
import base64
import tempfile
import subprocess
import requests
from pathlib import Path
import logging
import time

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("omniavatar")

# Paths
OMNIAVATAR_DIR = "/workspace/OmniAvatar"
MODEL_DIR = f"{OMNIAVATAR_DIR}/pretrained_models"

def download_file(url: str, dest: str) -> str:
    """Download file from URL"""
    logger.info(f"Downloading {url}")
    response = requests.get(url, stream=True, timeout=300)
    response.raise_for_status()
    with open(dest, "wb") as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)
    return dest

def base64_to_file(b64_data: str, suffix: str) -> str:
    """Save base64 data to temp file"""
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as f:
        f.write(base64.b64decode(b64_data))
        return f.name

def file_to_base64(filepath: str) -> str:
    """Read file and return base64"""
    with open(filepath, "rb") as f:
        return base64.b64encode(f.read()).decode()

def run_omniavatar(image_path: str, audio_path: str, output_path: str, 
                   prompt: str = "A professional person speaking naturally",
                   num_steps: int = 30, guidance_scale: float = 4.5,
                   audio_scale: float = 3.0) -> dict:
    """
    Run OmniAvatar inference via subprocess (torchrun required by OmniAvatar)
    """
    logger.info(f"Running OmniAvatar inference...")
    start_time = time.time()
    
    # Create input file for OmniAvatar (their required format)
    input_file = tempfile.mktemp(suffix=".txt")
    with open(input_file, "w") as f:
        # Format: prompt@@image_path@@audio_path
        f.write(f"{prompt}@@{image_path}@@{audio_path}\n")
    
    # OmniAvatar requires torchrun for distributed setup even with 1 GPU
    cmd = [
        "torchrun", "--standalone", "--nproc_per_node=1",
        f"{OMNIAVATAR_DIR}/scripts/inference.py",
        "--config", f"{OMNIAVATAR_DIR}/configs/inference_1.3B.yaml",
        "--input_file", input_file,
        f"--hp=num_steps={num_steps},guidance_scale={guidance_scale},audio_scale={audio_scale}"
    ]
    
    try:
        result = subprocess.run(
            cmd,
            cwd=OMNIAVATAR_DIR,
            capture_output=True,
            text=True,
            timeout=600,
            env={**os.environ, "CUDA_VISIBLE_DEVICES": "0"}
        )
        
        if result.returncode != 0:
            logger.error(f"Inference failed: {result.stderr}")
            return {"status": "error", "error": result.stderr[:500]}
        
        # Find output video (OmniAvatar writes to outputs/)
        output_dir = Path(OMNIAVATAR_DIR) / "outputs"
        videos = list(output_dir.glob("*.mp4"))
        if videos:
            latest_video = max(videos, key=lambda p: p.stat().st_mtime)
            subprocess.run(["cp", str(latest_video), output_path], check=True)
            
            elapsed = time.time() - start_time
            logger.info(f"Video generated in {elapsed:.1f}s: {output_path}")
            return {"status": "success", "output_path": output_path, "elapsed": elapsed}
        else:
            return {"status": "error", "error": "No output video found in outputs/"}
            
    except subprocess.TimeoutExpired:
        return {"status": "error", "error": "Inference timeout (600s)"}
    except Exception as e:
        return {"status": "error", "error": str(e)}
    finally:
        try:
            os.unlink(input_file)
        except:
            pass

def handler(job):
    """
    RunPod serverless handler for OmniAvatar full-body video generation.
    
    Input (job["input"]):
        image: base64 encoded image OR
        image_url: URL to download image from
        audio: base64 encoded audio OR
        audio_url: URL to download audio from
        prompt: (optional) motion/behavior control text
        num_steps: (optional) 20-50, default 30
        guidance_scale: (optional) prompt strength, default 4.5
        audio_scale: (optional) lip-sync strength, default 3.0
        
    Output:
        video_base64: base64 encoded MP4 video
        duration: video duration in seconds
        quality_score: 95 (OmniAvatar benchmark rating)
        model: "omniavatar-1.3b"
        elapsed: generation time in seconds
    """
    job_input = job["input"]
    job_id = job.get("id", "unknown")
    
    logger.info(f"Job {job_id}: Starting OmniAvatar generation")
    
    # Track temp files for cleanup
    temp_files = []
    
    try:
        # Get image
        if "image" in job_input:
            image_path = base64_to_file(job_input["image"], ".jpg")
            temp_files.append(image_path)
        elif "image_url" in job_input:
            image_path = tempfile.mktemp(suffix=".jpg")
            temp_files.append(image_path)
            download_file(job_input["image_url"], image_path)
        else:
            return {"error": "No image provided (use 'image' or 'image_url')"}
        
        # Get audio
        if "audio" in job_input:
            audio_path = base64_to_file(job_input["audio"], ".wav")
            temp_files.append(audio_path)
        elif "audio_url" in job_input:
            audio_path = tempfile.mktemp(suffix=".wav")
            temp_files.append(audio_path)
            download_file(job_input["audio_url"], audio_path)
        else:
            return {"error": "No audio provided (use 'audio' or 'audio_url')"}
        
        # Get optional parameters
        prompt = job_input.get("prompt", "A professional person speaking naturally with subtle gestures")
        num_steps = int(job_input.get("num_steps", 30))
        guidance_scale = float(job_input.get("guidance_scale", 4.5))
        audio_scale = float(job_input.get("audio_scale", 3.0))
        
        # Validate parameters
        num_steps = max(20, min(50, num_steps))
        guidance_scale = max(1.0, min(10.0, guidance_scale))
        audio_scale = max(1.0, min(10.0, audio_scale))
        
        # Output path
        output_path = tempfile.mktemp(suffix=".mp4")
        temp_files.append(output_path)
        
        # Run OmniAvatar inference
        result = run_omniavatar(
            image_path, audio_path, output_path,
            prompt=prompt,
            num_steps=num_steps,
            guidance_scale=guidance_scale,
            audio_scale=audio_scale
        )
        
        if result["status"] == "error":
            return {"error": result["error"]}
        
        # Get video duration via ffprobe
        duration = 0.0
        try:
            duration_cmd = ["ffprobe", "-v", "error", "-show_entries", 
                          "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", 
                          output_path]
            duration = float(subprocess.check_output(duration_cmd).decode().strip())
        except Exception as e:
            logger.warning(f"Could not get duration: {e}")
        
        # Encode output video to base64
        video_base64 = file_to_base64(output_path)
        
        logger.info(f"Job {job_id}: Complete - {duration:.1f}s video in {result['elapsed']:.1f}s")
        
        return {
            "video_base64": video_base64,
            "duration": round(duration, 2),
            "quality_score": 95,
            "model": "omniavatar-1.3b",
            "elapsed": round(result["elapsed"], 2)
        }
        
    except Exception as e:
        logger.error(f"Job {job_id}: Error - {str(e)}")
        return {"error": str(e)}
    finally:
        # Cleanup all temp files
        for f in temp_files:
            try:
                os.unlink(f)
            except:
                pass

# RunPod serverless entrypoint - this is the ONLY thing that runs
if __name__ == "__main__":
    runpod.serverless.start({"handler": handler})
