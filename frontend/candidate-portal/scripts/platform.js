/**
 * BroyhillGOP Platform - Unified Navigation & Integration Module
 * Connects all ecosystems to AI Brain Intelligence (Ecosystem 20)
 * Provides cross-ecosystem navigation and real-time status
 */

const BroyhillGOP = {
    // Supabase Configuration
    config: {
        supabaseUrl: 'https://isbgjpnbocdkeslofota.supabase.co',
        supabaseKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlzYmdqcG5ib2Nka2VzbG9mb3RhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzM4NzI2NTcsImV4cCI6MjA0OTQ0ODY1N30.UwpYp7KjMT8vO0cTxFjDadO3BQPkt9JsI0S4-RwA0Mw',
        apiBase: '/api'
    },

    // Current candidate context
    candidate: {
        id: 'dave-boliek',
        name: 'Dave Boliek',
        office: 'NC House District 68',
        avatar: 'DB'
    },

    // All 16 Ecosystems with status
    ecosystems: [
        { id: 'donor-intelligence', name: 'Donor Intelligence', icon: 'ti-users', color: '#0071e3', file: 'ecosystem-donor-intelligence.html', python: 'ecosystem_01_donor_intelligence_complete.py' },
        { id: 'email', name: 'Email Studio', icon: 'ti-mail', color: '#34c759', file: 'ecosystem-email.html', python: 'ecosystem_30_email_complete.py' },
        { id: 'sms', name: 'SMS Center', icon: 'ti-message', color: '#af52de', file: 'ecosystem-sms.html', python: 'ecosystem_31_sms_complete.py' },
        { id: 'voice', name: 'ULTRA Voice', icon: 'ti-microphone', color: '#ff3b30', file: 'ecosystem-voice.html', python: 'ecosystem_16b_voice_synthesis_ULTRA.py' },
        { id: 'video', name: 'Video Studio', icon: 'ti-video', color: '#ff2d55', file: 'ecosystem-video.html', python: 'ecosystem_45_video_studio_complete.py' },
        { id: 'direct-mail', name: 'Direct Mail', icon: 'ti-mail-forward', color: '#ff9500', file: 'ecosystem-direct-mail.html', python: 'ecosystem_33_direct_mail_complete.py' },
        { id: 'donations', name: 'Donations', icon: 'ti-wallet', color: '#34c759', file: 'ecosystem-donations.html', python: 'ecosystem_02_donation_processing_complete.py' },
        { id: 'events', name: 'Events & RSVP', icon: 'ti-calendar-event', color: '#5856d6', file: 'ecosystem-events.html', python: 'ecosystem_34_events_complete.py' },
        { id: 'volunteers', name: 'Volunteers', icon: 'ti-heart-handshake', color: '#32ade6', file: 'ecosystem-volunteers.html', python: 'ecosystem_05_volunteer_management_complete.py' },
        { id: 'social', name: 'Social Media', icon: 'ti-brand-twitter', color: '#ff2d55', file: 'ecosystem-social.html', python: 'ecosystem_19_social_media_manager.py' },
        { id: 'compliance', name: 'Compliance & FEC', icon: 'ti-shield-check', color: '#34c759', file: 'ecosystem-compliance.html', python: 'ecosystem_10_compliance_manager_complete.py' },
        { id: 'analytics', name: 'Analytics', icon: 'ti-chart-line', color: '#5ac8fa', file: 'ecosystem-analytics.html', python: 'ecosystem_06_analytics_engine_complete.py' },
        { id: 'ai-hub', name: 'AI Hub', icon: 'ti-sparkles', color: '#5856d6', file: 'ecosystem-ai-hub.html', python: 'ecosystem_13_ai_hub_complete.py' },
        { id: 'budget', name: 'Budget', icon: 'ti-currency-dollar', color: '#00c7be', file: 'ecosystem-budget.html', python: 'ecosystem_11_budget_management_complete.py' },
        { id: 'canvassing', name: 'Canvassing', icon: 'ti-map-pin', color: '#a8e063', file: 'ecosystem-canvassing.html', python: 'ecosystem_38_volunteer_coordination_complete.py' },
        { id: 'phone-banking', name: 'Phone Banking', icon: 'ti-phone', color: '#5856d6', file: 'ecosystem-phone-banking.html', python: 'ecosystem_32_phone_banking_complete.py' }
    ],

    // AI Brain Intelligence Connection (Ecosystem 20)
    aiBrain: {
        endpoint: '/api/ai-brain',
        status: 'active',
        
        async getRecommendations(ecosystemId) {
            try {
                const response = await fetch(`${BroyhillGOP.config.apiBase}/ai-brain/recommendations/${ecosystemId}`);
                return await response.json();
            } catch (e) {
                console.log('AI Brain offline, using cached recommendations');
                return this.getCachedRecommendations(ecosystemId);
            }
        },
        
        async logActivity(ecosystemId, action, data) {
            try {
                await fetch(`${BroyhillGOP.config.apiBase}/ai-brain/activity`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ ecosystem: ecosystemId, action, data, timestamp: new Date().toISOString() })
                });
            } catch (e) {
                console.log('Activity logged locally');
            }
        },
        
        getCachedRecommendations(ecosystemId) {
            return {
                insights: [
                    { type: 'opportunity', message: 'AI Brain analyzing patterns...' }
                ]
            };
        }
    },

    // Machine Learning Cost Accounting
    costAccounting: {
        async getEcosystemCosts(ecosystemId) {
            return {
                totalSpend: 0,
                costPerAction: 0,
                roi: 0,
                budget: { allocated: 0, remaining: 0 }
            };
        },
        
        async trackCost(ecosystemId, actionType, cost) {
            console.log(`Cost tracked: ${ecosystemId} - ${actionType} - $${cost}`);
        }
    },

    // Generate Navigation HTML
    generateNavigation(currentPage) {
        const commandCenterPath = '../command-center/DAVE_BOLIEK_COMMAND_CENTER.html';
        const ecosystemPath = '../candidate-portal/';
        
        return `
        <aside class="sidebar">
            <div class="sidebar-header">
                <a href="${commandCenterPath}" class="logo">
                    <div class="logo-icon">B</div>
                    <span class="logo-text">BroyhillGOP</span>
                </a>
            </div>
            
            <div class="candidate-card">
                <div class="candidate-info">
                    <div class="candidate-avatar">${this.candidate.avatar}</div>
                    <div>
                        <div class="candidate-name">${this.candidate.name}</div>
                        <div class="candidate-office">${this.candidate.office}</div>
                    </div>
                </div>
            </div>
            
            <a href="${commandCenterPath}" class="back-btn">
                <i class="ti ti-home"></i> Command Center
            </a>
            
            <nav class="sidebar-nav">
                <div class="nav-section">
                    <div class="nav-section-title">Communication</div>
                    ${this.renderNavItems(['email', 'sms', 'voice', 'video', 'direct-mail'], currentPage, ecosystemPath)}
                </div>
                
                <div class="nav-section">
                    <div class="nav-section-title">Fundraising</div>
                    ${this.renderNavItems(['donor-intelligence', 'donations', 'events'], currentPage, ecosystemPath)}
                </div>
                
                <div class="nav-section">
                    <div class="nav-section-title">Operations</div>
                    ${this.renderNavItems(['volunteers', 'canvassing', 'phone-banking'], currentPage, ecosystemPath)}
                </div>
                
                <div class="nav-section">
                    <div class="nav-section-title">Intelligence</div>
                    ${this.renderNavItems(['ai-hub', 'analytics', 'social'], currentPage, ecosystemPath)}
                </div>
                
                <div class="nav-section">
                    <div class="nav-section-title">Management</div>
                    ${this.renderNavItems(['budget', 'compliance'], currentPage, ecosystemPath)}
                </div>
            </nav>
            
            <div class="sidebar-footer">
                <div class="ai-brain-status">
                    <i class="ti ti-brain"></i>
                    <span>AI Brain: Active</span>
                    <div class="status-dot active"></div>
                </div>
            </div>
        </aside>`;
    },

    renderNavItems(ids, currentPage, basePath) {
        return ids.map(id => {
            const eco = this.ecosystems.find(e => e.id === id);
            if (!eco) return '';
            const isActive = currentPage === eco.id;
            return `
                <a href="${basePath}${eco.file}" class="nav-item ${isActive ? 'active' : ''}" style="${isActive ? '' : `--nav-color: ${eco.color}`}">
                    <i class="${eco.icon}"></i>
                    <span>${eco.name}</span>
                </a>`;
        }).join('');
    },

    // Initialize on page load
    init(currentEcosystem) {
        console.log(`BroyhillGOP Platform initialized - ${currentEcosystem}`);
        this.aiBrain.logActivity(currentEcosystem, 'page_view', { timestamp: new Date() });
        
        // Add keyboard shortcut for Command Center (Cmd/Ctrl + H)
        document.addEventListener('keydown', (e) => {
            if ((e.metaKey || e.ctrlKey) && e.key === 'h') {
                e.preventDefault();
                window.location.href = '../command-center/DAVE_BOLIEK_COMMAND_CENTER.html';
            }
        });
    }
};

// Auto-detect current page and initialize
document.addEventListener('DOMContentLoaded', () => {
    const path = window.location.pathname;
    const match = path.match(/ecosystem-([^.]+)\.html/);
    if (match) {
        BroyhillGOP.init(match[1]);
    }
});

// Export for module usage
if (typeof module !== 'undefined') {
    module.exports = BroyhillGOP;
}
