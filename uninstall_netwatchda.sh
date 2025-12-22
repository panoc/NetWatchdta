#!/bin/sh
# netwatchda Uninstaller - Automated Removal for OpenWrt
# Copyright (C) 2025 panoc
# Licensed under the GNU General Public License v3.0

# --- SELF-CLEAN LOGIC ---
# Deletes this script file on Exit, Abort, or Ctrl+C
SCRIPT_NAME="$0"
cleanup() {
    rm -f "$SCRIPT_NAME"
    exit
}
trap cleanup INT TERM EXIT

# --- COLOR DEFINITIONS (VIBRANT & HIGH CONTRAST) ---
NC='\033[0m'       
BOLD='\033[1m'
RED='\033[1;31m'    # Light Red (High Visibility)
GREEN='\033[1;32m'  # Light Green
BLUE='\033[1;34m'   # Light Blue
CYAN='\033[1;36m'   # Light Cyan
YELLOW='\033[1;33m' # Bold Yellow

# --- INITIAL SPACING ---
echo ""
echo -e "${RED}=======================================================${NC}"
echo -e "${BOLD}${RED}🗑️  netwatchda Uninstaller${NC} (by ${BOLD}panoc${NC})"
echo -e "${RED}=======================================================${NC}"

INSTALL_DIR="/root/netwatchda"
SERVICE_NAME="netwatchda"
SERVICE_PATH="/etc/init.d/$SERVICE_NAME"

# --- 1. USER CHOICE MENU ---
if [ -d "$INSTALL_DIR" ] || [ -f "$SERVICE_PATH" ]; then
    echo -e "\n${BOLD}What would you like to do?${NC}"
    echo -e "${BOLD}1.${NC} ${RED}Full Uninstall${NC} (Remove everything)"
    echo -e "${BOLD}2.${NC} ${YELLOW}Keep Settings${NC} (Remove script/service only)"
    echo -e "${BOLD}3.${NC} Cancel"
    printf "${BOLD}Enter choice [1-3]: ${NC}"
    read choice </dev/tty

    case "$choice" in
        3)
            echo -e "\n${BLUE}❌ Uninstallation cancelled.${NC}"
            echo ""
            exit 0
            ;;
        2)
            KEEP_CONF=1
            echo -e "\n${YELLOW}📂 Preservation Mode: Configuration files will be kept.${NC}"
            ;;
        *)
            KEEP_CONF=0
            echo -e "\n${RED}🗑️  Full Uninstall: All files and settings will be deleted.${NC}"
            ;;
    esac
else
    echo -e "\n${CYAN}ℹ️  No installation found at $INSTALL_DIR. Nothing to do.${NC}"
    exit 1
fi

# --- 2. STOP AND REMOVE SERVICE ---
if [ -f "$SERVICE_PATH" ]; then
    echo -e "\n${CYAN}🛑 Stopping and disabling service...${NC}"
    $SERVICE_PATH stop 2>/dev/null
    $SERVICE_PATH disable 2>/dev/null
    
    # Sniper Kill: Kill background script but NOT this uninstaller ($$)
    TARGET_PID=$(pgrep -f "netwatchda.sh" | grep -v "$$")
    [ -n "$TARGET_PID" ] && kill -9 $TARGET_PID 2>/dev/null
    
    # Cleanup orphaned pings
    killall -q ping 2>/dev/null 

    rm -f "$SERVICE_PATH"
    echo -e "${GREEN}✅ Service removed.${NC}"
fi

# --- 3. CLEAN UP TEMPORARY STATE FILES ---
echo -e "${CYAN}🧹 Cleaning up temporary state files...${NC}"
rm -f /tmp/netwatchda_log.txt /tmp/nwda_ext_* /tmp/nwda_c_* /tmp/nwda_d_* /tmp/nwda_t_*
echo -e "${GREEN}✅ Temp files cleared.${NC}"

# --- 4. REMOVE INSTALLATION FILES ---
if [ "$KEEP_CONF" -eq 1 ]; then
    # Specifically remove only the core logic script
    if [ -f "$INSTALL_DIR/netwatchda.sh" ]; then
        rm -f "$INSTALL_DIR/netwatchda.sh"
        echo -e "${GREEN}✅ Core script removed.${NC}"
    fi
    echo -e "${YELLOW}📂 Configuration preserved in $INSTALL_DIR${NC}"
else
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${RED}🗑️  Removing directory $INSTALL_DIR...${NC}"
        rm -rf "$INSTALL_DIR"
        
        # Verification check
        if [ -d "$INSTALL_DIR" ]; then
            echo -e "${BOLD}${RED}❌ ERROR: Could not remove directory. Filesystem might be Read-Only!${NC}"
        else
            echo -e "${GREEN}✅ All files removed.${NC}"
        fi
    fi
fi

# --- 5. FINAL CLEANUP ---
echo -e "\n${GREEN}---${NC}"
echo -e "${BOLD}${GREEN}✨ Uninstallation complete! Uninstaller file deleted.${NC}"
echo -e "${RED}-------------------------------------------------------${NC}"
echo ""