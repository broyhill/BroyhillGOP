#!/usr/bin/env python3
"""Run on MacBook - Downloads + Clones Jeff Zenger voice"""
import urllib.request, json, base64, time, os, subprocess

TOKEN = "YOUR_REPLICATE_TOKEN_HERE"
OUT = os.path.expanduser("~/Dropbox/BroyhillGOP GOD FILES")
os.makedirs(OUT, exist_ok=True)

SCRIPT = """Hi, I'm Jeff Zenger, your State Representative for House District 74.
As a small business owner and builder for over 30 years, I understand what it takes to create jobs and grow our economy.
I believe in limited government, local decision-making, and protecting your hard-earned tax dollars.
I'm fighting to make homeownership affordable for the next generation.
I'm Jeff Zenger, and I'd be honored to have your vote."""

VIDEOS = [
    ("https://www.youtube.com/watch?v=Wo8ch6oMnFw", 145, 30),
    ("https://www.youtube.com/watch?v=vAwH_yayWyo", 37, 30),
]

print("📥 Downloading Jeff Zenger audio...")
samples = []
for url, start, dur in VIDEOS:
    out = f"{OUT}/jeff_{len(samples)}.mp3"
    subprocess.run(["yt-dlp","-x","--audio-format","mp3",
        "--postprocessor-args",f"-ss {start} -t {dur}","-o",out,url],
        capture_output=True)
    if os.path.exists(out): samples.append(out)

if not samples: print("❌ No audio"); exit(1)

# Combine
combined = f"{OUT}/jeff_combined.mp3"
with open(f"{OUT}/c.txt","w") as f:
    for s in samples: f.write(f"file '{s}'\n")
subprocess.run(["ffmpeg","-y","-f","concat","-safe","0","-i",f"{OUT}/c.txt","-c","copy",combined],capture_output=True)

with open(combined,"rb") as f: audio_b64 = base64.b64encode(f.read()).decode()

print("🎤 Cloning voice on Replicate...")
req = urllib.request.Request("https://api.replicate.com/v1/predictions",
    data=json.dumps({"version":"684bc3855b37866c0c65add2ff39c78f3dea3f4ff103a436465326e0f438d55e",
        "input":{"text":SCRIPT,"speaker":f"data:audio/mp3;base64,{audio_b64}","language":"en"}}).encode(),
    headers={"Authorization":f"Token {TOKEN}","Content-Type":"application/json"},method='POST')
job = json.loads(urllib.request.urlopen(req,timeout=60).read()).get("id")

for i in range(60):
    time.sleep(3)
    data = json.loads(urllib.request.urlopen(urllib.request.Request(
        f"https://api.replicate.com/v1/predictions/{job}",
        headers={"Authorization":f"Token {TOKEN}"}),timeout=30).read())
    print(f"[{i*3}s] {data.get('status')}")
    if data.get("status")=="succeeded":
        url = data.get("output")
        out = f"{OUT}/jeff_zenger_cloned_voice.wav"
        urllib.request.urlretrieve(url, out)
        print(f"✅ {out}")
        break
    if data.get("status")=="failed": print(f"❌ {data.get('error')}"); break
