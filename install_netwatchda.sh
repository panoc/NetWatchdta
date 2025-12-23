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
WHITE='\033[1;37m'  # Bold White

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

# --- DIRECTORY & FILE SETUP ---
INSTALL_DIR="/root/netwatchda"
TMP_DIR="/tmp/netwatchda"
CONFIG_FILE="$INSTALL_DIR/nwda_settings.conf"
IP_LIST_FILE="$INSTALL_DIR/nwda_ips.conf"
VAULT_FILE="$INSTALL_DIR/.vault.enc"
SERVICE_NAME="netwatchda"
SERVICE_PATH="/etc/init.d/$SERVICE_NAME"

# Ensure temp directory exists for installation logs
mkdir -p "$TMP_DIR"

# --- 1. CHECK DEPENDENCIES & STORAGE (FLASH & RAM) ---
echo -e "\n${BOLD}📦 Checking system readiness...${NC}"

# Flash Storage Check (Root partition)
FREE_FLASH_KB=$(df / | awk 'NR==2 {print $4}')
MIN_FLASH_KB=3072 # 3MB Threshold

# RAM Check (/tmp partition)
FREE_RAM_KB=$(df /tmp | awk 'NR==2 {print $4}')
MIN_RAM_KB=4096 # 4MB Threshold for OpenSSL operations

# Depedency List
MISSING_DEPS=""
command -v curl >/dev/null 2>&1 || MISSING_DEPS="$MISSING_DEPS curl"
command -v openssl >/dev/null 2>&1 || MISSING_DEPS="$MISSING_DEPS openssl-util"
[ -f /etc/ssl/certs/ca-certificates.crt ] || command -v opkg >/dev/null && opkg list-installed | grep -q ca-bundle || MISSING_DEPS="$MISSING_DEPS ca-bundle"

# RAM Guard for Installation
if [ "$FREE_RAM_KB" -lt "$MIN_RAM_KB" ]; then
    echo -e "${RED}❌ ERROR: Insufficient RAM for encryption operations!${NC}"
    echo -e "${YELLOW}Available: $((FREE_RAM_KB / 1024))MB | Required: 4MB${NC}"
    exit 1
fi

# Flash & Dependency Logic
if [ -n "$MISSING_DEPS" ]; then
    echo -e "${CYAN}🔍 Missing dependencies found:${BOLD}$MISSING_DEPS${NC}"
    if [ "$FREE_FLASH_KB" -lt "$MIN_FLASH_KB" ]; then
        echo -e "${RED}❌ ERROR: Insufficient Flash storage to install dependencies!${NC}"
        echo -e "${YELLOW}Available: $((FREE_FLASH_KB / 1024))MB | Required: 3MB${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ Sufficient Flash space found: $((FREE_FLASH_KB / 1024))MB available.${NC}"
        printf "${BOLD}❓ Download missing dependencies? [y/n]: ${NC}"
        read install_deps_confirm </dev/tty
        
        if [ "$install_deps_confirm" = "y" ] || [ "$install_deps_confirm" = "Y" ]; then
             echo -e "${YELLOW}📥 Updating package lists...${NC}"
             opkg update --no-check-certificate > /dev/null 2>&1
             
             echo -e "${YELLOW}📥 Installing:$MISSING_DEPS...${NC}"
             # Install without output unless error
             opkg install --no-check-certificate $MISSING_DEPS > /tmp/nwda_install_err.log 2>&1
             if [ $? -ne 0 ]; then
                echo -e "${RED}❌ Error installing dependencies. Log:${NC}"
                cat /tmp/nwda_install_err.log
                exit 1
             fi
             echo -e "${GREEN}✅ Dependencies installed successfully.${NC}"
        else
             echo -e "${RED}❌ Cannot proceed without dependencies. Aborting.${NC}"
             exit 1
        fi
    fi
else
    echo -e "${GREEN}✅ All dependencies (curl, openssl) are installed.${NC}"
    echo -e "${GREEN}✅ Flash storage check passed: $((FREE_FLASH_KB / 1024))MB available.${NC}"
fi

echo -e "${GREEN}✅ Sufficient RAM for operations ($FREE_RAM_KB KB available).${NC}"

# --- 2. SMART UPGRADE / INSTALL CHECK ---
KEEP_CONFIG=0
if [ -f "$CONFIG_FILE" ]; then
    echo -e "\n${YELLOW}⚠️  Existing installation found.${NC}"
    echo -e "1. Keep settings (Upgrade)"
    echo -e "2. Clean install"
    printf "${BOLD}Enter choice [1-2]: ${NC}"
    read choice </dev/tty
    
    if [ "$choice" = "1" ]; then
        echo -e "${CYAN}🔧 Upgrading logic while keeping settings...${NC}"
        KEEP_CONFIG=1
    else
        echo -e "${RED}🧹 Performing clean install...${NC}"
        /etc/init.d/netwatchda stop >/dev/null 2>&1
        rm -rf "$INSTALL_DIR"
    fi
fi

mkdir -p "$INSTALL_DIR"

# --- 3. CLEAN INSTALL INPUTS ---
if [ "$KEEP_CONFIG" -eq 0 ]; then
    echo -e "\n${BLUE}--- Configuration ---${NC}"
    
    # Router Name
    printf "${BOLD}🏷️  Enter Router Name (e.g., MyRouter): ${NC}"
    read router_name_input </dev/tty
    
    # Discord Setup
    DISCORD_ENABLE_VAL="NO"
    DISCORD_WEBHOOK=""
    DISCORD_USERID=""
    
    echo -e "\n${BLUE}--- Notification Settings ---${NC}"
    printf "${BOLD}1. Enable Discord Notifications? [y/n]: ${NC}"
    read discord_choice </dev/tty
    if [ "$discord_choice" = "y" ] || [ "$discord_choice" = "Y" ]; then
        DISCORD_ENABLE_VAL="YES"
        printf "${BOLD}   > Enter Discord Webhook URL: ${NC}"
        read DISCORD_WEBHOOK </dev/tty
        printf "${BOLD}   > Enter Discord User ID (for @mentions): ${NC}"
        read DISCORD_USERID </dev/tty
    fi

    # Telegram Setup
    TELEGRAM_ENABLE_VAL="NO"
    TELEGRAM_BOT_TOKEN=""
    TELEGRAM_CHAT_ID=""
    
    printf "${BOLD}2. Enable Telegram Notifications? [y/n]: ${NC}"
    read telegram_choice </dev/tty
    if [ "$telegram_choice" = "y" ] || [ "$telegram_choice" = "Y" ]; then
        TELEGRAM_ENABLE_VAL="YES"
        printf "${BOLD}   > Enter Telegram Bot Token: ${NC}"
        read TELEGRAM_BOT_TOKEN </dev/tty
        printf "${BOLD}   > Enter Telegram Chat ID: ${NC}"
        read TELEGRAM_CHAT_ID </dev/tty
    fi
    
    # Notify User of choice
    echo -e "\n${BOLD}${WHITE}Selected Notification Strategy:${NC}"
    if [ "$DISCORD_ENABLE_VAL" = "YES" ] && [ "$TELEGRAM_ENABLE_VAL" = "YES" ]; then
        echo -e "   • ${GREEN}BOTH (Redundant)${NC}"
    elif [ "$DISCORD_ENABLE_VAL" = "YES" ]; then
         echo -e "   • ${BLUE}Discord Only${NC}"
    elif [ "$TELEGRAM_ENABLE_VAL" = "YES" ]; then
         echo -e "   • ${CYAN}Telegram Only${NC}"
    else
         echo -e "   • ${RED}NONE (Log only mode)${NC}"
    fi

    # Silent Hours
    SILENT_ENABLE_VAL="NO"
    user_silent_start="23"
    user_silent_end="07"
    
    echo -e "\n${BLUE}--- Silent Hours (Mute Alerts) ---${NC}"
    printf "${BOLD}🌙 Enable Silent Hours? [y/n]: ${NC}"
    read enable_silent_choice </dev/tty
    
    if [ "$enable_silent_choice" = "y" ] || [ "$enable_silent_choice" = "Y" ]; then
        SILENT_ENABLE_VAL="YES"
        while :; do
            printf "${BOLD}   > Start Hour (0-23): ${NC}"
            read user_silent_start </dev/tty
            if echo "$user_silent_start" | grep -qE '^[0-9]+$' && [ "$user_silent_start" -ge 0 ] && [ "$user_silent_start" -le 23 ] 2>/dev/null; then
                break
            else
                echo -e "${RED}   ❌ Invalid hour. Use 0-23.${NC}"
            fi
        done
        while :; do
            printf "${BOLD}   > End Hour (0-23): ${NC}"
            read user_silent_end </dev/tty
            if echo "$user_silent_end" | grep -qE '^[0-9]+$' && [ "$user_silent_end" -ge 0 ] && [ "$user_silent_end" -le 23 ] 2>/dev/null; then
                break
            else
                echo -e "${RED}   ❌ Invalid hour. Use 0-23.${NC}"
            fi
        done
    fi
    
    # Heartbeat
    HB_VAL="NO"; HB_SEC="86400"; HB_MENTION="NO"
    echo -e "\n${BLUE}--- Heartbeat Settings ---${NC}"
    printf "${BOLD}💓 Enable Heartbeat (System check-in)? [y/n]: ${NC}"
    read hb_enabled </dev/tty
    if [ "$hb_enabled" = "y" ] || [ "$hb_enabled" = "Y" ]; then
        HB_VAL="YES"
        printf "${BOLD}   > Interval in HOURS (e.g., 24): ${NC}"
        read hb_hours </dev/tty
        # Validate integer input for hours
        if echo "$hb_hours" | grep -qE '^[0-9]+$'; then
             HB_SEC=$((hb_hours * 3600))
        else
             HB_SEC=86400 # Default fallback
        fi
        
        printf "${BOLD}   > Mention in Heartbeat? [y/n]: ${NC}"
        read hb_m </dev/tty
        [ "$hb_m" = "y" ] || [ "$hb_m" = "Y" ] && HB_MENTION="YES"
    fi

    # Monitoring Mode
    echo -e "\n${BLUE}--- Monitoring Mode ---${NC}"
    echo -e "${BOLD}${WHITE}1.${NC} Both: Full monitoring (Default)"
    echo -e "${BOLD}${WHITE}2.${NC} Device Connectivity only: Pings local network"
    echo -e "${BOLD}${WHITE}3.${NC} Internet Connectivity only: Pings external IP"
    
    while :; do
        printf "${BOLD}Enter choice [1-3]: ${NC}"
        read mode_choice </dev/tty
        case "$mode_choice" in
            1|2|3) break ;;
            *) echo -e "${RED}❌ Invalid choice. Try again.${NC}" ;;
        esac
    done

    case "$mode_choice" in
        2) EXT_VAL="NO";  DEV_VAL="YES" ;;
        3) EXT_VAL="YES"; DEV_VAL="NO"  ;;
        *) EXT_VAL="YES"; DEV_VAL="YES" ;;
    esac

    # --- GENERATE SETTINGS FILE ---
    cat <<EOF > "$CONFIG_FILE"
# nwda_settings.conf - Configuration for netwatchda
# Note: Discord/Telegram tokens are stored encrypted in .vault.enc
ROUTER_NAME="$router_name_input"

[Log Settings]
UPTIME_LOG_MAX_SIZE=51200 # Max log file size in bytes for uptime tracking. Default is 51200.
PING_LOG_ENABLE=NO # Enable or disable detailed ping logging (YES/NO). Default is NO.

[Discord Settings]
DISCORD_ENABLE=$DISCORD_ENABLE_VAL # Global toggle for Discord notifications (YES/NO). Default is NO.
SILENT_ENABLE=$SILENT_ENABLE_VAL # Mutes Discord alerts during specific hours (YES/NO). Default is NO.
SILENT_START=$user_silent_start # Hour to start silent mode (0-23). Default is 23.
SILENT_END=$user_silent_end # Hour to end silent mode (0-23). Default is 07.

[Telegram Settings]
TELEGRAM_ENABLE=$TELEGRAM_ENABLE_VAL # Global toggle for Telegram notifications (YES/NO). Default is NO.

[Monitoring Settings]
CPU_GUARD_THRESHOLD=2.0 # Max CPU load average allowed before skipping pings. Default is 2.0.
RAM_GUARD_MIN_FREE=4096 # Minimum free RAM in KB required to run alerts. Default is 4096.
HEARTBEAT=$HB_VAL # Periodic I am alive notification (YES/NO). Default is NO.
HB_INTERVAL=$HB_SEC # Seconds between heartbeat messages. Default is 86400.
HB_MENTION=$HB_MENTION # Ping User ID in heartbeat messages (YES/NO). Default is NO.

[Internet Connectivity]
EXT_ENABLE=$EXT_VAL # Global toggle for internet monitoring (YES/NO). Default is YES.
EXT_IP=1.1.1.1 # Primary external IP to monitor. Default is 1.1.1.1.
EXT_IP2=8.8.8.8 # Secondary external IP for redundancy. Default is 8.8.8.8.
EXT_SCAN_INTERVAL=60 # Seconds between internet checks. Default is 60.
EXT_FAIL_THRESHOLD=1 # Failed cycles before internet alert. Default is 1.
EXT_PING_COUNT=4 # Number of packets per internet check. Default is 4.
EXT_PING_TIMEOUT=1 # Seconds to wait for ping response. Default is 1.

[Local Device Monitoring]
DEVICE_MONITOR=$DEV_VAL # Enable monitoring of local IPs (YES/NO). Default is YES.
DEV_SCAN_INTERVAL=10 # Seconds between local device checks. Default is 10.
DEV_FAIL_THRESHOLD=3 # Failed cycles before device alert. Default is 3.
DEV_PING_COUNT=4 # Number of packets per device check. Default is 4.
EOF

    # --- GENERATE IP LIST ---
    cat <<EOF > "$IP_LIST_FILE"
# Format: IP_ADDRESS @ NAME
# Example: 192.168.1.50 @ Home Server
EOF
    LOCAL_IP=$(uci -q get network.lan.ipaddr || ip addr show br-lan | grep -oE 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 | awk '{print $2}')
    [ -n "$LOCAL_IP" ] && echo "$LOCAL_IP @ Router Gateway" >> "$IP_LIST_FILE"
fi
# --- 4. SECURITY & VAULT GENERATION ---
echo -e "\n${CYAN}🔐 Securing credentials...${NC}"

# Function to generate a unique Hardware Key (HWID)
# Uses CPU Serial (if available), MAC address, and a hidden seed.
get_hw_key() {
    local seed="nwda_v1_secure_seed_2025"
    local cpu_serial=$(grep -i "serial" /proc/cpuinfo | head -1 | awk '{print $3}')
    [ -z "$cpu_serial" ] && cpu_serial="unknown_serial"
    
    local mac_addr=$(cat /sys/class/net/eth0/address 2>/dev/null)
    [ -z "$mac_addr" ] && mac_addr=$(cat /sys/class/net/br-lan/address 2>/dev/null)
    [ -z "$mac_addr" ] && mac_addr="00:00:00:00:00:00"

    echo -n "${seed}${cpu_serial}${mac_addr}" | openssl dgst -sha256 | awk '{print $2}'
}

# Create the Vault Data String
# Format: DISCORD_WEBHOOK|DISCORD_USERID|TELEGRAM_BOT_TOKEN|TELEGRAM_CHAT_ID
VAULT_DATA="${DISCORD_WEBHOOK}|${DISCORD_USERID}|${TELEGRAM_BOT_TOKEN}|${TELEGRAM_CHAT_ID}"

# Encrypt the Vault
HW_KEY=$(get_hw_key)
if echo -n "$VAULT_DATA" | openssl enc -aes-256-cbc -a -salt -pbkdf2 -iter 10000 -k "$HW_KEY" -out "$VAULT_FILE" 2>/dev/null; then
    echo -e "${GREEN}✅ Credentials encrypted and locked to this hardware.${NC}"
else
    echo -e "${RED}❌ Encryption failed! Check openssl-util.${NC}"
    # Fallback for installation flow, though service will fail to notify
fi

# --- 5. CORE SCRIPT GENERATION ---
echo -e "\n${CYAN}🛠️  Generating core script...${NC}"
cat <<'EOF' > "$INSTALL_DIR/netwatchda.sh"
#!/bin/sh
# netwatchda - Network Monitoring for OpenWrt (Core Engine)

BASE_DIR="/root/netwatchda"
IP_LIST_FILE="$BASE_DIR/nwda_ips.conf"
CONFIG_FILE="$BASE_DIR/nwda_settings.conf"
VAULT_FILE="$BASE_DIR/.vault.enc"

# RAM Paths
TMP_DIR="/tmp/netwatchda"
LOGFILE="$TMP_DIR/nwda_uptime.log"
PINGLOG="$TMP_DIR/nwda_ping.log"
SILENT_BUFFER="$TMP_DIR/nwda_silent_buffer"

# State Tracking
LAST_EXT_CHECK=0
LAST_DEV_CHECK=0
LAST_HB_CHECK=$(date +%s)
mkdir -p "$TMP_DIR"
[ ! -f "$SILENT_BUFFER" ] && touch "$SILENT_BUFFER"
[ ! -f "$LOGFILE" ] && touch "$LOGFILE"

# --- HELPER: LOGGING ---
log_msg() {
    local msg="$1"
    local type="$2" # UPTIME or PING
    local ts=$(date '+%b %d %H:%M:%S')
    
    if [ "$type" = "PING" ] && [ "$PING_LOG_ENABLE" = "YES" ]; then
        echo "$ts - $msg" >> "$PINGLOG"
        # Rotate Ping Log (Simple tail cut to keep size manageable)
        if [ -f "$PINGLOG" ] && [ $(wc -c < "$PINGLOG") -gt "$UPTIME_LOG_MAX_SIZE" ]; then
            echo "$ts - [SYSTEM] Log rotated." > "$PINGLOG"
        fi
    elif [ "$type" = "UPTIME" ]; then
        echo "$ts - $msg" >> "$LOGFILE"
        # Rotate Uptime Log
        if [ -f "$LOGFILE" ] && [ $(wc -c < "$LOGFILE") -gt "$UPTIME_LOG_MAX_SIZE" ]; then
            echo "$ts - [SYSTEM] Log rotated." > "$LOGFILE"
        fi
    fi
}

# --- HELPER: CONFIG LOADER ---
load_config() {
    [ -f "$CONFIG_FILE" ] && eval "$(sed '/^\[.*\]/d' "$CONFIG_FILE" | sed 's/ #.*//')"
}

# --- HELPER: CREDENTIAL DECRYPTION (RAM ONLY) ---
get_hw_key() {
    local seed="nwda_v1_secure_seed_2025"
    local cpu_serial=$(grep -i "serial" /proc/cpuinfo | head -1 | awk '{print $3}')
    [ -z "$cpu_serial" ] && cpu_serial="unknown_serial"
    local mac_addr=$(cat /sys/class/net/eth0/address 2>/dev/null)
    [ -z "$mac_addr" ] && mac_addr=$(cat /sys/class/net/br-lan/address 2>/dev/null)
    [ -z "$mac_addr" ] && mac_addr="00:00:00:00:00:00"
    echo -n "${seed}${cpu_serial}${mac_addr}" | openssl dgst -sha256 | awk '{print $2}'
}

load_credentials() {
    if [ -f "$VAULT_FILE" ]; then
        local key=$(get_hw_key)
        local decrypted=$(openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -iter 10000 -k "$key" -in "$VAULT_FILE" 2>/dev/null)
        if [ -n "$decrypted" ]; then
            export DISCORD_WEBHOOK=$(echo "$decrypted" | cut -d'|' -f1)
            export DISCORD_USERID=$(echo "$decrypted" | cut -d'|' -f2)
            export TELEGRAM_BOT_TOKEN=$(echo "$decrypted" | cut -d'|' -f3)
            export TELEGRAM_CHAT_ID=$(echo "$decrypted" | cut -d'|' -f4)
            return 0
        fi
    fi
    return 1
}

# --- HELPER: NOTIFICATIONS ---
send_notification() {
    local title="$1"
    local desc="$2"
    local color="$3"
    local type="$4" # "ALERT", "SUCCESS", "INFO", "WARNING", "SUMMARY"
    
    # Check RAM Guard before firing curl/openssl
    local free_ram=$(df /tmp | awk 'NR==2 {print $4}')
    [ "$free_ram" -lt "$RAM_GUARD_MIN_FREE" ] && log_msg "[SYSTEM] RAM LOW ($free_ram KB). Notification skipped." "UPTIME" && return

    # Load credentials into RAM only for this execution
    load_credentials
    
    # 1. DISCORD
    if [ "$DISCORD_ENABLE" = "YES" ] && [ -n "$DISCORD_WEBHOOK" ]; then
        curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"$title\", \"description\": \"$desc\", \"color\": $color}]}" "$DISCORD_WEBHOOK" >/dev/null 2>&1
    fi

    # 2. TELEGRAM
    if [ "$TELEGRAM_ENABLE" = "YES" ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        # Format for Telegram (Convert Markdown to simple text or HTML if needed, here keeping simple)
        # Replacing common markdown bold ** with empty string or keep as is. Telegram parsing depends on mode.
        # We will use simple text concatenation.
        local t_msg="$title - $desc"
        # Sanitize newlines for URL
        # Using curl --data-urlencode is safer
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$title
$desc" >/dev/null 2>&1
    fi
    
    # Clear credentials from RAM
    unset DISCORD_WEBHOOK DISCORD_USERID TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
}

# --- MAIN LOOP ---
while true; do
    load_config
    
    NOW_HUMAN=$(date '+%b %d %H:%M:%S')
    NOW_SEC=$(date +%s)
    CUR_HOUR=$(date +%H)
    
    # Bandwidth/CPU Guard
    CPU_LOAD=$(cat /proc/loadavg | awk '{print $1}')
    if awk "BEGIN {exit !($CPU_LOAD > $CPU_GUARD_THRESHOLD)}"; then
        log_msg "[SYSTEM] High Load ($CPU_LOAD). Skipping cycle." "UPTIME"
        sleep 10
        continue
    fi

    # --- HEARTBEAT ---
    if [ "$HEARTBEAT" = "YES" ] && [ $((NOW_SEC - LAST_HB_CHECK)) -ge "$HB_INTERVAL" ]; then
        LAST_HB_CHECK=$NOW_SEC
        HB_MSG="**Router:** $ROUTER_NAME\n**Status:** Systems Operational\n**Time:** $NOW_HUMAN"
        [ "$HB_MENTION" = "YES" ] && HB_MSG="$HB_MSG\n<@$DISCORD_USERID>"
        send_notification "💓 Heartbeat Report" "$HB_MSG" "1752220" "INFO"
        log_msg "[$ROUTER_NAME] Heartbeat sent." "UPTIME"
    fi

    # --- SILENT MODE ---
    IS_SILENT=0
    if [ "$SILENT_ENABLE" = "YES" ]; then
        if [ "$SILENT_START" -gt "$SILENT_END" ]; then
            if [ "$CUR_HOUR" -ge "$SILENT_START" ] || [ "$CUR_HOUR" -lt "$SILENT_END" ]; then IS_SILENT=1; fi
        else
            if [ "$CUR_HOUR" -ge "$SILENT_START" ] && [ "$CUR_HOUR" -lt "$SILENT_END" ]; then IS_SILENT=1; fi
        fi
    fi

    # --- SILENT SUMMARY TRIGGER (End of Silent Window) ---
    if [ "$IS_SILENT" -eq 0 ] && [ -s "$SILENT_BUFFER" ]; then
        SUMMARY_CONTENT=$(cat "$SILENT_BUFFER")
        CLEAN_SUMMARY=$(echo "$SUMMARY_CONTENT" | sed ':a;N;$!ba;s/\n/\\n/g')
        send_notification "🌙 Silent Hours Summary" "**Router:** $ROUTER_NAME\n$CLEAN_SUMMARY" "10181046" "SUMMARY"
        > "$SILENT_BUFFER"
    fi

    # --- INTERNET CHECK ---
    if [ "$EXT_ENABLE" = "YES" ] && [ $((NOW_SEC - LAST_EXT_CHECK)) -ge "$EXT_SCAN_INTERVAL" ]; then
        LAST_EXT_CHECK=$NOW_SEC
        FD="$TMP_DIR/nwda_ext_d"; FT="$TMP_DIR/nwda_ext_t"; FC="$TMP_DIR/nwda_ext_c"
        
        EXT_UP=0
        if [ -n "$EXT_IP" ] && ping -q -c "$EXT_PING_COUNT" -W "$EXT_PING_TIMEOUT" "$EXT_IP" > /dev/null 2>&1; then
            EXT_UP=1; log_msg "INTERNET_CHECK ($EXT_IP): UP" "PING"
        elif [ -n "$EXT_IP2" ] && ping -q -c "$EXT_PING_COUNT" -W "$EXT_PING_TIMEOUT" "$EXT_IP2" > /dev/null 2>&1; then
            EXT_UP=1; log_msg "INTERNET_CHECK ($EXT_IP2): UP" "PING"
        else
            log_msg "INTERNET_CHECK: DOWN" "PING"
        fi

        if [ "$EXT_UP" -eq 0 ]; then
            C=$(($(cat "$FC" 2>/dev/null || echo 0)+1)); echo "$C" > "$FC"
            if [ "$C" -ge "$EXT_FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                echo "$NOW_SEC" > "$FD"; echo "$NOW_HUMAN" > "$FT"
                log_msg "[ALERT] [$ROUTER_NAME] INTERNET DOWN" "UPTIME"
                
                MSG="**Router:** $ROUTER_NAME\n**Time:** $NOW_HUMAN"
                if [ "$IS_SILENT" -eq 0 ]; then
                    send_notification "🔴 Internet Down" "$MSG" "15548997" "ALERT"
                else
                    echo "Internet Down: $NOW_HUMAN" >> "$SILENT_BUFFER"
                fi
            fi
        else
            if [ -f "$FD" ]; then
                START_TIME=$(cat "$FT"); START_SEC=$(cat "$FD")
                DURATION_SEC=$((NOW_SEC - START_SEC))
                DR="$((DURATION_SEC/60))m $((DURATION_SEC%60))s"
                
                MSG="**Router:** $ROUTER_NAME\n**Down at:** $START_TIME\n**Up at:** $NOW_HUMAN\n**Total Outage:** $DR"
                log_msg "[SUCCESS] [$ROUTER_NAME] INTERNET UP (Down $DR)" "UPTIME"
                
                if [ "$IS_SILENT" -eq 0 ]; then
                    send_notification "🟢 Connectivity Restored" "$MSG" "3066993" "SUCCESS"
                else
                    echo -e "Internet Restored: $NOW_HUMAN (Down $DR)" >> "$SILENT_BUFFER"
                fi
                rm -f "$FD" "$FT"
            fi
            echo 0 > "$FC"
        fi
    fi

    # --- DEVICE CHECK (Parallel) ---
    if [ "$DEVICE_MONITOR" = "YES" ] && [ $((NOW_SEC - LAST_DEV_CHECK)) -ge "$DEV_SCAN_INTERVAL" ]; then
        LAST_DEV_CHECK=$NOW_SEC
        # Read file into memory to loop
        grep -vE '^#|^$' "$IP_LIST_FILE" | while read -r line; do
            (
                TIP=$(echo "$line" | cut -d'@' -f1 | tr -d ' ')
                NAME=$(echo "$line" | cut -d'@' -f2- | sed 's/^[ \t]*//')
                [ -z "$NAME" ] && NAME="$TIP"
                [ -z "$TIP" ] && exit
                
                SIP=$(echo "$TIP" | tr '.' '_')
                FC="$TMP_DIR/dev_${SIP}_c"; FD="$TMP_DIR/dev_${SIP}_d"; FT="$TMP_DIR/dev_${SIP}_t"
                
                if ping -q -c "$DEV_PING_COUNT" -W 1 "$TIP" > /dev/null 2>&1; then
                    log_msg "DEVICE - $NAME - $TIP: UP" "PING"
                    if [ -f "$FD" ]; then
                        DSTART=$(cat "$FT"); DSSEC=$(cat "$FD"); DUR=$(( $(date +%s) - DSSEC ))
                        DR_STR="$((DUR/60))m $((DUR%60))s"
                        
                        D_MSG="**Router:** $ROUTER_NAME\n**Device:** $NAME ($TIP)\n**Down at:** $DSTART\n**Up at:** $(date '+%b %d %H:%M:%S')\n**Outage:** $DR_STR"
                        log_msg "[SUCCESS] [$ROUTER_NAME] Device: $NAME ($TIP) Online (Down $DR_STR)" "UPTIME"
                        
                        if [ "$SILENT_ENABLE" = "YES" ] && [ "$IS_SILENT" -eq 1 ]; then
                             echo "Device $NAME UP: $(date '+%b %d %H:%M:%S') (Down $DR_STR)" >> "$SILENT_BUFFER"
                        else
                             # Using load_credentials handled inside send_notification, but since we are in subshell,
                             # we need to ensure the parent environment or reloading works. 
                             # Since send_notification re-loads from file, it works in subshell.
                             send_notification "🟢 Device Online" "$D_MSG" "3066993" "SUCCESS"
                        fi
                        rm -f "$FD" "$FT"
                    fi
                    echo 0 > "$FC"
                else
                    log_msg "DEVICE - $NAME - $TIP: DOWN" "PING"
                    C=$(($(cat "$FC" 2>/dev/null || echo 0)+1)); echo "$C" > "$FC"
                    if [ "$C" -ge "$DEV_FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                         TS=$(date '+%b %d %H:%M:%S'); TSEC=$(date +%s)
                         echo "$TSEC" > "$FD"; echo "$TS" > "$FT"
                         log_msg "[ALERT] [$ROUTER_NAME] Device: $NAME ($TIP) Down" "UPTIME"
                         
                         D_MSG="**Router:** $ROUTER_NAME\n**Device:** $NAME ($TIP)\n**Time:** $TS"
                         if [ "$SILENT_ENABLE" = "YES" ] && [ "$IS_SILENT" -eq 1 ]; then
                             echo "Device $NAME DOWN: $TS" >> "$SILENT_BUFFER"
                         else
                             send_notification "🔴 Device Down" "$D_MSG" "15548997" "ALERT"
                         fi
                    fi
                fi
            ) &
        done
        wait
    fi

    sleep 1
done
EOF
chmod +x "$INSTALL_DIR/netwatchda.sh"
# --- 6. SERVICE SETUP (PROCD) ---
echo -e "\n${CYAN}⚙️  Configuring system service...${NC}"
cat <<EOF > "$SERVICE_PATH"
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

# Command Definitions
extra_command "status" "Check if monitor is running"
extra_command "logs" "View last 20 log entries"
extra_command "clear" "Clear the log file"
extra_command "discord" "Test Discord notification"
extra_command "telegram" "Test Telegram notification"
extra_command "credentials" "Update Discord/Telegram credentials"
extra_command "purge" "Interactive smart uninstaller"
extra_command "enable_service" "Enable service autostart"
extra_command "disable_service" "Disable service autostart"
extra_command "reload" "Reload configuration files"

start_service() {
    procd_open_instance
    procd_set_param command /bin/sh "$INSTALL_DIR/netwatchda.sh"
    procd_set_param respawn
    procd_set_param stdout 0
    procd_set_param stderr 0
    procd_close_instance
}

status() {
    if pgrep -f "netwatchda.sh" > /dev/null; then
        echo -e "\033[1;32m● netwatchda is RUNNING.\033[0m"
        echo "   PID: \$(pgrep -f "netwatchda.sh" | head -1)"
        echo "   Uptime Log: /tmp/netwatchda/nwda_uptime.log"
    else
        echo -e "\033[1;31m● netwatchda is STOPPED.\033[0m"
    fi
}

logs() {
    if [ -f "/tmp/netwatchda/nwda_uptime.log" ]; then
        echo -e "\033[1;34m--- Recent Activity ---\033[0m"
        tail -n 20 /tmp/netwatchda/nwda_uptime.log
    else
        echo "No log found."
    fi
}

clear() {
    echo "\$(date '+%b %d %H:%M:%S') - [SYSTEM] Log cleared manually." > "/tmp/netwatchda/nwda_uptime.log"
    echo "Log file cleared."
}

# Helper to source functions for manual commands
load_functions() {
    if [ -f "$INSTALL_DIR/netwatchda.sh" ]; then
        # Grep functions out of the core script safely
        # Ideally we just source it, but the loop runs immediately.
        # We rely on the fact that core script defines functions first.
        # However, simpler to replicate the send logic for test commands or use a separate lib.
        # For this implementation, we will duplicate the bare minimum load logic here for robustness.
        . "$INSTALL_DIR/nwda_settings.conf" 2>/dev/null
    fi
}

# Function to get HW key (Duplicated for Service Standalone usage)
get_hw_key() {
    local seed="nwda_v1_secure_seed_2025"
    local cpu_serial=\$(grep -i "serial" /proc/cpuinfo | head -1 | awk '{print \$3}')
    [ -z "\$cpu_serial" ] && cpu_serial="unknown_serial"
    local mac_addr=\$(cat /sys/class/net/eth0/address 2>/dev/null)
    [ -z "\$mac_addr" ] && mac_addr=\$(cat /sys/class/net/br-lan/address 2>/dev/null)
    [ -z "\$mac_addr" ] && mac_addr="00:00:00:00:00:00"
    echo -n "\${seed}\${cpu_serial}\${mac_addr}" | openssl dgst -sha256 | awk '{print \$2}'
}

discord() {
    load_functions
    local vault="$INSTALL_DIR/.vault.enc"
    if [ -f "\$vault" ]; then
         local key=\$(get_hw_key)
         local decrypted=\$(openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -iter 10000 -k "\$key" -in "\$vault" 2>/dev/null)
         local webhook=\$(echo "\$decrypted" | cut -d'|' -f1)
         
         if [ -n "\$webhook" ]; then
             echo "Sending Discord test..."
             curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🛠️ Discord Warning Test\", \"description\": \"**Router:** \$ROUTER_NAME\nManual warning triggered.\", \"color\": 16776960}]}" "\$webhook"
             echo "Sent."
         else
             echo "No Discord Webhook configured."
         fi
    else
         echo "Vault not found."
    fi
}

telegram() {
    load_functions
    local vault="$INSTALL_DIR/.vault.enc"
    if [ -f "\$vault" ]; then
         local key=\$(get_hw_key)
         local decrypted=\$(openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -iter 10000 -k "\$key" -in "\$vault" 2>/dev/null)
         local token=\$(echo "\$decrypted" | cut -d'|' -f3)
         local chat=\$(echo "\$decrypted" | cut -d'|' -f4)
         
         if [ -n "\$token" ]; then
             echo "Sending Telegram test..."
             curl -s -X POST "https://api.telegram.org/bot\$token/sendMessage" -d chat_id="\$chat" -d text="🛠️ Telegram Warning Test - \$ROUTER_NAME"
             echo "Sent."
         else
             echo "No Telegram Token configured."
         fi
    fi
}

credentials() {
    echo ""
    echo -e "\033[1;33m🔐 Credential Manager\033[0m"
    echo "1. Change Discord Credentials"
    echo "2. Change Telegram Credentials"
    echo "3. Change Both"
    printf "Choice [1-3]: "
    read c_choice </dev/tty
    
    # Decrypt existing first to preserve others
    local vault="$INSTALL_DIR/.vault.enc"
    local key=\$(get_hw_key)
    local current=\$(openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -iter 10000 -k "\$key" -in "\$vault" 2>/dev/null)
    
    local d_hook=\$(echo "\$current" | cut -d'|' -f1)
    local d_uid=\$(echo "\$current" | cut -d'|' -f2)
    local t_tok=\$(echo "\$current" | cut -d'|' -f3)
    local t_chat=\$(echo "\$current" | cut -d'|' -f4)
    
    if [ "\$c_choice" = "1" ] || [ "\$c_choice" = "3" ]; then
        printf "New Discord Webhook: "
        read d_hook </dev/tty
        printf "New Discord User ID: "
        read d_uid </dev/tty
    fi
    
    if [ "\$c_choice" = "2" ] || [ "\$c_choice" = "3" ]; then
        printf "New Telegram Token: "
        read t_tok </dev/tty
        printf "New Telegram Chat ID: "
        read t_chat </dev/tty
    fi
    
    local new_data="\${d_hook}|\${d_uid}|\${t_tok}|\${t_chat}"
    if echo -n "\$new_data" | openssl enc -aes-256-cbc -a -salt -pbkdf2 -iter 10000 -k "\$key" -out "\$vault" 2>/dev/null; then
        echo -e "\033[1;32m✅ Credentials updated and re-encrypted.\033[0m"
        /etc/init.d/netwatchda restart
    else
        echo -e "\033[1;31m❌ Encryption failed.\033[0m"
    fi
}

reload() {
    # Send SIGHUP to the running script (if supported) or just restart
    # Since we use simple loop, restart is safer to pick up config changes
    /etc/init.d/netwatchda restart
}

purge() {
    echo ""
    echo -e "\033[1;31m=======================================================\033[0m"
    echo -e "\033[1;31m🗑️  netwatchda Smart Uninstaller\033[0m"
    echo -e "\033[1;31m=======================================================\033[0m"
    echo ""
    echo "1. Full Uninstall (Remove everything)"
    echo "2. Keep Settings (Remove logic but keep config)"
    echo "3. Cancel"
    printf "Choice [1-3]: "
    read choice </dev/tty
    
    case "\$choice" in
        1)
            echo "🛑 Stopping service..."
            /etc/init.d/netwatchda stop
            /etc/init.d/netwatchda disable
            
            # Smart Dependency Check
            echo "📦 Checking dependencies..."
            printf "❓ Remove curl, openssl-util, and ca-bundle? (May break other apps) [y/N]: "
            read rem_deps </dev/tty
            if [ "\$rem_deps" = "y" ] || [ "\$rem_deps" = "Y" ]; then
                opkg remove curl openssl-util ca-bundle
                echo "Dependencies removed."
            else
                echo "Dependencies kept."
            fi

            echo "🧹 Cleaning up /tmp and buffers..."
            rm -rf "/tmp/netwatchda"
            echo "🗑️  Removing installation directory..."
            rm -rf "$INSTALL_DIR"
            echo "🔥 Self-destructing service file..."
            rm -f "$SERVICE_PATH"
            echo -e "\033[1;32m✅ netwatchda has been completely removed.\033[0m"
            ;;
        2)
            echo "🛑 Stopping service..."
            /etc/init.d/netwatchda stop
            /etc/init.d/netwatchda disable
            echo "🧹 Cleaning up /tmp..."
            rm -rf "/tmp/netwatchda"
            echo "🗑️  Removing core script..."
            rm -f "$INSTALL_DIR/netwatchda.sh"
            echo "🔥 Removing service file..."
            rm -f "$SERVICE_PATH"
            echo -e "\033[1;33m✅ Logic removed. Settings preserved in $INSTALL_DIR\033[0m"
            ;;
        *)
            echo "❌ Purge cancelled."
            exit 0
            ;;
    esac
}
EOF

chmod +x "$SERVICE_PATH"
"$SERVICE_PATH" enable >/dev/null 2>&1
"$SERVICE_PATH" restart >/dev/null 2>&1

# --- 7. FINAL SUCCESS & TEST NOTIFICATION ---
# Source the newly created script to load notification function into memory for this session
. "$INSTALL_DIR/netwatchda.sh" >/dev/null 2>&1

# Send Installation Complete Notification
NOW_FINAL=$(date '+%b %d, %Y %H:%M:%S')
MSG="**Router:** $router_name_input\n**Time:** $NOW_FINAL\n**Status:** Service Installed & Active"
send_notification "🚀 netwatchda Service Started" "$MSG" "1752220" "INFO"

# --- FINAL OUTPUT ---
echo ""
echo -e "${GREEN}=======================================================${NC}"
echo -e "${BOLD}${GREEN}✅ Installation complete!${NC}"
echo -e "${CYAN}📂 Folder:${NC} $INSTALL_DIR"
echo -e "${GREEN}=======================================================${NC}"
echo -e "\n${BOLD}Quick Commands:${NC}"
echo -e "  Uninstall        : ${RED}/etc/init.d/netwatchda purge${NC}"
echo -e "  Manage Creds     : ${YELLOW}/etc/init.d/netwatchda credentials${NC}"
echo -e "  Edit Settings    : ${CYAN}$CONFIG_FILE${NC}"
echo -e "  Edit IP List     : ${CYAN}$IP_LIST_FILE${NC}"
echo -e "  Restart          : ${YELLOW}/etc/init.d/netwatchda restart${NC}"
echo ""
echo ""