#!/bin/sh
# netwatchda Uninstaller - Standalone Cleanup Tool
# Copyright (C) 2025 panoc
# Licensed under the GNU General Public License v3.0

# ==============================================================================
#  SELF-CLEANUP MECHANISM
# ==============================================================================
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
#  PATHS
# ==============================================================================
INSTALL_DIR="/root/netwatchda"
TMP_DIR="/tmp/netwatchda"
SERVICE_PATH="/etc/init.d/netwatchda"

# ==============================================================================
#  UI HEADER
# ==============================================================================
echo -e "${RED}=======================================================${NC}"
echo -e "${BOLD}${RED}🗑️  netwatchda Uninstaller${NC}"
echo -e "${RED}=======================================================${NC}"
echo ""

# ==============================================================================
#  MENU LOGIC
# ==============================================================================
echo -e "${BOLD}${WHITE}1.${NC} Full Uninstall (Remove everything)"
echo -e "${BOLD}${WHITE}2.${NC} Keep Settings (Remove logic but keep configs)"
echo -e "${BOLD}${WHITE}3.${NC} Cancel"
echo ""

while true; do
    printf "${BOLD}Choice [1-3]: ${NC}"
    read choice </dev/tty
    if echo "$choice" | grep -qE "^[1-3]$"; then
        break
    fi
done

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
        echo -e "${YELLOW}⚠️  Warning: Removing dependencies might affect other applications.${NC}"
        
        while true; do
            printf "${BOLD}❓ Remove curl, openssl-util, and ca-bundle? [y/N]: ${NC}"
            read rem_deps </dev/tty
            case "$rem_deps" in
                y|Y)
                    echo -e "${YELLOW}📥 Removing packages...${NC}"
                    opkg remove curl openssl-util ca-bundle >/dev/null 2>&1
                    echo -e "${GREEN}✅ Dependencies removed.${NC}"
                    break
                    ;;
                n|N|"")
                    echo -e "${CYAN}ℹ️  Dependencies kept.${NC}"
                    break
                    ;;
                *) ;;
            esac
        done

        echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
        rm -rf "$TMP_DIR"

        echo -e "${YELLOW}🗑️  Removing installation directory...${NC}"
        rm -rf "$INSTALL_DIR"

        echo -e "${YELLOW}🔥 Removing system service...${NC}"
        rm -f "$SERVICE_PATH"

        echo ""
        echo -e "${GREEN}=======================================================${NC}"
        echo -e "${BOLD}${GREEN}✅ netwatchda has been completely removed.${NC}"
        echo -e "${GREEN}=======================================================${NC}"
        ;;

    2)
        # --- OPTION 2: KEEP SETTINGS ---
        echo ""
        echo -e "${YELLOW}🛑 Stopping service...${NC}"
        if [ -f "$SERVICE_PATH" ]; then
            "$SERVICE_PATH" stop >/dev/null 2>&1
            "$SERVICE_PATH" disable >/dev/null 2>&1
        fi

        echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
        rm -rf "$TMP_DIR"

        echo -e "${YELLOW}🗑️  Removing core logic script...${NC}"
        rm -f "$INSTALL_DIR/netwatchda.sh"

        echo -e "${YELLOW}🔥 Removing system service...${NC}"
        rm -f "$SERVICE_PATH"

        echo ""
        echo -e "${GREEN}=======================================================${NC}"
        echo -e "${BOLD}${GREEN}✅ Logic removed.${NC}"
        echo -e "${CYAN}ℹ️  Settings preserved in: ${BOLD}$INSTALL_DIR${NC}"
        echo -e "${GREEN}=======================================================${NC}"
        ;;

    3)
        # --- OPTION 3: CANCEL ---
        echo -e "${RED}❌ Uninstall cancelled.${NC}"
        exit 0
        ;;
esac