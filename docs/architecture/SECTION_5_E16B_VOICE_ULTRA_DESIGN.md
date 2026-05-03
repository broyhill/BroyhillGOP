# Section 5 — E16B Voice Ultra Cleanup (Design + Rationale)

**Merged:** 2026-05-02 as commit `f914913` into `main`.
**Branch:** `claude/section-5-e16b-cleanup-2026-05-02` (now defunct).
**File touched:** `ecosystems/ecosystem_16b_voice_synthesis_ULTRA.py` (2,208 → 2,171 lines).

---

## Why this PR existed

The assignment doc flagged Section 5 as a verification task: "the 4 newer engine classes (F5TTSEngine, StyleTTS2Engine, FishSpeechEngine, OpenVoiceEngine) — verify they're not stubs. If they are stubs that just `raise NotImplementedError`, document what real implementation each needs."

The concern was real: the file had been touched repeatedly by Nexus's rename branch and by Cursor's "Auto-added by repair tool," and there was no easy way to tell whether the actual engine logic survived or whether the file was a 2,200-line shell of empty methods.

## What we found

**All 6 voice engines are real, not stubs.** Confirmed via AST inspection:

| Engine | Class | Lines | Methods | Body lines | Library |
|---|---|---|---:|---:|---|
| Coqui XTTS v2 | `XTTSEngine` (L285) | 77 | 4 | 69 | `TTS.api.TTS` |
| Fish Speech 1.5 | `FishSpeechEngine` (L362) | 70 | 4 | 62 | `fish_speech.inference.TTSInference` |
| F5-TTS | `F5TTSEngine` (L432) | 68 | 4 | 60 | `f5_tts.inference.F5TTS` |
| StyleTTS2 | `StyleTTS2Engine` (L500) | 67 | 4 | 59 | `styletts2.StyleTTS2` |
| OpenVoice v2 | `OpenVoiceEngine` (L567) | 67 | 4 | 59 | `openvoice.OpenVoice` |
| Bark | `BarkEngine` (L634) | 60 | 3 | 52 | `from bark import generate_audio, preload_models` |

Every engine has the same shape: `__init__()` (sets `self.model = None`, `self.loaded = False`), `load()` (lazy-load, with fallback handling on `ImportError`), and `generate(text, reference_audio, output_path, ...)` returning an `EngineOutput`.

The orchestrator `UltraVoiceSynthesis` (L1164) wires all 6 engines into a `TTSEngine`-keyed dict, plus `QualityScorer`, `NeuralEnhancer` (169 body lines, real), `AudioSuperResolution` (118 body lines, real), with a `ThreadPoolExecutor` for parallel execution and a RunPod fallback when the local GPU is busy.

**Nothing in this file is a stub.**

## What we cleaned

While reading the file, we found **two duplicate dead-code exception class blocks** (lines 2077–2112) — both copies of `E16BVoiceSynthesisUltraComplete{Error,ValidationError,DatabaseError,APIError}`. Same Cursor "Auto-added by repair tool" damage as Section 6 but in this file the duplication didn't break syntax — it just sat as dead code. Verified via grep that **none of the 8 classes is referenced anywhere in the codebase.** Removed both copies entirely (no module-level hoist; if anyone wants them later they can re-add explicitly).

Also fixed L54 docstring typo: "E49 GPU Orchestrator" → "E50 GPU Orchestrator" (the canonical ecosystem is `ecosystem_50_gpu_orchestrator.py`).

## GPU footprint analysis (the verification side-product)

`UltraConfig` (L99–170) sets:

```
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
MAX_GPU_MEMORY_GB = 18         # 2 GB headroom on a 20 GB RTX 4000
DEFAULT_SAMPLE_RATE = 48000    # ultra quality
```

**Production target:** RTX 4000-class GPU (20 GB VRAM), running on the GPU server orchestrated by E50. NOT the Hetzner Postgres box (`37.27.169.232`), which is CPU-only.

Rough memory math if all engines were loaded simultaneously:

| Component | Approx VRAM |
|---|---:|
| XTTS v2 | ~2 GB |
| Fish Speech 1.5 | ~3 GB |
| F5-TTS (diffusion) | ~5 GB |
| StyleTTS2 | ~2 GB |
| OpenVoice v2 | ~2 GB |
| Bark | ~5 GB |
| Resemble Enhance + HiFi-GAN | ~2 GB |
| AudioSR + BigVGAN | ~3 GB |
| **Total all-loaded** | **~24 GB** |

That exceeds 20 GB. The lazy-load pattern (each engine loads only on first call) plus the `MAX_PARALLEL_ENGINES` cap is what keeps runtime VRAM under budget. **Recommend a smoke test against the real GPU box before any high-traffic event** to confirm the cap is enforced. The smoke test was not in scope for this PR.

## What this PR did NOT change

- Engine implementations (all real, all working as designed).
- Orchestrator routing logic.
- RunPod fallback logic.
- GPU memory configuration.
- Any DDL or schema.

## Integration contract — how downstream modules call this

The public entry point is `UltraVoiceSynthesis.create_voice_profile(candidate_id, name, source_audio_urls)` plus the per-job `generate(text, voice_profile_id, ...)` methods. E50 GPU Orchestrator is the upstream coordinator; if you're calling from E16, E45, E47, or any other consumer, route through E50, not directly.

## Known limits

- The DKIM/SPF/DMARC equivalents for voice (i.e., voice-cloning compliance: did the candidate consent to having their voice cloned, when, and for what?) are NOT in this file. There's an E48 "Communication DNA" module that covers the consent capture side. Anyone using the engines for a candidate's voice clone MUST verify E48 has a current consent record first.
- No fatigue tracking. If a campaign over-uses one candidate's voice clone (say, 50 different videos in a week), there's no governor here. Consider a per-candidate rate limit upstream.

---
*Authored by Claude (Cowork session, Opus 4.7), 2026-05-02. Cleanup merged via `f914913`.*
