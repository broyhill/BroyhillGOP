/**
 * ============================================================
 * BROYHILLGOP DEMO ECOSYSTEM - VIDEO GENERATION API MODULE
 * ============================================================
 * Complete API integrations for AI video and voice generation
 * 
 * Supported Services:
 * - HeyGen (AI Avatar Videos)
 * - D-ID (Photo Animation)
 * - Synthesia (AI Presenters)
 * - ElevenLabs (Voice Synthesis)
 * - PlayHT (Voice Synthesis Alternative)
 * 
 * Version: 1.0
 * Created: December 11, 2025
 * ============================================================
 */

// ============================================================
// CONFIGURATION
// ============================================================

const CONFIG = {
    // API Keys (set via environment variables in production)
    HEYGEN_API_KEY: process.env.HEYGEN_API_KEY || '',
    DID_API_KEY: process.env.DID_API_KEY || '',
    SYNTHESIA_API_KEY: process.env.SYNTHESIA_API_KEY || '',
    ELEVENLABS_API_KEY: process.env.ELEVENLABS_API_KEY || '',
    PLAYHT_API_KEY: process.env.PLAYHT_API_KEY || '',
    PLAYHT_USER_ID: process.env.PLAYHT_USER_ID || '',
    
    // API Endpoints
    HEYGEN_BASE_URL: 'https://api.heygen.com/v2',
    DID_BASE_URL: 'https://api.d-id.com',
    SYNTHESIA_BASE_URL: 'https://api.synthesia.io/v2',
    ELEVENLABS_BASE_URL: 'https://api.elevenlabs.io/v1',
    PLAYHT_BASE_URL: 'https://api.play.ht/api/v2',
    
    // Webhook URL for async callbacks
    WEBHOOK_BASE_URL: process.env.WEBHOOK_BASE_URL || 'https://your-domain.com/api/webhooks',
    
    // Storage (Supabase)
    SUPABASE_URL: process.env.SUPABASE_URL || '',
    SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY || ''
};

// ============================================================
// HEYGEN API INTEGRATION
// Photo-realistic AI Avatar Videos
// ============================================================

class HeyGenAPI {
    constructor(apiKey = CONFIG.HEYGEN_API_KEY) {
        this.apiKey = apiKey;
        this.baseUrl = CONFIG.HEYGEN_BASE_URL;
    }

    async _request(endpoint, method = 'GET', body = null) {
        const response = await fetch(`${this.baseUrl}${endpoint}`, {
            method,
            headers: {
                'X-Api-Key': this.apiKey,
                'Content-Type': 'application/json'
            },
            body: body ? JSON.stringify(body) : null
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(`HeyGen API Error: ${error.message || response.statusText}`);
        }
        
        return response.json();
    }

    /**
     * List available avatars
     */
    async listAvatars() {
        return this._request('/avatars');
    }

    /**
     * List available voices
     */
    async listVoices() {
        return this._request('/voices');
    }

    /**
     * Create a talking photo video from an uploaded image
     * @param {Object} options
     * @param {string} options.photoUrl - URL of the photo to animate
     * @param {string} options.script - Text for the avatar to speak
     * @param {string} options.voiceId - HeyGen voice ID
     * @param {Object} options.voiceSettings - Speed, pitch adjustments
     */
    async createTalkingPhoto(options) {
        const { photoUrl, script, voiceId, voiceSettings = {} } = options;
        
        const payload = {
            video_inputs: [{
                character: {
                    type: 'talking_photo',
                    talking_photo_url: photoUrl
                },
                voice: {
                    type: 'text',
                    input_text: script,
                    voice_id: voiceId,
                    speed: voiceSettings.speed || 1.0,
                    pitch: voiceSettings.pitch || 0
                }
            }],
            dimension: {
                width: 1920,
                height: 1080
            },
            aspect_ratio: '16:9',
            callback_url: `${CONFIG.WEBHOOK_BASE_URL}/heygen`
        };
        
        return this._request('/video/generate', 'POST', payload);
    }

    /**
     * Create video with pre-built HeyGen avatar
     * @param {Object} options
     * @param {string} options.avatarId - HeyGen avatar ID
     * @param {string} options.script - Text to speak
     * @param {string} options.voiceId - Voice ID
     * @param {string} options.background - Background URL or color
     */
    async createAvatarVideo(options) {
        const { avatarId, script, voiceId, background = '#0A1628' } = options;
        
        const payload = {
            video_inputs: [{
                character: {
                    type: 'avatar',
                    avatar_id: avatarId,
                    avatar_style: 'normal'
                },
                voice: {
                    type: 'text',
                    input_text: script,
                    voice_id: voiceId
                },
                background: {
                    type: 'color',
                    value: background
                }
            }],
            dimension: {
                width: 1920,
                height: 1080
            },
            callback_url: `${CONFIG.WEBHOOK_BASE_URL}/heygen`
        };
        
        return this._request('/video/generate', 'POST', payload);
    }

    /**
     * Create video with custom avatar from uploaded photo
     * @param {Object} options
     */
    async createPhotoAvatar(options) {
        const { photoUrl, name } = options;
        
        const payload = {
            image_url: photoUrl,
            name: name || 'Custom Avatar'
        };
        
        return this._request('/photo_avatar', 'POST', payload);
    }

    /**
     * Get video generation status
     * @param {string} videoId
     */
    async getVideoStatus(videoId) {
        return this._request(`/video/${videoId}`);
    }

    /**
     * Clone a voice from audio sample
     * @param {Object} options
     * @param {string} options.audioUrl - URL of voice sample
     * @param {string} options.name - Name for the cloned voice
     */
    async cloneVoice(options) {
        const { audioUrl, name } = options;
        
        const payload = {
            audio_url: audioUrl,
            name: name
        };
        
        return this._request('/voice/clone', 'POST', payload);
    }
}

// ============================================================
// D-ID API INTEGRATION
// Photo Animation with Voice
// ============================================================

class DIDApi {
    constructor(apiKey = CONFIG.DID_API_KEY) {
        this.apiKey = apiKey;
        this.baseUrl = CONFIG.DID_BASE_URL;
    }

    async _request(endpoint, method = 'GET', body = null) {
        const response = await fetch(`${this.baseUrl}${endpoint}`, {
            method,
            headers: {
                'Authorization': `Basic ${this.apiKey}`,
                'Content-Type': 'application/json'
            },
            body: body ? JSON.stringify(body) : null
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(`D-ID API Error: ${error.message || response.statusText}`);
        }
        
        return response.json();
    }

    /**
     * Create a talking head video from photo
     * @param {Object} options
     * @param {string} options.sourceUrl - Photo URL
     * @param {string} options.script - Text to speak
     * @param {string} options.provider - Voice provider (microsoft, amazon, elevenlabs)
     * @param {string} options.voiceId - Voice ID for the provider
     */
    async createTalk(options) {
        const { sourceUrl, script, provider = 'microsoft', voiceId = 'en-US-GuyNeural' } = options;
        
        const payload = {
            source_url: sourceUrl,
            script: {
                type: 'text',
                input: script,
                provider: {
                    type: provider,
                    voice_id: voiceId
                }
            },
            config: {
                fluent: true,
                pad_audio: 0.5,
                stitch: true
            },
            webhook: `${CONFIG.WEBHOOK_BASE_URL}/did`
        };
        
        return this._request('/talks', 'POST', payload);
    }

    /**
     * Create talk with audio file instead of text
     * @param {Object} options
     * @param {string} options.sourceUrl - Photo URL
     * @param {string} options.audioUrl - Pre-generated audio URL
     */
    async createTalkWithAudio(options) {
        const { sourceUrl, audioUrl } = options;
        
        const payload = {
            source_url: sourceUrl,
            script: {
                type: 'audio',
                audio_url: audioUrl
            },
            config: {
                fluent: true,
                stitch: true
            },
            webhook: `${CONFIG.WEBHOOK_BASE_URL}/did`
        };
        
        return this._request('/talks', 'POST', payload);
    }

    /**
     * Get talk/video status
     * @param {string} talkId
     */
    async getTalkStatus(talkId) {
        return this._request(`/talks/${talkId}`);
    }

    /**
     * List available presenters
     */
    async listPresenters() {
        return this._request('/clips/presenters');
    }

    /**
     * Create clip with D-ID presenter
     * @param {Object} options
     */
    async createClip(options) {
        const { presenterId, script, voiceId } = options;
        
        const payload = {
            presenter_id: presenterId,
            script: {
                type: 'text',
                input: script,
                provider: {
                    type: 'microsoft',
                    voice_id: voiceId
                }
            },
            webhook: `${CONFIG.WEBHOOK_BASE_URL}/did`
        };
        
        return this._request('/clips', 'POST', payload);
    }
}

// ============================================================
// SYNTHESIA API INTEGRATION
// Professional AI Video Presenters
// ============================================================

class SynthesiaAPI {
    constructor(apiKey = CONFIG.SYNTHESIA_API_KEY) {
        this.apiKey = apiKey;
        this.baseUrl = CONFIG.SYNTHESIA_BASE_URL;
    }

    async _request(endpoint, method = 'GET', body = null) {
        const response = await fetch(`${this.baseUrl}${endpoint}`, {
            method,
            headers: {
                'Authorization': this.apiKey,
                'Content-Type': 'application/json'
            },
            body: body ? JSON.stringify(body) : null
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(`Synthesia API Error: ${error.message || response.statusText}`);
        }
        
        return response.json();
    }

    /**
     * List available avatars
     */
    async listAvatars() {
        return this._request('/avatars');
    }

    /**
     * List available voices
     */
    async listVoices() {
        return this._request('/voices');
    }

    /**
     * Create a video
     * @param {Object} options
     * @param {string} options.title - Video title
     * @param {string} options.avatarId - Synthesia avatar ID
     * @param {string} options.voiceId - Voice ID
     * @param {string} options.script - Script text
     * @param {Object} options.background - Background settings
     */
    async createVideo(options) {
        const { 
            title, 
            avatarId = 'anna_costume1_cameraA', 
            voiceId = 'en-US-JennyNeural',
            script,
            background = { color: '#0A1628' }
        } = options;
        
        const payload = {
            title,
            input: [{
                scriptText: script,
                avatar: avatarId,
                avatarSettings: {
                    voice: voiceId,
                    horizontalAlign: 'center',
                    scale: 1.0,
                    style: 'rectangular',
                    seamless: false
                },
                background: background.type === 'image' 
                    ? { type: 'image', url: background.url }
                    : { type: 'color', color: background.color || '#0A1628' }
            }],
            aspectRatio: '16:9',
            callbackUrl: `${CONFIG.WEBHOOK_BASE_URL}/synthesia`
        };
        
        return this._request('/videos', 'POST', payload);
    }

    /**
     * Create video from template
     * @param {Object} options
     */
    async createFromTemplate(options) {
        const { templateId, templateData } = options;
        
        const payload = {
            templateId,
            templateData,
            callbackUrl: `${CONFIG.WEBHOOK_BASE_URL}/synthesia`
        };
        
        return this._request('/videos/fromTemplate', 'POST', payload);
    }

    /**
     * Get video status
     * @param {string} videoId
     */
    async getVideoStatus(videoId) {
        return this._request(`/videos/${videoId}`);
    }

    /**
     * Create personal avatar from video submission
     * @param {Object} options
     */
    async createPersonalAvatar(options) {
        const { name, videoUrl, consentVideoUrl } = options;
        
        const payload = {
            name,
            trainingVideoUrl: videoUrl,
            consentVideoUrl
        };
        
        return this._request('/avatars', 'POST', payload);
    }
}

// ============================================================
// ELEVENLABS API INTEGRATION
// Ultra-Realistic Voice Synthesis
// ============================================================

class ElevenLabsAPI {
    constructor(apiKey = CONFIG.ELEVENLABS_API_KEY) {
        this.apiKey = apiKey;
        this.baseUrl = CONFIG.ELEVENLABS_BASE_URL;
    }

    async _request(endpoint, method = 'GET', body = null, isAudio = false) {
        const response = await fetch(`${this.baseUrl}${endpoint}`, {
            method,
            headers: {
                'xi-api-key': this.apiKey,
                'Content-Type': 'application/json'
            },
            body: body ? JSON.stringify(body) : null
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(`ElevenLabs API Error: ${error.detail || response.statusText}`);
        }
        
        if (isAudio) {
            return response.arrayBuffer();
        }
        
        return response.json();
    }

    /**
     * List all available voices
     */
    async listVoices() {
        return this._request('/voices');
    }

    /**
     * Get voice details
     * @param {string} voiceId
     */
    async getVoice(voiceId) {
        return this._request(`/voices/${voiceId}`);
    }

    /**
     * Generate speech from text
     * @param {Object} options
     * @param {string} options.voiceId - Voice ID
     * @param {string} options.text - Text to speak
     * @param {Object} options.voiceSettings - Stability, similarity boost, style
     * @param {string} options.modelId - Model to use (eleven_monolingual_v1, eleven_multilingual_v2)
     * @returns {ArrayBuffer} Audio data
     */
    async textToSpeech(options) {
        const { 
            voiceId, 
            text, 
            voiceSettings = {},
            modelId = 'eleven_monolingual_v1'
        } = options;
        
        const payload = {
            text,
            model_id: modelId,
            voice_settings: {
                stability: voiceSettings.stability || 0.5,
                similarity_boost: voiceSettings.similarityBoost || 0.75,
                style: voiceSettings.style || 0,
                use_speaker_boost: voiceSettings.useSpeakerBoost || true
            }
        };
        
        return this._request(`/text-to-speech/${voiceId}`, 'POST', payload, true);
    }

    /**
     * Generate speech with timestamps (for lip sync)
     * @param {Object} options
     */
    async textToSpeechWithTimestamps(options) {
        const { voiceId, text, voiceSettings = {} } = options;
        
        const payload = {
            text,
            model_id: 'eleven_monolingual_v1',
            voice_settings: {
                stability: voiceSettings.stability || 0.5,
                similarity_boost: voiceSettings.similarityBoost || 0.75
            }
        };
        
        return this._request(`/text-to-speech/${voiceId}/with-timestamps`, 'POST', payload);
    }

    /**
     * Clone a voice from audio samples
     * @param {Object} options
     * @param {string} options.name - Voice name
     * @param {string} options.description - Voice description
     * @param {Array<string>} options.audioUrls - URLs of audio samples
     */
    async cloneVoice(options) {
        const { name, description, audioUrls } = options;
        
        // For instant voice cloning
        const formData = new FormData();
        formData.append('name', name);
        formData.append('description', description || '');
        
        // Fetch audio files and add to form
        for (const url of audioUrls) {
            const response = await fetch(url);
            const blob = await response.blob();
            formData.append('files', blob, 'sample.mp3');
        }
        
        const response = await fetch(`${this.baseUrl}/voices/add`, {
            method: 'POST',
            headers: {
                'xi-api-key': this.apiKey
            },
            body: formData
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(`ElevenLabs Clone Error: ${error.detail}`);
        }
        
        return response.json();
    }

    /**
     * Delete a cloned voice
     * @param {string} voiceId
     */
    async deleteVoice(voiceId) {
        return this._request(`/voices/${voiceId}`, 'DELETE');
    }

    /**
     * Get user subscription info
     */
    async getSubscription() {
        return this._request('/user/subscription');
    }
}

// ============================================================
// PLAYHT API INTEGRATION
// Alternative Voice Synthesis
// ============================================================

class PlayHTAPI {
    constructor(apiKey = CONFIG.PLAYHT_API_KEY, userId = CONFIG.PLAYHT_USER_ID) {
        this.apiKey = apiKey;
        this.userId = userId;
        this.baseUrl = CONFIG.PLAYHT_BASE_URL;
    }

    async _request(endpoint, method = 'GET', body = null) {
        const response = await fetch(`${this.baseUrl}${endpoint}`, {
            method,
            headers: {
                'Authorization': `Bearer ${this.apiKey}`,
                'X-User-Id': this.userId,
                'Content-Type': 'application/json'
            },
            body: body ? JSON.stringify(body) : null
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(`PlayHT API Error: ${error.message || response.statusText}`);
        }
        
        return response.json();
    }

    /**
     * List available voices
     */
    async listVoices() {
        return this._request('/voices');
    }

    /**
     * Generate speech
     * @param {Object} options
     */
    async generateSpeech(options) {
        const { text, voice, quality = 'premium', speed = 1.0 } = options;
        
        const payload = {
            text,
            voice,
            quality,
            speed,
            output_format: 'mp3'
        };
        
        return this._request('/tts', 'POST', payload);
    }

    /**
     * Clone voice
     * @param {Object} options
     */
    async cloneVoice(options) {
        const { name, sampleFileUrl } = options;
        
        const payload = {
            voice_name: name,
            sample_file_url: sampleFileUrl
        };
        
        return this._request('/cloned-voices', 'POST', payload);
    }
}

// ============================================================
// UNIFIED VIDEO GENERATION SERVICE
// High-level abstraction over all providers
// ============================================================

class VideoGenerationService {
    constructor(config = {}) {
        this.heygen = new HeyGenAPI(config.heygenKey);
        this.did = new DIDApi(config.didKey);
        this.synthesia = new SynthesiaAPI(config.synthesiaKey);
        this.elevenlabs = new ElevenLabsAPI(config.elevenlabsKey);
        this.playht = new PlayHTAPI(config.playhtKey, config.playhtUserId);
        
        this.defaultProvider = config.defaultProvider || 'heygen';
    }

    /**
     * Generate video from photo and script
     * @param {Object} options
     * @param {string} options.provider - 'heygen', 'did', or 'synthesia'
     * @param {string} options.photoUrl - URL of photo to animate
     * @param {string} options.script - Text for voiceover
     * @param {string} options.voiceId - Voice ID (provider-specific)
     * @param {Object} options.voiceSettings - Speed, pitch, emotion
     * @returns {Object} Generation job details
     */
    async generateFromPhoto(options) {
        const { 
            provider = this.defaultProvider,
            photoUrl,
            script,
            voiceId,
            voiceSettings = {}
        } = options;

        switch (provider) {
            case 'heygen':
                return this.heygen.createTalkingPhoto({
                    photoUrl,
                    script,
                    voiceId: voiceId || 'en-US-JennyNeural',
                    voiceSettings
                });

            case 'did':
                return this.did.createTalk({
                    sourceUrl: photoUrl,
                    script,
                    voiceId: voiceId || 'en-US-GuyNeural'
                });

            case 'synthesia':
                // Synthesia requires creating avatar first, then video
                throw new Error('Synthesia requires pre-created avatars. Use generateFromAvatar() instead.');

            default:
                throw new Error(`Unknown provider: ${provider}`);
        }
    }

    /**
     * Generate video using pre-built avatar
     * @param {Object} options
     */
    async generateFromAvatar(options) {
        const {
            provider = this.defaultProvider,
            avatarId,
            script,
            voiceId,
            background
        } = options;

        switch (provider) {
            case 'heygen':
                return this.heygen.createAvatarVideo({
                    avatarId,
                    script,
                    voiceId,
                    background
                });

            case 'did':
                return this.did.createClip({
                    presenterId: avatarId,
                    script,
                    voiceId
                });

            case 'synthesia':
                return this.synthesia.createVideo({
                    title: 'Generated Video',
                    avatarId,
                    voiceId,
                    script,
                    background: { color: background || '#0A1628' }
                });

            default:
                throw new Error(`Unknown provider: ${provider}`);
        }
    }

    /**
     * Generate audio only (for use with custom video editing)
     * @param {Object} options
     * @param {string} options.provider - 'elevenlabs' or 'playht'
     * @param {string} options.voiceId - Voice ID
     * @param {string} options.text - Text to speak
     * @param {Object} options.settings - Voice settings
     */
    async generateAudio(options) {
        const {
            provider = 'elevenlabs',
            voiceId,
            text,
            settings = {}
        } = options;

        switch (provider) {
            case 'elevenlabs':
                const audioBuffer = await this.elevenlabs.textToSpeech({
                    voiceId,
                    text,
                    voiceSettings: settings
                });
                return { audioBuffer, format: 'mp3' };

            case 'playht':
                return this.playht.generateSpeech({
                    text,
                    voice: voiceId,
                    speed: settings.speed || 1.0
                });

            default:
                throw new Error(`Unknown audio provider: ${provider}`);
        }
    }

    /**
     * Generate video with separate audio generation
     * (Generate audio with ElevenLabs, then create video with D-ID)
     * @param {Object} options
     */
    async generateWithCustomVoice(options) {
        const {
            photoUrl,
            script,
            voiceId,
            voiceSettings = {}
        } = options;

        // Step 1: Generate audio with ElevenLabs
        const audioResult = await this.elevenlabs.textToSpeech({
            voiceId,
            text: script,
            voiceSettings
        });

        // Step 2: Upload audio to storage and get URL
        // (This would upload to Supabase or another storage provider)
        const audioUrl = await this._uploadAudio(audioResult);

        // Step 3: Create video with D-ID using the audio
        return this.did.createTalkWithAudio({
            sourceUrl: photoUrl,
            audioUrl
        });
    }

    /**
     * Get generation status (unified across providers)
     * @param {string} provider
     * @param {string} jobId
     */
    async getStatus(provider, jobId) {
        switch (provider) {
            case 'heygen':
                return this.heygen.getVideoStatus(jobId);
            case 'did':
                return this.did.getTalkStatus(jobId);
            case 'synthesia':
                return this.synthesia.getVideoStatus(jobId);
            default:
                throw new Error(`Unknown provider: ${provider}`);
        }
    }

    /**
     * List available voices (unified)
     */
    async listVoices(provider = 'elevenlabs') {
        switch (provider) {
            case 'heygen':
                return this.heygen.listVoices();
            case 'elevenlabs':
                return this.elevenlabs.listVoices();
            case 'playht':
                return this.playht.listVoices();
            case 'synthesia':
                return this.synthesia.listVoices();
            default:
                throw new Error(`Unknown provider: ${provider}`);
        }
    }

    /**
     * List available avatars (unified)
     */
    async listAvatars(provider = 'heygen') {
        switch (provider) {
            case 'heygen':
                return this.heygen.listAvatars();
            case 'did':
                return this.did.listPresenters();
            case 'synthesia':
                return this.synthesia.listAvatars();
            default:
                throw new Error(`Unknown provider: ${provider}`);
        }
    }

    /**
     * Clone voice from audio sample
     * @param {Object} options
     */
    async cloneVoice(options) {
        const { provider = 'elevenlabs', name, audioUrls } = options;

        switch (provider) {
            case 'elevenlabs':
                return this.elevenlabs.cloneVoice({
                    name,
                    description: `Cloned voice for ${name}`,
                    audioUrls
                });
            case 'heygen':
                return this.heygen.cloneVoice({
                    name,
                    audioUrl: audioUrls[0]
                });
            case 'playht':
                return this.playht.cloneVoice({
                    name,
                    sampleFileUrl: audioUrls[0]
                });
            default:
                throw new Error(`Voice cloning not supported for: ${provider}`);
        }
    }

    /**
     * Internal: Upload audio buffer to storage
     */
    async _uploadAudio(audioBuffer) {
        // Implementation would upload to Supabase Storage
        // and return the public URL
        console.log('Uploading audio to storage...');
        // Placeholder - implement actual upload
        return 'https://storage.example.com/audio/generated.mp3';
    }
}

// ============================================================
// EXPORTS
// ============================================================

module.exports = {
    CONFIG,
    HeyGenAPI,
    DIDApi,
    SynthesiaAPI,
    ElevenLabsAPI,
    PlayHTAPI,
    VideoGenerationService
};

// ES6 export for modern environments
export {
    CONFIG,
    HeyGenAPI,
    DIDApi,
    SynthesiaAPI,
    ElevenLabsAPI,
    PlayHTAPI,
    VideoGenerationService
};
