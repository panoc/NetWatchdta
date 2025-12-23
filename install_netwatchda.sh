#!/bin/sh
# netwatchda Installer - Automated Setup for OpenWrt
# Copyright (C) 2025 panoc
# Licensed under the GNU General Public License v3.0

# --- SELF-CLEAN LOGIC ---
# This ensures the installer script deletes itself after execution
SCRIPT_NAME="$0"
cleanup() {
    rm -f "$SCRIPT_NAME"
    exit
}
trap cleanup INT TERM EXIT

# --- COLOR DEFINITIONS ---
NC='\033[0m'       
BOLD='\033[1m'
RED='\033[1;31m'    # Light Red
GREEN='\033[1;32m'  # Light Green
BLUE='\033[1;34m'   # Light Blue (Vibrant)
CYAN='\033[1;36m'   # Light Cyan (Vibrant)
YELLOW='\033[1;33m' # Bold Yellow

# --- INITIAL HEADER ---
echo -e "${BLUE}=======================================================${NC}"
echo -e "${BOLD}${CYAN}🚀 netwatchda Automated Setup${NC} (by ${BOLD}panoc${NC})"
echo -e "${BLUE}⚖️  License: GNU GPLv3${NC}"
echo -e "${BLUE}=======================================================${NC}"
echo ""

# --- 0. PRE-INSTALLATION CONFIRMATION ---
printf "${BOLD}❓ This will begin the installation process. Continue? [y/n]: ${NC}"
read start_confirm </dev/tty
if [ "$start_confirm" != "y" ] && [ "$start_confirm" != "Y" ]; then
    echo -e "${RED}❌ Installation aborted by user. Cleaning up...${NC}"
    exit 0
fi

# --- DIRECTORY AND FILE DEFINITIONS ---
INSTALL_DIR="/root/netwatchda"
CONFIG_FILE="$INSTALL_DIR/nwda_settings.conf"
IP_LIST_FILE="$INSTALL_DIR/nwda_ips.conf"
AUTH_FILE="$INSTALL_DIR/.nwda_auth"
SEED_FILE="$INSTALL_DIR/.nwda_seed"
SERVICE_NAME="netwatchda"
SERVICE_PATH="/etc/init.d/$SERVICE_NAME"
LOG_DIR="/tmp/netwatchda"
UPTIME_LOG="$LOG_DIR/nwda_uptime.log"
PING_LOG="$LOG_DIR/nwda_ping.log"

# --- 1. DEPENDENCY CHECK ---
echo -e "\n${BOLD}📦 Checking system dependencies...${NC}"

# Check for openssl-util (New Security Requirement)
if ! command -v openssl >/dev/null 2>&1; then
    echo -e "${CYAN}🔍 openssl-util not found. Required for encrypted credentials.${NC}"
    echo -e "${YELLOW}📥 Installing openssl-util...${NC}"
    opkg update && opkg install openssl-util
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to install openssl-util. Cannot continue securely.${NC}"
        exit 1
    fi
fi

# Check for curl
if ! command -v curl >/dev/null 2>&1; then
    echo -e "${CYAN}🔍 curl not found. Installing...${NC}"
    opkg update && opkg install curl ca-bundle
fi

# Create Directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$LOG_DIR"

# --- 2. HARDWARE-LOCKED SEED GENERATION ---
if [ ! -f "$SEED_FILE" ]; then
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 > "$SEED_FILE"
    chmod 600 "$SEED_FILE"
fi

get_hw_key() {
    CPU_ID=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2 | xargs)
    BOARD=$(cat /tmp/sysinfo/board_name 2>/dev/null || echo "generic")
    SEED=$(cat "$SEED_FILE")
    echo "${CPU_ID}${BOARD}${SEED}" | md5sum | cut -d' ' -f1
}

# --- 3. NOTIFICATION CONFIGURATION MENU ---
echo -e "\n${BLUE}-------------------------------------------------------${NC}"
echo -e "${BOLD}🔔 NOTIFICATION SETUP${NC}"
echo -e "${BLUE}-------------------------------------------------------${NC}"
echo "1) Enable Discord Notifications"
echo "2) Enable Telegram Notifications"
echo "3) Enable Both (Redundancy)"
echo "4) None (Logs only - events tracked in $UPTIME_LOG)"
echo -e "${BLUE}-------------------------------------------------------${NC}"

while :; do
    printf "${BOLD}Select an option [1-4]: ${NC}"
    read notify_choice </dev/tty
    case "$notify_choice" in
        1|2|3|4) break ;;
        *) echo -e "${RED}❌ Invalid selection. Please enter 1, 2, 3, or 4.${NC}" ;;
    esac
done

DIS_EN="NO"; TEL_EN="NO"; DIS_WEB=""; DIS_ID=""; TEL_TOK=""; TEL_CHT=""

# Discord Prompts
if [ "$notify_choice" -eq 1 ] || [ "$notify_choice" -eq 3 ]; then
    DIS_EN="YES"
    printf "${BOLD}🔗 Enter Discord Webhook URL: ${NC}"; read DIS_WEB </dev/tty
    printf "${BOLD}👤 Enter Discord User ID (for pings): ${NC}"; read DIS_ID </dev/tty
fi

# Telegram Prompts
if [ "$notify_choice" -eq 2 ] || [ "$notify_choice" -eq 3 ]; then
    TEL_EN="YES"
    printf "${BOLD}🤖 Enter Telegram Bot Token: ${NC}"; read TEL_TOK </dev/tty
    printf "${BOLD}🆔 Enter Telegram Chat ID: ${NC}"; read TEL_CHT </dev/tty
    
    echo -e "${CYAN}🧪 Sending Telegram test notification...${NC}"
    curl -s -X POST "https://api.telegram.org/bot$TEL_TOK/sendMessage" \
        -d "chat_id=$TEL_CHT" \
        -d "text=🚀 netwatchda: Telegram test successful for $router_name_input" > /dev/null
    
    printf "${BOLD}❓ Did you receive the Telegram message? [y/n]: ${NC}"
    read confirm_tel </dev/tty
    if [ "$confirm_tel" != "y" ] && [ "$confirm_tel" != "Y" ]; then
        echo -e "${RED}❌ Telegram setup failed. Aborting installation.${NC}"
        exit 1
    fi
fi

# Secure Encryption
HW_KEY=$(get_hw_key)
RAW_AUTH="DIS_URL='$DIS_WEB'
DIS_ID='$DIS_ID'
TEL_TOKEN='$TEL_TOK'
TEL_CHAT='$TEL_CHT'"

echo -e "$RAW_AUTH" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 10000 -k "$HW_KEY" -out "$AUTH_FILE" 2>/dev/null
chmod 600 "$AUTH_FILE"

# --- 4. SETTINGS GENERATION ---
printf "${BOLD}🏷️  Enter a name for this Router: ${NC}"
read router_name_input </dev/tty

cat <<EOF > "$CONFIG_FILE"
# netwatchda Configuration File
# Updated: $(date)

[Router Identification]
ROUTER_NAME="$router_name_input"

[Discord Settings]
DISCORD_ENABLE="$DIS_EN"

[TELEGRAM]
TELEGRAM_ENABLE="$TEL_EN"

[Log settings]
UPTIME_LOG_MAX_SIZE=51200
PING_LOG_ENABLE="OFF"

[Notification Schedule]
HEARTBEAT_ENABLE="ON"
HEARTBEAT_HOUR="12"
SILENT_HOURS_ENABLE="OFF"
SILENT_START="23"
SILENT_END="07"

[Internet Connectivity]
EXT_IP="1.1.1.1"
EXT_IP2="8.8.8.8"
EXT_SCAN_INTERVAL=60
EXT_FAIL_THRESHOLD=1
EXT_PING_COUNT=4

[Local Device Monitoring]
DEVICE_MONITOR="ON"
DEV_SCAN_INTERVAL=10
DEV_FAIL_THRESHOLD=3
DEV_PING_COUNT=4
EOF

if [ ! -f "$IP_LIST_FILE" ]; then
    echo "# Format: IP_ADDRESS @ DEVICE_NAME" > "$IP_LIST_FILE"
    echo "1.1.1.1 @ Google_DNS" >> "$IP_LIST_FILE"
fi

echo -e "${GREEN}✅ Configuration and Security layers established.${NC}"
# --- 5. CORE ENGINE GENERATION ---
cat <<'EOF' > "$INSTALL_DIR/netwatchda.sh"
#!/bin/sh
# netwatchda Core Monitoring Script
# This script handles the main monitoring loop and notification logic

BASE_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG_FILE="$BASE_DIR/nwda_settings.conf"
IP_LIST_FILE="$BASE_DIR/nwda_ips.conf"
AUTH_FILE="$BASE_DIR/.nwda_auth"
SEED_FILE="$BASE_DIR/.nwda_seed"
LOG_DIR="/tmp/netwatchda"
UPTIME_LOG="$LOG_DIR/nwda_uptime.log"
PING_LOG="$LOG_DIR/nwda_ping.log"

# --- INTERNAL FUNCTIONS ---

# Gather hardware info for decryption key
get_hw_key() {
    CPU_ID=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2 | xargs)
    BOARD=$(cat /tmp/sysinfo/board_name 2>/dev/null || echo "generic")
    SEED=$(cat "$SEED_FILE")
    echo "${CPU_ID}${BOARD}${SEED}" | md5sum | cut -d' ' -f1
}

# Decrypt and load credentials into shell variables
load_auth() {
    if [ -f "$AUTH_FILE" ]; then
        HW_KEY=$(get_hw_key)
        # We use eval to load the decrypted variables directly into the session
        eval "$(openssl enc -d -aes-256-cbc -pbkdf2 -iter 10000 -k "$HW_KEY" -in "$AUTH_FILE" 2>/dev/null)"
    fi
}

# Parse settings from the config file
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # Removes ini-style headers and evals the key=value pairs
        eval "$(sed '/^\[.*\]/d' "$CONFIG_FILE")"
    fi
    load_auth
}

# Notification dispatcher for Discord and Telegram
send_notify() {
    local TITLE="$1"
    local MSG="$2"
    local COLOR="$3"
    local DURATION="$5"
    
    load_config
    
    # Check Silent Hours
    local CURRENT_HOUR=$(date +%H)
    if [ "$SILENT_HOURS_ENABLE" = "ON" ]; then
        if [ "$SILENT_START" -gt "$SILENT_END" ]; then
            # Overnight range (e.g., 23 to 07)
            if [ "$CURRENT_HOUR" -ge "$SILENT_START" ] || [ "$CURRENT_HOUR" -lt "$SILENT_END" ]; then
                return 0
            fi
        else
            # Same-day range (e.g., 09 to 17)
            if [ "$CURRENT_HOUR" -ge "$SILENT_START" ] && [ "$CURRENT_HOUR" -lt "$SILENT_END" ]; then
                return 0
            fi
        fi
    fi

    local TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    local FINAL_MSG="$MSG\nTime: $TIMESTAMP"
    if [ -n "$DURATION" ]; then
        FINAL_MSG="$FINAL_MSG\nDowntime Total: $DURATION"
    fi

    # Discord Notification Logic
    if [ "$DISCORD_ENABLE" = "YES" ] && [ -n "$DIS_URL" ]; then
        local DISCORD_PAYLOAD=$(echo -e "$FINAL_MSG" | sed ':a;N;$!ba;s/\n/\\n/g')
        curl -s -H "Content-Type: application/json" -X POST \
            -d "{\"embeds\": [{\"title\": \"$TITLE\", \"description\": \"$DISCORD_PAYLOAD\", \"color\": $COLOR}]}" \
            "$DIS_URL" > /dev/null 2>&1
    fi

    # Telegram Notification Logic (Uses Dash '-' Separator)
    if [ "$TELEGRAM_ENABLE" = "YES" ] && [ -n "$TEL_TOKEN" ]; then
        local TELEGRAM_TEXT=$(echo -e "*${TITLE}*\n${FINAL_MSG}" | sed 's/_/\\_/g')
        curl -s -X POST "https://api.telegram.org/bot$TEL_TOKEN/sendMessage" \
            -d "chat_id=$TEL_CHAT" \
            -d "parse_mode=Markdown" \
            -d "text=$TELEGRAM_TEXT" > /dev/null 2>&1
    fi
}

# --- INITIALIZATION ---

EXT_DOWN_TIME=0
LAST_HEARTBEAT_DAY=""
# Create log directory in RAM if it doesn't exist
[ -d "$LOG_DIR" ] || mkdir -p "$LOG_DIR"

# --- MAIN MONITORING LOOP ---

while true; do
    load_config
    # System Regional Format for Logs
    NOW_LOG=$(date '+%b %d %H:%M:%S')
    
    # 1. Heartbeat Logic
    CURRENT_DAY=$(date +%Y-%m-%d)
    CURRENT_HOUR=$(date +%H)
    if [ "$HEARTBEAT_ENABLE" = "ON" ] && [ "$CURRENT_HOUR" -eq "$HEARTBEAT_HOUR" ]; then
        if [ "$CURRENT_DAY" != "$LAST_HEARTBEAT_DAY" ]; then
            send_notify "💓 Heartbeat Status" "Router: $ROUTER_NAME _ Status: System Active" 3447003
            LAST_HEARTBEAT_DAY="$CURRENT_DAY"
        fi
    fi

    # 2. Internet Connectivity Check
    if ping -q -c "$EXT_PING_COUNT" -W 2 "$EXT_IP" > /dev/null 2>&1 || \
       ping -q -c "$EXT_PING_COUNT" -W 2 "$EXT_IP2" > /dev/null 2>&1; then
        
        # Recovery Logic
        if [ "$EXT_DOWN_TIME" -ne 0 ]; then
            END_TIME=$(date +%s)
            TOTAL_SECONDS=$((END_TIME - EXT_DOWN_TIME))
            
            # Format downtime string
            HOURS=$((TOTAL_SECONDS / 3600))
            MINS=$(((TOTAL_SECONDS % 3600) / 60))
            SECS=$((TOTAL_SECONDS % 60))
            DOWNTIME_STR="${HOURS}h ${MINS}m ${SECS}s"
            
            send_notify "🟢 Internet Restored" "Router: $ROUTER_NAME _ Status: Online" 3066993 "" "$DOWNTIME_STR"
            echo "$NOW_LOG - INTERNET_CHECK _ $EXT_IP : UP _ (Downtime: $DOWNTIME_STR)" >> "$UPTIME_LOG"
            EXT_DOWN_TIME=0
        fi
        
        # Detail Ping Log
        if [ "$PING_LOG_ENABLE" = "ON" ]; then
            echo "$NOW_LOG - INTERNET_CHECK _ $EXT_IP : UP" >> "$PING_LOG"
        fi
    else
        # Failure Logic
        if [ "$EXT_DOWN_TIME" -eq 0 ]; then
            EXT_DOWN_TIME=$(date +%s)
            send_notify "🔴 Internet Down" "Router: $ROUTER_NAME _ Status: Disconnected" 15158332
        fi
        
        echo "$NOW_LOG - INTERNET_CHECK _ $EXT_IP : DOWN" >> "$UPTIME_LOG"
        if [ "$PING_LOG_ENABLE" = "ON" ]; then
            echo "$NOW_LOG - INTERNET_CHECK _ $EXT_IP : DOWN" >> "$PING_LOG"
        fi
    fi

    # 3. Local Device Monitoring Loop
    if [ "$DEVICE_MONITOR" = "ON" ] && [ -f "$IP_LIST_FILE" ]; then
        # Use sed to remove comments and empty lines from IP list
        sed -e '/^#/d' -e '/^$/d' "$IP_LIST_FILE" | while read -r line; do
            DEV_IP=$(echo "$line" | cut -d'@' -f1 | xargs)
            DEV_NAME=$(echo "$line" | cut -d'@' -f2- | xargs)
            
            # Note: For full device downtime tracking, individual variables 
            # would be needed here. Keeping original logic for simplicity.
            if ping -q -c "$DEV_PING_COUNT" -W 2 "$DEV_IP" > /dev/null 2>&1; then
                if [ "$PING_LOG_ENABLE" = "ON" ]; then
                    echo "$NOW_LOG - DEVICE _ $DEV_NAME _ $DEV_IP : UP" >> "$PING_LOG"
                fi
            else
                echo "$NOW_LOG - DEVICE _ $DEV_NAME _ $DEV_IP : DOWN" >> "$UPTIME_LOG"
                if [ "$PING_LOG_ENABLE" = "ON" ]; then
                    echo "$NOW_LOG - DEVICE _ $DEV_NAME _ $DEV_IP : DOWN" >> "$PING_LOG"
                fi
            fi
        done
    fi

    # 4. Log Rotation (50KB / 51200 Bytes)
    if [ -f "$UPTIME_LOG" ]; then
        FILESIZE=$(wc -c < "$UPTIME_LOG")
        if [ "$FILESIZE" -gt "$UPTIME_LOG_MAX_SIZE" ]; then
            echo "$NOW_LOG - [System] Uptime Log Rotated (Limit Reached)" > "$UPTIME_LOG"
        fi
    fi

    if [ "$PING_LOG_ENABLE" = "ON" ] && [ -f "$PING_LOG" ]; then
        FILESIZE_PING=$(wc -c < "$PING_LOG")
        if [ "$FILESIZE_PING" -gt "$UPTIME_LOG_MAX_SIZE" ]; then
            echo "$NOW_LOG - [System] Ping Log Rotated (Limit Reached)" > "$PING_LOG"
        fi
    fi

    sleep "$EXT_SCAN_INTERVAL"
done
EOF
# --- 6. SERVICE SCRIPT GENERATION ---
cat <<'EOF' > "$SERVICE_PATH"
#!/bin/sh /etc/rc.common
# netwatchda Service Management Script

START=99
USE_PROCD=1

INSTALL_DIR="/root/netwatchda"
CORE_SCRIPT="$INSTALL_DIR/netwatchda.sh"
CONFIG_FILE="$INSTALL_DIR/nwda_settings.conf"
AUTH_FILE="$INSTALL_DIR/.nwda_auth"
SEED_FILE="$INSTALL_DIR/.nwda_seed"
LOG_DIR="/tmp/netwatchda"
UPTIME_LOG="$LOG_DIR/nwda_uptime.log"
PING_LOG="$LOG_DIR/nwda_ping.log"

# Define commands for OpenWrt 'service' system
extra_command "clear" "Clear all netwatchda logs"
extra_command "discord" "Send a test message to Discord"
extra_command "telegram" "Send a test message to Telegram"
extra_command "credentials" "Update Discord/Telegram tokens (Secure)"
extra_command "purge" "Completely uninstall netwatchda and all logs"
extra_command "help" "Show detailed command list"

# Logic for Decryption Key (same as Core Engine)
get_hw_key() {
    CPU_ID=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2 | xargs)
    BOARD=$(cat /tmp/sysinfo/board_name 2>/dev/null || echo "generic")
    SEED=$(cat "$SEED_FILE")
    echo "${CPU_ID}${BOARD}${SEED}" | md5sum | cut -d' ' -f1
}

start_service() {
    [ -d "$LOG_DIR" ] || mkdir -p "$LOG_DIR"
    procd_open_instance
    procd_set_param command /bin/sh "$CORE_SCRIPT"
    procd_set_param respawn # Automatically restarts if it crashes
    procd_close_instance
}

clear() {
    echo -e "$(date '+%b %d %H:%M:%S') - [System] Logs manually cleared" > "$UPTIME_LOG"
    echo -e "$(date '+%b %d %H:%M:%S') - [System] Logs manually cleared" > "$PING_LOG"
    echo "✅ Logs in $LOG_DIR have been reset."
}

discord() {
    echo "🧪 Sending test Discord notification..."
    # Sources the script but only runs the notify function
    ( . "$CORE_SCRIPT" && send_notify "🧪 Test" "Manual Discord Test from Router" 3447003 )
}

telegram() {
    echo "🧪 Sending test Telegram notification..."
    ( . "$CORE_SCRIPT" && send_notify "🧪 Test" "Manual Telegram Test from Router" 3447003 )
}

credentials() {
    echo -e "\n--- 🔐 Secure Credential Manager ---"
    echo "1. Update Discord Webhook/ID"
    echo "2. Update Telegram Token/ChatID"
    echo "3. Update Both"
    printf "Selection [1-3]: "
    read choice </dev/tty
    
    HW_KEY=$(get_hw_key)
    # Decrypt existing values into memory
    eval "$(openssl enc -d -aes-256-cbc -pbkdf2 -iter 10000 -k "$HW_KEY" -in "$AUTH_FILE" 2>/dev/null)"
    
    case "$choice" in
        1|3)
            printf "New Discord Webhook: "; read DIS_URL </dev/tty
            printf "New Discord User ID: "; read DIS_ID </dev/tty
            ;;
    esac
    case "$choice" in
        2|3)
            printf "New Telegram Token: "; read TEL_TOKEN </dev/tty
            printf "New Telegram Chat ID: "; read TEL_CHAT </dev/tty
            ;;
    esac

    # Re-encrypt
    RAW="DIS_URL='$DIS_URL'\nDIS_ID='$DIS_ID'\nTEL_TOKEN='$TEL_TOKEN'\nTEL_CHAT='$TEL_CHAT'"
    echo -e "$RAW" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 10000 -k "$HW_KEY" -out "$AUTH_FILE"
    echo "✅ Credentials updated and encrypted."
}

purge() {
    printf "⚠️  WARNING: This will delete everything in $INSTALL_DIR. Proceed? [y/N]: "
    read p_confirm </dev/tty
    if [ "$p_confirm" = "y" ] || [ "$p_confirm" = "Y" ]; then
        /etc/init.d/netwatchda stop
        /etc/init.d/netwatchda disable
        rm -rf "$INSTALL_DIR"
        rm -rf "$LOG_DIR"
        rm -f "/etc/init.d/netwatchda"
        echo "🔥 netwatchda has been fully removed from the system."
    else
        echo "❌ Purge cancelled."
    fi
}

help() {
    echo -e "\nnetwatchda Management Commands:"
    echo "  start       - Start the monitor service"
    echo "  stop        - Stop the monitor service"
    echo "  restart     - Restart the service (reloads config)"
    echo "  status      - Show if service is running"
    echo "  enable      - Enable autostart on boot"
    echo "  disable     - Disable autostart on boot"
    echo "  clear       - Wipe log files in /tmp"
    echo "  discord     - Test Discord connection"
    echo "  telegram    - Test Telegram connection"
    echo "  credentials - Securely edit your tokens"
    echo "  purge       - Completely uninstall the script"
    echo ""
}
EOF

# --- 7. FINALIZATION ---

# Set Permissions
chmod +x "$INSTALL_DIR/netwatchda.sh"
chmod +x "$SERVICE_PATH"

# Enable and Start
"$SERVICE_PATH" enable
"$SERVICE_PATH" restart

echo -e "\n${BLUE}=======================================================${NC}"
echo -e "${BOLD}${GREEN}✅ INSTALLATION SUCCESSFUL!${NC}"
echo -e "${BLUE}=======================================================${NC}"
echo -e "${BOLD}📁 App Folder:${NC}  $INSTALL_DIR"
echo -e "${CYAN}📂 Folder:${NC} $INSTALL_DIR"
echo -e "${GREEN}=======================================================${NC}"
echo -e "\n${BOLD}Quick Commands:${NC}"
echo -e "  View Help       : ${CYAN}cat $README_FILE${NC}"
echo -e "  Uninstall       : ${RED}/etc/init.d/netwatchda purge${NC}"
echo -e "  Edit Settings   : ${CYAN}$CONFIG_FILE${NC}"
echo -e "  Edit IP List    : ${CYAN}$IP_LIST_FILE${NC}"
echo -e "  Restart         : ${YELLOW}/etc/init.d/netwatchda restart${NC}"
echo ""
echo ""