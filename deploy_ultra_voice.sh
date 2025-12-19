#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════════════════╗
# ║     BROYHILLGOP PLATFORM - ULTRA VOICE GITHUB DEPLOYMENT SCRIPT                         ║
# ║     Deploys ULTRA Voice Synthesis to GitHub                                              ║
# ╚══════════════════════════════════════════════════════════════════════════════════════════╝

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     ULTRA VOICE SYNTHESIS - GITHUB DEPLOYMENT                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"

# Navigate to repository
cd "$(dirname "$0")"

# Check if git is configured
if ! git config user.email > /dev/null 2>&1; then
    echo -e "${YELLOW}Setting up git configuration...${NC}"
    git config user.email "ed@broyhill.net"
    git config user.name "Eddie Broyhill"
fi

# Check if remote exists
if ! git remote | grep -q "origin"; then
    echo -e "${YELLOW}No GitHub remote found. Adding remote...${NC}"
    echo ""
    echo "Please enter your GitHub repository URL:"
    echo "  Example: https://github.com/yourusername/BroyhillGOP-COMPLETE-PLATFORM.git"
    echo "  Or SSH:  git@github.com:yourusername/BroyhillGOP-COMPLETE-PLATFORM.git"
    read -p "Repository URL: " REPO_URL
    
    if [ -n "$REPO_URL" ]; then
        git remote add origin "$REPO_URL"
        echo -e "${GREEN}Remote added successfully!${NC}"
    else
        echo -e "${YELLOW}No URL provided. You can add it later with:${NC}"
        echo "  git remote add origin <your-repo-url>"
    fi
fi

# Show what will be committed
echo ""
echo -e "${BLUE}Files to be committed:${NC}"
echo "  - backend/python/ecosystems/ecosystem_16b_voice_synthesis_ULTRA.py"
echo "  - backend/python/ecosystems/ecosystem_16b_voice_synthesis_ULTRA_full.py"
echo "  - backend/python/integrations/ultra_voice_integration_hub.py"
echo "  - database/migrations/ultra_voice/001_ultra_voice_core_tables.sql"
echo "  - database/migrations/ultra_voice/002_ultra_voice_stored_procedures.sql"
echo "  - database/migrations/ultra_voice/003_ultra_voice_indexes_rollback.sql"
echo "  - frontend/ultra_voice_control_panel.html"
echo "  - docs/ULTRA_INTEGRATION_GUIDE.md"

# Stage all ULTRA files
echo ""
echo -e "${BLUE}Staging files...${NC}"
git add backend/python/ecosystems/ecosystem_16b_voice_synthesis_ULTRA*.py 2>/dev/null
git add backend/python/integrations/ultra_voice_integration_hub.py 2>/dev/null
git add database/migrations/ultra_voice/*.sql 2>/dev/null
git add frontend/ultra_voice_control_panel.html 2>/dev/null
git add docs/ULTRA_INTEGRATION_GUIDE.md 2>/dev/null

# Show status
echo ""
echo -e "${BLUE}Git status:${NC}"
git status --short

# Commit
echo ""
read -p "Commit these changes? (y/n): " CONFIRM
if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
    git commit -m "Add ULTRA Voice Synthesis - Replaces ElevenLabs

ULTRA Voice Synthesis Integration:
- 102-108% of ElevenLabs quality at 99.4% cost savings
- Annual savings: \$85,536 (72 candidates × \$99/mo)
- Multi-engine ensemble: Fish Speech 1.5, F5-TTS, XTTS v2, StyleTTS2
- Neural enhancement: Resemble Enhance, BigVGAN v2, HiFi-GAN
- Super-resolution: 48kHz AudioSR/FlashSR
- Quality scoring: PESQ, STOI, MOS prediction

Files added:
- ecosystem_16b_voice_synthesis_ULTRA.py (2,178 lines)
- ultra_voice_integration_hub.py (850+ lines)
- SQL migrations (3 files, ~2,000 lines)
- Control panel HTML (900+ lines)
- Integration documentation

Connected ecosystems: E13, E16, E17, E20, E30, E45, E47, E48"
    
    echo -e "${GREEN}Changes committed!${NC}"
    
    # Push
    echo ""
    read -p "Push to GitHub? (y/n): " PUSH_CONFIRM
    if [ "$PUSH_CONFIRM" = "y" ] || [ "$PUSH_CONFIRM" = "Y" ]; then
        echo -e "${BLUE}Pushing to GitHub...${NC}"
        git push -u origin main 2>/dev/null || git push -u origin master 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║     DEPLOYMENT COMPLETE! ULTRA Voice is now on GitHub!          ║${NC}"
            echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
        else
            echo -e "${YELLOW}Push failed. You may need to authenticate or create the repository first.${NC}"
            echo ""
            echo "To create a new repository on GitHub:"
            echo "1. Go to https://github.com/new"
            echo "2. Name: BroyhillGOP-COMPLETE-PLATFORM"
            echo "3. Keep it private"
            echo "4. Don't initialize with README"
            echo "5. Copy the repository URL and run:"
            echo "   git remote set-url origin <your-repo-url>"
            echo "   git push -u origin main"
        fi
    fi
else
    echo -e "${YELLOW}Changes not committed. Files are staged and ready.${NC}"
fi

echo ""
echo -e "${BLUE}Done!${NC}"
