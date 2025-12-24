#!/bin/sh
# netwatchdta Standalone Uninstaller
# Copyright (C) 2025 panoc
# Licensed under the GNU General Public License v3.0

# ==============================================================================
#  SELF-CLEANUP MECHANISM
# ==============================================================================
# This ensures the uninstaller script deletes itself after execution to keep
# the /tmp directory clean.
SCRIPT_NAME="$0"
cleanup() {
    rm -f "$SCRIPT_NAME"
    exit
}
trap cleanup INT TERM EXIT

# ==============================================================================
#  TERMINAL COLOR DEFINITIONS
# ==============================================================================
NC='\033[0m'        # No Color (Reset)
BOLD='\033[1m'      # Bold Text
RED='\033[1;31m'    # Light Red (Errors/Warnings)
GREEN='\033[1;32m'  # Light Green (Success)
BLUE='\033[1;34m'   # Light Blue (Headers)
CYAN='\033[1;36m'   # Light Cyan (Info)
YELLOW='\033[1;33m' # Bold Yellow (Prompts)
WHITE='\033[1;37m'  # Bold White (High Contrast)

# ==============================================================================
#  DIRECTORY & FILE PATH DEFINITIONS
# ==============================================================================
INSTALL_DIR="/root/netwatchdta"
SERVICE_PATH="/etc/init.d/netwatchdta"
TMP_DIR="/tmp/netwatchdta"

# ==============================================================================
#  UNINSTALLER HEADER
# ==============================================================================
echo ""
echo -e "${RED}=======================================================${NC}"
echo -e "${RED}🗑️  netwatchdta Smart Uninstaller${NC}"
echo -e "${RED}=======================================================${NC}"
echo ""

# ==============================================================================
#  USER INTERACTION & LOGIC
# ==============================================================================

echo -e "${BOLD}${WHITE}1.${NC} Full Uninstall (Remove everything)"
echo -e "${BOLD}${WHITE}2.${NC} Keep Settings (Remove logic but keep config)"
echo -e "${BOLD}${WHITE}3.${NC} Cancel"
echo ""

# Input Loop
while true; do
    printf "${BOLD}Choice [1-3]: ${NC}"
    read choice </dev/tty
    
    case "$choice" in
        1)
            # --- OPTION 1: FULL UNINSTALL ---
            echo ""
            echo -e "${YELLOW}🛑 Stopping service...${NC}"
            if [ -f "$SERVICE_PATH" ]; then
                "$SERVICE_PATH" stop >/dev/null 2>&1
                "$SERVICE_PATH" disable >/dev/null 2>&1
            fi
            
            echo -e "${YELLOW}🧹 Cleaning up /tmp and buffers...${NC}"
            rm -rf "$TMP_DIR"
            
            echo -e "${YELLOW}🗑️  Removing installation directory...${NC}"
            rm -rf "$INSTALL_DIR"
            
            echo -e "${YELLOW}🔥 Self-destructing service file...${NC}"
            rm -f "$SERVICE_PATH"
            
            echo ""
            echo -e "${GREEN}=======================================================${NC}"
            echo -e "${BOLD}${GREEN}✅ netwatchdta has been completely removed.${NC}"
            echo -e "${GREEN}=======================================================${NC}"
            break
            ;;
            
        2)
            # --- OPTION 2: KEEP SETTINGS ---
            echo ""
            echo -e "${YELLOW}🛑 Stopping service...${NC}"
            if [ -f "$SERVICE_PATH" ]; then
                "$SERVICE_PATH" stop >/dev/null 2>&1
                "$SERVICE_PATH" disable >/dev/null 2>&1
            fi
            
            echo -e "${YELLOW}🧹 Cleaning up /tmp...${NC}"
            rm -rf "$TMP_DIR"
            
            echo -e "${YELLOW}🗑️  Removing core script...${NC}"
            rm -f "$INSTALL_DIR/netwatchdta.sh"
            
            echo -e "${YELLOW}🔥 Removing service file...${NC}"
            rm -f "$SERVICE_PATH"
            
            echo ""
            echo -e "${GREEN}=======================================================${NC}"
            echo -e "${YELLOW}✅ Logic removed. Settings preserved in:${NC}"
            echo -e "   $INSTALL_DIR"
            echo -e "${GREEN}=======================================================${NC}"
            break
            ;;
            
        3)
            # --- OPTION 3: CANCEL ---
            echo -e "${RED}❌ Purge cancelled.${NC}"
            exit 0
            ;;
            
        *)
            # --- INVALID INPUT ---
            # Loop will continue until valid input
            ;;
    esac
done