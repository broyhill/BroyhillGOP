/**
 * ============================================================
 * BROYHILLGOP - WEBHOOK HANDLER FOR VIDEO GENERATION CALLBACKS
 * ============================================================
 * Receives async callbacks from HeyGen, D-ID, Synthesia
 * Updates database with video status and URLs
 * Deploy to: supabase functions deploy webhook-handler
 * ============================================================
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || ''
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    const url = new URL(req.url)
    const provider = url.pathname.split('/').pop() // /webhook/heygen -> heygen

    try {
        const payload = await req.json()
        console.log(`Webhook received from ${provider}:`, JSON.stringify(payload))

        let result

        switch (provider) {
            case 'heygen':
                result = await handleHeyGenWebhook(supabase, payload)
                break
            case 'did':
                result = await handleDIDWebhook(supabase, payload)
                break
            case 'synthesia':
                result = await handleSynthesiaWebhook(supabase, payload)
                break
            default:
                throw new Error(`Unknown webhook provider: ${provider}`)
        }

        return new Response(JSON.stringify({ success: true, result }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200
        })

    } catch (error) {
        console.error('Webhook error:', error)
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400
        })
    }
})

// ============================================================
// HEYGEN WEBHOOK HANDLER
// ============================================================

async function handleHeyGenWebhook(supabase, payload) {
    const { video_id, status, video_url, error } = payload

    // Find the screenplay element with this job ID
    const { data: element, error: fetchError } = await supabase
        .from('demo_ecosystem.screenplay_elements')
        .select('*')
        .eq('generation_job_id', video_id)
        .single()

    if (fetchError) {
        console.log('Element not found for HeyGen job:', video_id)
        // Log to webhook_logs table anyway
        await supabase.from('demo_ecosystem.webhook_logs').insert({
            provider: 'heygen',
            job_id: video_id,
            payload: JSON.stringify(payload),
            status: status,
            created_at: new Date().toISOString()
        })
        return { logged: true }
    }

    // Update the element with video URL
    if (status === 'completed' && video_url) {
        await supabase
            .from('demo_ecosystem.screenplay_elements')
            .update({
                generated_video_url: video_url,
                generation_status: 'completed',
                generation_completed_at: new Date().toISOString()
            })
            .eq('element_id', element.element_id)

        // Notify via realtime or email
        await notifyCompletion(supabase, element, video_url)
    } else if (status === 'failed') {
        await supabase
            .from('demo_ecosystem.screenplay_elements')
            .update({
                generation_status: 'failed',
                generation_error: error || 'Unknown error'
            })
            .eq('element_id', element.element_id)
    }

    return { elementId: element.element_id, status }
}

// ============================================================
// D-ID WEBHOOK HANDLER
// ============================================================

async function handleDIDWebhook(supabase, payload) {
    const { id, status, result_url, error } = payload

    // D-ID uses 'id' instead of 'video_id'
    const jobId = id

    const { data: element, error: fetchError } = await supabase
        .from('demo_ecosystem.screenplay_elements')
        .select('*')
        .eq('generation_job_id', jobId)
        .single()

    if (fetchError) {
        await supabase.from('demo_ecosystem.webhook_logs').insert({
            provider: 'did',
            job_id: jobId,
            payload: JSON.stringify(payload),
            status: status,
            created_at: new Date().toISOString()
        })
        return { logged: true }
    }

    // D-ID status values: created, started, done, error
    if (status === 'done' && result_url) {
        await supabase
            .from('demo_ecosystem.screenplay_elements')
            .update({
                generated_video_url: result_url,
                generation_status: 'completed',
                generation_completed_at: new Date().toISOString()
            })
            .eq('element_id', element.element_id)

        await notifyCompletion(supabase, element, result_url)
    } else if (status === 'error') {
        await supabase
            .from('demo_ecosystem.screenplay_elements')
            .update({
                generation_status: 'failed',
                generation_error: error?.message || 'Unknown error'
            })
            .eq('element_id', element.element_id)
    }

    return { elementId: element.element_id, status }
}

// ============================================================
// SYNTHESIA WEBHOOK HANDLER
// ============================================================

async function handleSynthesiaWebhook(supabase, payload) {
    const { id, status, download } = payload

    const { data: element, error: fetchError } = await supabase
        .from('demo_ecosystem.screenplay_elements')
        .select('*')
        .eq('generation_job_id', id)
        .single()

    if (fetchError) {
        await supabase.from('demo_ecosystem.webhook_logs').insert({
            provider: 'synthesia',
            job_id: id,
            payload: JSON.stringify(payload),
            status: status,
            created_at: new Date().toISOString()
        })
        return { logged: true }
    }

    // Synthesia status: in_progress, complete, failed
    if (status === 'complete' && download) {
        await supabase
            .from('demo_ecosystem.screenplay_elements')
            .update({
                generated_video_url: download,
                generation_status: 'completed',
                generation_completed_at: new Date().toISOString()
            })
            .eq('element_id', element.element_id)

        await notifyCompletion(supabase, element, download)
    } else if (status === 'failed') {
        await supabase
            .from('demo_ecosystem.screenplay_elements')
            .update({
                generation_status: 'failed',
                generation_error: 'Synthesia generation failed'
            })
            .eq('element_id', element.element_id)
    }

    return { elementId: element.element_id, status }
}

// ============================================================
// NOTIFICATION
// ============================================================

async function notifyCompletion(supabase, element, videoUrl) {
    // Get screenplay info
    const { data: screenplay } = await supabase
        .from('demo_ecosystem.screenplays')
        .select('*, candidates(*)')
        .eq('screenplay_id', element.screenplay_id)
        .single()

    if (!screenplay) return

    // Check if all elements are complete
    const { data: allElements } = await supabase
        .from('demo_ecosystem.screenplay_elements')
        .select('generation_status')
        .eq('screenplay_id', element.screenplay_id)

    const allComplete = allElements?.every(e => 
        e.generation_status === 'completed' || !e.requires_generation
    )

    if (allComplete) {
        // Update screenplay status
        await supabase
            .from('demo_ecosystem.screenplays')
            .update({
                status: 'ready',
                demo_url: `/demo/${screenplay.screenplay_id}`
            })
            .eq('screenplay_id', element.screenplay_id)

        // Send email notification (would integrate with email service)
        console.log(`Demo ${screenplay.title} is ready!`)
        
        // Could send to Resend, SendGrid, etc.
        // await sendEmail({
        //     to: screenplay.created_by,
        //     subject: `Your demo "${screenplay.title}" is ready!`,
        //     body: `Your demo video has been generated and is ready to view.`
        // })
    }
}
