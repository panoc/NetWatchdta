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

INSTALL_DIR="/root/netwatchda"
CONFIG_FILE="$INSTALL_DIR/netwatchda_settings.conf"
IP_LIST_FILE="$INSTALL_DIR/netwatchda_ips.conf"
README_FILE="$INSTALL_DIR/README.txt"
SERVICE_NAME="netwatchda"
SERVICE_PATH="/etc/init.d/$SERVICE_NAME"
LOG_DIR="/tmp/netwatchda"
UPTIME_LOG="$LOG_DIR/nwda_uptime.txt"
PING_LOG="$LOG_DIR/nwda_ping.log"

# --- 1. CHECK DEPENDENCIES & STORAGE (FLASH & RAM) ---
echo -e "\n${BOLD}📦 Checking system readiness...${NC}"

# Flash Storage Check (Root partition)
FREE_FLASH_KB=$(df / | awk 'NR==2 {print $4}')
MIN_FLASH_KB=3072 # 3MB Threshold

# RAM Check (/tmp partition)
FREE_RAM_KB=$(df /tmp | awk 'NR==2 {print $4}')
MIN_RAM_KB=512 # 512KB Threshold
DEFAULT_MAX_LOG=51200 # Default 50KB for log size (51200 bytes)

if ! command -v curl >/dev/null 2>&1; then
    echo -e "${CYAN}🔍 curl not found. Checking flash storage...${NC}"
    if [ "$FREE_FLASH_KB" -lt "$MIN_FLASH_KB" ]; then
        echo -e "${RED}❌ ERROR: Insufficient Flash storage!${NC}"
        echo -e "${YELLOW}Available: $((FREE_FLASH_KB / 1024))MB | Required: 3MB${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ Sufficient Flash space found: $((FREE_FLASH_KB / 1024))MB available.${NC}"
        echo -e "${YELLOW}📥 Attempting to install curl and ca-bundle...${NC}"
        opkg update && opkg install curl ca-bundle
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Error: Failed to install curl. Aborting.${NC}"
            exit 1
        fi
    fi
else
    echo -e "${GREEN}✅ curl is already installed.${NC}"
    echo -e "${GREEN}✅ Flash storage check passed: $((FREE_FLASH_KB / 1024))MB available.${NC}"
fi

# Determine Log size based on RAM availability (RAM Guard Logic)
if [ "$FREE_RAM_KB" -lt "$MIN_RAM_KB" ]; then
    echo -e "${YELLOW}⚠️  Low RAM detected in /tmp ($FREE_RAM_KB KB).${NC}"
    echo -e "${CYAN}📉 Scaling down log rotation size to 10KB for system stability.${NC}"
    DEFAULT_MAX_LOG=10240 # 10KB (10240 bytes)
else
    echo -e "${GREEN}✅ Sufficient RAM for standard logging ($FREE_RAM_KB KB available).${NC}"
fi

# --- 2. SMART UPGRADE / INSTALL CHECK ---
KEEP_CONFIG=0
if [ -f "$CONFIG_FILE" ]; then
    echo -e "\n${YELLOW}⚠️  Existing installation found.${NC}"
    echo -e "${BOLD}1.${NC} Keep settings (Upgrade)"
    echo -e "${BOLD}2.${NC} Clean install"
    
    while :; do
        printf "${BOLD}Enter choice [1-2]: ${NC}"
        read choice </dev/tty
        [ "$choice" = "1" ] || [ "$choice" = "2" ] && break
        echo -e "${RED}Invalid selection.${NC}"
    done
    
    if [ "$choice" = "1" ]; then
        echo -e "${CYAN}🔧 Scanning for missing configuration lines...${NC}"
        
        add_if_missing() {
            if ! grep -q "^$1=" "$CONFIG_FILE"; then
                echo "$1=$2 $3" >> "$CONFIG_FILE"
                echo -e "  ${GREEN}➕ Added missing line:${NC} $1"
            fi
        }

        add_if_missing "ROUTER_NAME" "\"My_OpenWrt_Router\"" "# Name that appears in notifications."
        add_if_missing "DISCORD_ENABLE" "\"NO\"" "# Enable Discord Notifications (YES/NO)."
        add_if_missing "DISCORD_URL" "\"\"" "# Your Discord Webhook URL."
        add_if_missing "TELEGRAM_ENABLE" "\"NO\"" "# Enable Telegram Notifications (YES/NO)."
        add_if_missing "TELE_BOT_TOKEN" "\"\"" "# Telegram Bot Token."
        add_if_missing "TELE_CHAT_ID" "\"\"" "# Telegram Chat ID."
        add_if_missing "MY_ID" "\"\"" "# Your Discord User ID (for @mentions)."
        add_if_missing "UPTIME_LOG_MAX_SIZE" "$DEFAULT_MAX_LOG" "# Max log file size in bytes."
        add_if_missing "PING_LOG_ENABLE" "\"OFF\"" "# Set to ON to log every ping attempt."
        add_if_missing "HEARTBEAT" "\"OFF\"" "# Set to ON to receive a periodic check-in message."
        add_if_missing "HB_INTERVAL" "86400" "# Interval in seconds."
        add_if_missing "HB_MENTION" "\"OFF\"" "# Set to ON to include @mention in heartbeats."
        add_if_missing "EXT_PING_COUNT" "4" "# Number of pings per internet check."
        add_if_missing "EXT_SCAN_INTERVAL" "60" "# Seconds between internet checks."
        add_if_missing "EXT_FAIL_THRESHOLD" "1" "# Failed cycles before alert."
        add_if_missing "EXT_IP" "\"1.1.1.1\"" "# External IP to ping."
        add_if_missing "EXT_IP2" "\"8.8.8.8\"" "# Secondary External IP."
        add_if_missing "DEVICE_MONITOR" "\"ON\"" "# Set to ON to enable local IP monitoring."
        add_if_missing "DEV_PING_COUNT" "4" "# Number of pings per device check."
        add_if_missing "DEV_SCAN_INTERVAL" "10" "# Seconds between device pings."
        add_if_missing "DEV_FAIL_THRESHOLD" "3" "# Failed cycles before alert."
        add_if_missing "SILENT_ENABLE" "\"OFF\"" "# Set to ON to enable silent hours mode."
        add_if_missing "SILENT_START" "23" "# Hour to start silent mode (0-23)."
        add_if_missing "SILENT_END" "07" "# Hour to end silent mode (0-23)."

        echo -e "${GREEN}✅ Configuration patch complete.${NC}"
        KEEP_CONFIG=1
    else
        echo -e "${RED}🧹 Performing clean install...${NC}"
        /etc/init.d/netwatchda stop 2>/dev/null
        rm -rf "$INSTALL_DIR"
    fi
fi

mkdir -p "$INSTALL_DIR"
mkdir -p "$LOG_DIR"

# --- 3. CLEAN INSTALL INPUTS ---
if [ "$KEEP_CONFIG" -eq 0 ]; then
    echo -e "\n${BLUE}--- Configuration ---${NC}"
    printf "${BOLD}🏷️  Enter Router Name (e.g., MyRouter): ${NC}"
    read router_name_input </dev/tty

    echo -e "\n${BLUE}--- Notification Setup ---${NC}"
    echo "1. Enable Discord Notifications"
    echo "2. Enable Telegram Notifications"
    echo "3. Enable Both"
    echo "4. None (Logs only)"
    
    while :; do
        printf "${BOLD}Select option [1-4]: ${NC}"
        read notify_choice </dev/tty
        case "$notify_choice" in
            1|2|3|4) break ;;
            *) echo -e "${RED}Invalid selection.${NC}" ;;
        esac
    done

    DIS_EN="NO"; TEL_EN="NO"
    user_webhook=""; user_id=""
    tele_token=""; tele_chat=""

    # Discord Config
    if [ "$notify_choice" -eq 1 ] || [ "$notify_choice" -eq 3 ]; then
        DIS_EN="YES"
        printf "${BOLD}🔗 Enter Discord Webhook URL: ${NC}"
        read user_webhook </dev/tty
        printf "${BOLD}👤 Enter Discord User ID (for @mentions): ${NC}"
        read user_id </dev/tty
        
        echo -e "${CYAN}🧪 Sending Discord test notification...${NC}"
        curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"📟 Router Setup\", \"description\": \"Discord test successful for **$router_name_input**!\", \"color\": 1752220}]}" "$user_webhook" > /dev/null
        printf "${BOLD}❓ Received Discord notification? [y/n]: ${NC}"
        read confirm_dis </dev/tty
        [ "$confirm_dis" != "y" ] && [ "$confirm_dis" != "Y" ] && { echo -e "${RED}Aborted. Check Discord URL.${NC}"; exit 1; }
    fi

    # Telegram Config
    if [ "$notify_choice" -eq 2 ] || [ "$notify_choice" -eq 3 ]; then
        TEL_EN="YES"
        printf "${BOLD}🤖 Enter Telegram Bot Token: ${NC}"
        read tele_token </dev/tty
        printf "${BOLD}🆔 Enter Telegram Chat ID: ${NC}"
        read tele_chat </dev/tty
        
        echo -e "${CYAN}🧪 Sending Telegram test notification...${NC}"
        curl -s -X POST "https://api.telegram.org/bot$tele_token/sendMessage" -d "chat_id=$tele_chat" -d "text=🚀 netwatchda: Telegram test successful for $router_name_input!" > /dev/null
        printf "${BOLD}❓ Received Telegram notification? [y/n]: ${NC}"
        read confirm_tel </dev/tty
        [ "$confirm_tel" != "y" ] && [ "$confirm_tel" != "Y" ] && { echo -e "${RED}Aborted. Check Telegram credentials.${NC}"; exit 1; }
    fi

    if [ "$notify_choice" -eq 4 ]; then
        echo -e "${YELLOW}ℹ️ Notifications disabled. Events will only be tracked in $UPTIME_LOG.${NC}"
    fi
echo -e "\n${BLUE}--- Silent Hours (No Alerts) ---${NC}"
    printf "${BOLD}🌙 Enable Silent Hours? [y/n]: ${NC}"
    read enable_silent_choice </dev/tty
    
    if [ "$enable_silent_choice" = "y" ] || [ "$enable_silent_choice" = "Y" ]; then
        SILENT_VAL="ON"
        while :; do
            printf "${BOLD}   > Start Hour (24H Format 0-23): ${NC}"
            read user_silent_start </dev/tty
            if echo "$user_silent_start" | grep -qE '^[0-9]+$' && [ "$user_silent_start" -ge 0 ] && [ "$user_silent_start" -le 23 ] 2>/dev/null; then
                break
            else
                echo -e "${RED}   ❌ Invalid hour. Use 0-23.${NC}"
            fi
        done
        while :; do
            printf "${BOLD}   > End Hour (24H Format 0-23): ${NC}"
            read user_silent_end </dev/tty
            if echo "$user_silent_end" | grep -qE '^[0-9]+$' && [ "$user_silent_end" -ge 0 ] && [ "$user_silent_end" -le 23 ] 2>/dev/null; then
                break
            else
                echo -e "${RED}   ❌ Invalid hour. Use 0-23.${NC}"
            fi
        done
    else
        SILENT_VAL="OFF"; user_silent_start="23"; user_silent_end="07"
    fi

    echo -e "\n${BLUE}--- Heartbeat Settings ---${NC}"
    printf "${BOLD}💓 Enable Heartbeat (System check-in)? [y/n]: ${NC}"
    read hb_enabled </dev/tty
    if [ "$hb_enabled" = "y" ] || [ "$hb_enabled" = "Y" ]; then
        HB_VAL="ON"
        printf "${BOLD}⏰ Interval in HOURS (e.g., 24): ${NC}"
        read hb_hours </dev/tty
        HB_SEC=$((hb_hours * 3600))
        printf "${BOLD}🔔 Mention in Heartbeat? [y/n]: ${NC}"
        read hb_m </dev/tty
        [ "$hb_m" = "y" ] || [ "$hb_m" = "Y" ] && HB_MENTION="ON" || HB_MENTION="OFF"
    else
        HB_VAL="OFF"; HB_SEC="86400"; HB_MENTION="OFF"
    fi

    echo -e "\n${BLUE}--- Monitoring Mode ---${NC}"
    echo "1. Both: Full monitoring (Default)"
    echo "2. Device Connectivity only"
    echo "3. Internet Connectivity only"
    printf "${BOLD}Enter choice [1-3]: ${NC}"
    read mode_choice </dev/tty

    case "$mode_choice" in
        2) EXT_VAL="";        DEV_VAL="ON"  ;;
        3) EXT_VAL="1.1.1.1"; DEV_VAL="OFF" ;;
        *) EXT_VAL="1.1.1.1"; DEV_VAL="ON"  ;;
    esac

    # --- NEW: PING LOGGING OPTION ---
    echo -e "\n${BLUE}--- Ping Logging ---${NC}"
    printf "${BOLD}📑 Enable detailed ping logging (nwda_ping.log)? [y/n]: ${NC}"
    read p_log_choice </dev/tty
    [ "$p_log_choice" = "y" ] || [ "$p_log_choice" = "Y" ] && P_LOG_VAL="ON" || P_LOG_VAL="OFF"

    cat <<EOF > "$CONFIG_FILE"
[Router Identification]
ROUTER_NAME="$router_name_input" # Name that appears in notifications.

[Discord Settings]
DISCORD_ENABLE="$DIS_EN" # Enable Discord Notifications (YES/NO).
DISCORD_URL="$user_webhook" # Your Discord Webhook URL.
MY_ID="$user_id" # Your Discord User ID (for @mentions).

[Telegram Settings]
TELEGRAM_ENABLE="$TEL_EN" # Enable Telegram Notifications (YES/NO).
TELE_BOT_TOKEN="$tele_token" # Your Telegram Bot Token.
TELE_CHAT_ID="$tele_chat" # Your Telegram Chat ID.

[Silent Hours Settings]
SILENT_ENABLE="$SILENT_VAL" # Set to ON to enable silent hours mode.
SILENT_START=$user_silent_start # Hour to start silent mode (24H Format 0-23).
SILENT_END=$user_silent_end # Hour to end silent mode (24H Format 0-23).

[Log Settings]
UPTIME_LOG_MAX_SIZE=$DEFAULT_MAX_LOG # Max log file size in bytes.
PING_LOG_ENABLE="$P_LOG_VAL" # Set to ON to log every ping attempt.

[Heartbeat Settings]
HEARTBEAT="$HB_VAL" # Set to ON to receive a periodic check-in message.
HB_INTERVAL=$HB_SEC # Interval in seconds. Default is 86400
HB_MENTION="$HB_MENTION" # Set to ON to include @mention in heartbeats.

[Internet Connectivity]
EXT_IP="$EXT_VAL" # External IP to ping. Leave empty to disable.
EXT_IP2="8.8.8.8" # Secondary External IP for redundancy.
EXT_SCAN_INTERVAL=60 # Seconds between internet checks. Default is 60.
EXT_FAIL_THRESHOLD=1 # Number of failed checks before alert. Default 1.
EXT_PING_COUNT=4 # Number of pings per check. Default 4.

[Local Device Monitoring]
DEVICE_MONITOR="$DEV_VAL" # Set to ON to enable local IP monitoring.
DEV_SCAN_INTERVAL=10 # Seconds between device pings. Default is 10.
DEV_FAIL_THRESHOLD=3 # Number of failed cycles before alert. Default 3.
DEV_PING_COUNT=4 # Number of pings per check. Default 4.
EOF

    cat <<EOF > "$IP_LIST_FILE"
# Format: IP_ADDRESS @ NAME
# Example: 192.168.1.50 @ Home Server
EOF
    
    LOCAL_IP=$(uci -q get network.lan.ipaddr || ip addr show br-lan | grep -oE 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 | awk '{print $2}')
    [ -n "$LOCAL_IP" ] && echo "$LOCAL_IP @ Router Gateway" >> "$IP_LIST_FILE"
fi

# --- 4. CREATE INITIAL LOG & README ---
NOW_LOG=$(date '+%b %d, %Y %H:%M:%S')
echo "$NOW_LOG - [SYSTEM] netwatchda installation successful." > "$UPTIME_LOG"

cat <<EOF > "$README_FILE"
===========================================================
🚀 netwatchda - Network Monitoring for OpenWrt
===========================================================
Copyright (C) 2025 panoc
License: GNU GPLv3

A lightweight daemon for monitoring internet connectivity 
and local network devices with Discord & Telegram notifications.

--- 📂 DIRECTORY STRUCTURE ---
All files are located in: /root/netwatchda/

1. netwatchda.sh            - Core monitoring engine.
2. netwatchda_settings.conf - Main configuration file.
3. netwatchda_ips.conf      - Local device list.
4. README.txt               - This manual.

Logs are stored in RAM to protect flash: /tmp/netwatchda/

--- ⚙️ SETTINGS.CONF EXPLAINED ---

[Router Identification]
- ROUTER_NAME: The name shown in notification titles.

[Discord/Telegram Settings]
- ENABLE: (YES/NO) Toggle specific notification services.
- DISCORD_URL: Your Webhook URL for message delivery.
- MY_ID: Your numeric Discord User ID for @mentions.
- TELE_BOT_TOKEN: Your Telegram bot API token.
- TELE_CHAT_ID: Your Telegram chat or group ID.

[Silent Hours Settings]
- SILENT_ENABLE: (ON/OFF) If ON, mutes alerts during specified hours.
- SILENT_START/END: 24h format (e.g., 23 and 07). 
  *Note: Outages are bundled into a Summary sent at SILENT_END.*

[Log Settings]
- UPTIME_LOG_MAX_SIZE: Max size in bytes (e.g., 51200). Once reached, the 
  log file in /tmp clears itself to save RAM.
- PING_LOG_ENABLE: (ON/OFF) Toggle detailed logging of every ping attempt.

[Heartbeat Settings]
- HEARTBEAT: (ON/OFF) Sends a periodic "I am alive" message.
- HB_INTERVAL: Seconds between heartbeats (Default 86400 = 24h).
- HB_MENTION: (ON/OFF) Choose if the heartbeat should ping your @ID.

[Internet Connectivity]
- EXT_IP: The primary target to ping.
- EXT_IP2: The secondary target to ping for redundancy.
- EXT_SCAN_INTERVAL: Seconds between internet checks (Default 60).
- EXT_FAIL_THRESHOLD: Failed checks needed to trigger a "Down" alert.
- EXT_PING_COUNT: Number of packets sent per check (Default 4).

[Local Device Monitoring]
- DEVICE_MONITOR: (ON/OFF) Enable/Disable tracking of local IPs.
- DEV_SCAN_INTERVAL: Seconds between device checks (Default 10).
- DEV_FAIL_THRESHOLD: Failed checks needed to trigger alert. 

--- 📋 DEVICE LIST (ips.conf) ---
Add devices using the format: IP_ADDRESS @ Device Name
Example: 192.168.1.15 @ Smart_TV

--- 🎨 NOTIFICATION COLORS ---
- 🔴 RED (15548997): CRITICAL - Internet or Device is DOWN.
- 🟢 GREEN (3066993): SUCCESS - Connectivity is RESTORED.
- 🟡 YELLOW (16776960): WARNING - Manual test triggered.
- 🔵 CYAN (1752220): INFO - System startup or Heartbeat.
- 🟣 PURPLE (10181046): SUMMARY - Silent hours report.

--- 🛠️ MANAGEMENT COMMANDS ---
  /etc/init.d/netwatchda restart  - Apply configuration changes
  /etc/init.d/netwatchda status   - Check if the daemon is running
  /etc/init.d/netwatchda logs     - View recent activity history
  /etc/init.d/netwatchda discord  - Send a Yellow Warning test alert
  /etc/init.d/netwatchda purge    - Interactive Smart Uninstaller
===========================================================
EOF

# --- 5. CORE SCRIPT GENERATION ---
cat <<'EOF' > "$INSTALL_DIR/netwatchda.sh"
#!/bin/sh
BASE_DIR=$(cd "$(dirname "$0")" && pwd)
IP_LIST_FILE="$BASE_DIR/netwatchda_ips.conf"
CONFIG_FILE="$BASE_DIR/netwatchda_settings.conf"
LOG_DIR="/tmp/netwatchda"
UPTIME_LOG="$LOG_DIR/nwda_uptime.txt"
PING_LOG="$LOG_DIR/nwda_ping.log"
SILENT_BUFFER="/tmp/nwda_silent_buffer"

mkdir -p "$LOG_DIR"
[ ! -f "$UPTIME_LOG" ] && touch "$UPTIME_LOG"
[ ! -f "$PING_LOG" ] && touch "$PING_LOG"
[ ! -f "$SILENT_BUFFER" ] && touch "$SILENT_BUFFER"

load_config() {
    [ -f "$CONFIG_FILE" ] && eval "$(sed '/^\[.*\]/d' "$CONFIG_FILE")"
}

send_notify() {
    TITLE="$1"; MSG="$2"; COLOR="$3"; TYPE="$4"
    CLEAN_MSG=$(echo -e "$MSG" | sed ':a;N;$!ba;s/\n/\\n/g')
    
    if [ "$DISCORD_ENABLE" = "YES" ]; then
        curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"$TITLE\", \"description\": \"$CLEAN_MSG\", \"color\": $COLOR}]}" "$DISCORD_URL" > /dev/null 2>&1
    fi
    if [ "$TELEGRAM_ENABLE" = "YES" ]; then
        TELE_TEXT="*$TITLE*\n$MSG"
        curl -s -X POST "https://api.telegram.org/bot$TELE_BOT_TOKEN/sendMessage" -d "chat_id=$TELE_CHAT_ID" -d "parse_mode=Markdown" -d "text=$TELE_TEXT" > /dev/null 2>&1
    fi
}

LAST_EXT_CHECK=0; LAST_DEV_CHECK=0; LAST_HB_CHECK=$(date +%s)

while true; do
    load_config
    NOW_HUMAN=$(date '+%b %d %H:%M:%S'); NOW_SEC=$(date +%s); CUR_HOUR=$(date +%H)

    # --- HEARTBEAT ---
    if [ "$HEARTBEAT" = "ON" ] && [ $((NOW_SEC - LAST_HB_CHECK)) -ge "$HB_INTERVAL" ]; then
        LAST_HB_CHECK=$NOW_SEC
        HB_MSG="**Router:** $ROUTER_NAME\n**Status:** Online\n**Time:** $NOW_HUMAN"
        [ "$HB_MENTION" = "ON" ] && HB_MSG="$HB_MSG\n<@$MY_ID>"
        send_notify "💓 Heartbeat" "$HB_MSG" 1752220
        echo "$NOW_HUMAN - [SYSTEM] Heartbeat sent." >> "$UPTIME_LOG"
    fi

    # --- SILENT MODE LOGIC ---
    IS_SILENT=0
    if [ "$SILENT_ENABLE" = "ON" ]; then
        if [ "$SILENT_START" -gt "$SILENT_END" ]; then
            if [ "$CUR_HOUR" -ge "$SILENT_START" ] || [ "$CUR_HOUR" -lt "$SILENT_END" ]; then IS_SILENT=1; fi
        else
            if [ "$CUR_HOUR" -ge "$SILENT_START" ] && [ "$CUR_HOUR" -lt "$SILENT_END" ]; then IS_SILENT=1; fi
        fi
    fi

    if [ "$IS_SILENT" -eq 0 ] && [ -s "$SILENT_BUFFER" ]; then
        send_notify "🌙 Silent Hours Summary" "**Router:** $ROUTER_NAME\n$(cat "$SILENT_BUFFER")" 10181046
        > "$SILENT_BUFFER"
    fi

    # --- INTERNET CHECK ---
    if { [ -n "$EXT_IP" ] || [ -n "$EXT_IP2" ]; } && [ $((NOW_SEC - LAST_EXT_CHECK)) -ge "$EXT_SCAN_INTERVAL" ]; then
        LAST_EXT_CHECK=$NOW_SEC
        FD="/tmp/nwda_ext_d"; FT="/tmp/nwda_ext_t"; FC="/tmp/nwda_ext_c"
        EXT_UP=0
        
        if [ -n "$EXT_IP" ] && ping -q -c "$EXT_PING_COUNT" -W 2 "$EXT_IP" > /dev/null 2>&1; then EXT_UP=1
        elif [ -n "$EXT_IP2" ] && ping -q -c "$EXT_PING_COUNT" -W 2 "$EXT_IP2" > /dev/null 2>&1; then EXT_UP=1
        fi

        [ "$PING_LOG_ENABLE" = "ON" ] && echo "$NOW_HUMAN $ROUTER_NAME INTERNET_CHECK: $([ "$EXT_UP" -eq 1 ] && echo "UP" || echo "DOWN")" >> "$PING_LOG"

        if [ "$EXT_UP" -eq 0 ]; then
            C=$(($(cat "$FC" 2>/dev/null || echo 0)+1)); echo "$C" > "$FC"
            if [ "$C" -ge "$EXT_FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                echo "$NOW_SEC" > "$FD"; echo "$NOW_HUMAN" > "$FT"
                echo "$NOW_HUMAN - [ALERT] INTERNET DOWN" >> "$UPTIME_LOG"
                [ "$IS_SILENT" -eq 0 ] && send_notify "🔴 Internet Down" "**Router:** $ROUTER_NAME\n**Time:** $NOW_HUMAN" 15548997 || echo "🌐 Internet Outage: $NOW_HUMAN" >> "$SILENT_BUFFER"
            fi
        else
            if [ -f "$FD" ]; then
                DUR=$((NOW_SEC - $(cat "$FD"))); DR="$((DUR/60))m $((DUR%60))s"
                MSG="**Router:** $ROUTER_NAME\n**Down:** $(cat "$FT")\n**Up:** $NOW_HUMAN\n**Total:** $DR"
                echo "$NOW_HUMAN - [SUCCESS] INTERNET UP (Down $DR)" >> "$UPTIME_LOG"
                [ "$IS_SILENT" -eq 0 ] && send_notify "🟢 Internet Restored" "$MSG" 3066993 || echo -e "✅ Internet Restored (Down $DR)" >> "$SILENT_BUFFER"
                rm -f "$FD" "$FT"
            fi
            echo 0 > "$FC"
        fi
    fi

    # --- DEVICE CHECK ---
    if [ "$DEVICE_MONITOR" = "ON" ] && [ $((NOW_SEC - LAST_DEV_CHECK)) -ge "$DEV_SCAN_INTERVAL" ]; then
        LAST_DEV_CHECK=$NOW_SEC
        sed -e '/^#/d' -e '/^$/d' "$IP_LIST_FILE" | while read -r line; do
            TIP=$(echo "$line" | cut -d'@' -f1 | tr -d ' ')
            NAME=$(echo "$line" | cut -d'@' -f2- | sed 's/^[ \t]*//')
            SIP=$(echo "$TIP" | tr '.' '_')
            FC="/tmp/nwda_c_$SIP"; FD="/tmp/nwda_d_$SIP"; FT="/tmp/nwda_t_$SIP"
            
            if ping -q -c "$DEV_PING_COUNT" -W 2 "$TIP" > /dev/null 2>&1; then
                D_UP=1
                if [ -f "$FD" ]; then
                    DUR=$((NOW_SEC-$(cat "$FD"))); DR="$((DUR/60))m $((DUR%60))s"
                    MSG="**Device:** $NAME ($TIP)\n**Outage:** $DR"
                    echo "$NOW_HUMAN - [SUCCESS] $NAME ($TIP) Online (Down $DR)" >> "$UPTIME_LOG"
                    [ "$IS_SILENT" -eq 0 ] && send_notify "🟢 $NAME Online" "$MSG" 3066993 || echo -e "✅ $NAME Online ($DR)" >> "$SILENT_BUFFER"
                    rm -f "$FD" "$FT"
                fi
                echo 0 > "$FC"
            else
                D_UP=0
                C=$(($(cat "$FC" 2>/dev/null || echo 0)+1)); echo "$C" > "$FC"
                if [ "$C" -ge "$DEV_FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                    echo "$NOW_SEC" > "$FD"; echo "$NOW_HUMAN" > "$FT"
                    echo "$NOW_HUMAN - [ALERT] $NAME ($TIP) Down" >> "$UPTIME_LOG"
                    [ "$IS_SILENT" -eq 0 ] && send_notify "🔴 Device Down" "**Router:** $ROUTER_NAME\n**Device:** $NAME ($TIP)" 15548997 || echo -e "🔴 $NAME ($TIP) Down: $NOW_HUMAN" >> "$SILENT_BUFFER"
                fi
            fi
            [ "$PING_LOG_ENABLE" = "ON" ] && echo "$NOW_HUMAN $NAME $TIP: $([ "$D_UP" -eq 1 ] && echo "UP" || echo "DOWN")" >> "$PING_LOG"
        done
    fi

    # Log Rotations
    if [ $(wc -c < "$UPTIME_LOG") -gt "$UPTIME_LOG_MAX_SIZE" ]; then echo "$NOW_HUMAN - [SYSTEM] Log rotated." > "$UPTIME_LOG"; fi
    if [ $(wc -c < "$PING_LOG") -gt "$UPTIME_LOG_MAX_SIZE" ]; then echo "$NOW_HUMAN - [SYSTEM] Log rotated." > "$PING_LOG"; fi
    sleep 1
done
EOF

# --- 6. ENHANCED SERVICE SETUP ---
chmod +x "$INSTALL_DIR/netwatchda.sh"
cat <<EOF > "$SERVICE_PATH"
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

extra_command "status" "Check if monitor is running"
extra_command "logs" "View last 20 log entries"
extra_command "purge" "Interactive smart uninstaller"

start_service() {
    procd_open_instance
    procd_set_param command /bin/sh "$INSTALL_DIR/netwatchda.sh"
    procd_set_param respawn
    procd_close_instance
}

status() { pgrep -f "netwatchda.sh" > /dev/null && echo "netwatchda is RUNNING." || echo "netwatchda is STOPPED."; }
logs() { [ -f "$UPTIME_LOG" ] && tail -n 20 "$UPTIME_LOG" || echo "No log found."; }

purge() {
    echo -e "\033[1;31m🗑️ netwatchda Uninstaller\033[0m"
    echo "1. Full Uninstall | 2. Keep Config | 3. Cancel"
    read choice </dev/tty
    case "\$choice" in
        1)
            /etc/init.d/netwatchda stop; /etc/init.d/netwatchda disable
            rm -rf "$INSTALL_DIR" "$LOG_DIR" "$SERVICE_PATH" /tmp/nwda_*
            echo "✅ Completely removed." ;;
        2)
            /etc/init.d/netwatchda stop; rm -f "$INSTALL_DIR/netwatchda.sh" "$SERVICE_PATH" /tmp/nwda_*
            echo "✅ Logic removed. Config preserved." ;;
    esac
}
EOF

chmod +x "$SERVICE_PATH"
"$SERVICE_PATH" enable
"$SERVICE_PATH" restart

# --- 7. SUCCESS NOTIFICATION ---
eval "$(sed '/^\[.*\]/d' "$CONFIG_FILE")"
NOW_FINAL=$(date '+%b %d, %Y %H:%M:%S')
send_notify_init() {
    [ "$DISCORD_ENABLE" = "YES" ] && curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🚀 netwatchda Started\", \"description\": \"**Router:** $ROUTER_NAME\n**Time:** $NOW_FINAL\", \"color\": 1752220}]}" "$DISCORD_URL" > /dev/null
    [ "$TELEGRAM_ENABLE" = "YES" ] && curl -s -X POST "https://api.telegram.org/bot$TELE_BOT_TOKEN/sendMessage" -d "chat_id=$TELE_CHAT_ID" -d "text=🚀 netwatchda: Service started for $ROUTER_NAME at $NOW_FINAL" > /dev/null
}
send_notify_init

# --- FINAL OUTPUT ---
echo -e "${GREEN}=======================================================${NC}"
echo -e "${BOLD}${GREEN}✅ Installation complete!${NC}"
echo -e "${CYAN}📂 Folder:${NC} $INSTALL_DIR | ${CYAN}📊 Logs:${NC} $LOG_DIR"
echo -e "${GREEN}=======================================================${NC}"
echo -e "\n${BOLD}Quick Commands:${NC}"
echo -e "  View History    : ${CYAN}/etc/init.d/netwatchda logs${NC}"
echo -e "  Uninstall       : ${RED}/etc/init.d/netwatchda purge${NC}"
echo -e "  Settings        : ${CYAN}vi $CONFIG_FILE${NC}"
echo ""	