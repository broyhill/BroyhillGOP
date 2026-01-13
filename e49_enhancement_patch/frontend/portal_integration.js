/**
 * E49 Portal Integration - Wire existing UI to API endpoints
 * Add to candidate_portal/index.html: <script src="portal_integration.js"></script>
 */
const E49_API_BASE = window.E49_API_BASE || 'http://gpu.broyhillgop.com:8080';
const E49 = {
    candidateId: null,
    init() {
        this.candidateId = this.getCandidateId();
        this.wireVoiceUpload();
        this.wirePhotoUpload();
        this.wireYouTubeSubmit();
        console.log('E49 Portal Integration initialized', { candidateId: this.candidateId });
    },
    getCandidateId() {
        const urlParams = new URLSearchParams(window.location.search);
        return urlParams.get('candidate_id') || sessionStorage.getItem('candidate_id') || localStorage.getItem('candidate_id');
    },
    wireVoiceUpload() {
        const input = document.querySelector('input[type="file"][accept*="audio"]');
        if (!input) return;
        input.addEventListener('change', async (e) => {
            const file = e.target.files[0];
            if (!file) return;
            try {
                this.showToast('Uploading voice sample...', 'info');
                const formData = new FormData();
                formData.append('file', file);
                formData.append('candidate_id', this.candidateId);
                formData.append('source', 'cellphone');
                const resp = await fetch(`${E49_API_BASE}/voice/upload`, { method: 'POST', body: formData });
                const result = await resp.json();
                if (result.success) {
                    this.showToast(`Voice sample uploaded! Duration: ${result.duration_sec.toFixed(1)}s`, 'success');
                } else {
                    throw new Error(result.detail || 'Upload failed');
                }
            } catch (err) {
                this.showToast(`Upload failed: ${err.message}`, 'error');
            }
        });
    },
    wirePhotoUpload() {
        const input = document.querySelector('input[type="file"][accept*="image"]');
        if (!input) return;
        input.addEventListener('change', async (e) => {
            const file = e.target.files[0];
            if (!file) return;
            try {
                this.showToast('Uploading photo...', 'info');
                const formData = new FormData();
                formData.append('file', file);
                formData.append('candidate_id', this.candidateId);
                formData.append('photo_type', 'headshot');
                const resp = await fetch(`${E49_API_BASE}/photo/upload`, { method: 'POST', body: formData });
                const result = await resp.json();
                if (result.success) {
                    this.showToast('Photo uploaded successfully!', 'success');
                    const preview = document.querySelector('.photo-preview img');
                    if (preview) preview.src = result.public_url;
                } else {
                    throw new Error(result.detail || 'Upload failed');
                }
            } catch (err) {
                this.showToast(`Upload failed: ${err.message}`, 'error');
            }
        });
    },
    wireYouTubeSubmit() {
        const form = document.querySelector('#youtube-form, form[data-youtube]');
        if (!form) return;
        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            const urlInput = form.querySelector('input[type="url"], input[name="youtube_url"]');
            if (!urlInput || !urlInput.value) return;
            try {
                this.showToast('Starting YouTube extraction...', 'info');
                const resp = await fetch(`${E49_API_BASE}/youtube/submit`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ youtube_url: urlInput.value, candidate_id: this.candidateId })
                });
                const result = await resp.json();
                if (result.success) {
                    this.showToast('YouTube extraction started! Check status shortly.', 'success');
                    this.pollJobStatus(result.job_id);
                } else {
                    throw new Error(result.detail || 'Submission failed');
                }
            } catch (err) {
                this.showToast(`YouTube extraction failed: ${err.message}`, 'error');
            }
        });
    },
    async pollJobStatus(jobId, maxAttempts = 60) {
        for (let i = 0; i < maxAttempts; i++) {
            await new Promise(r => setTimeout(r, 5000));
            try {
                const resp = await fetch(`${E49_API_BASE}/jobs/${jobId}/status`);
                const result = await resp.json();
                if (result.status === 'completed') {
                    this.showToast('Job completed successfully!', 'success');
                    return result;
                } else if (result.status === 'failed') {
                    this.showToast(`Job failed: ${result.error}`, 'error');
                    return result;
                }
            } catch (err) {
                console.warn('Status check failed:', err);
            }
        }
        this.showToast('Job timed out', 'warning');
    },
    showToast(message, type = 'info') {
        if (window.toastr) {
            toastr[type](message);
        } else {
            console.log(`[${type.toUpperCase()}] ${message}`);
            const toast = document.createElement('div');
            toast.className = `e49-toast e49-toast-${type}`;
            toast.textContent = message;
            toast.style.cssText = 'position:fixed;top:20px;right:20px;padding:12px 20px;border-radius:4px;z-index:9999;color:white;background:' + ({info:'#17a2b8',success:'#28a745',error:'#dc3545',warning:'#ffc107'}[type] || '#17a2b8');
            document.body.appendChild(toast);
            setTimeout(() => toast.remove(), 5000);
        }
    }
};
document.addEventListener('DOMContentLoaded', () => E49.init());
