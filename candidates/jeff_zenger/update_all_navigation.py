#!/usr/bin/env python3
"""
BroyhillGOP Mass Navigation Update Script
December 31, 2025

This script updates all HTML files in the INSPINIA dist folder with:
1. 6 hemisphere dropdown navigation in topbar
2. Sticky topbar CSS
3. Remove language selector
4. Compact topbar styling
5. Custom admin user display

Usage:
    python update_all_navigation.py [--dry-run]
"""

import os
import re
import sys
from pathlib import Path

# Configuration
DIST_PATH = "/Users/Broyhill/Library/CloudStorage/GoogleDrive-ed@broyhill.net/My Drive/BroyhillGOP/inspinia 2/HTML/Full/dist"

# The 6 Hemisphere Dropdowns HTML
HEMISPHERE_DROPDOWNS = '''
                    <!-- 6 Hemisphere Dropdowns -->
                    <div class="topbar-item d-none d-lg-flex gap-1">
                        
                        <!-- 1. DATA -->
                        <div class="dropdown">
                            <button class="btn btn-sm btn-outline-primary dropdown-toggle" data-bs-toggle="dropdown" type="button">💾 Data</button>
                            <div class="dropdown-menu">
                                <a href="ecosystem-00-datahub.html" class="dropdown-item">E00 DataHub</a>
                                <a href="ecosystem-15-contact-directory.html" class="dropdown-item">E15 Contacts</a>
                                <a href="donors.html" class="dropdown-item">All Donors</a>
                                <a href="volunteers.html" class="dropdown-item">All Volunteers</a>
                            </div>
                        </div>
                        
                        <!-- 2. COMMS -->
                        <div class="dropdown">
                            <button class="btn btn-sm btn-outline-success dropdown-toggle" data-bs-toggle="dropdown" type="button">📣 Comms</button>
                            <div class="dropdown-menu">
                                <a href="ecosystem-30-email-studio.html" class="dropdown-item">E30 Email</a>
                                <a href="ecosystem-31-sms-studio.html" class="dropdown-item">E31 SMS</a>
                                <a href="ecosystem-32-phone-banking.html" class="dropdown-item">E32 Phone</a>
                                <a href="ecosystem-17-rvm.html" class="dropdown-item">E17 RVM</a>
                                <a href="ecosystem-33-direct-mail.html" class="dropdown-item">E33 Direct Mail</a>
                            </div>
                        </div>
                        
                        <!-- 3. MEDIA -->
                        <div class="dropdown">
                            <button class="btn btn-sm btn-outline-danger dropdown-toggle" data-bs-toggle="dropdown" type="button">🎬 Media</button>
                            <div class="dropdown-menu">
                                <a href="ecosystem-16-tv-radio.html" class="dropdown-item">E16 TV/Radio AI</a>
                                <a href="ecosystem-19-social-media.html" class="dropdown-item">E19 Social Media</a>
                                <a href="ecosystem-45-video-studio.html" class="dropdown-item">E45 Video Studio</a>
                                <a href="ecosystem-46-broadcast-hub.html" class="dropdown-item">E46 Broadcast</a>
                            </div>
                        </div>
                        
                        <!-- 4. BRAIN -->
                        <div class="dropdown">
                            <button class="btn btn-sm btn-outline-warning dropdown-toggle" data-bs-toggle="dropdown" type="button">🧠 Brain</button>
                            <div class="dropdown-menu">
                                <a href="ecosystem-20-intelligence-brain.html" class="dropdown-item">E20 Intelligence Brain</a>
                                <a href="ecosystem-13-ai-hub.html" class="dropdown-item">E13 AI Hub</a>
                                <a href="ecosystem-21-ml-clustering.html" class="dropdown-item">E21 ML Clustering</a>
                                <a href="ecosystem-51-nexus.html" class="dropdown-item">E51 NEXUS AI</a>
                            </div>
                        </div>
                        
                        <!-- 5. OPS -->
                        <div class="dropdown">
                            <button class="btn btn-sm btn-outline-secondary dropdown-toggle" data-bs-toggle="dropdown" type="button">⚙️ Ops</button>
                            <div class="dropdown-menu">
                                <a href="ecosystem-03-candidate-profiles.html" class="dropdown-item">E03 Candidates</a>
                                <a href="ecosystem-06-analytics.html" class="dropdown-item">E06 Analytics</a>
                                <a href="ecosystem-41-campaign-builder.html" class="dropdown-item">E41 Campaign Builder</a>
                                <a href="ecosystem-40-automation-control.html" class="dropdown-item">E40 Control Panel</a>
                                <a href="ecosystem-42-news-intelligence.html" class="dropdown-item">E42 News Intel</a>
                            </div>
                        </div>
                        
                        <!-- 6. WIZARDS -->
                        <div class="dropdown">
                            <button class="btn btn-sm btn-primary dropdown-toggle" data-bs-toggle="dropdown" type="button">🎯 Wizards</button>
                            <div class="dropdown-menu">
                                <a href="campaign-composer-wizard.html" class="dropdown-item fw-bold">🎬 Campaign Composer</a>
                                <div class="dropdown-divider"></div>
                                <a href="email-campaign-wizard.html" class="dropdown-item">📧 Email Wizard</a>
                                <a href="sms-campaign-wizard.html" class="dropdown-item">💬 SMS Wizard</a>
                                <a href="rvm-campaign-wizard.html" class="dropdown-item">🎤 RVM Wizard</a>
                                <a href="phone-banking-wizard.html" class="dropdown-item">📞 Phone Wizard</a>
                                <a href="direct-mail-wizard.html" class="dropdown-item">📬 Mail Wizard</a>
                            </div>
                        </div>
                        
                    </div>
'''

# Custom CSS to inject
CUSTOM_CSS = '''
    <style>
        /* BroyhillGOP Custom Styles */
        .app-topbar {
            position: sticky !important;
            top: 0 !important;
            z-index: 1050 !important;
        }
        .app-search {
            width: 100px !important;
            margin-right: 10px !important;
        }
        .app-search .form-control {
            font-size: 11px !important;
            padding: 5px 25px 5px 10px !important;
        }
        .topbar-item.d-none.d-lg-flex {
            gap: 4px !important;
        }
        .topbar-item.d-none.d-lg-flex .btn-sm {
            padding: 4px 8px !important;
            font-size: 12px !important;
        }
        .topbar-menu {
            padding-right: 10px !important;
        }
        .nav-user h5 {
            font-size: 13px !important;
            max-width: 100px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }
        .content-page {
            margin-right: 10px !important;
            padding-right: 10px !important;
        }
    </style>
'''

def find_html_files(directory):
    """Find all HTML files in directory"""
    html_files = []
    for root, dirs, files in os.walk(directory):
        # Skip assets subdirectories
        if 'assets' in root:
            continue
        for file in files:
            if file.endswith('.html'):
                html_files.append(os.path.join(root, file))
    return html_files

def update_file(filepath, dry_run=False):
    """Update a single HTML file with new navigation"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        modified = False
        
        # 1. Check if already has hemisphere dropdowns
        if '6 Hemisphere Dropdowns' not in content:
            # Find insertion point after search box
            search_pattern = r'(<!-- Search -->.*?</div>\s*\n)'
            match = re.search(search_pattern, content, re.DOTALL)
            if match:
                insertion_point = match.end()
                content = content[:insertion_point] + HEMISPHERE_DROPDOWNS + content[insertion_point:]
                modified = True
        
        # 2. Remove language selector if present
        lang_pattern = r'<!-- Language Dropdown -->.*?</div>\s*<!-- end topbar item-->'
        if re.search(lang_pattern, content, re.DOTALL):
            content = re.sub(lang_pattern, '<!-- Language Dropdown - REMOVED -->', content, flags=re.DOTALL)
            modified = True
        
        # 3. Add custom CSS if not present
        if 'BroyhillGOP Custom Styles' not in content:
            # Insert before </body>
            content = content.replace('</body>', CUSTOM_CSS + '\n</body>')
            modified = True
        
        if modified and not dry_run:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        elif modified:
            return True
        return False
        
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    dry_run = '--dry-run' in sys.argv
    
    if dry_run:
        print("DRY RUN MODE - No files will be modified")
    
    html_files = find_html_files(DIST_PATH)
    print(f"Found {len(html_files)} HTML files")
    
    updated = 0
    errors = 0
    
    for filepath in html_files:
        filename = os.path.basename(filepath)
        result = update_file(filepath, dry_run)
        if result:
            updated += 1
            print(f"✓ {'Would update' if dry_run else 'Updated'}: {filename}")
        else:
            print(f"  Skipped: {filename}")
    
    print(f"\n{'Would update' if dry_run else 'Updated'} {updated} of {len(html_files)} files")

if __name__ == '__main__':
    main()
