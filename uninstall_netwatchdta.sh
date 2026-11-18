#!/bin/sh
# ==============================================================================
#  NETWATCHDTA UNIVERSAL UNINSTALLER
# ==============================================================================
#  Description: Emergency removal tool for netwatchdta (works even if the
#               installer or the service file is broken or missing)
#  Version: 1.6.0 (matches installer v1.6.0, removes files from older versions too)
#  Supported OS: OpenWrt & Linux (Systemd)
#  Copyright (C) 2025-2026 panoc
#  Licensed under the GNU General Public License v3.0
# ==============================================================================

# --- SELF-CLEANUP (only when run from /tmp) ---
SCRIPT_NAME="$0"
SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
cleanup() {
    case "$SCRIPT_DIR" in
        /tmp|/tmp/*) [ -f "$SCRIPT_NAME" ] && rm -f "$SCRIPT_NAME" ;;
    esac
    exit
}
trap cleanup INT TERM EXIT

# --- COLORS ---
NC='\033[0m'
BOLD='\033[1m'
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'

# printf instead of 'echo -e' (dash on Debian/Ubuntu prints a literal "-e")
say() { printf '%b\n' "$*"; }

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
    say "${RED}❌ Error: Unsupported OS.${NC}"
    exit 1
fi

ENGINE="$INSTALL_DIR/netwatchdta.sh"

# ==============================================================================
#  2. PERMISSION CHECK
# ==============================================================================
if [ "$(id -u)" -ne 0 ]; then
    say "${RED}❌ Permission Denied.${NC} Please run as root (sudo)."
    exit 1
fi

# ==============================================================================
#  HELPERS
# ==============================================================================

# Read one line: from the terminal if one is available, otherwise from stdin.
# Returns non-zero on EOF so menus can't loop forever.
ask() {
    if [ -t 0 ]; then
        read -r ANSWER
    elif (: </dev/tty) 2>/dev/null; then
        # piped run (e.g. wget -O- ... | sh): stdin is the script, so use the terminal
        read -r ANSWER </dev/tty
    else
        read -r ANSWER
    fi
}

# Stop + disable the service, then kill any engine process still running
# (e.g. if the service file was already deleted or broken).
stop_everything() {
    say "${YELLOW}🛑 Stopping service...${NC}"
    if [ "$SERVICE_TYPE" = "PROCD" ]; then
        if [ -f "$SERVICE_PATH" ]; then
            "$SERVICE_PATH" stop >/dev/null 2>&1
            "$SERVICE_PATH" disable >/dev/null 2>&1
        fi
    elif [ "$SERVICE_TYPE" = "SYSTEMD" ]; then
        systemctl stop netwatchdta >/dev/null 2>&1
        systemctl disable netwatchdta >/dev/null 2>&1
    fi

    # Match the full engine path only, so this uninstaller (whose name also
    # contains "netwatchdta.sh") never matches itself.
    pids=$(pgrep -f "$ENGINE" 2>/dev/null)
    if [ -n "$pids" ]; then
        kill $pids 2>/dev/null
        sleep 1
        pids=$(pgrep -f "$ENGINE" 2>/dev/null)
        [ -n "$pids" ] && kill -9 $pids 2>/dev/null
        say "   - Stopped leftover engine process(es)"
    fi
}

# Remove RAM files: logs, state, notification lock, installer leftovers
clean_tmp() {
    say "${YELLOW}🧹 Cleaning up temporary files...${NC}"
    if [ -d "/tmp/netwatchdta" ]; then
        rm -rf "/tmp/netwatchdta"
        say "   - Removed /tmp/netwatchdta"
    fi
    rmdir /tmp/nwdta.lock 2>/dev/null
    rm -f /tmp/nwdta_install_err.log /tmp/nwdta_resp.* 2>/dev/null
}

# Remove the service file / systemd unit and the Linux CLI command
remove_integration() {
    say "${YELLOW}🔥 Removing system integration...${NC}"
    if [ -f "$SERVICE_PATH" ]; then
        rm -f "$SERVICE_PATH"
        say "   - Removed service file"
    fi
    if [ "$OS_TYPE" = "LINUX" ]; then
        if [ -f "$CLI_PATH" ]; then
            rm -f "$CLI_PATH"
            say "   - Removed CLI command 'netwatchdta'"
        fi
        systemctl daemon-reload >/dev/null 2>&1
    fi
}

# ==============================================================================
#  3. INTERACTIVE MENU
# ==============================================================================
say "${BLUE}=======================================================${NC}"
say "${BOLD}${RED}🗑️  netwatchdta Universal Uninstaller${NC}"
say "${BLUE}=======================================================${NC}"
say "${WHITE}🖥️  System Detected : ${GREEN}$OS_TYPE${NC}"
say "${WHITE}📂 Target Folder   : ${GREEN}$INSTALL_DIR${NC}"
if [ ! -d "$INSTALL_DIR" ] && [ ! -f "$SERVICE_PATH" ]; then
    say "${CYAN}ℹ️  No installation found - will only clean leftovers.${NC}"
fi
say ""
say "${WHITE}1.${NC} Full Uninstall (Remove logic, settings, credentials, logs, everything)"
say "${WHITE}2.${NC} Keep Settings (Remove logic only, preserve configs and credentials)"
say "${WHITE}3.${NC} Cancel"
say ""

while true; do
    printf "${BOLD}Choice [1-3]: ${NC}"
    if ! ask; then
        say "\n${RED}❌ No input available. Uninstall cancelled.${NC}"
        exit 1
    fi
    choice="$ANSWER"
    case "$choice" in 1|2|3) break ;; esac
done

# ==============================================================================
#  4. REMOVAL LOGIC
# ==============================================================================
case "$choice" in
    1)
        # --- OPTION 1: FULL UNINSTALL ---
        say ""
        stop_everything
        clean_tmp

        if [ -d "$INSTALL_DIR" ]; then
            rm -rf "$INSTALL_DIR"
            say "   - Removed $INSTALL_DIR (settings, IP lists, credentials, buffers)"
        fi

        remove_integration

        say ""
        say "${GREEN}✅ netwatchdta has been completely removed.${NC}"
        ;;

    2)
        # --- OPTION 2: KEEP SETTINGS ---
        say ""
        stop_everything
        clean_tmp

        say "${YELLOW}🗑️  Removing logic engine...${NC}"
        for f in netwatchdta.sh nwdta_common.sh; do
            if [ -f "$INSTALL_DIR/$f" ]; then
                rm -f "$INSTALL_DIR/$f"
                say "   - Removed $f"
            fi
        done

        remove_integration

        # List what was actually preserved
        kept=""
        for f in settings.conf device_ips.conf remote_ips.conf credentials.conf .vault.enc; do
            [ -f "$INSTALL_DIR/$f" ] && kept="$kept $f"
        done

        say ""
        say "${GREEN}✅ Logic removed.${NC}"
        if [ -n "$kept" ]; then
            say "${CYAN}ℹ️  Settings preserved in: $INSTALL_DIR${NC}"
            say "   ($(echo $kept | sed 's/ /, /g'))"
            say "   Re-run the installer and choose 'Keep settings' to restore the service."
        else
            say "${CYAN}ℹ️  No settings files were found to preserve.${NC}"
        fi
        ;;

    *)
        say "${RED}❌ Uninstall cancelled.${NC}"
        exit 0
        ;;
esac
