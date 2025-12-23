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
WHITE_BOLD='\033[1;37m'
RED='\033[1;31m'    # Light Red
GREEN='\033[1;32m'  # Light Green
BLUE='\033[1;34m'   # Light Blue
CYAN='\033[1;36m'   # Light Cyan
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

# --- DIRECTORY & FILE DEFINITIONS ---
INSTALL_DIR="/root/netwatchda"
CONFIG_FILE="$INSTALL_DIR/nwda_settings.conf"
IP_LIST_FILE="$INSTALL_DIR/nwda_ips.conf"
VAULT_FILE="$INSTALL_DIR/.vault.enc"
SERVICE_PATH="/etc/init.d/netwatchda"
LOG_DIR="/tmp/netwatchda"
UPTIME_LOG="$LOG_DIR/nwda_uptime.log"
PING_LOG="$LOG_DIR/nwda_ping.log"

# --- 1. HARDWARE KEY GENERATION (SECURITY LAYER) ---
# Generates a unique key based on CPU and MAC to lock the vault to this specific device.
get_hw_key() {
    local cpu_serial=$(grep -i "serial" /proc/cpuinfo | awk '{print $3}' | tr -d ' ')
    local mac_addr=$(cat /sys/class/net/eth0/address 2>/dev/null | tr -d ':')
    [ -z "$cpu_serial" ] && cpu_serial="NWDA_STATIC_SALT_2025"
    echo "${cpu_serial}${mac_addr}" | sha256sum | awk '{print $1}'
}

# --- 2. CHECK DEPENDENCIES & STORAGE ---
echo -e "\n${BOLD}📦 Checking system readiness...${NC}"

# Flash Storage Check
FREE_FLASH_KB=$(df / | awk 'NR==2 {print $4}')
MIN_FLASH_KB=5120 # 5MB Threshold for new dependencies

# RAM Check
FREE_RAM_KB=$(df /tmp | awk 'NR==2 {print $4}')
MIN_RAM_KB=8192 # 8MB Threshold for OpenSSL operations

# Dependency Installation Logic
install_dep() {
    local pkg=$1
    if ! command -v "$pkg" >/dev/null 2>&1 && [ "$pkg" != "openssl-util" ]; then
        NEED_UPDATE=1
    elif [ "$pkg" = "openssl-util" ] && ! command -v openssl >/dev/null 2>&1; then
        NEED_UPDATE=1
    fi
}

NEED_UPDATE=0
install_dep "curl"
install_dep "openssl-util"
install_dep "ca-bundle"

if [ "$NEED_UPDATE" -eq 1 ]; then
    echo -e "${CYAN}🔍 Required dependencies missing. Checking storage...${NC}"
    if [ "$FREE_FLASH_KB" -lt "$MIN_FLASH_KB" ]; then
        echo -e "${RED}❌ ERROR: Insufficient Flash storage!${NC}"
        echo -e "${YELLOW}Available: $((FREE_FLASH_KB / 1024))MB | Required: 5MB${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}📥 Installing dependencies...${NC}"
    # Silent download with progress bar as requested
    opkg update > /dev/null
    opkg install curl openssl-util ca-bundle | awk '{printf "\r\033[1;32mUpgrading: \033[0m[" ; for(i=0; i<=NR%10; i++) printf "#"; printf ">] %d", NR}'
    echo ""
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Error: Failed to install dependencies. Check internet connection.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ All dependencies (curl, openssl, ca-bundle) are present.${NC}"
fi

if [ "$FREE_FLASH_KB" -gt "$MIN_FLASH_KB" ]; then
    echo -e "${GREEN}✅ Flash storage check passed: $((FREE_FLASH_KB / 1024))MB available.${NC}"
fi

if [ "$FREE_RAM_KB" -lt "$MIN_RAM_KB" ]; then
    echo -e "${YELLOW}⚠️  Low RAM detected ($((FREE_RAM_KB / 1024))MB). High-security decryption might be slow.${NC}"
else
    echo -e "${GREEN}✅ Sufficient RAM for standard logging ($((FREE_RAM_KB / 1024))MB available).${NC}"
fi

mkdir -p "$INSTALL_DIR"
mkdir -p "$LOG_DIR"

# --- 3. NOTIFICATION PREFERENCES ---
echo -e "\n${BLUE}--- Notification Preferences ---${NC}"
echo -e "1. ${WHITE_BOLD}Enable Discord Notifications${NC}"
echo -e "2. ${WHITE_BOLD}Enable Telegram Notifications${NC}"
echo -e "3. ${WHITE_BOLD}Enable Both${NC}"
echo -e "4. ${WHITE_BOLD}None (Track events via logs only)${NC}"

while :; do
    printf "${BOLD}Enter choice [1-4]: ${NC}"
    read notify_choice </dev/tty
    case "$notify_choice" in
        1) DISCORD_VAL="YES"; TELEGRAM_VAL="NO"; break ;;
        2) DISCORD_VAL="NO"; TELEGRAM_VAL="YES"; break ;;
        3) DISCORD_VAL="YES"; TELEGRAM_VAL="YES"; break ;;
        4) DISCORD_VAL="NO"; TELEGRAM_VAL="NO"; 
           echo -e "${YELLOW}ℹ️  Events will only be tracked in $UPTIME_LOG${NC}"; break ;;
        *) echo -e "${RED}❌ Invalid choice. Please enter 1, 2, 3, or 4.${NC}" ;;
    esac
done
# --- 4. CREDENTIAL COLLECTION & ENCRYPTION ---
USER_HW_KEY=$(get_hw_key)

# Initialize blank variables
DISCORD_WEBHOOK=""
DISCORD_USER_ID=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# --- DISCORD INPUTS ---
if [ "$DISCORD_VAL" = "YES" ]; then
    echo -e "\n${BLUE}--- Discord Configuration ---${NC}"
    printf "${WHITE_BOLD}🔗 Enter Discord Webhook URL: ${NC}"
    read DISCORD_WEBHOOK </dev/tty
    printf "${WHITE_BOLD}👤 Enter Discord User ID (for @mentions): ${NC}"
    read DISCORD_USER_ID </dev/tty
    
    # --- TEST DISCORD ---
    echo -e "\n${CYAN}🧪 Sending initial Discord test notification...${NC}"
    curl -s -H "Content-Type: application/json" -X POST \
    -d "{\"embeds\": [{\"title\": \"📟 Router Setup\", \"description\": \"Basic connectivity test successful!\", \"color\": 1752220}]}" \
    "$DISCORD_WEBHOOK" > /dev/null
    
    printf "${BOLD}❓ Received notification on Discord? [y/n]: ${NC}"
    read confirm_discord </dev/tty
    if [ "$confirm_discord" != "y" ] && [ "$confirm_discord" != "Y" ]; then
        echo -e "${RED}❌ Aborted. Please check your Discord Webhook URL.${NC}"
        exit 1
    fi
fi

# --- TELEGRAM INPUTS ---
if [ "$TELEGRAM_VAL" = "YES" ]; then
    echo -e "\n${BLUE}--- Telegram Configuration ---${NC}"
    printf "${WHITE_BOLD}🤖 Enter Telegram Bot Token: ${NC}"
    read TELEGRAM_BOT_TOKEN </dev/tty
    printf "${WHITE_BOLD}🆔 Enter Telegram Chat ID: ${NC}"
    read TELEGRAM_CHAT_ID </dev/tty
    
    # --- TEST TELEGRAM ---
    echo -e "\n${CYAN}🧪 Sending initial Telegram test notification...${NC}"
    NOW_TEST=$(date '+%b %d %H:%M:%S')
    TEST_MSG="🚀 *netwatchda Setup* - Basic connectivity test successful! - $NOW_TEST"
    
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -d "chat_id=$TELEGRAM_CHAT_ID" -d "text=$TEST_MSG" -d "parse_mode=Markdown" > /dev/null
    
    printf "${BOLD}❓ Received notification on Telegram? [y/n]: ${NC}"
    read confirm_tele </dev/tty
    if [ "$confirm_tele" != "y" ] && [ "$confirm_tele" != "Y" ]; then
        echo -e "${RED}❌ Aborted. Please check your Telegram credentials.${NC}"
        exit 1
    fi
fi

# --- VAULT CREATION (The Hardened Layer) ---
# We store the tokens in a single string, then encrypt it using PBKDF2
echo -e "\n${CYAN}🔒 Securing credentials in encrypted vault...${NC}"
RAW_CREDENTIALS="DISCORD_URL='$DISCORD_WEBHOOK'
MY_ID='$DISCORD_USER_ID'
TELE_TOKEN='$TELEGRAM_BOT_TOKEN'
TELE_CHAT='$TELEGRAM_CHAT_ID'"

echo "$RAW_CREDENTIALS" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 10000 -out "$VAULT_FILE" -pass "pass:$USER_HW_KEY" 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Vault created and locked to this hardware.${NC}"
else
    echo -e "${RED}❌ ERROR: Failed to create encrypted vault.${NC}"
    exit 1
fi

# --- 5. SYSTEM SETTINGS ---
echo -e "\n${BLUE}--- General Settings ---${NC}"
printf "${WHITE_BOLD}🏷️  Enter Router Name (e.g., MyRouter): ${NC}"
read router_name_input </dev/tty

# Silent Hours Logic
echo -e "\n${BLUE}--- Silent Hours (No Notifications) ---${NC}"
printf "${WHITE_BOLD}🌙 Enable Silent Hours? [y/n]: ${NC}"
read enable_silent_choice </dev/tty

if [ "$enable_silent_choice" = "y" ] || [ "$enable_silent_choice" = "Y" ]; then
    SILENT_VAL="YES"
    while :; do
        printf "${WHITE_BOLD}   > Start Hour (0-23): ${NC}"
        read user_silent_start </dev/tty
        if echo "$user_silent_start" | grep -qE '^[0-9]+$' && [ "$user_silent_start" -le 23 ]; then break;
        else echo -e "${RED}   ❌ Invalid hour.${NC}"; fi
    done
    while :; do
        printf "${WHITE_BOLD}   > End Hour (0-23): ${NC}"
        read user_silent_end </dev/tty
        if echo "$user_silent_end" | grep -qE '^[0-9]+$' && [ "$user_silent_end" -le 23 ]; then break;
        else echo -e "${RED}   ❌ Invalid hour.${NC}"; fi
    done
else
    SILENT_VAL="NO"; user_silent_start="23"; user_silent_end="07"
fi

# Heartbeat Logic
echo -e "\n${BLUE}--- Heartbeat Settings ---${NC}"
printf "${WHITE_BOLD}💓 Enable Heartbeat (System check-in)? [y/n]: ${NC}"
read hb_enabled </dev/tty
if [ "$hb_enabled" = "y" ] || [ "$hb_enabled" = "Y" ]; then
    HB_VAL="YES"
    printf "${WHITE_BOLD}⏰ Interval in HOURS (e.g., 24): ${NC}"
    read hb_hours </dev/tty
    HB_SEC=$((hb_hours * 3600))
    printf "${WHITE_BOLD}🔔 Mention in Heartbeat? [y/n]: ${NC}"
    read hb_m </dev/tty
    [ "$hb_m" = "y" ] || [ "$hb_m" = "Y" ] && HB_MENTION="YES" || HB_MENTION="NO"
else
    HB_VAL="NO"; HB_SEC="86400"; HB_MENTION="NO"
fi

# Monitoring Mode
echo -e "\n${BLUE}--- Monitoring Mode ---${NC}"
echo "1. Both: Full monitoring (Default)"
echo "2. Device Connectivity only: Pings local network"
echo "3. Internet Connectivity only: Pings external IP"
while :; do
    printf "${BOLD}Enter choice [1-3]: ${NC}"
    read mode_choice </dev/tty
    case "$mode_choice" in
        2) EXT_ENABLED="NO"; DEV_VAL="YES"; break ;;
        3) EXT_ENABLED="YES"; DEV_VAL="NO"; break ;;
        1|"") EXT_ENABLED="YES"; DEV_VAL="YES"; break ;;
        *) echo -e "${RED}❌ Invalid choice.${NC}" ;;
    esac
done
# --- 6. CONFIGURATION GENERATION ---
echo -e "\n${CYAN}⚙️  Generating configuration files...${NC}"

cat <<EOF > "$CONFIG_FILE"
# nwda_settings.conf - Configuration for netwatchda
# Note: Discord/Telegram tokens are stored encrypted in .vault.enc

[Log settings]
UPTIME_LOG_MAX_SIZE=51200 # Max log file size in bytes for uptime tracking. Default is 51200.
PING_LOG_ENABLE="NO" # Enable or disable detailed ping logging (YES/NO). Default is NO.

[Discord Settings]
DISCORD_ENABLE="$DISCORD_VAL" # Global toggle for Discord notifications (YES/NO). Default is NO.
SILENT_ENABLE="$SILENT_VAL" # Mutes Discord alerts during specific hours (YES/NO). Default is NO.
SILENT_START=$user_silent_start # Hour to start silent mode (0-23). Default is 23.
SILENT_END=$user_silent_end # Hour to end silent mode (0-23). Default is 07.

[TELEGRAM Settings]
TELEGRAM_ENABLE="$TELEGRAM_VAL" # Global toggle for Telegram notifications (YES/NO). Default is NO.

[Monitoring Settings]
CPU_GUARD_THRESHOLD=2.0 # Max CPU load average allowed before skipping pings. Default is 2.0.
RAM_GUARD_MIN_FREE=4096 # Minimum free RAM in KB required to run alerts. Default is 4096.
HEARTBEAT="$HB_VAL" # Periodic "I am alive" notification (YES/NO). Default is NO.
HB_INTERVAL=$HB_SEC # Seconds between heartbeat messages. Default is 86400.
HB_MENTION="$HB_MENTION" # Ping User ID in heartbeat messages (YES/NO). Default is NO.

[Internet Connectivity]
EXT_ENABLE="$EXT_ENABLED" # Global toggle for internet monitoring (YES/NO). Default is YES.
EXT_IP="1.1.1.1" # Primary external IP to monitor. Default is 1.1.1.1.
EXT_IP2="8.8.8.8" # Secondary external IP for redundancy. Default is 8.8.8.8.
EXT_SCAN_INTERVAL=60 # Seconds between internet checks. Default is 60.
EXT_FAIL_THRESHOLD=1 # Failed cycles before internet alert. Default is 1.
EXT_PING_COUNT=4 # Number of packets per internet check. Default is 4.
EXT_PING_TIMEOUT=1 # Seconds to wait for ping response. Default is 1.

[Local Device Monitoring]
DEVICE_MONITOR="$DEV_VAL" # Enable monitoring of local IPs (YES/NO). Default is YES.
DEV_SCAN_INTERVAL=10 # Seconds between local device checks. Default is 10.
DEV_FAIL_THRESHOLD=3 # Failed cycles before device alert. Default is 3.
DEV_PING_COUNT=4 # Number of packets per device check. Default is 4.
EOF

cat <<EOF > "$IP_LIST_FILE"
# Format: IP_ADDRESS @ NAME
# Example: 192.168.1.50 @ Home Server
EOF

# Auto-detect gateway to populate initial IP list
LOCAL_IP=$(uci -q get network.lan.ipaddr || ip addr show br-lan | grep -oE 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 | awk '{print $2}')
[ -n "$LOCAL_IP" ] && echo "$LOCAL_IP @ Router Gateway" >> "$IP_LIST_FILE"

# --- 7. CORE ENGINE GENERATION (Part A) ---
echo -e "${CYAN}🛠️  Generating core logic engine...${NC}"

cat <<'EOF' > "$INSTALL_DIR/netwatchda.sh"
#!/bin/sh
# netwatchda Core Engine - Automated Monitoring

BASE_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG_FILE="$BASE_DIR/nwda_settings.conf"
IP_LIST_FILE="$BASE_DIR/nwda_ips.conf"
VAULT_FILE="$BASE_DIR/.vault.enc"
LOG_DIR="/tmp/netwatchda"
UPTIME_LOG="$LOG_DIR/nwda_uptime.log"
PING_LOG="$LOG_DIR/nwda_ping.log"
SILENT_BUFFER="/tmp/nwda_silent_buffer"

mkdir -p "$LOG_DIR"
[ ! -f "$UPTIME_LOG" ] && echo "$(date '+%b %d %H:%M:%S') - [SYSTEM] - Log Initialized" > "$UPTIME_LOG"

# --- HARDWARE DECRYPTION LOGIC ---
get_hw_key() {
    local cpu_serial=$(grep -i "serial" /proc/cpuinfo | awk '{print $3}' | tr -d ' ')
    local mac_addr=$(cat /sys/class/net/eth0/address 2>/dev/null | tr -d ':')
    [ -z "$cpu_serial" ] && cpu_serial="NWDA_STATIC_SALT_2025"
    echo "${cpu_serial}${mac_addr}" | sha256sum | awk '{print $1}'
}

# Decrypt credentials directly into RAM environment variables
load_credentials() {
    local key=$(get_hw_key)
    if [ -f "$VAULT_FILE" ]; then
        eval "$(openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 10000 -in "$VAULT_FILE" -pass "pass:$key" 2>/dev/null)"
    fi
}

load_config() {
    [ -f "$CONFIG_FILE" ] && eval "$(sed '/^\[.*\]/d' "$CONFIG_FILE")"
}

# Notification Dispatcher (Handles both Discord and Telegram)
send_notification() {
    local title="$1"
    local msg="$2"
    local color="$3" # Discord Color (Int)
    local type="$4"  # ALERT or SUCCESS or INFO
    
    # Check RAM Guard before sending
    local free_ram=$(free | awk '/Mem:/ {print $4}')
    if [ "$free_ram" -lt "$RAM_GUARD_MIN_FREE" ]; then
        echo "$(date '+%b %d %H:%M:%S') - [GUARD] - Low RAM ($free_ram KB). Notification skipped." >> "$UPTIME_LOG"
        return
    fi

    # Send to Discord
    if [ "$DISCORD_ENABLE" = "YES" ] && [ -n "$DISCORD_URL" ]; then
        local payload="{\"embeds\": [{\"title\": \"$title\", \"description\": \"$msg\", \"color\": $color}]}"
        curl -s -H "Content-Type: application/json" -X POST -d "$payload" "$DISCORD_URL" > /dev/null 2>&1
    fi

    # Send to Telegram
    if [ "$TELEGRAM_ENABLE" = "YES" ] && [ -n "$TELE_TOKEN" ]; then
        local tele_msg="*$title*\n$msg"
        # Format for Telegram (convert \n to real newlines and remove markdown incompatible chars)
        curl -s -X POST "https://api.telegram.org/bot$TELE_TOKEN/sendMessage" \
            -d "chat_id=$TELE_CHAT" -d "text=$tele_msg" -d "parse_mode=Markdown" > /dev/null 2>&1
    fi
}

# State Variables
LAST_EXT_CHECK=0
LAST_DEV_CHECK=0
LAST_HB_CHECK=$(date +%s)
EOF
# --- 7. CORE ENGINE GENERATION (Part B) ---
cat <<'EOF' >> "$INSTALL_DIR/netwatchda.sh"

# Main Loop
while true; do
    load_config
    load_credentials
    
    NOW_HUMAN=$(date '+%b %d %H:%M:%S')
    NOW_SEC=$(date +%s)
    CUR_HOUR=$(date +%H)

    # --- CPU LOAD GUARD ---
    # Check if system load is too high before processing pings
    CPU_LOAD=$(cat /proc/loadavg | awk '{print $1}')
    LOAD_TOO_HIGH=$(echo "$CPU_LOAD > $CPU_GUARD_THRESHOLD" | bc 2>/dev/null || [ "$(echo "$CPU_LOAD > $CPU_GUARD_THRESHOLD" | awk '{print ($1 > $2)}' v1="$CPU_LOAD" v2="$CPU_GUARD_THRESHOLD")" -eq 1 ] && echo 1 || echo 0)

    if [ "$LOAD_TOO_HIGH" -eq 1 ]; then
        echo "$NOW_HUMAN - [GUARD] - High CPU Load ($CPU_LOAD). Skipping cycle." >> "$UPTIME_LOG"
        sleep 5
        continue
    fi

    # --- HEARTBEAT LOGIC ---
    if [ "$HEARTBEAT" = "YES" ] && [ $((NOW_SEC - LAST_HB_CHECK)) -ge "$HB_INTERVAL" ]; then
        LAST_HB_CHECK=$NOW_SEC
        HB_MSG="💓 **Heartbeat Report**\n**Router:** $ROUTER_NAME\n**Status:** Systems Operational\n**Time:** $NOW_HUMAN"
        [ "$HB_MENTION" = "YES" ] && HB_MSG="$HB_MSG\n<@$MY_ID>"
        send_notification "System Healthy" "$HB_MSG" 1752220 "INFO"
        echo "$NOW_HUMAN - [SYSTEM] - Heartbeat sent." >> "$UPTIME_LOG"
    fi

    # --- SILENT MODE LOGIC ---
    IS_SILENT=0
    if [ "$SILENT_ENABLE" = "YES" ]; then
        if [ "$SILENT_START" -gt "$SILENT_END" ]; then
            if [ "$CUR_HOUR" -ge "$SILENT_START" ] || [ "$CUR_HOUR" -lt "$SILENT_END" ]; then IS_SILENT=1; fi
        else
            if [ "$CUR_HOUR" -ge "$SILENT_START" ] && [ "$CUR_HOUR" -lt "$SILENT_END" ]; then IS_SILENT=1; fi
        fi
    fi

    # --- SUMMARY DISPATCH (End of Silent Hours) ---
    if [ "$IS_SILENT" -eq 0 ] && [ -s "$SILENT_BUFFER" ]; then
        SUMMARY_CONTENT=$(cat "$SILENT_BUFFER")
        CLEAN_SUMMARY=$(echo "$SUMMARY_CONTENT" | sed ':a;N;$!ba;s/\n/\\n/g')
        send_notification "🌙 Silent Hours Summary" "**Router:** $ROUTER_NAME\\n$CLEAN_SUMMARY" 10181046 "SUMMARY"
        [ $? -eq 0 ] && > "$SILENT_BUFFER"
    fi

    # --- INTERNET CHECK ---
    if [ "$EXT_ENABLE" = "YES" ] && [ $((NOW_SEC - LAST_EXT_CHECK)) -ge "$EXT_SCAN_INTERVAL" ]; then
        LAST_EXT_CHECK=$NOW_SEC
        FD="/tmp/nwda_ext_d"; FT="/tmp/nwda_ext_t"; FC="/tmp/nwda_ext_c"
        
        EXT_UP=0
        if ping -q -c "$EXT_PING_COUNT" -W "$EXT_PING_TIMEOUT" "$EXT_IP" > /dev/null 2>&1; then
            EXT_UP=1
        elif [ -n "$EXT_IP2" ] && ping -q -c "$EXT_PING_COUNT" -W "$EXT_PING_TIMEOUT" "$EXT_IP2" > /dev/null 2>&1; then
            EXT_UP=1
        fi

        # Detailed Ping Logging
        if [ "$PING_LOG_ENABLE" = "YES" ]; then
            P_STAT="DOWN"; [ "$EXT_UP" -eq 1 ] && P_STAT="UP"
            echo "$NOW_HUMAN - INTERNET_CHECK - $EXT_IP: $P_STAT" >> "$PING_LOG"
        fi

        if [ "$EXT_UP" -eq 0 ]; then
            C=$(($(cat "$FC" 2>/dev/null || echo 0)+1)); echo "$C" > "$FC"
            if [ "$C" -ge "$EXT_FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                echo "$NOW_SEC" > "$FD"; echo "$NOW_HUMAN" > "$FT"
                echo "$NOW_HUMAN - [ALERT] - INTERNET DOWN" >> "$UPTIME_LOG"
                
                MSG="**Router:** $ROUTER_NAME\n**Time:** $NOW_HUMAN"
                if [ "$IS_SILENT" -eq 0 ]; then
                    send_notification "🔴 Internet Down" "$MSG" 15548997 "ALERT"
                else
                    echo "🌐 Internet Outage: $NOW_HUMAN" >> "$SILENT_BUFFER"
                fi
            fi
        else
            if [ -f "$FD" ]; then
                START_TIME=$(cat "$FT"); START_SEC=$(cat "$FD")
                DUR=$((NOW_SEC - START_SEC)); DR_STR="$((DUR/60))m $((DUR%60))s"
                MSG="**Router:** $ROUTER_NAME\n**Down at:** $START_TIME\n**Up at:** $NOW_HUMAN\n**Total Outage:** $DR_STR"
                echo "$NOW_HUMAN - [SUCCESS] - INTERNET UP (Down $DR_STR)" >> "$UPTIME_LOG"
                
                if [ "$IS_SILENT" -eq 0 ]; then
                    send_notification "🟢 Connectivity Restored" "$MSG" 3066993 "SUCCESS"
                else
                    echo "🌐 Internet Restored: $NOW_HUMAN - (Down $DR_STR)" >> "$SILENT_BUFFER"
                fi
                rm -f "$FD" "$FT"
            fi
            echo 0 > "$FC"
        fi
    fi

    # --- DEVICE CHECK (Background Ping Strategy) ---
    if [ "$DEVICE_MONITOR" = "YES" ] && [ $((NOW_SEC - LAST_DEV_CHECK)) -ge "$DEV_SCAN_INTERVAL" ]; then
        LAST_DEV_CHECK=$NOW_SEC
        sed -e '/^#/d' -e '/^$/d' "$IP_LIST_FILE" | while read -r line; do
            TIP=$(echo "$line" | cut -d'@' -f1 | tr -d ' ')
            NAME=$(echo "$line" | cut -d'@' -f2- | sed 's/^[ \t]*//')
            [ -z "$TIP" ] && continue
            
            SIP=$(echo "$TIP" | tr '.' '_')
            FC="/tmp/nwda_c_$SIP"; FD="/tmp/nwda_d_$SIP"; FT="/tmp/nwda_t_$SIP"
            
            # Background Ping Strategy for performance
            (
                if ping -q -c "$DEV_PING_COUNT" -W 1 "$TIP" > /dev/null 2>&1; then
                    DEV_RES="UP"
                else
                    DEV_RES="DOWN"
                fi

                if [ "$PING_LOG_ENABLE" = "YES" ]; then
                    echo "$(date '+%b %d %H:%M:%S') - DEVICE - $NAME - $TIP: $DEV_RES" >> "$PING_LOG"
                fi

                if [ "$DEV_RES" = "UP" ]; then
                    if [ -f "$FD" ]; then
                        DSTART=$(cat "$FT"); DSSEC=$(cat "$FD"); DUR=$((NOW_SEC-DSSEC))
                        DR_STR="$((DUR/60))m $((DUR%60))s"
                        D_MSG="**Router:** $ROUTER_NAME\n**Device:** $NAME ($TIP)\n**Down at:** $DSTART\n**Up at:** $(date '+%b %d %H:%M:%S')\n**Total Outage:** $DR_STR"
                        echo "$(date '+%b %d %H:%M:%S') - [SUCCESS] - Device: $NAME Online (Down $DR_STR)" >> "$UPTIME_LOG"
                        
                        if [ "$IS_SILENT" -eq 0 ]; then
                            send_notification "🟢 $NAME Online" "$D_MSG" 3066993 "SUCCESS"
                        else
                            echo "✅ $NAME Online: $NOW_HUMAN - (Down $DR_STR)" >> "$SILENT_BUFFER"
                        fi
                        rm -f "$FD" "$FT"
                    fi
                    echo 0 > "$FC"
                else
                    C=$(($(cat "$FC" 2>/dev/null || echo 0)+1)); echo "$C" > "$FC"
                    if [ "$C" -ge "$DEV_FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                        echo "$NOW_SEC" > "$FD"; echo "$(date '+%b %d %H:%M:%S')" > "$FT"
                        echo "$(date '+%b %d %H:%M:%S') - [ALERT] - Device: $NAME Down" >> "$UPTIME_LOG"
                        if [ "$IS_SILENT" -eq 0 ]; then
                            send_notification "🔴 Device Down" "**Router:** $ROUTER_NAME\n**Device:** $NAME ($TIP)\n**Time:** $(date '+%b %d %H:%M:%S')" 15548997 "ALERT"
                        else
                            echo "🔴 $NAME Down: $NOW_HUMAN" >> "$SILENT_BUFFER"
                        fi
                    fi
                fi
            ) & 
        done
        wait # Ensure all background pings finish before next cycle
    fi

    # --- LOG ROTATION ---
    for f in "$UPTIME_LOG" "$PING_LOG"; do
        if [ -f "$f" ] && [ $(wc -c < "$f") -gt "$UPTIME_LOG_MAX_SIZE" ]; then
            echo "$(date '+%b %d %H:%M:%S') - [SYSTEM] - Log rotated." > "$f"
        fi
    done

    sleep 1
done
EOF
# --- 8. ENHANCED SERVICE & MANAGEMENT TOOLS ---
chmod +x "$INSTALL_DIR/netwatchda.sh"

cat <<EOF > "$SERVICE_PATH"
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

# Custom Commands
extra_command "status" "Check if monitor is running"
extra_command "clear" "Clear all log files"
extra_command "discord" "Test Discord notification"
extra_command "telegram" "Test Telegram notification"
extra_command "credentials" "Change Discord/Telegram credentials"
extra_command "purge" "Interactive smart uninstaller"
extra_command "reload" "Reload configuration"

# Helper: Get HW Key for Vault
get_hw_key() {
    local cpu_serial=\$(grep -i "serial" /proc/cpuinfo | awk '{print \$3}' | tr -d ' ')
    local mac_addr=\$(cat /sys/class/net/eth0/address 2>/dev/null | tr -d ':')
    [ -z "\$cpu_serial" ] && cpu_serial="NWDA_STATIC_SALT_2025"
    echo "\${cpu_serial}\${mac_addr}" | sha256sum | awk '{print \$1}'
}

start_service() {
    procd_open_instance
    procd_set_param command /bin/sh "$INSTALL_DIR/netwatchda.sh"
    procd_set_param respawn
    # CPU/RAM Guard pre-check before starting
    local free_ram=\$(free | awk '/Mem:/ {print \$4}')
    if [ "\$free_ram" -lt 4096 ]; then
        echo "Insufficient RAM to start netwatchda securely."
        return 1
    fi
    procd_close_instance
}

status() {
    pgrep -f "netwatchda.sh" > /dev/null && echo "netwatchda is RUNNING." || echo "netwatchda is STOPPED."
}

clear() {
    > "$UPTIME_LOG"
    > "$PING_LOG"
    echo "Logs cleared."
}

discord() {
    # RAM-only decryption for manual test
    local key=\$(get_hw_key)
    eval "\$(openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 10000 -in "$VAULT_FILE" -pass "pass:\$key" 2>/dev/null)"
    eval "\$(sed '/^\[.*\]/d' "$CONFIG_FILE")"
    
    if [ "\$DISCORD_ENABLE" = "YES" ]; then
        curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🛠️ Test Alert\", \"description\": \"Manual Discord test successful.\", \"color\": 16776960}]}" "\$DISCORD_URL"
        echo "Discord test sent."
    else
        echo "Discord is disabled in settings."
    fi
}

telegram() {
    local key=\$(get_hw_key)
    eval "\$(openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 10000 -in "$VAULT_FILE" -pass "pass:\$key" 2>/dev/null)"
    eval "\$(sed '/^\[.*\]/d' "$CONFIG_FILE")"
    
    if [ "\$TELEGRAM_ENABLE" = "YES" ]; then
        curl -s -X POST "https://api.telegram.org/bot\$TELE_TOKEN/sendMessage" -d "chat_id=\$TELE_CHAT" -d "text=🛠️ *Test Alert* - Manual Telegram test successful." -d "parse_mode=Markdown"
        echo "Telegram test sent."
    else
        echo "Telegram is disabled in settings."
    fi
}

credentials() {
    local key=\$(get_hw_key)
    echo -e "\n${BLUE}--- Credentials Manager ---${NC}"
    echo "1. Change Discord Credentials"
    echo "2. Change Telegram Credentials"
    echo "3. Change Both"
    printf "Choice [1-3]: "
    read choice </dev/tty
    
    # Decrypt existing to keep what we don't change
    eval "\$(openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 10000 -in "$VAULT_FILE" -pass "pass:\$key" 2>/dev/null)"
    
    case "\$choice" in
        1|3) printf "New Discord Webhook: "; read DISCORD_URL </dev/tty; printf "New User ID: "; read MY_ID </dev/tty ;;
    esac
    case "\$choice" in
        2|3) printf "New Telegram Token: "; read TELE_TOKEN </dev/tty; printf "New Chat ID: "; read TELE_CHAT </dev/tty ;;
    esac
    
    RAW="DISCORD_URL='\$DISCORD_URL'\nMY_ID='\$MY_ID'\nTELE_TOKEN='\$TELE_TOKEN'\nTELE_CHAT='\$TELE_CHAT'"
    echo -e "\$RAW" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 10000 -out "$VAULT_FILE" -pass "pass:\$key"
    echo "Credentials updated. Restarting service..."
    /etc/init.d/netwatchda restart
}

purge() {
    echo -e "\n${RED}⚠️  Uninstalling netwatchda...${NC}"
    echo "1. Full Uninstall (Remove everything including dependencies)"
    echo "2. Keep Config (Remove logic but keep settings/vault)"
    printf "Choice: "
    read p_choice </dev/tty
    
    /etc/init.d/netwatchda stop
    /etc/init.d/netwatchda disable
    
    if [ "\$p_choice" = "1" ]; then
        rm -rf "$INSTALL_DIR"
        rm -f "$SERVICE_PATH"
        # Optional: Remove dependencies (Only if they were installed by script)
        # opkg remove openssl-util curl
        echo "Full cleanup complete."
    else
        rm -f "$INSTALL_DIR/netwatchda.sh"
        rm -f "$SERVICE_PATH"
        echo "Logic removed. Config preserved in $INSTALL_DIR"
    fi
}
EOF

# --- 9. FINALIZATION ---
chmod +x "$SERVICE_PATH"
"$SERVICE_PATH" enable
"$SERVICE_PATH" restart

# Final Setup Notification
load_credentials
NOW_FINAL=$(date '+%b %d, %Y %H:%M:%S')
MSG="**Router:** $router_name_input\n**Time:** $NOW_FINAL\n**Status:** Service Active"
send_notification "🚀 netwatchda Service Started" "$MSG" 1752220 "INFO"

# --- FINAL OUTPUT ---
echo ""
echo -e "${GREEN}=======================================================${NC}"
echo -e "${BOLD}${GREEN}✅ Installation complete!${NC}"
echo -e "${CYAN}📂 Folder:${NC} $INSTALL_DIR"
echo -e "${GREEN}=======================================================${NC}"
echo -e "\n${BOLD}Quick Commands:${NC}"
echo -e "  Edit Settings   : ${CYAN}$CONFIG_FILE${NC}"
echo -e "  Edit IP List    : ${CYAN}$IP_LIST_FILE${NC}"
echo -e "  Restart         : ${YELLOW}/etc/init.d/netwatchda restart${NC}"
echo -e "  Uninstall        : ${RED}/etc/init.d/netwatchda purge${NC}"
echo ""
echo -e "${BOLD}Logs Location:${NC} $LOG_DIR"
echo ""