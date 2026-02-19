/**
 * ============================================================
 * BROYHILLGOP - DEMO ORCHESTRATION SERVICE
 * ============================================================
 * Coordinates the entire demo generation workflow:
 * 1. Receives screenplay configuration from admin
 * 2. Processes each element (photo, script, voice, motion)
 * 3. Calls appropriate video generation APIs
 * 4. Assembles final demo experience
 * 5. Tracks progress and handles errors
 * ============================================================
 */

import { createClient } from '@supabase/supabase-js';

// ============================================================
// TYPES
// ============================================================

interface ScreenplayElement {
    element_id: string;
    screenplay_id: string;
    sequence_order: number;
    element_type: 'text-to-video' | 'avatar' | 'voice' | 'music' | 'media' | 'sms' | 'email' | 'call';
    content_text?: string;
    content_prompt?: string;
    avatar_id?: string;
    voice_id?: string;
    photo_motion?: string;
    transition_effect?: string;
    entrance_effect?: string;
    exit_effect?: string;
    motion_speed?: number;
    avatar_position?: string;
    avatar_size?: string;
    duration_seconds?: number;
    pointer_movements?: PointerMovement[];
}

interface PointerMovement {
    sequence_order: number;
    direction_id: string;
    target_element: string;
    duration_seconds: number;
    bubble_text?: string;
}

interface GenerationJob {
    job_id: string;
    provider: 'heygen' | 'did' | 'synthesia';
    status: 'pending' | 'processing' | 'completed' | 'failed';
    video_url?: string;
    error?: string;
}

interface DemoConfig {
    screenplay_id: string;
    title: string;
    tone: string;
    framework: string;
    selected_issues: string[];
    elements: ScreenplayElement[];
    candidate?: {
        name: string;
        email: string;
        photo_url?: string;
    };
}

// ============================================================
// ORCHESTRATION SERVICE
// ============================================================

export class DemoOrchestrationService {
    private supabase: any;
    private videoApiUrl: string;

    constructor(supabaseUrl: string, supabaseKey: string, videoApiUrl: string) {
        this.supabase = createClient(supabaseUrl, supabaseKey);
        this.videoApiUrl = videoApiUrl;
    }

    /**
     * MAIN ENTRY POINT: Generate entire demo from screenplay
     */
    async generateDemo(screenplayId: string): Promise<{ success: boolean; message: string }> {
        try {
            // Step 1: Load screenplay configuration
            const config = await this.loadScreenplayConfig(screenplayId);
            console.log(`Starting demo generation for: ${config.title}`);

            // Step 2: Update status to processing
            await this.updateScreenplayStatus(screenplayId, 'processing');

            // Step 3: Process each element
            const jobs: GenerationJob[] = [];
            
            for (const element of config.elements) {
                const job = await this.processElement(element, config);
                if (job) {
                    jobs.push(job);
                }
            }

            // Step 4: Wait for all jobs (or handle async via webhooks)
            console.log(`Started ${jobs.length} generation jobs`);

            return {
                success: true,
                message: `Demo generation started. ${jobs.length} video segments queued.`
            };

        } catch (error) {
            console.error('Demo generation failed:', error);
            await this.updateScreenplayStatus(screenplayId, 'failed');
            return {
                success: false,
                message: error.message
            };
        }
    }

    /**
     * Load screenplay with all elements and settings
     */
    private async loadScreenplayConfig(screenplayId: string): Promise<DemoConfig> {
        const { data: screenplay, error: screenplayError } = await this.supabase
            .from('demo_ecosystem.screenplays')
            .select(`
                *,
                tones(*),
                messaging_frameworks(*),
                candidates(*)
            `)
            .eq('screenplay_id', screenplayId)
            .single();

        if (screenplayError) throw new Error(`Failed to load screenplay: ${screenplayError.message}`);

        const { data: elements, error: elementsError } = await this.supabase
            .from('demo_ecosystem.screenplay_elements')
            .select(`
                *,
                pointer_movements(*),
                avatar_library(*),
                voice_library(*)
            `)
            .eq('screenplay_id', screenplayId)
            .order('sequence_order', { ascending: true });

        if (elementsError) throw new Error(`Failed to load elements: ${elementsError.message}`);

        return {
            screenplay_id: screenplayId,
            title: screenplay.title,
            tone: screenplay.tones?.tone_id,
            framework: screenplay.messaging_frameworks?.framework_id,
            selected_issues: screenplay.selected_issues || [],
            elements: elements || [],
            candidate: screenplay.candidates ? {
                name: screenplay.candidates.full_name,
                email: screenplay.candidates.email,
                photo_url: screenplay.candidates.profile_photo_url
            } : undefined
        };
    }

    /**
     * Process individual element and trigger video generation
     */
    private async processElement(element: ScreenplayElement, config: DemoConfig): Promise<GenerationJob | null> {
        console.log(`Processing element ${element.sequence_order}: ${element.element_type}`);

        // Skip elements that don't need video generation
        if (['music', 'sms', 'email', 'call'].includes(element.element_type)) {
            return null;
        }

        let job: GenerationJob;

        switch (element.element_type) {
            case 'text-to-video':
            case 'avatar':
                job = await this.generateAvatarVideo(element, config);
                break;
            case 'voice':
                job = await this.generateVoiceAudio(element, config);
                break;
            case 'media':
                // Media elements use uploaded content, no generation needed
                return null;
            default:
                console.log(`Unknown element type: ${element.element_type}`);
                return null;
        }

        // Save job ID to element
        await this.supabase
            .from('demo_ecosystem.screenplay_elements')
            .update({
                generation_job_id: job.job_id,
                generation_status: 'processing',
                generation_provider: job.provider
            })
            .eq('element_id', element.element_id);

        return job;
    }

    /**
     * Generate avatar/talking head video
     */
    private async generateAvatarVideo(element: ScreenplayElement, config: DemoConfig): Promise<GenerationJob> {
        // Determine photo source
        let photoUrl: string;
        
        if (element.avatar_id) {
            // Get avatar photo from library
            const { data: avatar } = await this.supabase
                .from('demo_ecosystem.avatar_library')
                .select('photo_url')
                .eq('avatar_id', element.avatar_id)
                .single();
            photoUrl = avatar?.photo_url;
        } else if (config.candidate?.photo_url) {
            // Use candidate's uploaded photo
            photoUrl = config.candidate.photo_url;
        } else {
            throw new Error('No photo available for avatar video');
        }

        // Process script with variable substitution
        const processedScript = this.processScript(element.content_text || '', config);

        // Determine voice
        let voiceId = element.voice_id || 'en-US-JennyNeural';

        // Call video generation API
        const response = await fetch(this.videoApiUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                action: 'generate-from-photo',
                photoUrl,
                script: processedScript,
                voiceId,
                provider: 'heygen' // or 'did'
            })
        });

        const result = await response.json();

        if (!response.ok) {
            throw new Error(`Video generation failed: ${result.error}`);
        }

        return {
            job_id: result.video_id || result.id,
            provider: 'heygen',
            status: 'processing'
        };
    }

    /**
     * Generate audio-only for voice elements
     */
    private async generateVoiceAudio(element: ScreenplayElement, config: DemoConfig): Promise<GenerationJob> {
        const processedScript = this.processScript(element.content_text || '', config);

        const response = await fetch(this.videoApiUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                action: 'generate-audio',
                text: processedScript,
                voiceId: element.voice_id || '21m00Tcm4TlvDq8ikWAM', // ElevenLabs default
                settings: {
                    stability: 0.5,
                    similarityBoost: 0.75
                }
            })
        });

        const result = await response.json();

        if (!response.ok) {
            throw new Error(`Audio generation failed: ${result.error}`);
        }

        // Save audio URL immediately (audio generation is usually sync)
        if (result.audio) {
            await this.supabase
                .from('demo_ecosystem.screenplay_elements')
                .update({
                    generated_audio_url: `data:audio/mp3;base64,${result.audio}`,
                    generation_status: 'completed'
                })
                .eq('element_id', element.element_id);
        }

        return {
            job_id: `audio-${element.element_id}`,
            provider: 'elevenlabs' as any,
            status: 'completed'
        };
    }

    /**
     * Process script with variable substitution
     */
    private processScript(script: string, config: DemoConfig): string {
        let processed = script;

        // Substitute variables
        const variables: Record<string, string> = {
            '[NAME]': config.candidate?.name || 'Candidate',
            '[CANDIDATE_NAME]': config.candidate?.name || 'Candidate',
            '[COMPANY]': 'BroyhillGOP',
            '[NUMBER]': '28,450',
            '[DONOR_COUNT]': '28,450',
            '[FUNDRAISING_POTENTIAL]': '$6.2 million',
            '[OFFICE_NAME]': 'your campaign',
        };

        for (const [variable, value] of Object.entries(variables)) {
            processed = processed.replace(new RegExp(variable.replace(/[[\]]/g, '\\$&'), 'g'), value);
        }

        // Handle pause markers (convert to SSML-like for some providers)
        processed = processed.replace(/\[PAUSE\]/g, '...');
        processed = processed.replace(/\[LONG_PAUSE\]/g, '... ...');

        // Handle emphasis (remove markers, some providers handle natively)
        processed = processed.replace(/\[EMPHASIS\]/g, '');
        processed = processed.replace(/\[\/EMPHASIS\]/g, '');

        return processed;
    }

    /**
     * Update screenplay status
     */
    private async updateScreenplayStatus(screenplayId: string, status: string) {
        await this.supabase
            .from('demo_ecosystem.screenplays')
            .update({
                status,
                updated_at: new Date().toISOString()
            })
            .eq('screenplay_id', screenplayId);
    }

    /**
     * Check generation progress
     */
    async checkProgress(screenplayId: string): Promise<{
        total: number;
        completed: number;
        failed: number;
        pending: number;
        percentage: number;
    }> {
        const { data: elements } = await this.supabase
            .from('demo_ecosystem.screenplay_elements')
            .select('generation_status')
            .eq('screenplay_id', screenplayId)
            .not('generation_status', 'is', null);

        const total = elements?.length || 0;
        const completed = elements?.filter(e => e.generation_status === 'completed').length || 0;
        const failed = elements?.filter(e => e.generation_status === 'failed').length || 0;
        const pending = total - completed - failed;

        return {
            total,
            completed,
            failed,
            pending,
            percentage: total > 0 ? Math.round((completed / total) * 100) : 0
        };
    }

    /**
     * Assemble final demo URL
     */
    async assembleDemo(screenplayId: string): Promise<string> {
        // Get all completed elements with video URLs
        const { data: elements } = await this.supabase
            .from('demo_ecosystem.screenplay_elements')
            .select('*')
            .eq('screenplay_id', screenplayId)
            .eq('generation_status', 'completed')
            .order('sequence_order', { ascending: true });

        // Create demo manifest
        const manifest = {
            screenplay_id: screenplayId,
            elements: elements?.map(e => ({
                order: e.sequence_order,
                type: e.element_type,
                video_url: e.generated_video_url,
                audio_url: e.generated_audio_url,
                duration: e.duration_seconds,
                motion: e.photo_motion,
                transition: e.transition_effect,
                avatar_position: e.avatar_position,
                avatar_size: e.avatar_size,
                pointer_movements: e.pointer_movements
            }))
        };

        // Save manifest
        await this.supabase
            .from('demo_ecosystem.screenplays')
            .update({
                demo_manifest: manifest,
                demo_url: `/demo/play/${screenplayId}`,
                status: 'ready'
            })
            .eq('screenplay_id', screenplayId);

        return `/demo/play/${screenplayId}`;
    }
}

// ============================================================
// FACTORY FUNCTION
// ============================================================

export function createOrchestrationService() {
    const supabaseUrl = process.env.SUPABASE_URL || '';
    const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
    const videoApiUrl = process.env.VIDEO_API_URL || 'https://your-project.supabase.co/functions/v1/generate-video';

    return new DemoOrchestrationService(supabaseUrl, supabaseKey, videoApiUrl);
}

export default DemoOrchestrationService;
