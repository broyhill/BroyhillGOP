/**
 * ============================================================
 * BROYHILLGOP DEMO ECOSYSTEM - AI VIDEO GENERATION API
 * ============================================================
 * 
 * This module integrates with multiple AI video generation services:
 * - HeyGen: Photo-realistic avatar videos
 * - D-ID: Photo animation with voice
 * - ElevenLabs: Ultra-realistic voice synthesis
 * - Synthesia: Professional AI avatars
 * 
 * Version: 1.0
 * Created: December 11, 2025
 */

// ============================================================
// CONFIGURATION
// ============================================================

const CONFIG = {
    // API Endpoints
    HEYGEN_API: 'https://api.heygen.com/v2',
    DID_API: 'https://api.d-id.com',
    ELEVENLABS_API: 'https://api.elevenlabs.io/v1',
    SYNTHESIA_API: 'https://api.synthesia.io/v2',
    
    // API Keys (set via environment or Supabase secrets)
    HEYGEN_API_KEY: process.env.HEYGEN_API_KEY || '',
    DID_API_KEY: process.env.DID_API_KEY || '',
    ELEVENLABS_API_KEY: process.env.ELEVENLABS_API_KEY || '',
    SYNTHESIA_API_KEY: process.env.SYNTHESIA_API_KEY || '',
    
    // Default settings
    DEFAULT_VOICE: 'professional-male',
    DEFAULT_AVATAR_STYLE: 'business',
    MAX_SCRIPT_LENGTH: 5000,
    
    // Webhook for completion notifications
    WEBHOOK_URL: process.env.WEBHOOK_URL || ''
};

// ============================================================
// ELEVENLABS - TEXT TO SPEECH
// ============================================================

class ElevenLabsService {
    constructor(apiKey) {
        this.apiKey = apiKey || CONFIG.ELEVENLABS_API_KEY;
        this.baseUrl = CONFIG.ELEVENLABS_API;
    }

    /**
     * Get available voices
     */
    async getVoices() {
        const response = await fetch(`${this.baseUrl}/voices`, {
            headers: {
                'xi-api-key': this.apiKey
            }
        });
        
        if (!response.ok) {
            throw new Error(`ElevenLabs API error: ${response.status}`);
        }
        
        return response.json();
    }

    /**
     * Generate speech from text
     * @param {string} text - The script to convert to speech
     * @param {string} voiceId - ElevenLabs voice ID
     * @param {object} settings - Voice settings (stability, similarity, style)
     */
    async generateSpeech(text, voiceId, settings = {}) {
        const defaultSettings = {
            stability: 0.5,
            similarity_boost: 0.75,
            style: 0.5,
            use_speaker_boost: true
        };

        const response = await fetch(`${this.baseUrl}/text-to-speech/${voiceId}`, {
            method: 'POST',
            headers: {
                'xi-api-key': this.apiKey,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                text: text,
                model_id: 'eleven_multilingual_v2',
                voice_settings: { ...defaultSettings, ...settings }
            })
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(`ElevenLabs generation failed: ${error.detail}`);
        }

        // Returns audio as binary
        const audioBlob = await response.blob();
        return audioBlob;
    }

    /**
     * Clone a voice from audio sample
     * @param {string} name - Name for the cloned voice
     * @param {File} audioFile - Audio sample file
     */
    async cloneVoice(name, audioFile) {
        const formData = new FormData();
        formData.append('name', name);
        formData.append('files', audioFile);

        const response = await fetch(`${this.baseUrl}/voices/add`, {
            method: 'POST',
            headers: {
                'xi-api-key': this.apiKey
            },
            body: formData
        });

        if (!response.ok) {
            throw new Error(`Voice cloning failed: ${response.status}`);
        }

        return response.json();
    }

    /**
     * Map our voice IDs to ElevenLabs voice IDs
     */
    getVoiceMapping() {
        return {
            'deep-authoritative': 'ErXwobaYiN019PkySvjV', // Antoni
            'professional-male': 'VR6AewLTigWG4xSOukaG', // Arnold
            'professional-female': 'EXAVITQu4vr4xnSDxMaL', // Bella
            'news-anchor': 'ODq5zmih8GrVes37Dizd', // Patrick
            'warm-friendly': 'ThT5KcBeYPX3keUQqHPh', // Dorothy
            'southern-accent': 'yoZ06aMxZJJ28mfd3POQ', // Sam
            'young-energetic': 'jBpfuIE2acCO8z3wKNLl', // Gigi
            'elder-statesman': 'GBv7mTt0atIp3Br8iCZE'  // Thomas
        };
    }
}

// ============================================================
// D-ID - PHOTO TO VIDEO
// ============================================================

class DIDService {
    constructor(apiKey) {
        this.apiKey = apiKey || CONFIG.DID_API_KEY;
        this.baseUrl = CONFIG.DID_API;
    }

    /**
     * Create a talking head video from a photo and audio
     * @param {string} photoUrl - URL of the source photo
     * @param {string} audioUrl - URL of the audio file (from ElevenLabs)
     * @param {object} options - Additional options
     */
    async createTalkingVideo(photoUrl, audioUrl, options = {}) {
        const payload = {
            source_url: photoUrl,
            script: {
                type: 'audio',
                audio_url: audioUrl
            },
            config: {
                stitch: true,
                result_format: 'mp4'
            },
            ...options
        };

        const response = await fetch(`${this.baseUrl}/talks`, {
            method: 'POST',
            headers: {
                'Authorization': `Basic ${this.apiKey}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(`D-ID creation failed: ${JSON.stringify(error)}`);
        }

        return response.json();
    }

    /**
     * Create video with text-to-speech (D-ID's built-in TTS)
     * @param {string} photoUrl - URL of the source photo
     * @param {string} script - Text script to speak
     * @param {string} voiceId - Voice provider voice ID
     */
    async createVideoWithTTS(photoUrl, script, voiceId = 'en-US-GuyNeural') {
        const payload = {
            source_url: photoUrl,
            script: {
                type: 'text',
                input: script,
                provider: {
                    type: 'microsoft',
                    voice_id: voiceId
                }
            },
            config: {
                stitch: true,
                result_format: 'mp4'
            }
        };

        const response = await fetch(`${this.baseUrl}/talks`, {
            method: 'POST',
            headers: {
                'Authorization': `Basic ${this.apiKey}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(`D-ID creation failed: ${JSON.stringify(error)}`);
        }

        return response.json();
    }

    /**
     * Get the status of a video generation
     * @param {string} talkId - The talk/video ID
     */
    async getVideoStatus(talkId) {
        const response = await fetch(`${this.baseUrl}/talks/${talkId}`, {
            headers: {
                'Authorization': `Basic ${this.apiKey}`
            }
        });

        if (!response.ok) {
            throw new Error(`D-ID status check failed: ${response.status}`);
        }

        return response.json();
    }

    /**
     * Poll until video is ready
     * @param {string} talkId - The talk/video ID
     * @param {number} maxAttempts - Maximum polling attempts
     */
    async waitForVideo(talkId, maxAttempts = 60) {
        for (let i = 0; i < maxAttempts; i++) {
            const status = await this.getVideoStatus(talkId);
            
            if (status.status === 'done') {
                return status;
            }
            
            if (status.status === 'error') {
                throw new Error(`Video generation failed: ${status.error}`);
            }
            
            // Wait 2 seconds before next poll
            await new Promise(resolve => setTimeout(resolve, 2000));
        }
        
        throw new Error('Video generation timed out');
    }

    /**
     * Map our voice IDs to Microsoft Azure voice IDs
     */
    getVoiceMapping() {
        return {
            'deep-authoritative': 'en-US-GuyNeural',
            'professional-male': 'en-US-DavisNeural',
            'professional-female': 'en-US-JennyNeural',
            'news-anchor': 'en-US-BrandonNeural',
            'warm-friendly': 'en-US-AriaNeural',
            'southern-accent': 'en-US-TonyNeural',
            'young-energetic': 'en-US-SaraNeural',
            'elder-statesman': 'en-US-RogerNeural'
        };
    }
}

// ============================================================
// HEYGEN - ADVANCED AVATAR VIDEOS
// ============================================================

class HeyGenService {
    constructor(apiKey) {
        this.apiKey = apiKey || CONFIG.HEYGEN_API_KEY;
        this.baseUrl = CONFIG.HEYGEN_API;
    }

    /**
     * Get available avatars
     */
    async getAvatars() {
        const response = await fetch(`${this.baseUrl}/avatars`, {
            headers: {
                'X-Api-Key': this.apiKey
            }
        });

        if (!response.ok) {
            throw new Error(`HeyGen API error: ${response.status}`);
        }

        return response.json();
    }

    /**
     * Create video with HeyGen avatar
     * @param {object} params - Video parameters
     */
    async createVideo(params) {
        const {
            avatarId,
            script,
            voiceId,
            backgroundUrl,
            outputFormat = 'mp4',
            dimension = { width: 1920, height: 1080 }
        } = params;

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
                background: backgroundUrl ? {
                    type: 'image',
                    url: backgroundUrl
                } : {
                    type: 'color',
                    value: '#0A1628'
                }
            }],
            dimension: dimension,
            output_format: outputFormat
        };

        const response = await fetch(`${this.baseUrl}/video/generate`, {
            method: 'POST',
            headers: {
                'X-Api-Key': this.apiKey,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(`HeyGen video creation failed: ${JSON.stringify(error)}`);
        }

        return response.json();
    }

    /**
     * Create video from uploaded photo (Photo Avatar)
     * @param {string} photoUrl - URL of the source photo
     * @param {string} script - Text script
     * @param {string} voiceId - Voice ID
     */
    async createPhotoAvatar(photoUrl, script, voiceId) {
        // First, create a photo avatar
        const avatarResponse = await fetch(`${this.baseUrl}/photo_avatar`, {
            method: 'POST',
            headers: {
                'X-Api-Key': this.apiKey,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                image_url: photoUrl
            })
        });

        if (!avatarResponse.ok) {
            throw new Error(`Photo avatar creation failed: ${avatarResponse.status}`);
        }

        const avatarData = await avatarResponse.json();
        
        // Then create video with the photo avatar
        return this.createVideo({
            avatarId: avatarData.data.avatar_id,
            script: script,
            voiceId: voiceId
        });
    }

    /**
     * Get video status
     * @param {string} videoId - The video ID
     */
    async getVideoStatus(videoId) {
        const response = await fetch(`${this.baseUrl}/video_status.get?video_id=${videoId}`, {
            headers: {
                'X-Api-Key': this.apiKey
            }
        });

        if (!response.ok) {
            throw new Error(`HeyGen status check failed: ${response.status}`);
        }

        return response.json();
    }

    /**
     * Poll until video is ready
     * @param {string} videoId - The video ID
     */
    async waitForVideo(videoId, maxAttempts = 120) {
        for (let i = 0; i < maxAttempts; i++) {
            const status = await this.getVideoStatus(videoId);
            
            if (status.data.status === 'completed') {
                return status;
            }
            
            if (status.data.status === 'failed') {
                throw new Error(`Video generation failed: ${status.data.error}`);
            }
            
            // Wait 3 seconds before next poll
            await new Promise(resolve => setTimeout(resolve, 3000));
        }
        
        throw new Error('Video generation timed out');
    }
}

// ============================================================
// MAIN VIDEO GENERATOR - ORCHESTRATES ALL SERVICES
// ============================================================

class VideoGenerator {
    constructor(config = {}) {
        this.elevenLabs = new ElevenLabsService(config.elevenLabsKey);
        this.did = new DIDService(config.didKey);
        this.heygen = new HeyGenService(config.heygenKey);
        this.preferredService = config.preferredService || 'did'; // 'did', 'heygen'
    }

    /**
     * Process script - replace variables and format
     * @param {string} script - Raw script with variables
     * @param {object} variables - Variable values
     */
    processScript(script, variables = {}) {
        let processed = script;
        
        // Replace variables
        Object.entries(variables).forEach(([key, value]) => {
            const regex = new RegExp(`\\[${key}\\]`, 'gi');
            processed = processed.replace(regex, value);
        });
        
        // Convert pause markers to SSML or timing
        processed = processed.replace(/\[PAUSE\]/g, '<break time="1s"/>');
        processed = processed.replace(/\[LONG_PAUSE\]/g, '<break time="2s"/>');
        
        // Convert emphasis markers
        processed = processed.replace(/\[EMPHASIS\](.*?)\[\/EMPHASIS\]/g, '<emphasis>$1</emphasis>');
        
        return processed;
    }

    /**
     * Generate complete video from script and photo
     * @param {object} params - Generation parameters
     */
    async generateVideo(params) {
        const {
            photoUrl,
            script,
            voiceId,
            variables = {},
            service = this.preferredService,
            backgroundUrl = null
        } = params;

        // Process the script
        const processedScript = this.processScript(script, variables);
        
        console.log('Starting video generation...');
        console.log('Service:', service);
        console.log('Script length:', processedScript.length);

        if (service === 'heygen') {
            return this.generateWithHeyGen(photoUrl, processedScript, voiceId, backgroundUrl);
        } else {
            return this.generateWithDID(photoUrl, processedScript, voiceId);
        }
    }

    /**
     * Generate with D-ID (Photo + ElevenLabs voice)
     */
    async generateWithDID(photoUrl, script, voiceId) {
        // Option 1: Use D-ID's built-in TTS
        const voiceMapping = this.did.getVoiceMapping();
        const microsoftVoiceId = voiceMapping[voiceId] || 'en-US-GuyNeural';
        
        console.log('Creating D-ID video with voice:', microsoftVoiceId);
        
        const result = await this.did.createVideoWithTTS(photoUrl, script, microsoftVoiceId);
        console.log('D-ID job created:', result.id);
        
        // Wait for completion
        const completed = await this.did.waitForVideo(result.id);
        
        return {
            success: true,
            service: 'd-id',
            videoId: result.id,
            videoUrl: completed.result_url,
            duration: completed.duration
        };
    }

    /**
     * Generate with D-ID using ElevenLabs voice (higher quality)
     */
    async generateWithDIDPremium(photoUrl, script, voiceId) {
        // First, generate audio with ElevenLabs
        const voiceMapping = this.elevenLabs.getVoiceMapping();
        const elevenLabsVoiceId = voiceMapping[voiceId] || voiceMapping['professional-male'];
        
        console.log('Generating ElevenLabs audio...');
        const audioBlob = await this.elevenLabs.generateSpeech(script, elevenLabsVoiceId);
        
        // Upload audio to get URL (would need storage service)
        // For now, assume we have the audio URL
        const audioUrl = await this.uploadAudio(audioBlob);
        
        console.log('Creating D-ID video with custom audio...');
        const result = await this.did.createTalkingVideo(photoUrl, audioUrl);
        
        const completed = await this.did.waitForVideo(result.id);
        
        return {
            success: true,
            service: 'd-id-premium',
            videoId: result.id,
            videoUrl: completed.result_url,
            duration: completed.duration
        };
    }

    /**
     * Generate with HeyGen
     */
    async generateWithHeyGen(photoUrl, script, voiceId, backgroundUrl) {
        console.log('Creating HeyGen photo avatar...');
        
        const result = await this.heygen.createPhotoAvatar(photoUrl, script, voiceId);
        console.log('HeyGen job created:', result.data.video_id);
        
        const completed = await this.heygen.waitForVideo(result.data.video_id);
        
        return {
            success: true,
            service: 'heygen',
            videoId: result.data.video_id,
            videoUrl: completed.data.video_url,
            duration: completed.data.duration
        };
    }

    /**
     * Upload audio blob to storage (placeholder - implement with your storage)
     */
    async uploadAudio(audioBlob) {
        // This would upload to Supabase Storage, S3, etc.
        // Return the public URL of the uploaded audio
        throw new Error('uploadAudio not implemented - connect to your storage service');
    }

    /**
     * Generate voice-only audio (no video)
     */
    async generateVoiceOnly(script, voiceId, variables = {}) {
        const processedScript = this.processScript(script, variables);
        const voiceMapping = this.elevenLabs.getVoiceMapping();
        const elevenLabsVoiceId = voiceMapping[voiceId] || voiceMapping['professional-male'];
        
        const audioBlob = await this.elevenLabs.generateSpeech(processedScript, elevenLabsVoiceId);
        
        return {
            success: true,
            audioBlob: audioBlob,
            voiceId: voiceId
        };
    }
}

// ============================================================
// SUPABASE EDGE FUNCTION HANDLER
// ============================================================

/**
 * Supabase Edge Function for video generation
 * Deploy this to handle video generation requests
 */
async function handleVideoRequest(req) {
    const { photoUrl, script, voiceId, variables, service } = await req.json();
    
    // Validate required fields
    if (!photoUrl || !script) {
        return new Response(JSON.stringify({
            error: 'Missing required fields: photoUrl and script'
        }), { status: 400 });
    }
    
    try {
        const generator = new VideoGenerator({
            elevenLabsKey: Deno.env.get('ELEVENLABS_API_KEY'),
            didKey: Deno.env.get('DID_API_KEY'),
            heygenKey: Deno.env.get('HEYGEN_API_KEY'),
            preferredService: service || 'did'
        });
        
        const result = await generator.generateVideo({
            photoUrl,
            script,
            voiceId: voiceId || 'professional-male',
            variables: variables || {},
            service: service || 'did'
        });
        
        return new Response(JSON.stringify(result), {
            status: 200,
            headers: { 'Content-Type': 'application/json' }
        });
        
    } catch (error) {
        console.error('Video generation error:', error);
        return new Response(JSON.stringify({
            error: error.message
        }), { status: 500 });
    }
}

// ============================================================
// BROWSER/CLIENT USAGE
// ============================================================

/**
 * Client-side function to call the video generation API
 */
async function generateDemoVideo(params) {
    const {
        photoUrl,
        script,
        voiceId = 'professional-male',
        variables = {},
        service = 'did'
    } = params;
    
    const response = await fetch('/api/generate-video', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            photoUrl,
            script,
            voiceId,
            variables,
            service
        })
    });
    
    if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Video generation failed');
    }
    
    return response.json();
}

// ============================================================
// EXPORT FOR MODULE USAGE
// ============================================================

if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        VideoGenerator,
        ElevenLabsService,
        DIDService,
        HeyGenService,
        generateDemoVideo,
        handleVideoRequest
    };
}

// ============================================================
// USAGE EXAMPLES
// ============================================================

/*
// Example 1: Generate video with D-ID
const generator = new VideoGenerator({
    didKey: 'your-d-id-api-key',
    elevenLabsKey: 'your-elevenlabs-key'
});

const result = await generator.generateVideo({
    photoUrl: 'https://example.com/candidate-photo.jpg',
    script: 'Welcome, [NAME]! I\'m excited to show you our platform. [PAUSE] Let me walk you through the key features.',
    voiceId: 'professional-male',
    variables: {
        NAME: 'John Smith',
        COMPANY: 'Acme Corp'
    },
    service: 'did'
});

console.log('Video URL:', result.videoUrl);


// Example 2: Generate voice-only audio
const audioResult = await generator.generateVoiceOnly(
    'Welcome to BroyhillGOP. [PAUSE] Your personalized demo is ready.',
    'news-anchor',
    { NAME: 'Sarah Johnson' }
);

// Save the audio blob to a file or upload to storage


// Example 3: Client-side usage in browser
document.getElementById('generate-btn').addEventListener('click', async () => {
    try {
        const result = await generateDemoVideo({
            photoUrl: uploadedPhotoUrl,
            script: document.getElementById('voiceover-script').value,
            voiceId: document.querySelector('input[name="voice"]:checked').value,
            variables: {
                NAME: candidateName,
                NUMBER: donorCount
            }
        });
        
        // Display the generated video
        document.getElementById('video-player').src = result.videoUrl;
    } catch (error) {
        alert('Error: ' + error.message);
    }
});
*/
