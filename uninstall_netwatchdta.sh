#!/bin/sh
# ==============================================================================
#  NETWATCHDTA UNIVERSAL UNINSTALLER
# ==============================================================================
#  Description: Emergency removal tool for netwatchdta
#  Version: 1.4.2 (Fixed I/O Error)
#  Supported OS: OpenWrt & Linux (Systemd)
#  Copyright (C) 2025 panoc
# ==============================================================================

# --- SELF-CLEANUP ---
SCRIPT_NAME="$0"
cleanup() {
    rm -f "$SCRIPT_NAME"
    exit
}
trap cleanup INT TERM EXIT

# --- COLORS ---
NC='\033[0m'
BOLD='\033[1m'
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'

# ==============================================================================
#  1. OS DETECTION ENGINE
# ==============================================================================
OS_TYPE="UNKNOWN"
INSTALL_DIR=""
SERVICE_TYPE=""
SERVICE_PATH=""
CLI_PATH=""

if [ -f /etc/openwrt_release ]; then
    OS_TYPE="OPENWRT"
    INSTALL_DIR="/root/netwatchdta"
    SERVICE_TYPE="PROCD"
    SERVICE_PATH="/etc/init.d/netwatchdta"
elif [ -f /etc/os-release ]; then
    OS_TYPE="LINUX"
    INSTALL_DIR="/opt/netwatchdta"
    SERVICE_TYPE="SYSTEMD"
    SERVICE_PATH="/etc/systemd/system/netwatchdta.service"
    CLI_PATH="/usr/local/bin/netwatchdta"
else
    echo -e "${RED}❌ Error: Unsupported OS.${NC}"
    exit 1
fi

# ==============================================================================
#  2. PERMISSION CHECK
# ==============================================================================
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ Permission Denied.${NC} Please run as root (sudo)."
    exit 1
fi

# ==============================================================================
#  3. INTERACTIVE MENU
# ==============================================================================
echo -e "${BLUE}=======================================================${NC}"
echo -e "${BOLD}${RED}🗑️  netwatchdta Universal Uninstaller${NC}"
echo -e "${BLUE}=======================================================${NC}"
echo -e "${WHITE}🖥️  System Detected : ${GREEN}$OS_TYPE${NC}"
echo -e "${WHITE}📂 Target Folder   : ${GREEN}$INSTALL_DIR${NC}"
echo ""
echo -e "${WHITE}1.${NC} Full Uninstall (Remove logic, settings, logs, everything)"
echo -e "${WHITE}2.${NC} Keep Settings (Remove logic only, preserve configs)"
echo -e "${WHITE}3.${NC} Cancel"
echo ""

while true; do
    printf "${BOLD}Choice [1-3]: ${NC}"
    # FIX: Read from standard input (removes </dev/tty dependency)
    read choice
    if echo "$choice" | grep -qE "^[1-3]$"; then
        break
    fi
done

# ==============================================================================
#  4. REMOVAL LOGIC
# ==============================================================================
case "$choice" in
    1)
        # --- OPTION 1: FULL UNINSTALL ---
        echo ""
        echo -e "${YELLOW}🛑 Stopping service...${NC}"
        
        # Stop & Disable Service
        if [ "$SERVICE_TYPE" = "PROCD" ]; then
            if [ -f "$SERVICE_PATH" ]; then
                "$SERVICE_PATH" stop >/dev/null 2>&1
                "$SERVICE_PATH" disable >/dev/null 2>&1
            fi
        elif [ "$SERVICE_TYPE" = "SYSTEMD" ]; then
            systemctl stop netwatchdta >/dev/null 2>&1
            systemctl disable netwatchdta >/dev/null 2>&1
        fi

        echo -e "${YELLOW}🧹 Cleaning up files...${NC}"
        
        # Remove Main Directory (Configs & Scripts)
        if [ -d "$INSTALL_DIR" ]; then
            rm -rf "$INSTALL_DIR"
            echo "   - Removed $INSTALL_DIR"
        fi
        
        # Remove Temp Logs & Buffers
        if [ -d "/tmp/netwatchdta" ]; then
            rm -rf "/tmp/netwatchdta"
            echo "   - Removed /tmp/netwatchdta"
        fi

        echo -e "${YELLOW}🔥 Removing system integration...${NC}"
        
        # Remove Service File
        if [ -f "$SERVICE_PATH" ]; then
            rm -f "$SERVICE_PATH"
            echo "   - Removed service file"
        fi
        
        # Linux Specific: Remove CLI Wrapper and Reload
        if [ "$OS_TYPE" = "LINUX" ]; then
            if [ -f "$CLI_PATH" ]; then
                rm -f "$CLI_PATH"
                echo "   - Removed CLI command 'netwatchdta'"
            fi
            systemctl daemon-reload >/dev/null 2>&1
        fi

        echo ""
        echo -e "${GREEN}✅ netwatchdta has been completely removed.${NC}"
        ;;

    2)
        # --- OPTION 2: KEEP SETTINGS ---
        echo ""
        echo -e "${YELLOW}🛑 Stopping service...${NC}"
        
        # Stop & Disable Service
        if [ "$SERVICE_TYPE" = "PROCD" ]; then
            if [ -f "$SERVICE_PATH" ]; then
                "$SERVICE_PATH" stop >/dev/null 2>&1
                "$SERVICE_PATH" disable >/dev/null 2>&1
            fi
        elif [ "$SERVICE_TYPE" = "SYSTEMD" ]; then
            systemctl stop netwatchdta >/dev/null 2>&1
            systemctl disable netwatchdta >/dev/null 2>&1
        fi

        echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
        rm -rf "/tmp/netwatchdta"

        echo -e "${YELLOW}🗑️  Removing logic engine...${NC}"
        # Only remove the script, keep the directory
        if [ -f "$INSTALL_DIR/netwatchdta.sh" ]; then
            rm -f "$INSTALL_DIR/netwatchdta.sh"
            echo "   - Removed engine script"
        fi

        echo -e "${YELLOW}🔥 Removing system integration...${NC}"
        
        # Remove Service File
        if [ -f "$SERVICE_PATH" ]; then
            rm -f "$SERVICE_PATH"
            echo "   - Removed service file"
        fi
        
        # Linux Specific: Remove CLI Wrapper
        if [ "$OS_TYPE" = "LINUX" ]; then
            if [ -f "$CLI_PATH" ]; then
                rm -f "$CLI_PATH"
                echo "   - Removed CLI command"
            fi
            systemctl daemon-reload >/dev/null 2>&1
        fi

        echo ""
        echo -e "${GREEN}✅ Logic removed.${NC}"
        echo -e "${CYAN}ℹ️  Settings preserved in: $INSTALL_DIR${NC}"
        echo -e "   (settings.conf, device_ips.conf, remote_ips.conf, .vault.enc)"
        ;;

    *)
        echo -e "${RED}❌ Uninstall cancelled.${NC}"
        exit 0
        ;;
esac