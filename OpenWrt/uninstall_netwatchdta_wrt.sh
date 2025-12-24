#!/bin/sh
# netwatchdta Uninstaller - Standalone Cleanup Tool
# Copyright (C) 2025 panoc
# Licensed under the GNU General Public License v3.0

# ==============================================================================
#  SELF-CLEANUP MECHANISM
# ==============================================================================
# This ensures the uninstaller deletes itself after running to keep /tmp clean.
SCRIPT_NAME="$0"
cleanup() {
    rm -f "$SCRIPT_NAME"
    exit
}
trap cleanup INT TERM EXIT

# ==============================================================================
#  TERMINAL COLORS
# ==============================================================================
NC='\033[0m'        # No Color
BOLD='\033[1m'      # Bold
RED='\033[1;31m'    # Light Red
GREEN='\033[1;32m'  # Light Green
BLUE='\033[1;34m'   # Light Blue
CYAN='\033[1;36m'   # Light Cyan
YELLOW='\033[1;33m' # Bold Yellow
WHITE='\033[1;37m'  # Bold White

# ==============================================================================
#  INPUT VALIDATION HELPER FUNCTIONS
# ==============================================================================
# Imported from installer to ensure consistent and robust input handling.

# Function: ask_yn
# Purpose:  Forces the user to answer 'y' or 'n'. Ignores all other keys.
ask_yn() {
    local prompt="$1"
    while true; do
        printf "${BOLD}%s [y/n]: ${NC}" "$prompt"
        read input_val </dev/tty
        case "$input_val" in
            y|Y) 
                ANSWER_YN="y"
                return 0 
                ;;
            n|N) 
                ANSWER_YN="n"
                return 1 
                ;;
            *) 
                # Invalid input. Loop silently to ask again.
                ;; 
        esac
    done
}

# Function: ask_opt
# Purpose:  Forces the user to select a number between 1 and MAX.
ask_opt() {
    local prompt="$1"
    local max="$2"
    while true; do
        printf "${BOLD}%s [1-%s]: ${NC}" "$prompt" "$max"
        read input_val </dev/tty
        # Validate that input is a single digit within range
        if echo "$input_val" | grep -qE "^[1-$max]$"; then
            ANSWER_OPT="$input_val"
            break
        fi
        # Invalid input. Loop silently.
    done
}

# ==============================================================================
#  PATHS
# ==============================================================================
INSTALL_DIR="/root/netwatchdta"
TMP_DIR="/tmp/netwatchdta"
SERVICE_PATH="/etc/init.d/netwatchdta"

# ==============================================================================
#  UI HEADER
# ==============================================================================
# Imported phrasing from "before remote" purge command
echo -e "${RED}=======================================================${NC}"
echo -e "${BOLD}${RED}🗑️  netwatchdta Smart Uninstaller${NC}"
echo -e "${RED}=======================================================${NC}"
echo ""

# ==============================================================================
#  MENU LOGIC
# ==============================================================================
echo -e "${BOLD}${WHITE}1.${NC} Full Uninstall (Remove everything)"
echo -e "${BOLD}${WHITE}2.${NC} Keep Settings (Remove logic but keep config)"
echo -e "${BOLD}${WHITE}3.${NC} Cancel"
echo ""

# Use the robust helper function for choice selection
ask_opt "Choice" "3"
choice="$ANSWER_OPT"

# ==============================================================================
#  EXECUTION LOGIC
# ==============================================================================

case "$choice" in
    1)
        # --- OPTION 1: FULL UNINSTALL ---
        echo ""
        echo -e "${YELLOW}🛑 Stopping service...${NC}"
        if [ -f "$SERVICE_PATH" ]; then
            "$SERVICE_PATH" stop >/dev/null 2>&1
            "$SERVICE_PATH" disable >/dev/null 2>&1
        fi
        
        # Dependency Check
        echo -e "${CYAN}📦 Checking dependencies...${NC}"
        
        # Use specific warning phrasing from the purge command
        ask_yn "❓ Remove curl, openssl-util, and ca-bundle? (May break other apps)"
        if [ "$ANSWER_YN" = "y" ]; then
            echo -e "${YELLOW}📥 Removing packages...${NC}"
            opkg remove curl openssl-util ca-bundle >/dev/null 2>&1
            echo -e "${GREEN}✅ Dependencies removed.${NC}"
        else
            echo -e "${CYAN}ℹ️  Dependencies kept.${NC}"
        fi

        echo -e "${YELLOW}🧹 Cleaning up /tmp and buffers...${NC}"
        rm -rf "$TMP_DIR"

        echo -e "${YELLOW}🗑️  Removing installation directory...${NC}"
        rm -rf "$INSTALL_DIR"

        echo -e "${YELLOW}🔥 Self-destructing service file...${NC}"
        rm -f "$SERVICE_PATH"

        echo ""
        echo -e "${GREEN}✅ netwatchdta has been completely removed.${NC}"
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
        # MATCHING PURGE LOGIC:
        # Only remove the executable script.
        # This preserves: nwdta_settings.conf, nwdta_ips.conf, remote_ips.conf, .vault.enc
        rm -f "$INSTALL_DIR/netwatchdta.sh"

        echo -e "${YELLOW}🔥 Removing service file...${NC}"
        rm -f "$SERVICE_PATH"

        echo ""
        # Matched the yellow success message from the purge command
        echo -e "${YELLOW}✅ Logic removed. Settings preserved in $INSTALL_DIR${NC}"
        ;;

    3)
        # --- OPTION 3: CANCEL ---
        echo -e "${RED}❌ Purge cancelled.${NC}"
        exit 0
        ;;
esac