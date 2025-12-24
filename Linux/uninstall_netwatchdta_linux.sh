#!/bin/bash
# netwatchdta Uninstaller - Universal Linux Cleanup Tool
# Copyright (C) 2025 panoc
# Licensed under the GNU General Public License v3.0

# ==============================================================================
#  SHELL COMPATIBILITY GUARD
# ==============================================================================
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

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
#  ROOT PRIVILEGE CHECK
# ==============================================================================
if [ "$(id -u)" -ne 0 ]; then
  echo -e "\033[1;31m❌ Error: This script must be run as root.\033[0m"
  echo -e "\033[1;33m👉 Please run: sudo bash $SCRIPT_NAME\033[0m"
  exit 1
fi

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
#  PATHS (LINUX STANDARD)
# ==============================================================================
INSTALL_DIR="/opt/netwatchdta"
TMP_DIR="/tmp/netwatchdta"
SERVICE_NAME="netwatchdta"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
CLI_WRAPPER="/usr/local/bin/netwatchdta"

# ==============================================================================
#  PACKAGE MANAGER DETECTION (FOR DEPENDENCY REMOVAL)
# ==============================================================================
PKG_MAN=""
REMOVE_CMD=""
PKG_NAMES=""

if command -v apt-get >/dev/null; then
    PKG_MAN="apt"
    REMOVE_CMD="apt-get remove -y"
    PKG_NAMES="curl openssl ca-certificates"
elif command -v dnf >/dev/null; then
    PKG_MAN="dnf"
    REMOVE_CMD="dnf remove -y"
    PKG_NAMES="curl openssl ca-certificates"
elif command -v pacman >/dev/null; then
    PKG_MAN="pacman"
    REMOVE_CMD="pacman -Rns --noconfirm"
    PKG_NAMES="curl openssl ca-certificates"
elif command -v yum >/dev/null; then
    PKG_MAN="yum"
    REMOVE_CMD="yum remove -y"
    PKG_NAMES="curl openssl ca-certificates"
fi

# ==============================================================================
#  UI HEADER
# ==============================================================================
echo -e "${RED}=======================================================${NC}"
echo -e "${BOLD}${RED}🗑️  netwatchdta Uninstaller${NC} (Linux Edition)"
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
    read choice
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
        systemctl stop "$SERVICE_NAME" >/dev/null 2>&1
        systemctl disable "$SERVICE_NAME" >/dev/null 2>&1
        
        # Dependency Check
        echo -e "${CYAN}📦 Checking dependencies...${NC}"
        echo -e "${YELLOW}⚠️  Warning: Removing dependencies might affect other applications.${NC}"
        
        while true; do
            printf "${BOLD}❓ Remove $PKG_NAMES? [y/N]: ${NC}"
            read rem_deps
            case "$rem_deps" in
                y|Y)
                    if [ -n "$REMOVE_CMD" ]; then
                        echo -e "${YELLOW}📥 Removing packages ($PKG_MAN)...${NC}"
                        $REMOVE_CMD $PKG_NAMES >/dev/null 2>&1
                        echo -e "${GREEN}✅ Dependencies removed.${NC}"
                    else
                        echo -e "${RED}❌ Could not detect package manager. Skipping dep removal.${NC}"
                    fi
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

        echo -e "${YELLOW}🔥 Removing system service & wrappers...${NC}"
        rm -f "$SERVICE_FILE"
        rm -f "$CLI_WRAPPER"
        systemctl daemon-reload >/dev/null 2>&1

        echo ""
        echo -e "${GREEN}=======================================================${NC}"
        echo -e "${BOLD}${GREEN}✅ netwatchdta has been completely removed.${NC}"
        echo -e "${GREEN}=======================================================${NC}"
        ;;
2)
        # --- OPTION 2: KEEP SETTINGS ---
        echo ""
        echo -e "${YELLOW}🛑 Stopping service...${NC}"
        systemctl stop "$SERVICE_NAME" >/dev/null 2>&1
        systemctl disable "$SERVICE_NAME" >/dev/null 2>&1

        echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
        rm -rf "$TMP_DIR"

        echo -e "${YELLOW}🗑️  Removing core logic script...${NC}"
        rm -f "$INSTALL_DIR/netwatchdta.sh"

        echo -e "${YELLOW}🔥 Removing system service & wrappers...${NC}"
        rm -f "$SERVICE_FILE"
        rm -f "$CLI_WRAPPER"
        systemctl daemon-reload >/dev/null 2>&1

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