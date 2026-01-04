#!/usr/bin/env python3
"""
JEFF ZENGER VOICE CLONE - Run on MacBook
Same approach that worked for Dave Boliek
"""
import urllib.request, json, base64, time, os, subprocess, sys

REPLICATE_TOKEN = "YOUR_REPLICATE_TOKEN_HERE"

# Jeff Zenger YouTube videos with timestamps
VIDEOS = [
    ("https://www.youtube.com/watch?v=Wo8ch6oMnFw", 145, 30, "jeff_sample_1"),  # 2:25 start
    ("https://www.youtube.com/watch?v=BvyPhhSeKS0", 0, 30, "jeff_sample_2"),
    ("https://www.youtube.com/watch?v=TOAl-AdS9Fs", 9, 30, "jeff_sample_3"),    # 0:09 start
    ("https://www.youtube.com/watch?v=etLFJL8K8cM", 80, 30, "jeff_sample_4"),   # 1:20 start
    ("https://www.youtube.com/watch?v=jtJRKPOvNM8", 0, 30, "jeff_sample_5"),
    ("https://www.youtube.com/watch?v=vAwH_yayWyo", 37, 30, "jeff_sample_6"),   # 0:37 start
]

# Campaign ad script
SCRIPT = """Hi, I'm Jeff Zenger, your State Representative for House District 74.
As a small business owner and builder for over 30 years, I understand what it takes to create jobs and grow our economy.
I believe in limited government, local decision-making, and protecting your hard-earned tax dollars.
I'm fighting to make homeownership affordable for the next generation.
I'm Jeff Zenger, and I'd be honored to have your vote."""

OUT_DIR = os.path.expanduser("~/Dropbox/BroyhillGOP GOD FILES")
os.makedirs(OUT_DIR, exist_ok=True)

def download_audio():
    """Download audio samples from YouTube"""
    print("\n" + "="*60)
    print("STEP 1: DOWNLOADING JEFF ZENGER AUDIO FROM YOUTUBE")
    print("="*60)
    
    combined_audio = f"{OUT_DIR}/jeff_zenger_voice_combined.mp3"
    sample_files = []
    
    for url, start, duration, name in VIDEOS:
        output = f"{OUT_DIR}/{name}.mp3"
        print(f"\n📥 Downloading: {name} (start={start}s, duration={duration}s)")
        
        try:
            cmd = [
                "yt-dlp", "-x", "--audio-format", "mp3",
                "--postprocessor-args", f"-ss {start} -t {duration}",
                "-o", output,
                url
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
            
            if os.path.exists(output):
                print(f"   ✅ Downloaded: {output}")
                sample_files.append(output)
            else:
                print(f"   ⚠️  Failed: {name}")
        except Exception as e:
            print(f"   ❌ Error: {e}")
    
    # Combine all samples into one file
    if sample_files:
        print(f"\n🔗 Combining {len(sample_files)} audio samples...")
        
        # Create concat file
        concat_file = f"{OUT_DIR}/concat_list.txt"
        with open(concat_file, "w") as f:
            for sf in sample_files:
                f.write(f"file '{sf}'\n")
        
        subprocess.run([
            "ffmpeg", "-y", "-f", "concat", "-safe", "0",
            "-i", concat_file,
            "-c", "copy",
            combined_audio
        ], capture_output=True)
        
        if os.path.exists(combined_audio):
            print(f"   ✅ Combined audio: {combined_audio}")
            return combined_audio
    
    # Fallback to first sample
    return sample_files[0] if sample_files else None

def clone_voice(audio_path):
    """Clone voice using Replicate XTTS"""
    print("\n" + "="*60)
    print("STEP 2: CLONING VOICE WITH XTTS ON REPLICATE")
    print("="*60)
    
    # Read and encode audio
    with open(audio_path, "rb") as f:
        audio_b64 = base64.b64encode(f.read()).decode()
    
    headers = {
        "Authorization": f"Token {REPLICATE_TOKEN}",
        "Content-Type": "application/json"
    }
    
    print(f"📤 Uploading voice sample to Replicate...")
    print(f"📝 Script: {SCRIPT[:50]}...")
    
    # Use XTTS v2
    req = urllib.request.Request(
        "https://api.replicate.com/v1/predictions",
        data=json.dumps({
            "version": "684bc3855b37866c0c65add2ff39c78f3dea3f4ff103a436465326e0f438d55e",
            "input": {
                "text": SCRIPT,
                "speaker": f"data:audio/mp3;base64,{audio_b64}",
                "language": "en"
            }
        }).encode(),
        headers=headers,
        method='POST'
    )
    
    result = json.loads(urllib.request.urlopen(req, timeout=60).read())
    job_id = result.get("id")
    print(f"   Job ID: {job_id}")
    
    # Poll for completion
    audio_url = None
    for i in range(60):  # Wait up to 3 minutes
        time.sleep(3)
        
        check_req = urllib.request.Request(
            f"https://api.replicate.com/v1/predictions/{job_id}",
            headers=headers
        )
        data = json.loads(urllib.request.urlopen(check_req, timeout=30).read())
        status = data.get("status")
        print(f"   [{(i+1)*3}s] Status: {status}")
        
        if status == "succeeded":
            audio_url = data.get("output")
            print(f"\n✅ Voice cloned successfully!")
            print(f"   Audio URL: {audio_url}")
            break
        elif status == "failed":
            print(f"\n❌ Voice cloning failed: {data.get('error')}")
            return None
    
    if audio_url:
        # Download the cloned audio
        output_path = f"{OUT_DIR}/jeff_zenger_cloned_voice.wav"
        print(f"\n📥 Downloading cloned audio...")
        urllib.request.urlretrieve(audio_url, output_path)
        print(f"   ✅ Saved: {output_path}")
        return output_path
    
    return None

def main():
    print("\n" + "="*60)
    print("🎬 JEFF ZENGER VOICE CLONE SCRIPT")
    print("="*60)
    print(f"Output directory: {OUT_DIR}")
    
    # Step 1: Download audio
    audio_path = download_audio()
    if not audio_path:
        print("\n❌ Failed to download any audio samples")
        return
    
    # Step 2: Clone voice
    cloned_audio = clone_voice(audio_path)
    if not cloned_audio:
        print("\n❌ Voice cloning failed")
        return
    
    print("\n" + "="*60)
    print("🎉 SUCCESS!")
    print("="*60)
    print(f"\nCloned voice audio: {cloned_audio}")
    print(f"\nNow upload this file to Claude to create the campaign video!")

if __name__ == "__main__":
    main()
