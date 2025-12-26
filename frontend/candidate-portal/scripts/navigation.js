// ============================================================================
// BROYHILLGOP SHARED NAVIGATION & SUPABASE CONNECTION
// Include this in all ecosystem pages
// ============================================================================

// Supabase Config
const SUPABASE_URL = 'https://isbgjpnbocdkeslofota.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlzYmdqcG5ib2Nka2VzbG9mb3RhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3MDc3MDcsImV4cCI6MjA4MDI4MzcwN30.pSF0-C-QOklmDWtbexUvnFphuz_bFTdF4INaBMSW1SM';

// Initialize Supabase (requires supabase-js to be loaded first)
let supabase;
if (window.supabase) {
    supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
}

// ============================================================================
// NAVIGATION HTML
// ============================================================================
const SIDEBAR_HTML = `
<aside class="sidebar" id="main-sidebar">
    <div class="sidebar-logo">
        <div class="logo-icon">B</div>
        <span class="logo-text">BroyhillGOP</span>
    </div>
    
    <div class="candidate-profile">
        <img src="https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=160&h=160&fit=crop&crop=face" class="candidate-photo" id="candidate-photo">
        <div class="candidate-name" id="candidate-name">Candidate Portal</div>
        <div class="candidate-office" id="candidate-office"></div>
        <a href="settings.html" class="settings-link"><i class="ti ti-settings"></i> Settings</a>
    </div>
    
    <nav class="nav-scroll">
        <a href="homepage.html" class="nav-item" data-page="homepage"><i class="ti ti-home"></i> Home</a>
        <a href="campaign-wizard.html" class="nav-item" data-page="campaign-wizard"><i class="ti ti-wand"></i> Campaign Wizard</a>
        
        <div class="nav-section">Donors & Volunteers</div>
        <a href="ecosystem-donor-intelligence-triple.html" class="nav-item" data-page="donor-intelligence"><i class="ti ti-chart-dots-3"></i> Donor Intelligence</a>
        <a href="donors-all.html" class="nav-item" data-page="donors-all"><i class="ti ti-users"></i> All Donors</a>
        <a href="donors-top-ai.html" class="nav-item" data-page="donors-top"><i class="ti ti-crown"></i> Top Donors</a>
        <a href="ecosystem-volunteers.html" class="nav-item" data-page="volunteers"><i class="ti ti-heart-handshake"></i> Volunteers</a>
        
        <div class="nav-section">Outreach</div>
        <a href="ecosystem-email.html" class="nav-item" data-page="email"><i class="ti ti-mail"></i> Email</a>
        <a href="ecosystem-sms.html" class="nav-item" data-page="sms"><i class="ti ti-message-circle"></i> SMS</a>
        <a href="ecosystem-phone-banking.html" class="nav-item" data-page="phone"><i class="ti ti-phone-call"></i> Phone Banking</a>
        <a href="ecosystem-direct-mail.html" class="nav-item" data-page="mail"><i class="ti ti-mailbox"></i> Direct Mail</a>
        <a href="ecosystem-social.html" class="nav-item" data-page="social"><i class="ti ti-brand-facebook"></i> Social Media</a>
        
        <div class="nav-section">Campaign</div>
        <a href="ecosystem-events.html" class="nav-item" data-page="events"><i class="ti ti-calendar-event"></i> Events</a>
        <a href="ecosystem-canvassing.html" class="nav-item" data-page="canvassing"><i class="ti ti-map-pin"></i> Canvassing</a>
        <a href="ecosystem-video.html" class="nav-item" data-page="video"><i class="ti ti-video"></i> Video Studio</a>
        <a href="ecosystem-voice.html" class="nav-item" data-page="voice"><i class="ti ti-microphone"></i> Voice AI</a>
        
        <div class="nav-section">Management</div>
        <a href="ecosystem-donations.html" class="nav-item" data-page="donations"><i class="ti ti-cash"></i> Donations</a>
        <a href="ecosystem-budget.html" class="nav-item" data-page="budget"><i class="ti ti-calculator"></i> Budget</a>
        <a href="ecosystem-compliance.html" class="nav-item" data-page="compliance"><i class="ti ti-shield-check"></i> Compliance</a>
        <a href="ecosystem-analytics.html" class="nav-item" data-page="analytics"><i class="ti ti-chart-bar"></i> Analytics</a>
        
        <div class="nav-divider"></div>
        <a href="ecosystem-ai-hub.html" class="nav-item" data-page="ai-hub"><i class="ti ti-brain"></i> AI Hub</a>
        <a href="settings.html" class="nav-item" data-page="settings"><i class="ti ti-settings"></i> Settings</a>
    </nav>
</aside>
`;

// ============================================================================
// NAVIGATION STYLES
// ============================================================================
const SIDEBAR_STYLES = `
<style id="broyhillgop-nav-styles">
    :root {
        --text-primary: #1d1d1f;
        --text-secondary: #86868b;
        --text-tertiary: #aeaeb2;
        --bg-primary: #ffffff;
        --bg-secondary: #f5f5f7;
        --bg-hover: #f0f0f2;
        --border-color: #e5e5e7;
        --accent-red: #cc0000;
        --sidebar-width: 280px;
    }
    .sidebar {
        position: fixed;
        left: 0;
        top: 0;
        bottom: 0;
        width: var(--sidebar-width);
        background: var(--bg-primary);
        border-right: 1px solid var(--border-color);
        display: flex;
        flex-direction: column;
        z-index: 100;
        overflow: hidden;
    }
    .sidebar-logo {
        padding: 20px;
        border-bottom: 1px solid var(--border-color);
        display: flex;
        align-items: center;
        gap: 12px;
    }
    .logo-icon {
        width: 40px;
        height: 40px;
        background: linear-gradient(135deg, #cc0000, #990000);
        border-radius: 10px;
        display: flex;
        align-items: center;
        justify-content: center;
        color: white;
        font-weight: 700;
        font-size: 16px;
    }
    .logo-text { font-size: 18px; font-weight: 700; }
    .candidate-profile {
        padding: 20px;
        text-align: center;
        border-bottom: 1px solid var(--border-color);
        background: var(--bg-secondary);
    }
    .candidate-photo {
        width: 70px;
        height: 70px;
        border-radius: 50%;
        object-fit: cover;
        margin-bottom: 10px;
        border: 3px solid white;
        box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    }
    .candidate-name { font-size: 16px; font-weight: 600; }
    .candidate-office { font-size: 12px; color: var(--text-secondary); margin-bottom: 10px; }
    .settings-link {
        display: inline-flex;
        align-items: center;
        gap: 4px;
        padding: 6px 12px;
        font-size: 12px;
        color: var(--text-secondary);
        background: white;
        border-radius: 6px;
        text-decoration: none;
        transition: all 0.15s;
    }
    .settings-link:hover { background: var(--bg-hover); color: var(--text-primary); }
    .nav-scroll {
        flex: 1;
        overflow-y: auto;
        padding: 12px 0;
    }
    .nav-section {
        padding: 16px 20px 8px;
        font-size: 10px;
        font-weight: 700;
        color: var(--text-tertiary);
        text-transform: uppercase;
        letter-spacing: 1px;
    }
    .nav-item {
        display: flex;
        align-items: center;
        padding: 10px 20px;
        margin: 2px 10px;
        color: var(--text-primary);
        text-decoration: none;
        font-size: 13px;
        font-weight: 500;
        border-radius: 8px;
        transition: all 0.15s;
    }
    .nav-item:hover { background: var(--bg-hover); }
    .nav-item.active { background: rgba(204, 0, 0, 0.1); color: var(--accent-red); }
    .nav-item i { width: 22px; font-size: 17px; margin-right: 10px; opacity: 0.7; }
    .nav-item.active i { opacity: 1; color: var(--accent-red); }
    .nav-divider { height: 1px; background: var(--border-color); margin: 10px 20px; }
    .main-with-sidebar { margin-left: var(--sidebar-width); min-height: 100vh; }
</style>
`;

// ============================================================================
// INJECT NAVIGATION
// ============================================================================
function injectNavigation(activePage) {
    // Add styles if not present
    if (!document.getElementById('broyhillgop-nav-styles')) {
        document.head.insertAdjacentHTML('beforeend', SIDEBAR_STYLES);
    }
    
    // Check if sidebar already exists
    if (document.getElementById('main-sidebar')) {
        return;
    }
    
    // Insert sidebar at start of body
    document.body.insertAdjacentHTML('afterbegin', SIDEBAR_HTML);
    
    // Set active page
    if (activePage) {
        const activeItem = document.querySelector(`.nav-item[data-page="${activePage}"]`);
        if (activeItem) {
            activeItem.classList.add('active');
        }
    }
    
    // Auto-detect active page from URL
    const path = window.location.pathname;
    document.querySelectorAll('.nav-item').forEach(item => {
        const href = item.getAttribute('href');
        if (href && path.includes(href.replace('.html', ''))) {
            item.classList.add('active');
        }
    });
}

// ============================================================================
// DATABASE HELPERS
// ============================================================================
const DB = {
    // Get donors with grades
    async getDonors(options = {}) {
        let query = supabase.from('persons').select('*').eq('is_donor', true);
        
        if (options.grade) {
            query = query.eq('donor_grade_state', options.grade);
        }
        if (options.county) {
            query = query.eq('county', options.county);
        }
        if (options.district) {
            query = query.eq('district_state_house', options.district);
        }
        if (options.limit) {
            query = query.limit(options.limit);
        }
        if (options.orderBy) {
            query = query.order(options.orderBy, { ascending: false });
        }
        
        const { data, error } = await query;
        return { data, error };
    },
    
    // Get districts
    async getDistricts(type = null) {
        let query = supabase.from('nc_districts').select('*');
        if (type) {
            query = query.eq('district_type', type);
        }
        const { data, error } = await query.order('district_id');
        return { data, error };
    },
    
    // Get office types
    async getOfficeTypes() {
        const { data, error } = await supabase
            .from('nc_office_types')
            .select('*')
            .order('office_category, office_name');
        return { data, error };
    },
    
    // Get donation levels
    async getDonationLevels() {
        const { data, error } = await supabase
            .from('donation_menu_levels')
            .select('*')
            .eq('is_active', true)
            .order('display_order');
        return { data, error };
    },
    
    // Get special guests
    async getSpecialGuests() {
        const { data, error } = await supabase
            .from('special_guest_types')
            .select('*')
            .order('multiplier', { ascending: false });
        return { data, error };
    },
    
    // Get microsegment performance
    async getMicrosegments(options = {}) {
        let query = supabase.from('microsegment_performance').select('*');
        if (options.strategy) {
            query = query.eq('current_strategy', options.strategy);
        }
        const { data, error } = await query.order('roi', { ascending: false });
        return { data, error };
    },
    
    // Count records
    async count(table, filters = {}) {
        let query = supabase.from(table).select('*', { count: 'exact', head: true });
        Object.entries(filters).forEach(([key, value]) => {
            query = query.eq(key, value);
        });
        const { count, error } = await query;
        return { count, error };
    }
};

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================
const Utils = {
    // Format currency
    currency(amount) {
        return new Intl.NumberFormat('en-US', { 
            style: 'currency', 
            currency: 'USD',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(amount || 0);
    },
    
    // Format number
    number(n) {
        return new Intl.NumberFormat('en-US').format(n || 0);
    },
    
    // Format percentage
    percent(n) {
        return (n * 100).toFixed(1) + '%';
    },
    
    // Grade color
    gradeColor(grade) {
        if (!grade) return '#86868b';
        if (grade.startsWith('A')) return '#34c759';
        if (grade.startsWith('B')) return '#007aff';
        if (grade.startsWith('C')) return '#ff9500';
        if (grade.startsWith('D')) return '#ff3b30';
        return '#86868b';
    },
    
    // Debounce
    debounce(fn, delay) {
        let timer;
        return (...args) => {
            clearTimeout(timer);
            timer = setTimeout(() => fn(...args), delay);
        };
    }
};

// ============================================================================
// AUTO-INITIALIZE
// ============================================================================
document.addEventListener('DOMContentLoaded', () => {
    // Auto-inject navigation if sidebar placeholder exists
    const placeholder = document.getElementById('sidebar-placeholder');
    if (placeholder) {
        placeholder.outerHTML = SIDEBAR_HTML;
        if (!document.getElementById('broyhillgop-nav-styles')) {
            document.head.insertAdjacentHTML('beforeend', SIDEBAR_STYLES);
        }
    }
});

// Export for use
window.BroyhillGOP = { supabase, DB, Utils, injectNavigation };
