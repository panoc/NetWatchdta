#!/bin/sh
# netwatchda Installer - Automated Setup for OpenWrt
# Copyright (C) 2025 panoc
# Licensed under the GNU General Public License v3.0

# --- SELF-CLEAN LOGIC ---
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
SERVICE_NAME="netwatchda"
SERVICE_PATH="/etc/init.d/$SERVICE_NAME"
LOGFILE="/tmp/netwatchda_log.txt"

# --- 1. CHECK DEPENDENCIES & STORAGE (FLASH & RAM) ---
echo -e "\n${BOLD}📦 Checking system readiness...${NC}"

# Flash Storage Check (Root partition)
FREE_FLASH_KB=$(df / | awk 'NR==2 {print $4}')
MIN_FLASH_KB=3072 # 3MB Threshold

# RAM Check (/tmp partition)
FREE_RAM_KB=$(df /tmp | awk 'NR==2 {print $4}')
MIN_RAM_KB=512 # 512KB Threshold
DEFAULT_MAX_LOG=512000 # Default 512KB

if ! command -v curl >/dev/null 2>&1; then
    echo -e "${CYAN}🔍 curl not found. Checking flash storage...${NC}"
    if [ "$FREE_FLASH_KB" -lt "$MIN_FLASH_KB" ]; then
        echo -e "${RED}❌ ERROR: Insufficient Flash storage!${NC}"
        echo -e "${YELLOW}Available: $((FREE_FLASH_KB / 1024))MB | Required: 3MB${NC}"
        exit 1
    else
        # --- STORAGE SUCCESS MESSAGE ---
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

# Determine Log size based on RAM availability
if [ "$FREE_RAM_KB" -lt "$MIN_RAM_KB" ]; then
    echo -e "${YELLOW}⚠️  Low RAM detected in /tmp ($FREE_RAM_KB KB).${NC}"
    echo -e "${CYAN}📉 Scaling down log rotation size to 64KB for system stability.${NC}"
    DEFAULT_MAX_LOG=65536 # 64KB
else
    echo -e "${GREEN}✅ Sufficient RAM for standard logging ($FREE_RAM_KB KB available).${NC}"
fi

# --- 2. SMART UPGRADE / INSTALL CHECK ---
KEEP_CONFIG=0
if [ -f "$CONFIG_FILE" ]; then
    echo -e "\n${YELLOW}⚠️  Existing installation found.${NC}"
    echo -e "${BOLD}1.${NC} Keep settings (Upgrade)"
    echo -e "${BOLD}2.${NC} Clean install"
    printf "${BOLD}Enter choice [1-2]: ${NC}"
    read choice </dev/tty
    
    if [ "$choice" = "1" ]; then
        echo -e "${CYAN}🔧 Scanning for missing configuration lines...${NC}"
        
        add_if_missing() {
            if ! grep -q "^$1=" "$CONFIG_FILE"; then
                echo "$1=$2 $3" >> "$CONFIG_FILE"
                echo -e "  ${GREEN}➕ Added missing line:${NC} $1"
            fi
        }

        add_if_missing "ROUTER_NAME" "\"My_OpenWrt_Router\"" "# Router ID for Discord"
        add_if_missing "SCAN_INTERVAL" "10" "# Seconds between pings"
        add_if_missing "FAIL_THRESHOLD" "3" "# Retries before alert"
        add_if_missing "MAX_SIZE" "$DEFAULT_MAX_LOG" "# Log rotation size in bytes"
        add_if_missing "HEARTBEAT" "\"OFF\"" "# Daily check-in toggle"
        add_if_missing "HB_INTERVAL" "86400" "# Heartbeat frequency in seconds"
        add_if_missing "HB_MENTION" "\"OFF\"" "# Heartbeat tagging toggle"
        add_if_missing "EXT_IP" "\"1.1.1.1\"" "# Internet check IP"
        add_if_missing "EXT_INTERVAL" "60" "# Internet check frequency"
        add_if_missing "DEVICE_MONITOR" "\"ON\"" "# Local monitoring toggle"

        echo -e "${GREEN}✅ Configuration patch complete.${NC}"
        KEEP_CONFIG=1
    else
        echo -e "${RED}🧹 Performing clean install...${NC}"
        /etc/init.d/netwatchda stop 2>/dev/null
        rm -rf "$INSTALL_DIR"
    fi
fi

mkdir -p "$INSTALL_DIR"

# --- 3. CLEAN INSTALL INPUTS ---
if [ "$KEEP_CONFIG" -eq 0 ]; then
    echo -e "\n${BLUE}--- Configuration ---${NC}"
    printf "${BOLD}🔗 Enter Discord Webhook URL: ${NC}"
    read user_webhook </dev/tty
    printf "${BOLD}👤 Enter Discord User ID (for @mentions): ${NC}"
    read user_id </dev/tty
    printf "${BOLD}🏷️  Enter Router Name (e.g., Panoc_WRT): ${NC}"
    read router_name_input </dev/tty
    
    NOW_HUMAN=$(date '+%b %d, %Y %H:%M:%S')

    echo -e "\n${CYAN}🧪 Sending initial test notification...${NC}"
    curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"📟 Router Setup\", \"description\": \"Basic connectivity test successful for **$router_name_input**! <@$user_id>\", \"color\": 3447003}]}" "$user_webhook" > /dev/null
    
    printf "${BOLD}❓ Received basic notification on Discord? [y/n]: ${NC}"
    read confirm_test </dev/tty
    [ "$confirm_test" != "y" ] && [ "$confirm_test" != "Y" ] && echo -e "${RED}❌ Aborted.${NC}" && exit 1

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
    echo "2. Device Connectivity only: Pings local network"
    echo "3. Internet Connectivity only: Pings external IP"
    printf "${BOLD}Enter choice [1-3]: ${NC}"
    read mode_choice </dev/tty

    case "$mode_choice" in
        2) EXT_VAL="";        DEV_VAL="ON"  ;;
        3) EXT_VAL="1.1.1.1"; DEV_VAL="OFF" ;;
        *) EXT_VAL="1.1.1.1"; DEV_VAL="ON"  ;;
    esac

    cat <<EOF > "$CONFIG_FILE"
# Router Identification
ROUTER_NAME="$router_name_input" # Name that appears in Discord notifications.

# Discord Settings
DISCORD_URL="$user_webhook" # Your Discord Webhook URL.
MY_ID="$user_id" # Your Discord User ID (for @mentions).

# Monitoring Settings
SCAN_INTERVAL=10 # Seconds between pings. Default is 10.
FAIL_THRESHOLD=3 # Number of failed pings before sending an alert. Default is 3.
MAX_SIZE=$DEFAULT_MAX_LOG # Max log file size in bytes for the log rotation.

# Heartbeat Settings
HEARTBEAT="$HB_VAL" # Set to ON to receive a periodic check-in message.
HB_INTERVAL=$HB_SEC # Interval in seconds. Default is 86400
HB_MENTION="$HB_MENTION" # Set to ON to include @mention in heartbeats.

# Internet Connectivity Check
EXT_IP="$EXT_VAL" # External IP to ping. Leave empty to disable.
EXT_INTERVAL=60 # Seconds between internet checks. Default is 60.

# Local Device Monitoring
DEVICE_MONITOR="$DEV_VAL" # Set to ON to enable local IP monitoring.
EOF

    cat <<EOF > "$IP_LIST_FILE"
# Format: IP_ADDRESS # NAME
# Example: 192.168.1.50 # Home Server
EOF
    
    LOCAL_IP=$(uci -q get network.lan.ipaddr || ip addr show br-lan | grep -oE 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 | awk '{print $2}')
    [ -n "$LOCAL_IP" ] && echo "$LOCAL_IP # Router Gateway" >> "$IP_LIST_FILE"
fi

# --- 4. CREATE INITIAL HUMAN-READABLE LOG ---
NOW_LOG=$(date '+%b %d, %Y %H:%M:%S')
echo "$NOW_LOG - [SYSTEM] netwatchda installation successful. RAM Guard set log limit to $DEFAULT_MAX_LOG bytes." > "$LOGFILE"

# --- 5. CORE SCRIPT GENERATION ---
echo -e "\n${CYAN}🛠️  Generating core script...${NC}"
cat <<'EOF' > "$INSTALL_DIR/netwatchda.sh"
#!/bin/sh
# netwatchda - Network Monitoring for OpenWrt
# Copyright (C) 2025 panoc
# Licensed under the GNU General Public License v3.0

BASE_DIR=$(cd "$(dirname "$0")" && pwd)
IP_LIST_FILE="$BASE_DIR/netwatchda_ips.conf"
CONFIG_FILE="$BASE_DIR/netwatchda_settings.conf"
LOGFILE="/tmp/netwatchda_log.txt"
LAST_EXT_CHECK=0
LAST_HB_CHECK=$(date +%s)

# Initialize Log File
NOW_HUMAN=$(date '+%b %d, %Y %H:%M:%S')
echo "$NOW_HUMAN - [SYSTEM] netwatchda service started." >> "$LOGFILE"

while true; do
    [ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"
    
    NOW_HUMAN=$(date '+%b %d, %Y %H:%M:%S')
    NOW_SEC=$(date +%s)

    # Log Rotation Check
    if [ -f "$LOGFILE" ] && [ $(wc -c < "$LOGFILE") -gt "$MAX_SIZE" ]; then
        echo "$NOW_HUMAN - [SYSTEM] Log rotated." > "$LOGFILE"
    fi

    PREFIX="📟 **Router:** $ROUTER_NAME\n"
    MENTION="\n🔔 **Attention:** <@$MY_ID>"
    IS_INT_DOWN=0

    # Heartbeat Logic
    if [ "$HEARTBEAT" = "ON" ] && [ $((NOW_SEC - LAST_HB_CHECK)) -ge "$HB_INTERVAL" ]; then
        LAST_HB_CHECK=$NOW_SEC
        HB_MSG="$NOW_HUMAN | $ROUTER_NAME | Router Online"
        DESC="💓 **Heartbeat**: $HB_MSG"
        [ "$HB_MENTION" = "ON" ] && DESC="$DESC$MENTION"
        curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"description\": \"$DESC\", \"color\": 15844367}]}" "$DISCORD_URL" > /dev/null 2>&1
    fi

    # Internet Check Logic
    if [ -n "$EXT_IP" ] && [ $((NOW_SEC - LAST_EXT_CHECK)) -ge "$EXT_INTERVAL" ]; then
        LAST_EXT_CHECK=$NOW_SEC
        FD="/tmp/nwda_ext_d"; FT="/tmp/nwda_ext_t"
        if ! ping -q -c 1 -W 2 "$EXT_IP" > /dev/null 2>&1; then
            if [ ! -f "$FD" ]; then
                echo "$NOW_SEC" > "$FD"; echo "$NOW_HUMAN" > "$FT"
                echo "$NOW_HUMAN - [ALERT] INTERNET DOWN" >> "$LOGFILE"
            fi
        else
            if [ -f "$FD" ]; then
                S=$(cat "$FD"); T=$(cat "$FT"); D=$((NOW_SEC-S)); DR="$(($D/60))m $(($D%60))s"
                echo "$NOW_HUMAN - [SUCCESS] INTERNET UP (Down for $DR)" >> "$LOGFILE"
                curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🌐 Internet Restored\", \"description\": \"$PREFIX❌ **Lost:** $T\n✅ **Restored:** $NOW_HUMAN\n**Outage:** $DR$MENTION\", \"color\": 1752220}]}" "$DISCORD_URL" > /dev/null 2>&1
                rm -f "$FD" "$FT"
            fi
        fi
    fi
    [ -f "/tmp/nwda_ext_d" ] && IS_INT_DOWN=1

    # Local Device Check Logic
    if [ "$DEVICE_MONITOR" = "ON" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in ""|\#*) continue ;; esac
            TIP=$(echo "$line" | cut -d'#' -f1 | xargs); NAME=$(echo "$line" | cut -s -d'#' -f2- | xargs)
            [ -z "$NAME" ] && NAME="Unknown"
            SIP=$(echo "$TIP" | tr '.' '_'); FC="/tmp/nwda_c_$SIP"; FD="/tmp/nwda_d_$SIP"; FT="/tmp/nwda_t_$SIP"
            if ping -q -c 1 -W 2 "$TIP" > /dev/null 2>&1; then
                if [ -f "$FD" ]; then
                    S=$(cat "$FD"); T=$(cat "$FT"); D=$((NOW_SEC-S)); DR="$(($D/60))m $(($D%60))s"
                    echo "$NOW_HUMAN - [SUCCESS] DEVICE UP: $NAME ($TIP) - Down for $DR" >> "$LOGFILE"
                    [ "$IS_INT_DOWN" -eq 0 ] && curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"✅ Device ONLINE\", \"description\": \"$PREFIX**$NAME** is back online.\n❌ **Lost:** $T\n✅ **Restored:** $NOW_HUMAN\n**Down for:** $DR$MENTION\", \"color\": 3066993}]}" "$DISCORD_URL" > /dev/null 2>&1
                    rm -f "$FD" "$FT"
                fi
                echo 0 > "$FC"
            else
                C=$(($(cat "$FC" 2>/dev/null || echo 0)+1)); echo "$C" > "$FC"
                if [ "$C" -eq "$FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                    echo "$NOW_SEC" > "$FD"; echo "$NOW_HUMAN" > "$FT"
                    echo "$NOW_HUMAN - [ALERT] DEVICE DOWN: $NAME ($TIP)" >> "$LOGFILE"
                    [ "$IS_INT_DOWN" -eq 0 ] && curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🔴 Device DOWN!\", \"description\": \"$PREFIX**$NAME** ($TIP) is unreachable.\n**Time:** $NOW_HUMAN$MENTION\", \"color\": 15158332}]}" "$DISCORD_URL" > /dev/null 2>&1
                fi
            fi
        done < "$IP_LIST_FILE"
    fi

    sleep "$SCAN_INTERVAL"
done
EOF

# --- 6. ENHANCED SERVICE SETUP ---
chmod +x "$INSTALL_DIR/netwatchda.sh"
cat <<EOF > "$SERVICE_PATH"
#!/bin/sh /etc/rc.common
# netwatchda service control
START=99
USE_PROCD=1

extra_command "status" "Check if monitor is running"
extra_command "logs" "View last 20 log entries"
extra_command "discord" "Test discord notification"

start_service() {
    procd_open_instance
    procd_set_param command /bin/sh "$INSTALL_DIR/netwatchda.sh"
    procd_set_param respawn
    procd_close_instance
}

status() {
    if pgrep -f "netwatchda.sh" > /dev/null; then
        echo "netwatchda is RUNNING."
    else
        echo "netwatchda is STOPPED."
    fi
}

logs() {
    if [ -f "/tmp/netwatchda_log.txt" ]; then
        tail -n 20 /tmp/netwatchda_log.txt
    else
        echo "No log file found."
    fi
}

discord() {
    if [ -f "$CONFIG_FILE" ]; then
        . "$CONFIG_FILE"
        NOW=\$(date '+%b %d, %Y %H:%M:%S')
        curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🛠️ Discord Test Notification\", \"description\": \"**Router:** \$ROUTER_NAME\n**Time:** \$NOW\nManual test triggered from CLI.\", \"color\": 3447003}]}" "\$DISCORD_URL"
        echo "Test message sent to Discord."
    else
        echo "Config file not found. Cannot send test."
    fi
}
EOF
chmod +x "$SERVICE_PATH"
"$SERVICE_PATH" enable
"$SERVICE_PATH" restart
echo -e "${GREEN}✅ Service configured and started.${NC}"

# --- 7. SUCCESS NOTIFICATION ---
. "$CONFIG_FILE"
NOW_FINAL=$(date '+%b %d, %Y %H:%M:%S')
curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🚀 netwatchda Service Started\", \"description\": \"**Router:** $ROUTER_NAME\n**Time:** $NOW_FINAL\nMonitoring is active.\", \"color\": 3447003}]}" "$DISCORD_URL" > /dev/null

# --- FINAL OUTPUT ---
echo ""
echo -e "${GREEN}=======================================================${NC}"
echo -e "${BOLD}${GREEN}✅ Installation complete! Script file deleted.${NC}"
echo -e "${CYAN}📂 Folder:${NC} $INSTALL_DIR"
echo -e "${GREEN}=======================================================${NC}"
echo -e "\n${BOLD}Next Steps:${NC}"
echo -e "${BOLD}1.${NC} Edit Settings: ${CYAN}$CONFIG_FILE${NC}"
echo -e "${BOLD}2.${NC} Edit IP List:  ${CYAN}$IP_LIST_FILE${NC}"
echo -e "${BOLD}3.${NC} Service Help:  ${BOLD}/etc/init.d/netwatchda help${NC}"
echo -e "${BOLD}4.${NC} View Logs:      ${BOLD}/etc/init.d/netwatchda logs${NC}"
echo ""
echo -e "Monitoring logs: ${BOLD}tail -f /tmp/netwatchda_log.txt${NC}"
echo -e "${BLUE}-------------------------------------------------------${NC}\n"