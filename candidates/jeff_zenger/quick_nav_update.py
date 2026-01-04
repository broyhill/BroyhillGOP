#!/usr/bin/env python3
"""
QUICK NAV UPDATE - Run this on your Mac
cd "/Users/Broyhill/Library/CloudStorage/GoogleDrive-ed@broyhill.net/My Drive/BroyhillGOP/inspinia 2/HTML/Full/dist"
python3 quick_nav_update.py
"""
import os
import re

BASE = "/Users/Broyhill/Library/CloudStorage/GoogleDrive-ed@broyhill.net/My Drive/BroyhillGOP/inspinia 2/HTML/Full/dist"

NAV = '''            <!-- BroyhillGOP AI Logo -->
            <a href="campaign-composer-wizard.html" class="logo" style="display: block; margin: 10px; text-decoration: none;">
                <iframe src="assets/broyhillgop-logo.html" style="width: 100%; height: 150px; border: none; pointer-events: none;" scrolling="no"></iframe>
            </a>
            <button class="button-on-hover"><i class="ti ti-menu-4 fs-22 align-middle"></i></button>
            <button class="button-close-offcanvas"><i class="ti ti-x align-middle"></i></button>
            <div class="scrollbar" data-simplebar>
            <ul class="side-nav">
                <li class="side-nav-item"><a href="jeff-zenger.html" class="side-nav-link"><span class="menu-icon"><i class="ti ti-home"></i></span><span class="menu-text">Candidate Home</span></a></li>
                <li class="side-nav-title">🧠 BRAIN</li>
                <li class="side-nav-item"><a data-bs-toggle="collapse" href="#navBrain" class="side-nav-link"><span class="menu-icon"><i class="ti ti-brain"></i></span><span class="menu-text">Intelligence</span><span class="badge bg-danger">AI</span></a>
                    <div class="collapse" id="navBrain"><ul class="sub-menu">
                        <li class="side-nav-item"><a href="ecosystem-20-intelligence-brain.html" class="side-nav-link"><span class="menu-text">E20 Brain</span></a></li>
                        <li class="side-nav-item"><a href="ecosystem-13-ai-hub.html" class="side-nav-link"><span class="menu-text">E13 AI Hub</span></a></li>
                        <li class="side-nav-item"><a href="ecosystem-21-ml-clustering.html" class="side-nav-link"><span class="menu-text">E21 ML</span></a></li>
                        <li class="side-nav-item"><a href="ecosystem-51-nexus.html" class="side-nav-link"><span class="menu-text">E51 NEXUS</span></a></li>
                    </ul></div></li>
                <li class="side-nav-title">💾 DATA</li>
                <li class="side-nav-item"><a data-bs-toggle="collapse" href="#navData" class="side-nav-link"><span class="menu-icon"><i class="ti ti-database"></i></span><span class="menu-text">Data</span><span class="badge bg-primary">130K+</span></a>
                    <div class="collapse" id="navData"><ul class="sub-menu">
                        <li class="side-nav-item"><a href="ecosystem-00-datahub.html" class="side-nav-link"><span class="menu-text">E00 DataHub</span></a></li>
                        <li class="side-nav-item"><a href="ecosystem-15-contact-directory.html" class="side-nav-link"><span class="menu-text">E15 Contacts</span></a></li>
                    </ul></div></li>
                <li class="side-nav-title">💰 DONORS</li>
                <li class="side-nav-item"><a data-bs-toggle="collapse" href="#navDonors" class="side-nav-link"><span class="menu-icon"><i class="ti ti-cash"></i></span><span class="menu-text">Fundraising</span></a>
                    <div class="collapse" id="navDonors"><ul class="sub-menu">
                        <li class="side-nav-item"><a href="ecosystem-01-donor-intelligence.html" class="side-nav-link"><span class="menu-text">E01 Donor Intel</span></a></li>
                        <li class="side-nav-item"><a href="ecosystem-02-donations.html" class="side-nav-link"><span class="menu-text">E02 Donations</span></a></li>
                        <li class="side-nav-item"><a href="donors.html" class="side-nav-link"><span class="menu-text">All Donors</span></a></li>
                        <li class="side-nav-item"><a href="jeff-zenger-donors.html" class="side-nav-link"><span class="menu-text">Zenger Donors</span></a></li>
                        <li class="side-nav-item"><a href="ecosystem-10-compliance.html" class="side-nav-link"><span class="menu-text">E10 Compliance</span></a></li>
                        <li class="side-nav-item"><a href="ecosystem-11-budget.html" class="side-nav-link"><span class="menu-text">E11 Budget</span></a></li>
                    </ul></div></li>
                <li class="side-nav-title">🙋 VOLUNTEERS</li>
                <li class="side-nav-item"><a data-bs-toggle="collapse" href="#navVol" class="side-nav-link"><span class="menu-icon"><i class="ti ti-users-group"></i></span><span class="menu-text">Activists</span></a>
                    <div class="collapse" id="navVol"><ul class="sub-menu">
                        <li class="side-nav-item"><a href="ecosystem-04-activist-network.html" class="side-nav-link"><span class="menu-text">E04 Activists</span></a></li>
                        <li class="side-nav-item"><a href="ecosystem-05-volunteers.html" class="side-nav-link"><span class="menu-text">E05 Volunteers</span></a></li>
                        <li class="side-nav-item"><a href="volunteers.html" class="side-nav-link"><span class="menu-text">All Volunteers</span></a></li>
                        <li class="side-nav-item"><a href="ecosystem-34-events.html" class="side-nav-link"><span class="menu-text">E34 Events</span></a></li>
                    </ul></div></li>
                <li class="side-nav-title">📣 COMMS</li>
                <li class="side-nav-item"><a data-bs-toggle="collapse" href="#navComms" class="side-nav-link"><span class="menu-icon"><i class="ti ti-message-circle"></i></span><span class="menu-text">Channels</span></a>
                    <div class="collapse" id="navComms"><ul class="sub-menu">
                        <li class="side-nav-item"><a href="ecosystem-30-email-studio.html" class="side-nav-link"><span class="menu-text">E30 Email</span></a></li>
                        <li class="side-nav-item"><a href="ecosystem-31-sms-studio.html" class="side-nav-link"><span class="menu-text">E31 SMS</span></a></li>
                        <li class="side-nav-item"><a href="ecosystem-32-phone-banking.html" class="side-nav-link"><span class="menu-text">E32 Phone</span></a></li>
                        <li class="side-nav-item"><a href="ecosystem-17-rvm.html" class="side-nav-link"><span class="menu-text">E17 RVM</span></a></li>
                        <li class="side-nav-item"><a href="ecosystem-33-direct-mail.html" class="side-nav-link"><span class="menu-text">E33 Mail</span></a></li>
                    </ul></div></li>
                <li class="side-nav-title">🎬 MEDIA</li>
                <li class="side-nav-item"><a data-bs-toggle="collapse" href="#navMedia" class="side-nav-link"><span class="menu-icon"><i class="ti ti-video"></i></span><span class="menu-text">Production</span></a>
                    <div class="collapse" id="navMedia"><ul class="sub-menu">
                        <li class="side-nav-item"><a href="ecosystem-16-tv-radio.html" class="side-nav-link"><span class="menu-text">E16 TV/Radio</span></a></li>
                        <li class="side-nav-item"><a href="ecosystem-19-social-media.html" class="side-nav-link"><span class="menu-text">E19 Social</span></a></li>
                        <li class="side-nav-item"><a href="ecosystem-45-video-studio.html" class="side-nav-link"><span class="menu-text">E45 Video</span></a></li>
                        <li class="side-nav-item"><a href="ecosystem-46-broadcast-hub.html" class="side-nav-link"><span class="menu-text">E46 Broadcast</span></a></li>
                    </ul></div></li>
                <li class="side-nav-title">⚙️ OPS</li>
                <li class="side-nav-item"><a data-bs-toggle="collapse" href="#navOps" class="side-nav-link"><span class="menu-icon"><i class="ti ti-settings"></i></span><span class="menu-text">Management</span></a>
                    <div class="collapse" id="navOps"><ul class="sub-menu">
                        <li class="side-nav-item"><a href="ecosystem-03-candidate-profiles.html" class="side-nav-link"><span class="menu-text">E03 Candidates</span></a></li>
                        <li class="side-nav-item"><a href="ecosystem-41-campaign-builder.html" class="side-nav-link"><span class="menu-text">E41 Builder</span></a></li>
                        <li class="side-nav-item"><a href="ecosystem-06-analytics.html" class="side-nav-link"><span class="menu-text">E06 Analytics</span></a></li>
                        <li class="side-nav-item"><a href="ecosystem-42-news-intelligence.html" class="side-nav-link"><span class="menu-text">E42 News</span></a></li>
                    </ul></div></li>
                <li class="side-nav-title">🎯 WIZARDS</li>
                <li class="side-nav-item"><a data-bs-toggle="collapse" href="#navWiz" class="side-nav-link"><span class="menu-icon"><i class="ti ti-wand"></i></span><span class="menu-text">Compose</span><span class="badge bg-success">NEW</span></a>
                    <div class="collapse" id="navWiz"><ul class="sub-menu">
                        <li class="side-nav-item"><a href="campaign-composer-wizard.html" class="side-nav-link"><span class="menu-text">🎬 Composer</span></a></li>
                        <li class="side-nav-item"><a href="email-campaign-wizard.html" class="side-nav-link"><span class="menu-text">📧 Email</span></a></li>
                        <li class="side-nav-item"><a href="sms-campaign-wizard.html" class="side-nav-link"><span class="menu-text">💬 SMS</span></a></li>
                        <li class="side-nav-item"><a href="rvm-campaign-wizard.html" class="side-nav-link"><span class="menu-text">🎤 RVM</span></a></li>
                        <li class="side-nav-item"><a href="phone-banking-wizard.html" class="side-nav-link"><span class="menu-text">📞 Phone</span></a></li>
                    </ul></div></li>
                <li class="side-nav-title">🔧 CONTROL</li>
                <li class="side-nav-item"><a href="ecosystem-40-automation-control.html" class="side-nav-link"><span class="menu-icon"><i class="ti ti-adjustments"></i></span><span class="menu-text">Control Panel</span></a></li>
                <li class="side-nav-item"><a href="settings.html" class="side-nav-link"><span class="menu-icon"><i class="ti ti-settings-2"></i></span><span class="menu-text">Settings</span></a></li>
            </ul>
            </div>
        </div>
        <!-- Sidenav Menu End -->'''

# Find files
files = [f for f in os.listdir(BASE) if f.endswith('.html')]
target = [f for f in files if 'ecosystem-' in f or 'wizard' in f or 'jeff-zenger' in f or 'donors' in f or 'volunteers' in f]

print(f"Updating {len(target)} files...")

for fname in sorted(target):
    fpath = os.path.join(BASE, fname)
    try:
        with open(fpath, 'r') as f:
            content = f.read()
        
        # Find sidenav section
        start = content.find('<div class="sidenav-menu">')
        end = content.find('<!-- Sidenav Menu End -->')
        
        if start != -1 and end != -1:
            new_content = content[:start] + '<div class="sidenav-menu">\n' + NAV + content[end+25:]
            with open(fpath, 'w') as f:
                f.write(new_content)
            print(f"✅ {fname}")
        else:
            print(f"⚠️ {fname} - no sidenav markers")
    except Exception as e:
        print(f"❌ {fname}: {e}")

print("Done!")
