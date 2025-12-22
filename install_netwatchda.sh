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
DEFAULT_MAX_LOG=512000 # Default 512KB for log size

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

        add_if_missing "ROUTER_NAME" "\"My_OpenWrt_Router\"" "# Name that appears in Discord notifications."
        add_if_missing "DISCORD_URL" "\"\"" "# Your Discord Webhook URL."
        add_if_missing "MY_ID" "\"\"" "# Your Discord User ID (for @mentions)."
        add_if_missing "MAX_SIZE" "$DEFAULT_MAX_LOG" "# Max log file size in bytes for the log rotation."
        add_if_missing "HEARTBEAT" "\"OFF\"" "# Set to ON to receive a periodic check-in message."
        add_if_missing "HB_INTERVAL" "86400" "# Interval in seconds. Default is 86400"
        add_if_missing "HB_MENTION" "\"OFF\"" "# Set to ON to include @mention in heartbeats."
        add_if_missing "EXT_PING_COUNT" "4" "# Number of pings per internet check interval. Default 4."
        add_if_missing "EXT_SCAN_INTERVAL" "60" "# Seconds between internet checks. Default is 60."
        add_if_missing "EXT_FAIL_THRESHOLD" "1" "# Failed cycles before alert. Default 1."
        add_if_missing "EXT_IP" "\"1.1.1.1\"" "# External IP to ping. Leave empty to disable."
        add_if_missing "DEVICE_MONITOR" "\"ON\"" "# Set to ON to enable local IP monitoring."
        add_if_missing "DEV_PING_COUNT" "4" "# Number of pings per device check interval. Default 4."
        add_if_missing "DEV_SCAN_INTERVAL" "10" "# Seconds between device pings. Default is 10."
        add_if_missing "DEV_FAIL_THRESHOLD" "3" "# Failed cycles before alert. Default 3."
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

# --- 3. CLEAN INSTALL INPUTS ---
if [ "$KEEP_CONFIG" -eq 0 ]; then
    echo -e "\n${BLUE}--- Configuration ---${NC}"
    printf "${BOLD}🔗 Enter Discord Webhook URL: ${NC}"
    read user_webhook </dev/tty
    printf "${BOLD}👤 Enter Discord User ID (for @mentions): ${NC}"
    read user_id </dev/tty
    printf "${BOLD}🏷️  Enter Router Name (e.g., MyRouter): ${NC}"
    read router_name_input </dev/tty

    echo -e "\n${BLUE}--- Silent Hours (No Discord Alerts) ---${NC}"
    printf "${BOLD}🌙 Enable Silent Hours? [y/n]: ${NC}"
    read enable_silent_choice </dev/tty
    
    if [ "$enable_silent_choice" = "y" ] || [ "$enable_silent_choice" = "Y" ]; then
        SILENT_VAL="ON"
        while :; do
            printf "${BOLD}   > Start Hour (0-23, e.g., 23 for 11PM): ${NC}"
            read user_silent_start </dev/tty
            if echo "$user_silent_start" | grep -qE '^[0-9]+$' && [ "$user_silent_start" -ge 0 ] && [ "$user_silent_start" -le 23 ] 2>/dev/null; then
                break
            else
                echo -e "${RED}   ❌ Invalid hour (0-23).${NC}"
            fi
        done
        while :; do
            printf "${BOLD}   > End Hour (0-23, e.g., 07 for 7AM): ${NC}"
            read user_silent_end </dev/tty
            if echo "$user_silent_end" | grep -qE '^[0-9]+$' && [ "$user_silent_end" -ge 0 ] && [ "$user_silent_end" -le 23 ] 2>/dev/null; then
                break
            else
                echo -e "${RED}   ❌ Invalid hour (0-23).${NC}"
            fi
        done
    else
        SILENT_VAL="OFF"; user_silent_start="23"; user_silent_end="07"
    fi
    
    # --- TEST NOTIFICATION ---
    echo -e "\n${CYAN}🧪 Sending initial test notification...${NC}"
    curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"📟 Router Setup\", \"description\": \"Basic connectivity test successful for **$router_name_input**! <@$user_id>\", \"color\": 3447003}]}" "$user_webhook" > /dev/null
    
    printf "${BOLD}❓ Received basic notification on Discord? [y/n]: ${NC}"
    read confirm_test </dev/tty
    if [ "$confirm_test" != "y" ] && [ "$confirm_test" != "Y" ]; then
        echo -e "${RED}❌ Aborted. Check your Webhook URL.${NC}"
        exit 1
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
    echo "2. Device Connectivity only: Pings local network"
    echo "3. Internet Connectivity only: Pings external IP"
    printf "${BOLD}Enter choice [1-3]: ${NC}"
    read mode_choice </dev/tty

    case "$mode_choice" in
        2) EXT_VAL="";        DEV_VAL="ON"  ;;
        3) EXT_VAL="1.1.1.1"; DEV_VAL="OFF" ;;
        *) EXT_VAL="1.1.1.1"; DEV_VAL="ON"  ;;
    esac

# --- BASE CODE (DO NOT CHANGE) ---
DEV_COUNT=4 # Number of pings to send to devices
EXT_COUNT=4 # Number of pings to send to external sites
# --- END BASE CODE ---

    cat <<EOF > "$CONFIG_FILE"
[Router Identification]
ROUTER_NAME="$router_name_input" # Name that appears in Discord notifications.

[Discord Settings]
DISCORD_URL="$user_webhook" # Your Discord Webhook URL.
MY_ID="$user_id" # Your Discord User ID (for @mentions).
SILENT_ENABLE="$SILENT_VAL" # Set to ON to enable silent hours mode.
SILENT_START=$user_silent_start # Hour to start silent mode (0-23).
SILENT_END=$user_silent_end # Hour to end silent mode (0-23).

[Monitoring Settings]
MAX_SIZE=$DEFAULT_MAX_LOG # Max log file size in bytes for the log rotation.

[Heartbeat Settings]
HEARTBEAT="$HB_VAL" # Set to ON to receive a periodic check-in message.
HB_INTERVAL=$HB_SEC # Interval in seconds. Default is 86400
HB_MENTION="$HB_MENTION" # Set to ON to include @mention in heartbeats.

[Internet Connectivity]
EXT_IP="$EXT_VAL" # External IP to ping. Leave empty to disable.
EXT_SCAN_INTERVAL=60 # Seconds between internet checks. Default is 60.
EXT_FAIL_THRESHOLD=1 # Number of failed checks before alert. Default 1.
EXT_PING_COUNT=$EXT_COUNT # Number of pings per check. Default 4.

[Local Device Monitoring]
DEVICE_MONITOR="$DEV_VAL" # Set to ON to enable local IP monitoring.
DEV_SCAN_INTERVAL=10 # Seconds between device pings. Default is 10.
DEV_FAIL_THRESHOLD=3 # Number of failed pings before alert. Default 3.
DEV_PING_COUNT=$DEV_COUNT # Number of pings per check. Default 4.
EOF

    cat <<EOF > "$IP_LIST_FILE"
# Format: IP_ADDRESS # NAME
# Example: 192.168.1.50 # Home Server
EOF
    
    LOCAL_IP=$(uci -q get network.lan.ipaddr || ip addr show br-lan | grep -oE 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 | awk '{print $2}')
    [ -n "$LOCAL_IP" ] && echo "$LOCAL_IP # Router Gateway" >> "$IP_LIST_FILE"
fi

# --- 4. CREATE INITIAL LOG ---
NOW_LOG=$(date '+%b %d, %Y %H:%M:%S')
echo "$NOW_LOG - [SYSTEM] netwatchda installation successful." > "$LOGFILE"

# --- 5. CORE SCRIPT GENERATION ---
echo -e "\n${CYAN}🛠️  Generating core script...${NC}"
cat <<'EOF' > "$INSTALL_DIR/netwatchda.sh"
#!/bin/sh
# netwatchda - Network Monitoring for OpenWrt
# Copyright (C) 2025 panoc

BASE_DIR=$(cd "$(dirname "$0")" && pwd)
IP_LIST_FILE="$BASE_DIR/netwatchda_ips.conf"
CONFIG_FILE="$BASE_DIR/netwatchda_settings.conf"
LOGFILE="/tmp/netwatchda_log.txt"
SILENT_BUFFER="/tmp/nwda_silent_buffer"
LAST_EXT_CHECK=0
LAST_DEV_CHECK=0
LAST_HB_CHECK=$(date +%s)
touch "$SILENT_BUFFER"

# Load config helper safely (strips INI headers)
load_config() {
    [ -f "$CONFIG_FILE" ] && eval "$(sed '/^\[.*\]/d' "$CONFIG_FILE")"
}

while true; do
    load_config
    
    NOW_HUMAN=$(date '+%b %d, %Y %H:%M:%S')
    NOW_SEC=$(date +%s)
    CUR_HOUR=$(date +%H)

    # Silent Mode Logic
    IS_SILENT=0
    if [ "$SILENT_ENABLE" = "ON" ]; then
        if [ "$SILENT_START" -le "$SILENT_END" ]; then
            if [ "$CUR_HOUR" -ge "$SILENT_START" ] && [ "$CUR_HOUR" -lt "$SILENT_END" ]; then IS_SILENT=1; fi
        else
            if [ "$CUR_HOUR" -ge "$SILENT_START" ] || [ "$CUR_HOUR" -lt "$SILENT_END" ]; then IS_SILENT=1; fi
        fi
    fi

    # Trigger Summary after silent hours end
    if [ "$IS_SILENT" -eq 0 ] && [ -s "$SILENT_BUFFER" ]; then
        SUMMARY_CONTENT=$(cat "$SILENT_BUFFER")
        curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🌙 Silent Hours Summary\", \"description\": \"**Router:** $ROUTER_NAME\nThe following events occurred while alerts were muted:\n\n$SUMMARY_CONTENT\", \"color\": 3447003}]}" "$DISCORD_URL" > /dev/null 2>&1
        > "$SILENT_BUFFER"
    fi

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
        if [ "$IS_SILENT" -eq 0 ]; then
            curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"description\": \"$DESC\", \"color\": 15844367}]}" "$DISCORD_URL" > /dev/null 2>&1
        else
            echo "💓 Heartbeat at $NOW_HUMAN" >> "$SILENT_BUFFER"
        fi
    fi

    # Internet Check Logic
    if [ -n "$EXT_IP" ] && [ $((NOW_SEC - LAST_EXT_CHECK)) -ge "$EXT_SCAN_INTERVAL" ]; then
        LAST_EXT_CHECK=$NOW_SEC
        FD="/tmp/nwda_ext_d"; FT="/tmp/nwda_ext_t"; FC="/tmp/nwda_ext_c"
        if ! ping -q -c "$EXT_PING_COUNT" -W 2 "$EXT_IP" > /dev/null 2>&1; then
            C=$(($(cat "$FC" 2>/dev/null || echo 0)+1)); echo "$C" > "$FC"
            if [ "$C" -ge "$EXT_FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                echo "$NOW_SEC" > "$FD"; echo "$NOW_HUMAN" > "$FT"
                echo "$NOW_HUMAN - [ALERT] INTERNET DOWN" >> "$LOGFILE"
                if [ "$IS_SILENT" -eq 1 ]; then
                   echo "🌐 Internet Outage Started: $NOW_HUMAN" >> "$SILENT_BUFFER"
                fi
            fi
        else
            if [ -f "$FD" ]; then
                S=$(cat "$FD"); T=$(cat "$FT"); D=$((NOW_SEC-S)); DR="$(($D/60))m $(($D%60))s"
                echo "$NOW_HUMAN - [SUCCESS] INTERNET UP (Down for $DR)" >> "$LOGFILE"
                if [ "$IS_SILENT" -eq 0 ]; then
                    curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🌐 Internet Restored\", \"description\": \"$PREFIX❌ **Lost:** $T\n✅ **Restored:** $NOW_HUMAN\n**Outage:** $DR$MENTION\", \"color\": 1752220}]}" "$DISCORD_URL" > /dev/null 2>&1
                else
                    echo "🌐 Internet Restored: $NOW_HUMAN (Down for $DR)" >> "$SILENT_BUFFER"
                fi
                rm -f "$FD" "$FT"
            fi
            echo 0 > "$FC"
        fi
    fi
    [ -f "/tmp/nwda_ext_d" ] && IS_INT_DOWN=1

    # Local Device Check Logic
    if [ "$DEVICE_MONITOR" = "ON" ] && [ $((NOW_SEC - LAST_DEV_CHECK)) -ge "$DEV_SCAN_INTERVAL" ]; then
        LAST_DEV_CHECK=$NOW_SEC
        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in ""|\#*) continue ;; esac
            TIP=$(echo "$line" | cut -d'#' -f1 | xargs); NAME=$(echo "$line" | cut -s -d'#' -f2- | xargs)
            [ -z "$NAME" ] && NAME="Unknown"
            SIP=$(echo "$TIP" | tr '.' '_'); FC="/tmp/nwda_c_$SIP"; FD="/tmp/nwda_d_$SIP"; FT="/tmp/nwda_t_$SIP"
            if ping -q -c "$DEV_PING_COUNT" -W 2 "$TIP" > /dev/null 2>&1; then
                if [ -f "$FD" ]; then
                    S=$(cat "$FD"); T=$(cat "$FT"); D=$((NOW_SEC-S)); DR="$(($D/60))m $(($D%60))s"
                    echo "$NOW_HUMAN - [SUCCESS] DEVICE UP: $NAME ($TIP) - Down for $DR" >> "$LOGFILE"
                    if [ "$IS_INT_DOWN" -eq 0 ]; then
                        if [ "$IS_SILENT" -eq 0 ]; then
                            curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"✅ Device ONLINE\", \"description\": \"$PREFIX**$NAME** back online.\n❌ **Lost:** $T\n✅ **Restored:** $NOW_HUMAN\n**Down for:** $DR$MENTION\", \"color\": 3066993}]}" "$DISCORD_URL" > /dev/null 2>&1
                        else
                            echo "✅ $NAME Online: Down for $DR (ended $NOW_HUMAN)" >> "$SILENT_BUFFER"
                        fi
                    fi
                    rm -f "$FD" "$FT"
                fi
                echo 0 > "$FC"
            else
                C=$(($(cat "$FC" 2>/dev/null || echo 0)+1)); echo "$C" > "$FC"
                if [ "$C" -ge "$DEV_FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                    echo "$NOW_SEC" > "$FD"; echo "$NOW_HUMAN" > "$FT"
                    echo "$NOW_HUMAN - [ALERT] DEVICE DOWN: $NAME ($TIP)" >> "$LOGFILE"
                    if [ "$IS_INT_DOWN" -eq 0 ]; then
                        if [ "$IS_SILENT" -eq 0 ]; then
                            curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🔴 Device DOWN!\", \"description\": \"$PREFIX**$NAME** ($TIP) unreachable.\n**Time:** $NOW_HUMAN$MENTION\", \"color\": 15158332}]}" "$DISCORD_URL" > /dev/null 2>&1
                        else
                            echo "🔴 $NAME Offline at $NOW_HUMAN" >> "$SILENT_BUFFER"
                        fi
                    fi
                fi
            fi
        done < "$IP_LIST_FILE"
    fi
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
extra_command "clear" "Clear the log file"
extra_command "discord" "Test discord notification"

start_service() {
    procd_open_instance
    procd_set_param command /bin/sh "$INSTALL_DIR/netwatchda.sh"
    procd_set_param respawn
    procd_close_instance
}

status() {
    pgrep -f "netwatchda.sh" > /dev/null && echo "netwatchda is RUNNING." || echo "netwatchda is STOPPED."
}

logs() {
    [ -f "/tmp/netwatchda_log.txt" ] && tail -n 20 /tmp/netwatchda_log.txt || echo "No log found."
}

clear() {
    echo "\$(date '+%b %d, %Y %H:%M:%S') - [SYSTEM] Log cleared." > "/tmp/netwatchda_log.txt"
    echo "Log file cleared."
}

discord() {
    if [ -f "$CONFIG_FILE" ]; then
        eval "\$(sed '/^\[.*\]/d' "$CONFIG_FILE")"
        curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🛠️ Discord Test Notification\", \"description\": \"**Router:** \$ROUTER_NAME\nManual test triggered from CLI.\", \"color\": 3447003}]}" "\$DISCORD_URL"
        echo "Test message sent."
    fi
}
EOF

chmod +x "$SERVICE_PATH"
"$SERVICE_PATH" enable
"$SERVICE_PATH" restart

# --- 7. SUCCESS NOTIFICATION ---
eval "$(sed '/^\[.*\]/d' "$CONFIG_FILE")"
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
echo -e "${BOLD}3.${NC} View Logs:      ${BOLD}/etc/init.d/netwatchda logs${NC}"
echo ""