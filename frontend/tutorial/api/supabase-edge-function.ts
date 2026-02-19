/**
 * ============================================================
 * BROYHILLGOP - SUPABASE EDGE FUNCTION: VIDEO GENERATION
 * ============================================================
 * Handles video generation requests and orchestrates the process
 * Deploy to: supabase functions deploy generate-video
 * ============================================================
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// API Keys from environment
const HEYGEN_API_KEY = Deno.env.get('HEYGEN_API_KEY') || ''
const DID_API_KEY = Deno.env.get('DID_API_KEY') || ''
const ELEVENLABS_API_KEY = Deno.env.get('ELEVENLABS_API_KEY') || ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || ''
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        const { action, ...params } = await req.json()

        let result

        switch (action) {
            case 'generate-from-photo':
                result = await generateFromPhoto(params)
                break
            case 'generate-audio':
                result = await generateAudio(params)
                break
            case 'generate-video-with-audio':
                result = await generateVideoWithAudio(params)
                break
            case 'check-status':
                result = await checkStatus(params)
                break
            case 'list-voices':
                result = await listVoices(params)
                break
            case 'list-avatars':
                result = await listAvatars(params)
                break
            case 'clone-voice':
                result = await cloneVoice(params)
                break
            default:
                throw new Error(`Unknown action: ${action}`)
        }

        // Log the request to database
        await supabase.from('demo_ecosystem.api_logs').insert({
            action,
            params: JSON.stringify(params),
            result: JSON.stringify(result),
            created_at: new Date().toISOString()
        })

        return new Response(JSON.stringify(result), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200
        })

    } catch (error) {
        console.error('Error:', error)
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400
        })
    }
})

// ============================================================
// HEYGEN FUNCTIONS
// ============================================================

async function generateFromPhoto({ photoUrl, script, voiceId, provider = 'heygen' }) {
    if (provider === 'heygen') {
        const response = await fetch('https://api.heygen.com/v2/video/generate', {
            method: 'POST',
            headers: {
                'X-Api-Key': HEYGEN_API_KEY,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                video_inputs: [{
                    character: {
                        type: 'talking_photo',
                        talking_photo_url: photoUrl
                    },
                    voice: {
                        type: 'text',
                        input_text: script,
                        voice_id: voiceId || 'en-US-JennyNeural'
                    }
                }],
                dimension: { width: 1920, height: 1080 },
                aspect_ratio: '16:9'
            })
        })

        if (!response.ok) {
            const error = await response.json()
            throw new Error(`HeyGen Error: ${JSON.stringify(error)}`)
        }

        return response.json()
    }

    if (provider === 'did') {
        const response = await fetch('https://api.d-id.com/talks', {
            method: 'POST',
            headers: {
                'Authorization': `Basic ${DID_API_KEY}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                source_url: photoUrl,
                script: {
                    type: 'text',
                    input: script,
                    provider: {
                        type: 'microsoft',
                        voice_id: voiceId || 'en-US-GuyNeural'
                    }
                },
                config: { fluent: true, stitch: true }
            })
        })

        if (!response.ok) {
            const error = await response.json()
            throw new Error(`D-ID Error: ${JSON.stringify(error)}`)
        }

        return response.json()
    }

    throw new Error(`Unknown provider: ${provider}`)
}

// ============================================================
// ELEVENLABS AUDIO GENERATION
// ============================================================

async function generateAudio({ text, voiceId, settings = {} }) {
    const response = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`, {
        method: 'POST',
        headers: {
            'xi-api-key': ELEVENLABS_API_KEY,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            text,
            model_id: 'eleven_monolingual_v1',
            voice_settings: {
                stability: settings.stability || 0.5,
                similarity_boost: settings.similarityBoost || 0.75,
                style: settings.style || 0
            }
        })
    })

    if (!response.ok) {
        const error = await response.json()
        throw new Error(`ElevenLabs Error: ${JSON.stringify(error)}`)
    }

    // Return audio as base64
    const audioBuffer = await response.arrayBuffer()
    const base64Audio = btoa(String.fromCharCode(...new Uint8Array(audioBuffer)))

    return {
        audio: base64Audio,
        format: 'mp3',
        voiceId
    }
}

// ============================================================
// COMBINED VIDEO + CUSTOM AUDIO
// ============================================================

async function generateVideoWithAudio({ photoUrl, script, voiceId, voiceSettings = {} }) {
    // Step 1: Generate audio with ElevenLabs
    const audioResult = await generateAudio({ text: script, voiceId, settings: voiceSettings })

    // Step 2: Upload audio to temporary storage (you'd implement this)
    // For now, we'll use D-ID with text instead
    
    // Step 3: Create video with D-ID
    const videoResult = await generateFromPhoto({
        photoUrl,
        script,
        voiceId,
        provider: 'did'
    })

    return {
        audioGenerated: true,
        videoJob: videoResult
    }
}

// ============================================================
// STATUS CHECK
// ============================================================

async function checkStatus({ provider, jobId }) {
    if (provider === 'heygen') {
        const response = await fetch(`https://api.heygen.com/v2/video/${jobId}`, {
            headers: { 'X-Api-Key': HEYGEN_API_KEY }
        })
        return response.json()
    }

    if (provider === 'did') {
        const response = await fetch(`https://api.d-id.com/talks/${jobId}`, {
            headers: { 'Authorization': `Basic ${DID_API_KEY}` }
        })
        return response.json()
    }

    throw new Error(`Unknown provider: ${provider}`)
}

// ============================================================
// LIST VOICES
// ============================================================

async function listVoices({ provider = 'elevenlabs' }) {
    if (provider === 'elevenlabs') {
        const response = await fetch('https://api.elevenlabs.io/v1/voices', {
            headers: { 'xi-api-key': ELEVENLABS_API_KEY }
        })
        return response.json()
    }

    if (provider === 'heygen') {
        const response = await fetch('https://api.heygen.com/v2/voices', {
            headers: { 'X-Api-Key': HEYGEN_API_KEY }
        })
        return response.json()
    }

    throw new Error(`Unknown provider: ${provider}`)
}

// ============================================================
// LIST AVATARS
// ============================================================

async function listAvatars({ provider = 'heygen' }) {
    if (provider === 'heygen') {
        const response = await fetch('https://api.heygen.com/v2/avatars', {
            headers: { 'X-Api-Key': HEYGEN_API_KEY }
        })
        return response.json()
    }

    if (provider === 'did') {
        const response = await fetch('https://api.d-id.com/clips/presenters', {
            headers: { 'Authorization': `Basic ${DID_API_KEY}` }
        })
        return response.json()
    }

    throw new Error(`Unknown provider: ${provider}`)
}

// ============================================================
// CLONE VOICE
// ============================================================

async function cloneVoice({ name, audioUrl, provider = 'elevenlabs' }) {
    if (provider === 'elevenlabs') {
        // Fetch the audio file
        const audioResponse = await fetch(audioUrl)
        const audioBlob = await audioResponse.blob()

        const formData = new FormData()
        formData.append('name', name)
        formData.append('files', audioBlob, 'sample.mp3')

        const response = await fetch('https://api.elevenlabs.io/v1/voices/add', {
            method: 'POST',
            headers: { 'xi-api-key': ELEVENLABS_API_KEY },
            body: formData
        })

        if (!response.ok) {
            const error = await response.json()
            throw new Error(`ElevenLabs Clone Error: ${JSON.stringify(error)}`)
        }

        return response.json()
    }

    throw new Error(`Voice cloning not supported for: ${provider}`)
}
