/**
 * ============================================================
 * BROYHILLGOP DEMO CREATOR - FRONTEND API CLIENT
 * ============================================================
 * Client-side library to connect Admin Console to backend APIs
 * Include this in the Admin Console HTML
 * ============================================================
 */

class BroyhillGOPClient {
    constructor(config = {}) {
        this.supabaseUrl = config.supabaseUrl || '';
        this.supabaseKey = config.supabaseKey || '';
        this.videoApiUrl = config.videoApiUrl || `${this.supabaseUrl}/functions/v1/generate-video`;
        
        // Initialize Supabase client if available
        if (window.supabase && this.supabaseUrl && this.supabaseKey) {
            this.supabase = window.supabase.createClient(this.supabaseUrl, this.supabaseKey);
        }
    }

    // ============================================================
    // SCREENPLAY MANAGEMENT
    // ============================================================

    /**
     * Create a new screenplay
     */
    async createScreenplay(data) {
        const { data: screenplay, error } = await this.supabase
            .from('demo_ecosystem.screenplays')
            .insert({
                title: data.title,
                start_date: data.startDate,
                target_completion: data.targetCompletion,
                purpose: data.purpose,
                tone_id: data.tone,
                framework_id: data.framework,
                selected_issues: data.selectedIssues,
                selected_channels: data.selectedChannels,
                selected_ecosystems: data.selectedEcosystems,
                show_21_tier_grading: data.show21TierGrading,
                show_1000_point_scoring: data.show1000PointScoring,
                show_heat_map: data.showHeatMap,
                candidate_id: data.candidateId,
                created_by: data.createdBy
            })
            .select()
            .single();

        if (error) throw new Error(error.message);
        return screenplay;
    }

    /**
     * Update screenplay
     */
    async updateScreenplay(screenplayId, data) {
        const { data: screenplay, error } = await this.supabase
            .from('demo_ecosystem.screenplays')
            .update(data)
            .eq('screenplay_id', screenplayId)
            .select()
            .single();

        if (error) throw new Error(error.message);
        return screenplay;
    }

    /**
     * Get screenplay with all elements
     */
    async getScreenplay(screenplayId) {
        const { data, error } = await this.supabase
            .from('demo_ecosystem.screenplays')
            .select(`
                *,
                tones(*),
                messaging_frameworks(*),
                candidates(*),
                screenplay_elements(
                    *,
                    pointer_movements(*),
                    avatar_library(*),
                    voice_library(*),
                    music_library(*)
                )
            `)
            .eq('screenplay_id', screenplayId)
            .single();

        if (error) throw new Error(error.message);
        return data;
    }

    /**
     * List all screenplays
     */
    async listScreenplays(filters = {}) {
        let query = this.supabase
            .from('demo_ecosystem.screenplays')
            .select('*, tones(tone_name), candidates(full_name)')
            .order('created_at', { ascending: false });

        if (filters.status) {
            query = query.eq('status', filters.status);
        }

        const { data, error } = await query;
        if (error) throw new Error(error.message);
        return data;
    }

    // ============================================================
    // SCREENPLAY ELEMENTS
    // ============================================================

    /**
     * Add element to screenplay
     */
    async addElement(screenplayId, elementData) {
        // Get current max sequence order
        const { data: existing } = await this.supabase
            .from('demo_ecosystem.screenplay_elements')
            .select('sequence_order')
            .eq('screenplay_id', screenplayId)
            .order('sequence_order', { ascending: false })
            .limit(1);

        const nextOrder = existing?.length > 0 ? existing[0].sequence_order + 1 : 1;

        const { data: element, error } = await this.supabase
            .from('demo_ecosystem.screenplay_elements')
            .insert({
                screenplay_id: screenplayId,
                sequence_order: nextOrder,
                ...elementData
            })
            .select()
            .single();

        if (error) throw new Error(error.message);
        return element;
    }

    /**
     * Update element
     */
    async updateElement(elementId, data) {
        const { data: element, error } = await this.supabase
            .from('demo_ecosystem.screenplay_elements')
            .update(data)
            .eq('element_id', elementId)
            .select()
            .single();

        if (error) throw new Error(error.message);
        return element;
    }

    /**
     * Delete element
     */
    async deleteElement(elementId) {
        const { error } = await this.supabase
            .from('demo_ecosystem.screenplay_elements')
            .delete()
            .eq('element_id', elementId);

        if (error) throw new Error(error.message);
        return true;
    }

    /**
     * Reorder elements
     */
    async reorderElements(screenplayId, elementIds) {
        const updates = elementIds.map((id, index) => ({
            element_id: id,
            sequence_order: index + 1
        }));

        for (const update of updates) {
            await this.supabase
                .from('demo_ecosystem.screenplay_elements')
                .update({ sequence_order: update.sequence_order })
                .eq('element_id', update.element_id);
        }

        return true;
    }

    // ============================================================
    // VIDEO GENERATION
    // ============================================================

    /**
     * Generate video from photo and script
     */
    async generateFromPhoto(options) {
        const response = await fetch(this.videoApiUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.supabaseKey}`
            },
            body: JSON.stringify({
                action: 'generate-from-photo',
                ...options
            })
        });

        const result = await response.json();
        if (!response.ok) throw new Error(result.error);
        return result;
    }

    /**
     * Generate audio from text
     */
    async generateAudio(options) {
        const response = await fetch(this.videoApiUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.supabaseKey}`
            },
            body: JSON.stringify({
                action: 'generate-audio',
                ...options
            })
        });

        const result = await response.json();
        if (!response.ok) throw new Error(result.error);
        return result;
    }

    /**
     * Check video generation status
     */
    async checkGenerationStatus(provider, jobId) {
        const response = await fetch(this.videoApiUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.supabaseKey}`
            },
            body: JSON.stringify({
                action: 'check-status',
                provider,
                jobId
            })
        });

        const result = await response.json();
        if (!response.ok) throw new Error(result.error);
        return result;
    }

    /**
     * Start full demo generation
     */
    async generateDemo(screenplayId) {
        // Update status
        await this.updateScreenplay(screenplayId, { status: 'generating' });

        // Get all elements
        const screenplay = await this.getScreenplay(screenplayId);
        const jobs = [];

        // Process each element that needs generation
        for (const element of screenplay.screenplay_elements || []) {
            if (['text-to-video', 'avatar'].includes(element.element_type)) {
                try {
                    const job = await this.generateFromPhoto({
                        photoUrl: element.avatar_library?.photo_url || screenplay.candidates?.profile_photo_url,
                        script: this.processScript(element.content_text, screenplay),
                        voiceId: element.voice_library?.api_voice_id || 'en-US-JennyNeural',
                        provider: 'heygen'
                    });

                    // Save job ID to element
                    await this.updateElement(element.element_id, {
                        generation_job_id: job.video_id || job.id,
                        generation_status: 'processing'
                    });

                    jobs.push(job);
                } catch (error) {
                    console.error(`Failed to generate element ${element.element_id}:`, error);
                    await this.updateElement(element.element_id, {
                        generation_status: 'failed',
                        generation_error: error.message
                    });
                }
            }
        }

        return { screenplayId, jobsStarted: jobs.length };
    }

    /**
     * Process script with variable substitution
     */
    processScript(script, screenplay) {
        if (!script) return '';

        let processed = script;
        const candidate = screenplay.candidates || {};

        const variables = {
            '[NAME]': candidate.full_name || 'Candidate',
            '[CANDIDATE_NAME]': candidate.full_name || 'Candidate',
            '[COMPANY]': 'BroyhillGOP',
            '[NUMBER]': '28,450',
            '[DONOR_COUNT]': candidate.matched_donor_count?.toLocaleString() || '28,450',
            '[FUNDRAISING_POTENTIAL]': candidate.fundraising_potential 
                ? `$${(candidate.fundraising_potential / 1000000).toFixed(1)} million`
                : '$6.2 million'
        };

        for (const [key, value] of Object.entries(variables)) {
            processed = processed.replace(new RegExp(key.replace(/[[\]]/g, '\\$&'), 'g'), value);
        }

        // Convert pause markers
        processed = processed.replace(/\[PAUSE\]/g, '...');
        processed = processed.replace(/\[LONG_PAUSE\]/g, '... ...');
        processed = processed.replace(/\[EMPHASIS\]/g, '');
        processed = processed.replace(/\[\/EMPHASIS\]/g, '');

        return processed;
    }

    // ============================================================
    // REFERENCE DATA
    // ============================================================

    /**
     * Get all tones
     */
    async getTones() {
        const { data, error } = await this.supabase
            .from('demo_ecosystem.tones')
            .select('*')
            .eq('is_active', true)
            .order('display_order');

        if (error) throw new Error(error.message);
        return data;
    }

    /**
     * Get all messaging frameworks
     */
    async getFrameworks() {
        const { data, error } = await this.supabase
            .from('demo_ecosystem.messaging_frameworks')
            .select('*')
            .eq('is_active', true)
            .order('display_order');

        if (error) throw new Error(error.message);
        return data;
    }

    /**
     * Get all hot issues
     */
    async getHotIssues() {
        const { data, error } = await this.supabase
            .from('demo_ecosystem.hot_issues')
            .select('*')
            .eq('is_active', true)
            .order('display_order');

        if (error) throw new Error(error.message);
        return data;
    }

    /**
     * Get voice library
     */
    async getVoices() {
        const { data, error } = await this.supabase
            .from('demo_ecosystem.voice_library')
            .select('*')
            .eq('is_active', true);

        if (error) throw new Error(error.message);
        return data;
    }

    /**
     * Get avatar library
     */
    async getAvatars() {
        const { data, error } = await this.supabase
            .from('demo_ecosystem.avatar_library')
            .select('*')
            .eq('is_active', true);

        if (error) throw new Error(error.message);
        return data;
    }

    /**
     * Get music library
     */
    async getMusic() {
        const { data, error } = await this.supabase
            .from('demo_ecosystem.music_library')
            .select('*')
            .eq('is_active', true);

        if (error) throw new Error(error.message);
        return data;
    }

    /**
     * Get motion effects
     */
    async getMotionEffects() {
        const { data, error } = await this.supabase
            .from('demo_ecosystem.motion_effects')
            .select('*')
            .eq('is_active', true);

        if (error) throw new Error(error.message);
        return data;
    }

    // ============================================================
    // FILE UPLOAD
    // ============================================================

    /**
     * Upload photo for avatar
     */
    async uploadPhoto(file, bucket = 'avatars') {
        const fileName = `${Date.now()}-${file.name}`;
        
        const { data, error } = await this.supabase.storage
            .from(bucket)
            .upload(fileName, file);

        if (error) throw new Error(error.message);

        // Get public URL
        const { data: urlData } = this.supabase.storage
            .from(bucket)
            .getPublicUrl(fileName);

        return urlData.publicUrl;
    }

    /**
     * Upload audio for voice cloning
     */
    async uploadAudioSample(file) {
        return this.uploadPhoto(file, 'voice-samples');
    }

    // ============================================================
    // DEMO SESSIONS
    // ============================================================

    /**
     * Create demo session (when candidate starts watching)
     */
    async createDemoSession(screenplayId, candidateInfo) {
        const sessionToken = this.generateToken();

        const { data, error } = await this.supabase
            .from('demo_ecosystem.demo_sessions')
            .insert({
                screenplay_id: screenplayId,
                session_token: sessionToken,
                email_used: candidateInfo.email,
                first_name_used: candidateInfo.firstName,
                started_at: new Date().toISOString()
            })
            .select()
            .single();

        if (error) throw new Error(error.message);
        return data;
    }

    /**
     * Track analytics event
     */
    async trackEvent(sessionId, eventType, eventTarget, data = {}) {
        const { error } = await this.supabase
            .from('demo_ecosystem.demo_analytics')
            .insert({
                session_id: sessionId,
                event_type: eventType,
                event_target: eventTarget,
                event_data: data
            });

        if (error) console.error('Failed to track event:', error);
    }

    /**
     * Generate random token
     */
    generateToken() {
        return Array.from(crypto.getRandomValues(new Uint8Array(32)))
            .map(b => b.toString(16).padStart(2, '0'))
            .join('');
    }
}

// ============================================================
// INITIALIZE AND EXPORT
// ============================================================

// Create global instance
window.BroyhillGOP = new BroyhillGOPClient({
    supabaseUrl: 'YOUR_SUPABASE_URL',
    supabaseKey: 'YOUR_SUPABASE_ANON_KEY'
});

// Usage examples:
/*
// Create a screenplay
const screenplay = await BroyhillGOP.createScreenplay({
    title: 'NC Governor Demo 2028',
    startDate: '2025-01-15',
    purpose: 'Personalized demo for gubernatorial candidates',
    tone: 'authoritative',
    framework: 'problem-solution',
    selectedIssues: ['second-amendment', 'fiscal-conservative', 'border-security']
});

// Add an element
await BroyhillGOP.addElement(screenplay.screenplay_id, {
    element_type: 'avatar',
    content_text: 'Welcome, [NAME]! I am excited to show you the BroyhillGOP platform.',
    avatar_id: 'ed-broyhill',
    voice_id: 'deep-authoritative',
    photo_motion: 'zoom-in',
    transition_effect: 'fade',
    avatar_position: 'bottom-right',
    avatar_size: 'medium',
    duration_seconds: 30
});

// Generate the demo
await BroyhillGOP.generateDemo(screenplay.screenplay_id);

// Check status
const status = await BroyhillGOP.checkGenerationStatus('heygen', jobId);
*/
