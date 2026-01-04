#!/usr/bin/env python3
"""
BROYHILLGOP INSPINIA NAVIGATION BUILDER
Updates all ecosystem pages with 7-hemisphere dropdown navigation
"""

import os
import re

BASE_DIR = "/Users/Broyhill/Library/CloudStorage/GoogleDrive-ed@broyhill.net/My Drive/BroyhillGOP/inspinia 2/HTML/Full/dist"

# 7 HEMISPHERE NAVIGATION STRUCTURE
NAVIGATION_HTML = '''
            <!-- BroyhillGOP AI Logo - Campaign Composer Wizard Button -->
            <a href="campaign-composer-wizard.html" class="logo" style="display: block; margin: 10px; text-decoration: none;">
                <iframe src="assets/broyhillgop-logo.html" style="width: 100%; height: 150px; border: none; pointer-events: none;" scrolling="no"></iframe>
            </a>

            <!-- Sidebar Hover Menu Toggle Button -->
            <button class="button-on-hover">
                <i class="ti ti-menu-4 fs-22 align-middle"></i>
            </button>

            <!-- Full Sidebar Menu Close Button -->
            <button class="button-close-offcanvas">
                <i class="ti ti-x align-middle"></i>
            </button>

            <div class="scrollbar" data-simplebar>

                <!--- BroyhillGOP 7 Hemisphere Navigation -->
                <ul class="side-nav">
                    
                    <!-- CANDIDATE HOME -->
                    <li class="side-nav-item">
                        <a href="jeff-zenger.html" class="side-nav-link">
                            <span class="menu-icon"><i class="ti ti-home"></i></span>
                            <span class="menu-text">Candidate Home</span>
                        </a>
                    </li>

                    <!-- 1. BRAIN HUB -->
                    <li class="side-nav-title">🧠 BRAIN HUB</li>
                    <li class="side-nav-item">
                        <a data-bs-toggle="collapse" href="#sidebarBrainHub" aria-expanded="false" class="side-nav-link">
                            <span class="menu-icon"><i class="ti ti-brain"></i></span>
                            <span class="menu-text">Intelligence</span>
                            <span class="badge bg-danger">AI</span>
                        </a>
                        <div class="collapse" id="sidebarBrainHub">
                            <ul class="sub-menu">
                                <li class="side-nav-item"><a href="ecosystem-20-intelligence-brain.html" class="side-nav-link"><span class="menu-text">E20 Intelligence Brain</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-13-ai-hub.html" class="side-nav-link"><span class="menu-text">E13 AI Hub</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-21-ml-clustering.html" class="side-nav-link"><span class="menu-text">E21 ML Clustering</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-51-nexus.html" class="side-nav-link"><span class="menu-text">E51 NEXUS AI</span></a></li>
                            </ul>
                        </div>
                    </li>

                    <!-- 2. DATA HUB -->
                    <li class="side-nav-title">💾 DATA HUB</li>
                    <li class="side-nav-item">
                        <a data-bs-toggle="collapse" href="#sidebarDataHub" aria-expanded="false" class="side-nav-link">
                            <span class="menu-icon"><i class="ti ti-database"></i></span>
                            <span class="menu-text">Data</span>
                            <span class="badge bg-primary">130K+</span>
                        </a>
                        <div class="collapse" id="sidebarDataHub">
                            <ul class="sub-menu">
                                <li class="side-nav-item"><a href="ecosystem-00-datahub.html" class="side-nav-link"><span class="menu-text">E00 DataHub</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-15-contact-directory.html" class="side-nav-link"><span class="menu-text">E15 Contacts</span></a></li>
                                <li class="side-nav-item"><a href="data-upload.html" class="side-nav-link"><span class="menu-text">Data Upload</span></a></li>
                            </ul>
                        </div>
                    </li>

                    <!-- 3. DONORS -->
                    <li class="side-nav-title">💰 DONORS</li>
                    <li class="side-nav-item">
                        <a data-bs-toggle="collapse" href="#sidebarDonors" aria-expanded="false" class="side-nav-link">
                            <span class="menu-icon"><i class="ti ti-cash"></i></span>
                            <span class="menu-text">Fundraising</span>
                            <span class="menu-arrow"></span>
                        </a>
                        <div class="collapse" id="sidebarDonors">
                            <ul class="sub-menu">
                                <li class="side-nav-item"><a href="ecosystem-01-donor-intelligence.html" class="side-nav-link"><span class="menu-text">E01 Donor Intelligence</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-02-donations.html" class="side-nav-link"><span class="menu-text">E02 Donations</span></a></li>
                                <li class="side-nav-item"><a href="donors.html" class="side-nav-link"><span class="menu-text">All Donors</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-39-p2p-fundraising.html" class="side-nav-link"><span class="menu-text">E39 P2P Fundraising</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-25-donor-portal.html" class="side-nav-link"><span class="menu-text">E25 Donor Portal</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-10-compliance.html" class="side-nav-link"><span class="menu-text">E10 Compliance</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-11-budget.html" class="side-nav-link"><span class="menu-text">E11 Budget</span></a></li>
                            </ul>
                        </div>
                    </li>

                    <!-- 4. VOLUNTEERS -->
                    <li class="side-nav-title">🙋 VOLUNTEERS</li>
                    <li class="side-nav-item">
                        <a data-bs-toggle="collapse" href="#sidebarVolunteers" aria-expanded="false" class="side-nav-link">
                            <span class="menu-icon"><i class="ti ti-users-group"></i></span>
                            <span class="menu-text">Activists</span>
                            <span class="menu-arrow"></span>
                        </a>
                        <div class="collapse" id="sidebarVolunteers">
                            <ul class="sub-menu">
                                <li class="side-nav-item"><a href="ecosystem-04-activist-network.html" class="side-nav-link"><span class="menu-text">E04 Activist Network</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-05-volunteers.html" class="side-nav-link"><span class="menu-text">E05 Volunteer Mgmt</span></a></li>
                                <li class="side-nav-item"><a href="volunteers.html" class="side-nav-link"><span class="menu-text">All Volunteers</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-38-volunteer-coordination.html" class="side-nav-link"><span class="menu-text">E38 Coordination</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-34-events.html" class="side-nav-link"><span class="menu-text">E34 Events</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-26-volunteer-portal.html" class="side-nav-link"><span class="menu-text">E26 Vol Portal</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-43-advocacy-tools.html" class="side-nav-link"><span class="menu-text">E43 Advocacy</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-52-training-lms.html" class="side-nav-link"><span class="menu-text">E52 Training</span></a></li>
                            </ul>
                        </div>
                    </li>

                    <!-- 5. COMMUNICATIONS -->
                    <li class="side-nav-title">📣 COMMUNICATIONS</li>
                    <li class="side-nav-item">
                        <a data-bs-toggle="collapse" href="#sidebarComms" aria-expanded="false" class="side-nav-link">
                            <span class="menu-icon"><i class="ti ti-message-circle"></i></span>
                            <span class="menu-text">Channels</span>
                            <span class="menu-arrow"></span>
                        </a>
                        <div class="collapse" id="sidebarComms">
                            <ul class="sub-menu">
                                <li class="side-nav-item"><a href="ecosystem-30-email-studio.html" class="side-nav-link"><span class="menu-text">E30 Email</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-31-sms-studio.html" class="side-nav-link"><span class="menu-text">E31 SMS</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-32-phone-banking.html" class="side-nav-link"><span class="menu-text">E32 Phone Banking</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-17-rvm.html" class="side-nav-link"><span class="menu-text">E17 RVM</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-33-direct-mail.html" class="side-nav-link"><span class="menu-text">E33 Direct Mail</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-36-messenger-integration.html" class="side-nav-link"><span class="menu-text">E36 Messenger</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-35-interactive-comm-hub.html" class="side-nav-link"><span class="menu-text">E35 Comm Hub</span></a></li>
                            </ul>
                        </div>
                    </li>

                    <!-- 6. MEDIA -->
                    <li class="side-nav-title">🎬 MEDIA</li>
                    <li class="side-nav-item">
                        <a data-bs-toggle="collapse" href="#sidebarMedia" aria-expanded="false" class="side-nav-link">
                            <span class="menu-icon"><i class="ti ti-video"></i></span>
                            <span class="menu-text">Production</span>
                            <span class="menu-arrow"></span>
                        </a>
                        <div class="collapse" id="sidebarMedia">
                            <ul class="sub-menu">
                                <li class="side-nav-item"><a href="ecosystem-16-tv-radio.html" class="side-nav-link"><span class="menu-text">E16 TV/Radio AI</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-19-social-media.html" class="side-nav-link"><span class="menu-text">E19 Social Media</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-45-video-studio.html" class="side-nav-link"><span class="menu-text">E45 Video Studio</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-46-broadcast-hub.html" class="side-nav-link"><span class="menu-text">E46 Broadcast Hub</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-47-ai-script-generator.html" class="side-nav-link"><span class="menu-text">E47 Script Gen</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-48-communication-dna.html" class="side-nav-link"><span class="menu-text">E48 Comm DNA</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-18-vdp-composition.html" class="side-nav-link"><span class="menu-text">E18 VDP</span></a></li>
                            </ul>
                        </div>
                    </li>

                    <!-- 7. OPERATIONS -->
                    <li class="side-nav-title">⚙️ OPERATIONS</li>
                    <li class="side-nav-item">
                        <a data-bs-toggle="collapse" href="#sidebarOps" aria-expanded="false" class="side-nav-link">
                            <span class="menu-icon"><i class="ti ti-settings"></i></span>
                            <span class="menu-text">Management</span>
                            <span class="menu-arrow"></span>
                        </a>
                        <div class="collapse" id="sidebarOps">
                            <ul class="sub-menu">
                                <li class="side-nav-item"><a href="ecosystem-03-candidate-profiles.html" class="side-nav-link"><span class="menu-text">E03 Candidates</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-41-campaign-builder.html" class="side-nav-link"><span class="menu-text">E41 Campaign Builder</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-40-automation-control.html" class="side-nav-link"><span class="menu-text">E40 Automation</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-06-analytics.html" class="side-nav-link"><span class="menu-text">E06 Analytics</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-27-realtime-dashboard.html" class="side-nav-link"><span class="menu-text">E27 Dashboard</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-42-news-intelligence.html" class="side-nav-link"><span class="menu-text">E42 News Intel</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-08-communications-library.html" class="side-nav-link"><span class="menu-text">E08 Templates</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-09-content-creation-ai.html" class="side-nav-link"><span class="menu-text">E09 Content AI</span></a></li>
                                <li class="side-nav-item"><a href="ecosystem-55-api-gateway.html" class="side-nav-link"><span class="menu-text">E55 API Gateway</span></a></li>
                            </ul>
                        </div>
                    </li>

                    <!-- WIZARDS -->
                    <li class="side-nav-title">🎯 WIZARDS</li>
                    <li class="side-nav-item">
                        <a data-bs-toggle="collapse" href="#sidebarWizards" aria-expanded="false" class="side-nav-link">
                            <span class="menu-icon"><i class="ti ti-wand"></i></span>
                            <span class="menu-text">Compose</span>
                            <span class="badge bg-success">NEW</span>
                        </a>
                        <div class="collapse" id="sidebarWizards">
                            <ul class="sub-menu">
                                <li class="side-nav-item"><a href="campaign-composer-wizard.html" class="side-nav-link"><span class="menu-text">🎬 Campaign Composer</span></a></li>
                                <li class="side-nav-item"><a href="email-campaign-wizard.html" class="side-nav-link"><span class="menu-text">📧 Email Wizard</span></a></li>
                                <li class="side-nav-item"><a href="sms-campaign-wizard.html" class="side-nav-link"><span class="menu-text">💬 SMS Wizard</span></a></li>
                                <li class="side-nav-item"><a href="rvm-campaign-wizard.html" class="side-nav-link"><span class="menu-text">🎤 RVM Wizard</span></a></li>
                                <li class="side-nav-item"><a href="phone-banking-wizard.html" class="side-nav-link"><span class="menu-text">📞 Phone Wizard</span></a></li>
                                <li class="side-nav-item"><a href="direct-mail-wizard.html" class="side-nav-link"><span class="menu-text">📬 Mail Wizard</span></a></li>
                            </ul>
                        </div>
                    </li>

                    <!-- CONTROL PANEL -->
                    <li class="side-nav-title">🔧 CONTROL</li>
                    <li class="side-nav-item">
                        <a href="ecosystem-40-automation-control.html" class="side-nav-link">
                            <span class="menu-icon"><i class="ti ti-adjustments"></i></span>
                            <span class="menu-text">Control Panel</span>
                        </a>
                    </li>
                    <li class="side-nav-item">
                        <a href="settings.html" class="side-nav-link">
                            <span class="menu-icon"><i class="ti ti-settings-2"></i></span>
                            <span class="menu-text">Settings</span>
                        </a>
                    </li>

                </ul>
                <!--- End Sidenav -->
'''

# Pattern to find and replace the sidenav section
OLD_SIDENAV_START = '<!-- Sidenav Menu Start -->'
OLD_SIDENAV_PATTERNS = [
    r'<!-- Brand Logo -->.*?<div class="scrollbar" data-simplebar>.*?<ul class="side-nav">',
    r'<!-- BroyhillGOP AI Logo.*?<ul class="side-nav">'
]

def update_file(filepath):
    """Update a single HTML file with new navigation"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if it's an ecosystem or relevant page
        if 'sidenav-menu' not in content:
            return False, "No sidenav found"
        
        # Find the sidenav section and replace navigation
        # Look for the start of sidenav content
        sidenav_start = content.find('<div class="sidenav-menu">')
        if sidenav_start == -1:
            return False, "No sidenav-menu div"
        
        # Find where scrollbar div starts (end of logo area)
        scrollbar_end = content.find('</ul>', content.find('<ul class="side-nav">', sidenav_start))
        if scrollbar_end == -1:
            return False, "Could not find nav end"
        
        # Find the closing of scrollbar div
        close_scrollbar = content.find('</div>', scrollbar_end)
        
        # For now, just confirm file can be processed
        return True, f"Found sidenav at {sidenav_start}"
        
    except Exception as e:
        return False, str(e)

def main():
    """Process all ecosystem files"""
    ecosystem_files = []
    
    for filename in os.listdir(BASE_DIR):
        if filename.startswith('ecosystem-') and filename.endswith('.html'):
            ecosystem_files.append(filename)
    
    ecosystem_files.sort()
    
    print(f"Found {len(ecosystem_files)} ecosystem files")
    
    for filename in ecosystem_files[:5]:  # Test first 5
        filepath = os.path.join(BASE_DIR, filename)
        success, msg = update_file(filepath)
        print(f"{'✅' if success else '❌'} {filename}: {msg}")

if __name__ == "__main__":
    main()
