#!/bin/sh
# netwatchdta Installer - Automated Setup for OpenWrt (Optimized & Portable)
# Copyright (C) 2025 panoc
# Licensed under the GNU General Public License v3.0

# ==============================================================================
#  SELF-CLEANUP MECHANISM
# ==============================================================================
# This ensures the installer script deletes itself after execution to keep
# the /tmp directory clean.
SCRIPT_NAME="$0"
cleanup() {
    rm -f "$SCRIPT_NAME"
    exit
}
trap cleanup INT TERM EXIT

# ==============================================================================
#  TERMINAL COLOR DEFINITIONS
# ==============================================================================
NC='\033[0m'        # No Color (Reset)
BOLD='\033[1m'      # Bold Text
RED='\033[1;31m'    # Light Red (Errors)
GREEN='\033[1;32m'  # Light Green (Success)
BLUE='\033[1;34m'   # Light Blue (Headers)
CYAN='\033[1;36m'   # Light Cyan (Info)
YELLOW='\033[1;33m' # Bold Yellow (Warnings)
WHITE='\033[1;37m'  # Bold White (High Contrast)

# ==============================================================================
#  INPUT VALIDATION HELPER FUNCTIONS
# ==============================================================================

# Function: ask_yn
# Purpose:  Forces the user to answer 'y' or 'n'. Ignores all other keys.
ask_yn() {
    local prompt="$1"
    while true; do
        printf "${BOLD}%s [y/n]: ${NC}" "$prompt"
        read input_val </dev/tty
        case "$input_val" in
            y|Y) 
                ANSWER_YN="y"
                return 0 
                ;;
            n|N) 
                ANSWER_YN="n"
                return 1 
                ;;
            *) 
                # Invalid input. Loop silently to ask again.
                ;; 
        esac
    done
}

# Function: ask_opt
# Purpose:  Forces the user to select a number between 1 and MAX.
ask_opt() {
    local prompt="$1"
    local max="$2"
    while true; do
        printf "${BOLD}%s [1-%s]: ${NC}" "$prompt" "$max"
        read input_val </dev/tty
        # Validate that input is a single digit within range
        if echo "$input_val" | grep -qE "^[1-$max]$"; then
            ANSWER_OPT="$input_val"
            break
        fi
        # Invalid input. Loop silently.
    done
}

# ==============================================================================
#  PORTABLE FETCH WRAPPER (INSTALLER VERSION)
# ==============================================================================
# Defined early so the installer can use it for connectivity tests.
safe_fetch() {
    local url="$1"
    local data="$2"   # JSON Payload
    local header="$3" # e.g. "Content-Type: application/json"

    # STRATEGY 1: Standard Linux (Curl)
    if command -v curl >/dev/null 2>&1; then
        curl -s -k -X POST -H "$header" -d "$data" "$url" >/dev/null 2>&1
        return $?
    fi

    # STRATEGY 2: OpenWrt Native (uclient-fetch)
    if command -v uclient-fetch >/dev/null 2>&1; then
        if uclient-fetch --help 2>&1 | grep -q "\-\-header"; then
            uclient-fetch --no-check-certificate --header="$header" --post-data="$data" "$url" -O /dev/null >/dev/null 2>&1
            return $?
        fi
    fi

    # STRATEGY 3: Wget (Standard Linux Alternative)
    if command -v wget >/dev/null 2>&1; then
        wget -q --no-check-certificate --header="$header" \
             --post-data="$data" "$url" -O /dev/null
        return $?
    fi
    
    return 1 # Failure: No tool found
}

# ==============================================================================
#  INSTALLER HEADER
# ==============================================================================
echo -e "${BLUE}=======================================================${NC}"
echo -e "${BOLD}${CYAN}🚀 netwatchdta Automated Setup${NC} v2.32 (Final)"
echo -e "${BLUE}⚖️  License: GNU GPLv3${NC}"
echo -e "${BLUE}=======================================================${NC}"
echo ""

# --- 0. PRE-INSTALLATION CONFIRMATION ---
ask_yn "❓ This will begin the installation process. Continue?"
if [ "$ANSWER_YN" = "n" ]; then
    echo -e "${RED}❌ Installation aborted by user. Cleaning up...${NC}"
    exit 0
fi

# ==============================================================================
#  DIRECTORY & FILE PATH DEFINITIONS
# ==============================================================================
INSTALL_DIR="/root/netwatchdta"
TMP_DIR="/tmp/netwatchdta"
CONFIG_FILE="$INSTALL_DIR/settings.conf"
IP_LIST_FILE="$INSTALL_DIR/device_ips.conf"
REMOTE_LIST_FILE="$INSTALL_DIR/remote_ips.conf"
VAULT_FILE="$INSTALL_DIR/.vault.enc"
SERVICE_NAME="netwatchdta"
SERVICE_PATH="/etc/init.d/$SERVICE_NAME"

# Ensure temp directory exists for installation logs
mkdir -p "$TMP_DIR"

# ==============================================================================
#  STEP 1: SYSTEM READINESS CHECKS
# ==============================================================================
echo -e "\n${BOLD}📦 Checking system readiness...${NC}"

# 1. Check Flash Storage (Root partition)
FREE_FLASH_KB=$(df / | awk 'NR==2 {print $4}')
MIN_FLASH_KB=3072 # 3MB Threshold

# 2. Check RAM (/tmp partition)
FREE_RAM_KB=$(df /tmp | awk 'NR==2 {print $4}')
MIN_RAM_KB=4096 # 4MB Threshold

# 3. Check Physical Memory for Execution Method Auto-Detection
# Rule: >= 256MB (262144 kB) = Parallel (1), < 256MB = Sequential (2)
TOTAL_PHY_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
if [ "$TOTAL_PHY_MEM_KB" -ge 262144 ]; then
    AUTO_EXEC_METHOD="1"
    EXEC_MSG="Parallel (High RAM Detected: $((TOTAL_PHY_MEM_KB/1024))MB)"
else
    AUTO_EXEC_METHOD="2"
    EXEC_MSG="Sequential (Low RAM Detected: $((TOTAL_PHY_MEM_KB/1024))MB)"
fi

# 4. Define Dependency List
MISSING_DEPS=""
if ! command -v uclient-fetch >/dev/null 2>&1; then
    command -v curl >/dev/null 2>&1 || MISSING_DEPS="$MISSING_DEPS curl"
fi
[ -f /etc/ssl/certs/ca-certificates.crt ] || command -v opkg >/dev/null && opkg list-installed | grep -q ca-bundle || MISSING_DEPS="$MISSING_DEPS ca-bundle"
command -v openssl >/dev/null 2>&1 || MISSING_DEPS="$MISSING_DEPS openssl-util"

# RAM Guard Check
if [ "$FREE_RAM_KB" -lt "$MIN_RAM_KB" ]; then
    echo -e "${RED}❌ ERROR: Insufficient RAM for operations!${NC}"
    echo -e "${YELLOW}Available: $((FREE_RAM_KB / 1024))MB | Required: 4MB${NC}"
    exit 1
fi

# Dependency Installation Logic
if [ -n "$MISSING_DEPS" ]; then
    echo -e "${CYAN}🔍 Missing dependencies found:${BOLD}$MISSING_DEPS${NC}"
    
    if [ "$FREE_FLASH_KB" -lt "$MIN_FLASH_KB" ]; then
        echo -e "${RED}❌ ERROR: Insufficient Flash storage to install dependencies!${NC}"
        echo -e "${YELLOW}Available: $((FREE_FLASH_KB / 1024))MB | Required: 3MB${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ Sufficient Flash space found: $((FREE_FLASH_KB / 1024))MB available.${NC}"
        
        ask_yn "❓ Download missing dependencies?"
        if [ "$ANSWER_YN" = "y" ]; then
             echo -e "${YELLOW}📥 Updating package lists...${NC}"
             opkg update --no-check-certificate > /dev/null 2>&1
             
             echo -e "${YELLOW}📥 Installing:$MISSING_DEPS...${NC}"
             opkg install --no-check-certificate $MISSING_DEPS > /tmp/nwdta_install_err.log 2>&1
             
             if [ $? -ne 0 ]; then
                echo -e "${RED}❌ Error installing dependencies. Log:${NC}"
                cat /tmp/nwdta_install_err.log
                exit 1
             fi
             echo -e "${GREEN}✅ Dependencies installed successfully.${NC}"
        else
             echo -e "${RED}❌ Cannot proceed without dependencies. Aborting.${NC}"
             exit 1
        fi
    fi
else
    echo -e "${GREEN}✅ All dependencies are installed.${NC}"
    echo -e "${GREEN}✅ Flash storage check passed: $((FREE_FLASH_KB / 1024))MB available.${NC}"
fi

echo -e "${GREEN}✅ System Ready.${NC}"
echo -e "${GREEN}✅ Execution Mode Auto-Selected: ${BOLD}${WHITE}$EXEC_MSG${NC}"

# ==============================================================================
#  STEP 2: SMART UPGRADE / INSTALL CHECK
# ==============================================================================
KEEP_CONFIG=0
if [ -f "$CONFIG_FILE" ]; then
    echo -e "\n${YELLOW}⚠️  Existing installation found.${NC}"
    echo -e "${BOLD}${WHITE}1.${NC} Keep settings (Upgrade)"
    echo -e "${BOLD}${WHITE}2.${NC} Clean install"
    
    ask_opt "Enter choice" "2"
    
    if [ "$ANSWER_OPT" = "1" ]; then
        echo -e "${CYAN}🔧 Upgrading logic while keeping settings...${NC}"
        KEEP_CONFIG=1
    else
        echo -e "${RED}🧹 Performing clean install...${NC}"
        /etc/init.d/netwatchdta stop >/dev/null 2>&1
        rm -rf "$INSTALL_DIR"
    fi
fi

mkdir -p "$INSTALL_DIR"

# ==============================================================================
#  STEP 3: CONFIGURATION INPUTS
# ==============================================================================
if [ "$KEEP_CONFIG" -eq 0 ]; then
    echo -e "\n${BLUE}--- Configuration ---${NC}"
    
    # 3a. Router Name
    printf "${BOLD}🏷️  Enter Router Name (e.g., MyRouter): ${NC}"
    read router_name_input </dev/tty
    
    # 3b. Discord Setup Loop
    DISCORD_ENABLE_VAL="NO"
    DISCORD_WEBHOOK=""
    DISCORD_USERID=""
    
    echo -e "\n${BLUE}--- Notification Settings ---${NC}"
    
    while :; do
        ask_yn "1. Enable Discord Notifications?"
        if [ "$ANSWER_YN" = "n" ]; then
            DISCORD_ENABLE_VAL="NO"
            break
        fi
        
        DISCORD_ENABLE_VAL="YES"
        printf "${BOLD}   > Enter Discord Webhook URL: ${NC}"
        read DISCORD_WEBHOOK </dev/tty
        printf "${BOLD}   > Enter Discord User ID (for @mentions): ${NC}"
        read DISCORD_USERID </dev/tty
        
        ask_yn "   ❓ Send test notification to Discord now?"
        if [ "$ANSWER_YN" = "y" ]; then
             echo -e "${YELLOW}   🧪 Sending Discord test...${NC}"
             safe_fetch "$DISCORD_WEBHOOK" "{\"content\": \"<@$DISCORD_USERID>\", \"embeds\": [{\"title\": \"🧪 Setup Test\", \"description\": \"Discord configured successfully for **$router_name_input**.\", \"color\": 1752220}]}" "Content-Type: application/json"
             
             echo -e "${CYAN}   ℹ️  Signal sent. Please check your Discord channel.${NC}"
             ask_yn "   ❓ Did you receive the notification?"
             
             if [ "$ANSWER_YN" = "y" ]; then
                 echo -e "${GREEN}   ✅ Discord configured.${NC}"
                 break
             else
                 echo -e "${RED}   ❌ Test failed.${NC}"
                 echo -e "${BOLD}${WHITE}   1.${NC} Input credentials again"
                 echo -e "${BOLD}${WHITE}   2.${NC} Disable Discord and continue"
                 echo -e "${BOLD}${WHITE}   3.${NC} Cancel installation"
                 ask_opt "   Choice" "3"
                 if [ "$ANSWER_OPT" = "2" ]; then
                     DISCORD_ENABLE_VAL="NO"
                     break
                 fi
                 if [ "$ANSWER_OPT" = "3" ]; then
                     echo -e "${RED}❌ Installation cancelled by user.${NC}"
                     exit 0
                 fi
             fi
        else
            break
        fi
    done

    # 3c. Telegram Setup Loop
    TELEGRAM_ENABLE_VAL="NO"
    TELEGRAM_BOT_TOKEN=""
    TELEGRAM_CHAT_ID=""
    
    while :; do
        ask_yn "2. Enable Telegram Notifications?"
        if [ "$ANSWER_YN" = "n" ]; then
            TELEGRAM_ENABLE_VAL="NO"
            break
        fi
        
        TELEGRAM_ENABLE_VAL="YES"
        printf "${BOLD}   > Enter Telegram Bot Token: ${NC}"
        read TELEGRAM_BOT_TOKEN </dev/tty
        printf "${BOLD}   > Enter Telegram Chat ID: ${NC}"
        read TELEGRAM_CHAT_ID </dev/tty
        
        ask_yn "   ❓ Send test notification to Telegram now?"
        if [ "$ANSWER_YN" = "y" ]; then
            echo -e "${YELLOW}   🧪 Sending Telegram test...${NC}"
            safe_fetch "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" "{\"chat_id\": \"$TELEGRAM_CHAT_ID\", \"text\": \"🧪 Setup Test - Telegram configured successfully for $router_name_input.\"}" "Content-Type: application/json"
            
            echo -e "${CYAN}   ℹ️  Signal sent. Please check your Telegram chat.${NC}"
            ask_yn "   ❓ Did you receive the notification?"
            
            if [ "$ANSWER_YN" = "y" ]; then
                echo -e "${GREEN}   ✅ Telegram configured.${NC}"
                break
            else
                echo -e "${RED}   ❌ Test failed.${NC}"
                echo -e "${BOLD}${WHITE}   1.${NC} Input credentials again"
                echo -e "${BOLD}${WHITE}   2.${NC} Disable Telegram and continue"
                echo -e "${BOLD}${WHITE}   3.${NC} Cancel installation"
                ask_opt "   Choice" "3"
                if [ "$ANSWER_OPT" = "2" ]; then
                    TELEGRAM_ENABLE_VAL="NO"
                    break
                fi
                if [ "$ANSWER_OPT" = "3" ]; then
                     echo -e "${RED}❌ Installation cancelled by user.${NC}"
                     exit 0
                fi
            fi
        else
            break
        fi
    done
    
    # 3e. Silent Hours
    SILENT_ENABLE_VAL="NO"
    user_silent_start="23"
    user_silent_end="07"
    
    echo -e "\n${BLUE}--- Silent Hours (Mute Alerts) ---${NC}"
    ask_yn "🌙 Enable Silent Hours?"
    
    if [ "$ANSWER_YN" = "y" ]; then
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
    
    # 3f. Heartbeat Logic
    HB_VAL="NO"
    HB_SEC="86400"
    HB_TARGET="BOTH"
    HB_START_HOUR="12"
    
    echo -e "\n${BLUE}--- Heartbeat Settings ---${NC}"
    ask_yn "💓 Enable Heartbeat (System check-in)?"
    
    if [ "$ANSWER_YN" = "y" ]; then
        HB_VAL="YES"
        printf "${BOLD}   > Interval in HOURS (e.g., 24): ${NC}"
        read hb_hours </dev/tty
        if echo "$hb_hours" | grep -qE '^[0-9]+$'; then
             HB_SEC=$((hb_hours * 3600))
        else
             HB_SEC=86400 # Default fallback
        fi

        # Ask for Start Hour
        while :; do
            printf "${BOLD}   > Start Hour (0-23) [Default 12]: ${NC}"
            read HB_START_HOUR </dev/tty
            if [ -z "$HB_START_HOUR" ]; then HB_START_HOUR="12"; break; fi
            if echo "$HB_START_HOUR" | grep -qE '^[0-9]+$' && [ "$HB_START_HOUR" -ge 0 ] && [ "$HB_START_HOUR" -le 23 ]; then
                break
            fi
            echo -e "${RED}   ❌ Invalid hour.${NC}"
        done
        
        # --- HEARTBEAT TARGET SELECTOR ---
        if [ "$DISCORD_ENABLE_VAL" = "YES" ] && [ "$TELEGRAM_ENABLE_VAL" = "YES" ]; then
             echo -e "${BOLD}${WHITE}   Where to send Heartbeat?${NC}"
             echo -e "   1. ${BOLD}${WHITE}Discord Only${NC}"
             echo -e "   2. ${BOLD}${WHITE}Telegram Only${NC}"
             echo -e "   3. ${BOLD}${WHITE}Both${NC}"
             ask_opt "   Choice" "3"
             case "$ANSWER_OPT" in
                 1) HB_TARGET="DISCORD" ;;
                 2) HB_TARGET="TELEGRAM" ;;
                 3) HB_TARGET="BOTH" ;;
             esac
        elif [ "$DISCORD_ENABLE_VAL" = "YES" ]; then
             HB_TARGET="DISCORD"
        elif [ "$TELEGRAM_ENABLE_VAL" = "YES" ]; then
             HB_TARGET="TELEGRAM"
        else
             HB_TARGET="NONE"
        fi
    fi

    # 3g. Summary Display
    echo -e "\n${BLUE}--- 📋 Configuration Summary ---${NC}"
    echo -e " • Router Name    : ${BOLD}${WHITE}$router_name_input${NC}"
    echo -e " • Discord        : ${BOLD}${WHITE}$DISCORD_ENABLE_VAL${NC}"
    echo -e " • Telegram       : ${BOLD}${WHITE}$TELEGRAM_ENABLE_VAL${NC}"
    echo -e " • Silent Mode    : ${BOLD}${WHITE}$SILENT_ENABLE_VAL${NC} (Start: $user_silent_start, End: $user_silent_end)"
    echo -e " • Heartbeat      : ${BOLD}${WHITE}$HB_VAL${NC} (Start Hour: $HB_START_HOUR)"
    echo -e " • Execution Mode : ${BOLD}${WHITE}$EXEC_MSG${NC}"

    # ==============================================================================
    #  STEP 4: GENERATE CONFIGURATION FILES
    # ==============================================================================
    cat <<EOF > "$CONFIG_FILE"
# settings.conf - Configuration for netwatchdta
# Note: Credentials are stored in .vault.enc (Method: OPENSSL)
ROUTER_NAME="$router_name_input"
EXEC_METHOD=$AUTO_EXEC_METHOD # 1 = Parallel (Fast, High RAM > 256MB), 2 = Sequential (Safe, Low RAM < 256MB)

[Log Settings]
UPTIME_LOG_MAX_SIZE=51200 # Max log file size in bytes for uptime tracking. Default is 51200.
PING_LOG_ENABLE=NO # Enable or disable detailed ping logging (YES/NO). Default is NO.

[Notification Settings]
DISCORD_ENABLE=$DISCORD_ENABLE_VAL # Global toggle for Discord notifications (YES/NO). Default is NO.
TELEGRAM_ENABLE=$TELEGRAM_ENABLE_VAL # Global toggle for Telegram notifications (YES/NO). Default is NO.
SILENT_ENABLE=$SILENT_ENABLE_VAL # Mutes Discord alerts during specific hours (YES/NO). Default is NO.
SILENT_START=$user_silent_start # Hour to start silent mode (0-23). Default is 23.
SILENT_END=$user_silent_end # Hour to end silent mode (0-23). Default is 07.

[Discord]
# Toggle mentions <@UserID> for specific events (YES/NO)
DISCORD_MENTION_LOCAL=YES # Mention on Local Device Down/Up events. Default is YES.
DISCORD_MENTION_REMOTE=YES # Mention on Remote Device Down/Up events. Default is YES.
DISCORD_MENTION_NET=YES # Mention on Internet Connectivity loss/restore. Default is YES.
DISCORD_MENTION_HB=NO # Mention inside Heartbeat reports. Default is NO.

[Performance Settings]
CPU_GUARD_THRESHOLD=2.0 # Max CPU load average allowed before skipping pings. Default is 2.0.
RAM_GUARD_MIN_FREE=4096 # Minimum free RAM in KB required to run alerts. Default is 4096.

[Heartbeat]
HEARTBEAT=$HB_VAL # Periodic I am alive notification (YES/NO). Default is NO.
HB_INTERVAL=$HB_SEC # Seconds between heartbeat messages. Default is 86400.
HB_TARGET=$HB_TARGET # Target for Heartbeat: DISCORD, TELEGRAM, BOTH
HB_START_HOUR=$HB_START_HOUR # Time of Heartbeat will start, also if 24H interval is selected time of day Heartbeat will notify. Default is 12.

[Internet Connectivity]
EXT_ENABLE=YES # Global toggle for internet monitoring (YES/NO). Default is YES.
EXT_IP=1.1.1.1 # Primary external IP to monitor. Default is 1.1.1.1.
EXT_IP2=8.8.8.8 # Secondary external IP for redundancy. Default is 8.8.8.8.
EXT_SCAN_INTERVAL=60 # Seconds between internet checks. Default is 60.
EXT_FAIL_THRESHOLD=1 # Failed cycles before internet alert. Default is 1.
EXT_PING_COUNT=4 # Number of packets per internet check. Default is 4.
EXT_PING_TIMEOUT=1 # Seconds to wait for ping response. Default is 1.

[Local Device Monitoring]
DEVICE_MONITOR=YES # Enable monitoring of local IPs (YES/NO). Default is YES.
DEV_SCAN_INTERVAL=10 # Seconds between local device checks. Default is 10.
DEV_FAIL_THRESHOLD=3 # Failed cycles before device alert. Default is 3.
DEV_PING_COUNT=4 # Number of packets per device check. Default is 4.

[Remote Device Monitoring]
REMOTE_MONITOR=YES # Enable monitoring of Remote IPs (YES/NO). Default is YES.
REM_SCAN_INTERVAL=30 # Seconds between remote device checks. Default is 30.
REM_FAIL_THRESHOLD=2 # Failed cycles before remote alert. Default is 2.
REM_PING_COUNT=4 # Number of packets per remote check. Default is 4.
EOF

    # Generate default IP list
    cat <<EOF > "$IP_LIST_FILE"
# Format: IP_ADDRESS @ NAME
# Example: 192.168.1.50 @ Home Server
EOF
    # Attempt to auto-detect local gateway IP for user convenience
    LOCAL_IP=$(uci -q get network.lan.ipaddr || ip addr show br-lan | grep -oE 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 | awk '{print $2}')
    [ -n "$LOCAL_IP" ] && echo "$LOCAL_IP @ Router Gateway" >> "$IP_LIST_FILE"

    # Generate default Remote IP list
    cat <<EOF > "$REMOTE_LIST_FILE"
# Format: IP_ADDRESS @ NAME
# Example: 142.250.180.206 @ Google Server
# Note: These are ONLY checked if Internet is UP (Strict Dependency).
EOF
fi

# ==============================================================================
#  STEP 5: SECURE CREDENTIAL VAULT (OPENSSL ENFORCED)
# ==============================================================================
echo -e "\n${CYAN}🔐 Securing credentials (OpenSSL AES-256)...${NC}"

# Function: get_hw_key (FIXED: Improved AWK for different CPUINFO formats)
get_hw_key() {
    local seed="nwdta_v1_secure_seed_2025"
    # Improved parsing: Splits by ':' and trims spaces to handle "Serial : XXX" vs "Serial: XXX"
    local cpu_serial=$(grep -i "serial" /proc/cpuinfo | head -1 | awk -F: '{print $2}' | tr -d ' ')
    [ -z "$cpu_serial" ] && cpu_serial="unknown_serial"
    local mac_addr=$(cat /sys/class/net/*/address 2>/dev/null | grep -v "00:00:00:00:00:00" | sort | head -1)
    [ -z "$mac_addr" ] && mac_addr="00:00:00:00:00:00"
    echo -n "${seed}${cpu_serial}${mac_addr}" | openssl dgst -sha256 | awk '{print $2}'
}

# Create the Vault Data String
# Format: DISCORD_WEBHOOK|DISCORD_USERID|TELEGRAM_BOT_TOKEN|TELEGRAM_CHAT_ID
if [ "$KEEP_CONFIG" -eq 0 ]; then
    VAULT_DATA="${DISCORD_WEBHOOK}|${DISCORD_USERID}|${TELEGRAM_BOT_TOKEN}|${TELEGRAM_CHAT_ID}"
    
    # FORCED OPENSSL AES-256-CBC
    HW_KEY=$(get_hw_key)
    if echo -n "$VAULT_DATA" | openssl enc -aes-256-cbc -a -salt -pbkdf2 -iter 10000 -k "$HW_KEY" -out "$VAULT_FILE" 2>/dev/null; then
        echo -e "${GREEN}✅ Credentials Encrypted and locked to this hardware.${NC}"
    else
        echo -e "${RED}❌ OpenSSL Encryption failed! Check openssl-util.${NC}"
    fi
fi
# ==============================================================================
#  STEP 6: GENERATE CORE SCRIPT (THE ENGINE)
# ==============================================================================
echo -e "\n${CYAN}🛠️  Generating core script...${NC}"

cat <<'EOF' > "$INSTALL_DIR/netwatchdta.sh"
#!/bin/sh
# netwatchdta - Network Monitoring for OpenWrt (Core Engine)

# --- DIRECTORY DEFS ---
BASE_DIR="/root/netwatchdta"
IP_LIST_FILE="$BASE_DIR/device_ips.conf"
REMOTE_LIST_FILE="$BASE_DIR/remote_ips.conf"
CONFIG_FILE="$BASE_DIR/settings.conf"
VAULT_FILE="$BASE_DIR/.vault.enc"

# Flash Paths
SILENT_BUFFER="$BASE_DIR/nwdta_silent_buffer"
OFFLINE_BUFFER="$BASE_DIR/nwdta_offline_buffer"

# RAM Paths
TMP_DIR="/tmp/netwatchdta"
LOGFILE="$TMP_DIR/nwdta_uptime.log"
PINGLOG="$TMP_DIR/nwdta_ping.log"
NET_STATUS_FILE="$TMP_DIR/nwdta_net_status"

# Initialization
mkdir -p "$TMP_DIR"
if [ ! -f "$SILENT_BUFFER" ]; then touch "$SILENT_BUFFER"; fi
if [ ! -f "$LOGFILE" ]; then touch "$LOGFILE"; fi
if [ ! -f "$NET_STATUS_FILE" ]; then echo "UP" > "$NET_STATUS_FILE"; fi

# Tracking Variables
LAST_EXT_CHECK=0
LAST_DEV_CHECK=0
LAST_REM_CHECK=0
LAST_HB_CHECK=0
EXT_UP_GLOBAL=1
LAST_CFG_LOAD=0

# --- HELPER: LOGGING ---
log_msg() {
    local msg="$1"
    local type="$2" # UPTIME or PING
    local ts="$3"   # Passed from main loop
    
    if [ "$type" = "PING" ] && [ "$PING_LOG_ENABLE" = "YES" ]; then
        echo "$ts - $msg" >> "$PINGLOG"
        if [ -f "$PINGLOG" ] && [ $(wc -c < "$PINGLOG") -gt "$UPTIME_LOG_MAX_SIZE" ]; then
            echo "$ts - [SYSTEM] Log rotated." > "$PINGLOG"
        fi
    elif [ "$type" = "UPTIME" ]; then
        echo "$ts - $msg" >> "$LOGFILE"
        if [ -f "$LOGFILE" ] && [ $(wc -c < "$LOGFILE") -gt "$UPTIME_LOG_MAX_SIZE" ]; then
            echo "$ts - [SYSTEM] Log rotated." > "$LOGFILE"
        fi
    fi
}

# --- HELPER: CONFIG LOADER (NUCLEAR FIX) ---
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        local cur_cfg_sig=$(ls -l --time-style=+%s "$CONFIG_FILE" 2>/dev/null || ls -l "$CONFIG_FILE")
        if [ "$cur_cfg_sig" != "$LAST_CFG_LOAD" ]; then
            # EXPLANATION OF FIX:
            # 1. /^\[.*\]/d         -> Remove [Header] lines
            # 2. s/[ \t]*#.*//      -> Remove comments (#) and any spaces/tabs before them
            # 3. s/[ \t]*$//        -> Remove any remaining trailing spaces at end of line
            # 4. tr -d '\r'         -> Remove Windows carriage returns
            eval "$(sed '/^\[.*\]/d' "$CONFIG_FILE" | sed 's/[ \t]*#.*//' | sed 's/[ \t]*$//' | tr -d '\r')"
            LAST_CFG_LOAD="$cur_cfg_sig"
        fi
    fi
}

# --- HELPER: HW KEY GENERATION (ROBUST) ---
get_hw_key() {
    local seed="nwdta_v1_secure_seed_2025"
    local cpu_serial=$(grep -i "serial" /proc/cpuinfo | head -1 | awk -F: '{print $2}' | tr -d ' ')
    [ -z "$cpu_serial" ] && cpu_serial="unknown_serial"
    local mac_addr=$(cat /sys/class/net/*/address 2>/dev/null | grep -v "00:00:00:00:00:00" | sort | head -1)
    [ -z "$mac_addr" ] && mac_addr="00:00:00:00:00:00"
    echo -n "${seed}${cpu_serial}${mac_addr}" | openssl dgst -sha256 | awk '{print $2}'
}

# --- HELPER: CREDENTIAL DECRYPTION ---
load_credentials() {
    if [ -f "$VAULT_FILE" ]; then
        local key=$(get_hw_key)
        local decrypted=$(openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -iter 10000 -k "$key" -in "$VAULT_FILE" 2>/dev/null)
        if [ -n "$decrypted" ]; then
            # Trim potential whitespace/newlines from decrypted output
            decrypted=$(echo "$decrypted" | tr -d '\r')
            export DISCORD_WEBHOOK="${decrypted%%|*}"
            local temp1="${decrypted#*|}"
            export DISCORD_USERID="${temp1%%|*}"
            local temp2="${temp1#*|}"
            export TELEGRAM_BOT_TOKEN="${temp2%%|*}"
            export TELEGRAM_CHAT_ID="${temp2#*|}"
            return 0
        fi
    fi
    return 1
}

# ==============================================================================
#  PORTABLE FETCH WRAPPER
# ==============================================================================
safe_fetch() {
    local url="$1"
    local data="$2"
    local header="$3"

    if command -v uclient-fetch >/dev/null 2>&1; then
        if uclient-fetch --help 2>&1 | grep -q "\-\-header"; then
            uclient-fetch --no-check-certificate --header="$header" --post-data="$data" "$url" -O /dev/null >/dev/null 2>&1
            return $?
        fi
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -s -k -X POST -H "$header" -d "$data" "$url" >/dev/null 2>&1
        return $?
    fi

    if command -v wget >/dev/null 2>&1; then
        wget -q --no-check-certificate --header="$header" \
             --post-data="$data" "$url" -O /dev/null
        return $?
    fi
    return 1
}

# --- INTERNAL: SEND PAYLOAD ---
send_payload() {
    local title="$1"
    local desc="$2"
    local color="$3"
    local filter="$4"
    local telegram_text="$5" 
    local do_mention="$6"
    local success=0

    # 1. DISCORD
    if [ "$DISCORD_ENABLE" = "YES" ] && [ -n "$DISCORD_WEBHOOK" ]; then
        if [ -z "$filter" ] || [ "$filter" = "BOTH" ] || [ "$filter" = "DISCORD" ]; then
             local json_desc=$(echo "$desc" | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
             local d_payload
             if [ "$do_mention" = "YES" ] && [ -n "$DISCORD_USERID" ]; then
                d_payload="{\"content\": \"<@$DISCORD_USERID>\", \"embeds\": [{\"title\": \"$title\", \"description\": \"$json_desc\", \"color\": $color}]}"
             else
                d_payload="{\"embeds\": [{\"title\": \"$title\", \"description\": \"$json_desc\", \"color\": $color}]}"
             fi
             if safe_fetch "$DISCORD_WEBHOOK" "$d_payload" "Content-Type: application/json"; then success=1; else log_msg "[ERROR] Discord send failed." "UPTIME" "$NOW_HUMAN"; fi
        fi
    fi

    # 2. TELEGRAM
    if [ "$TELEGRAM_ENABLE" = "YES" ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        if [ -z "$filter" ] || [ "$filter" = "BOTH" ] || [ "$filter" = "TELEGRAM" ]; then
             local t_msg="$title
$desc"
             if [ -n "$telegram_text" ]; then t_msg="$telegram_text"; fi
             local t_safe_text=$(echo "$t_msg" | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}')
             local t_payload="{\"chat_id\": \"$TELEGRAM_CHAT_ID\", \"text\": \"$t_safe_text\"}"
             if safe_fetch "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" "$t_payload" "Content-Type: application/json"; then success=1; else log_msg "[ERROR] Telegram send failed." "UPTIME" "$NOW_HUMAN"; fi
        fi
    fi
    return $((1 - success))
}

# --- HELPER: NOTIFICATION SENDER ---
send_notification() {
    local title="$1"
    local desc="$2"
    local color="$3"
    local type="$4"
    local filter="$5"
    local force="$6"
    local tel_text="$7"
    local mention="$8"
    
    if [ "$CUR_FREE_RAM" -lt "$RAM_GUARD_MIN_FREE" ]; then
        log_msg "[SYSTEM] RAM LOW ($CUR_FREE_RAM KB). Notification skipped." "UPTIME" "$NOW_HUMAN"
        return
    fi
    
    sleep 1
    local net_stat="UP"
    [ -f "$NET_STATUS_FILE" ] && read net_stat < "$NET_STATUS_FILE"

    if [ "$net_stat" = "DOWN" ] && [ "$force" != "YES" ]; then
        if [ -f "$OFFLINE_BUFFER" ] && [ $(wc -c < "$OFFLINE_BUFFER") -ge 5120 ]; then
             log_msg "[BUFFER] Buffer full. Dropped." "UPTIME" "$NOW_HUMAN"
             return
        fi
        local clean_desc=$(echo "$desc" | sed ':a;N;$!ba;s/\n/__BR__/g')
        local clean_tel=$(echo "$tel_text" | sed ':a;N;$!ba;s/\n/__BR__/g')
        echo "${title}|||${clean_desc}|||${color}|||${filter}|||${clean_tel}|||${mention}" >> "$OFFLINE_BUFFER"
        log_msg "[BUFFER] Internet Down. Notification buffered." "UPTIME" "$NOW_HUMAN"
        return
    fi

    if ! send_payload "$title" "$desc" "$color" "$filter" "$tel_text" "$mention"; then
        if [ -f "$OFFLINE_BUFFER" ] && [ $(wc -c < "$OFFLINE_BUFFER") -ge 5120 ]; then
             log_msg "[BUFFER] Buffer full. Failed." "UPTIME" "$NOW_HUMAN"
        else
             local clean_desc=$(echo "$desc" | sed ':a;N;$!ba;s/\n/__BR__/g')
             local clean_tel=$(echo "$tel_text" | sed ':a;N;$!ba;s/\n/__BR__/g')
             echo "${title}|||${clean_desc}|||${color}|||${filter}|||${clean_tel}|||${mention}" >> "$OFFLINE_BUFFER"
             log_msg "[BUFFER] Send failed. Buffered." "UPTIME" "$NOW_HUMAN"
        fi
    fi
}

# --- HELPER: FLUSH BUFFER ---
flush_buffer() {
    if [ -f "$OFFLINE_BUFFER" ]; then
        log_msg "[SYSTEM] Internet Restored. Flushing buffer..." "UPTIME" "$NOW_HUMAN"
        while IFS="|||" read -r b_title b_desc_raw b_color b_filter b_tel_raw b_mention; do
             local b_desc=$(echo "$b_desc_raw" | sed 's/__BR__/\\n/g')
             local b_tel=$(echo "$b_tel_raw" | sed 's/__BR__/\n/g')
             sleep 1 
             send_payload "$b_title" "$b_desc" "$b_color" "$b_filter" "$b_tel" "$b_mention"
        done < "$OFFLINE_BUFFER"
        rm -f "$OFFLINE_BUFFER"
        log_msg "[SYSTEM] Buffer flushed." "UPTIME" "$NOW_HUMAN"
    fi
}

# --- STARTUP SEQUENCE ---
load_config
load_credentials
if [ $? -eq 0 ]; then
    log_msg "[SYSTEM] Credentials loaded." "UPTIME" "$(date '+%b %d %H:%M:%S')"
else
    log_msg "[WARNING] Vault error or missing." "UPTIME" "$(date '+%b %d %H:%M:%S')"
fi

if [ "$HEARTBEAT" = "YES" ]; then LAST_HB_CHECK=$(date +%s); fi

# --- MAIN LOGIC LOOP ---
while true; do
    load_config
    NOW_HUMAN=$(date '+%b %d %H:%M:%S')
    NOW_SEC=$(date +%s)
    CUR_HOUR=$(date +%H)
    CUR_FREE_RAM=$(df /tmp | awk 'NR==2 {print $4}')
    CPU_LOAD=$(cat /proc/loadavg | awk '{print $1}')
    
    if awk "BEGIN {exit !($CPU_LOAD > $CPU_GUARD_THRESHOLD)}"; then
        log_msg "[SYSTEM] High Load ($CPU_LOAD). Skipping." "UPTIME" "$NOW_HUMAN"
        sleep 10
        continue
    fi

    # --- HEARTBEAT ---
    if [ "$HEARTBEAT" = "YES" ]; then 
        HB_DIFF=$((NOW_SEC - LAST_HB_CHECK))
        if [ "$HB_DIFF" -ge "$HB_INTERVAL" ]; then
            CAN_SEND=0
            if [ "$HB_INTERVAL" -ge 86000 ]; then
                 if [ "$CUR_HOUR" -eq "$HB_START_HOUR" ]; then CAN_SEND=1; fi
                 if [ "$HB_DIFF" -gt 90000 ]; then CAN_SEND=1; fi
            else
                 CAN_SEND=1
            fi
            if [ "$CAN_SEND" -eq 1 ]; then
                LAST_HB_CHECK=$NOW_SEC
                HB_MSG="**Router:** $ROUTER_NAME\n**Status:** Systems Operational\n**Time:** $NOW_HUMAN"
                TARGET=${HB_TARGET:-BOTH}
                send_notification "💓 Heartbeat Report" "$HB_MSG" "1752220" "INFO" "$TARGET" "NO" "💓 Heartbeat - $ROUTER_NAME - $NOW_HUMAN" "$DISCORD_MENTION_HB"
                log_msg "Heartbeat sent ($TARGET)." "UPTIME" "$NOW_HUMAN"
            fi
        fi
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

    if [ "$IS_SILENT" -eq 0 ] && [ -s "$SILENT_BUFFER" ]; then
        SUMMARY_CONTENT=$(cat "$SILENT_BUFFER")
        CLEAN_SUMMARY=$(echo "$SUMMARY_CONTENT" | sed ':a;N;$!ba;s/\n/\\n/g')
        send_notification "🌙 Silent Hours Summary" "**Router:** $ROUTER_NAME\n$CLEAN_SUMMARY" "10181046" "SUMMARY" "BOTH" "NO" "🌙 Silent Hours Summary - $ROUTER_NAME
$SUMMARY_CONTENT" "NO"
        > "$SILENT_BUFFER"
        log_msg "[SYSTEM] Silent buffer dumped." "UPTIME" "$NOW_HUMAN"
    fi

    # --- INTERNET MONITOR ---
    if [ "$EXT_ENABLE" = "YES" ]; then
        if [ $((NOW_SEC - LAST_EXT_CHECK)) -ge "$EXT_SCAN_INTERVAL" ]; then
            LAST_EXT_CHECK=$NOW_SEC
            FD="$TMP_DIR/nwdta_ext_d"; FT="$TMP_DIR/nwdta_ext_t"; FC="$TMP_DIR/nwdta_ext_c"
            EXT_UP=0
            if [ -n "$EXT_IP" ] && ping -q -c "$EXT_PING_COUNT" -W "$EXT_PING_TIMEOUT" "$EXT_IP" > /dev/null 2>&1; then EXT_UP=1;
            elif [ -n "$EXT_IP2" ] && ping -q -c "$EXT_PING_COUNT" -W "$EXT_PING_TIMEOUT" "$EXT_IP2" > /dev/null 2>&1; then EXT_UP=1; fi
            EXT_UP_GLOBAL=$EXT_UP

            if [ "$EXT_UP" -eq 0 ]; then
                local C=0
                [ -f "$FC" ] && read C < "$FC"
                C=$((C+1))
                echo "$C" > "$FC"
                if [ "$C" -ge "$EXT_FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                    echo "$NOW_SEC" > "$FD"; echo "$NOW_HUMAN" > "$FT"; echo "DOWN" > "$NET_STATUS_FILE"
                    log_msg "[ALERT] INTERNET DOWN" "UPTIME" "$NOW_HUMAN"
                    if [ "$IS_SILENT" -ne 0 ]; then
                         if [ -f "$SILENT_BUFFER" ] && [ $(wc -c < "$SILENT_BUFFER") -ge 5120 ]; then :; else echo "Internet Down: $NOW_HUMAN" >> "$SILENT_BUFFER"; fi
                    fi
                fi
            else
                if [ -f "$FD" ]; then
                    echo "UP" > "$NET_STATUS_FILE"
                    local START_TIME; local START_SEC
                    [ -f "$FT" ] && read START_TIME < "$FT"
                    [ -f "$FD" ] && read START_SEC < "$FD"
                    DURATION_SEC=$((NOW_SEC - START_SEC))
                    DR="$((DURATION_SEC/60))m $((DURATION_SEC%60))s"
                    MSG_D="**Router:** $ROUTER_NAME\n**Down at:** $START_TIME\n**Up at:** $NOW_HUMAN\n**Total Outage:** $DR"
                    MSG_T="🟢 Connectivity Restored * $ROUTER_NAME - $START_TIME - $NOW_HUMAN - $DR"
                    log_msg "[SUCCESS] INTERNET UP (Down $DR)" "UPTIME" "$NOW_HUMAN"
                    if [ "$IS_SILENT" -eq 0 ]; then
                        send_notification "🟢 Connectivity Restored" "$MSG_D" "3066993" "SUCCESS" "BOTH" "YES" "$MSG_T" "$DISCORD_MENTION_NET"
                        flush_buffer
                    else
                         if [ -f "$SILENT_BUFFER" ] && [ $(wc -c < "$SILENT_BUFFER") -ge 5120 ]; then :; else echo -e "Internet Restored: $NOW_HUMAN (Down $DR)" >> "$SILENT_BUFFER"; fi
                    fi
                    rm -f "$FD" "$FT"
                else
                     echo "UP" > "$NET_STATUS_FILE"
                fi
                echo 0 > "$FC"
            fi
        fi
    else
        EXT_UP_GLOBAL=1
    fi

    # --- SHARED CHECK FUNCTION ---
    check_ip_logic() {
        local TIP=$1; local NAME=$2; local TYPE=$3; local THRESH=$4; local P_COUNT=$5
        local N_SEC=$6; local N_HUM=$7
        
        # FIX: Ensure we didn't pick up hidden chars in args
        TIP=$(echo "$TIP" | tr -d '\r')
        NAME=$(echo "$NAME" | tr -d '\r')

        local SIP=$(echo "$TIP" | tr '.' '_')
        local FC="$TMP_DIR/${TYPE}_${SIP}_c"
        local FD="$TMP_DIR/${TYPE}_${SIP}_d"
        local FT="$TMP_DIR/${TYPE}_${SIP}_t"
        local M_FLAG="NO"
        if [ "$TYPE" = "Device" ]; then M_FLAG="$DISCORD_MENTION_LOCAL"; fi
        if [ "$TYPE" = "Remote" ]; then M_FLAG="$DISCORD_MENTION_REMOTE"; fi
        
        if ping -q -c "$P_COUNT" -W 1 "$TIP" > /dev/null 2>&1; then
            if [ -f "$FD" ]; then
                local DSTART; local DSSEC
                read DSTART < "$FT"
                read DSSEC < "$FD"
                local DUR=$(( N_SEC - DSSEC ))
                local DR_STR="$((DUR/60))m $((DUR%60))s"
                local D_MSG="**Router:** $ROUTER_NAME\n**${TYPE}:** $NAME ($TIP)\n**Down at:** $DSTART\n**Up at:** $N_HUM\n**Outage:** $DR_STR"
                local T_MSG="🟢 ${TYPE} UP* $ROUTER_NAME - $NAME - $TIP - $N_HUM - $DR_STR"
                log_msg "[SUCCESS] ${TYPE}: $NAME Online ($DR_STR)" "UPTIME" "$N_HUM"
                if [ "$IS_SILENT" -eq 1 ]; then
                     if [ -f "$SILENT_BUFFER" ] && [ $(wc -c < "$SILENT_BUFFER") -ge 5120 ]; then :; else echo "${TYPE} $NAME UP: $N_HUM (Down $DR_STR)" >> "$SILENT_BUFFER"; fi
                else
                     send_notification "🟢 ${TYPE} Online" "$D_MSG" "3066993" "SUCCESS" "BOTH" "NO" "$T_MSG" "$M_FLAG"
                fi
                rm -f "$FD" "$FT"
            fi
            echo 0 > "$FC"
        else
            local C=0
            [ -f "$FC" ] && read C < "$FC"
            C=$((C+1))
            echo "$C" > "$FC"
            if [ "$C" -ge "$THRESH" ] && [ ! -f "$FD" ]; then
                 echo "$N_SEC" > "$FD"; echo "$N_HUM" > "$FT"
                 log_msg "[ALERT] ${TYPE}: $NAME Down" "UPTIME" "$N_HUM"
                 local D_MSG="**Router:** $ROUTER_NAME\n**${TYPE}:** $NAME ($TIP)\n**Time:** $N_HUM"
                 local T_MSG="🔴 ${TYPE} Down * $ROUTER_NAME - $NAME - $TIP - $N_HUM"
                 if [ "$IS_SILENT" -eq 1 ]; then
                     if [ -f "$SILENT_BUFFER" ] && [ $(wc -c < "$SILENT_BUFFER") -ge 5120 ]; then :; else echo "${TYPE} $NAME DOWN: $N_HUM" >> "$SILENT_BUFFER"; fi
                 else
                     send_notification "🔴 ${TYPE} Down" "$D_MSG" "15548997" "ALERT" "BOTH" "NO" "$T_MSG" "$M_FLAG"
                 fi
            fi
        fi
    }

    # --- DEVICE MONITOR ---
    if [ "$DEVICE_MONITOR" = "YES" ]; then
        if [ $((NOW_SEC - LAST_DEV_CHECK)) -ge "$DEV_SCAN_INTERVAL" ]; then
            LAST_DEV_CHECK=$NOW_SEC
            # FIX: Loop robust against missing newlines
            while read -r line || [ -n "$line" ]; do
                case "$line" in \#*|"") continue ;; esac
                
                # Sanitize input (remove carriage returns)
                line=$(echo "$line" | tr -d '\r')
                
                TIP="${line%%@*}"
                TIP="${TIP%% }" 
                TIP="${TIP## }" 
                NAME="${line#*@}"
                NAME="${NAME## }" 
                [ "$NAME" = "$line" ] && NAME="$TIP" 
                
                if [ -n "$TIP" ]; then
                    if [ "$EXEC_METHOD" -eq 1 ]; then
                         check_ip_logic "$TIP" "$NAME" "Device" "$DEV_FAIL_THRESHOLD" "$DEV_PING_COUNT" "$NOW_SEC" "$NOW_HUMAN" &
                    else
                         check_ip_logic "$TIP" "$NAME" "Device" "$DEV_FAIL_THRESHOLD" "$DEV_PING_COUNT" "$NOW_SEC" "$NOW_HUMAN"
                    fi
                fi
            done < "$IP_LIST_FILE"
            [ "$EXEC_METHOD" -eq 1 ] && wait
        fi
    fi

    # --- REMOTE MONITOR ---
    if [ "$REMOTE_MONITOR" = "YES" ] && [ "$EXT_UP_GLOBAL" -eq 1 ]; then
        if [ $((NOW_SEC - LAST_REM_CHECK)) -ge "$REM_SCAN_INTERVAL" ]; then
            LAST_REM_CHECK=$NOW_SEC
            # FIX: Loop robust against missing newlines
            while read -r line || [ -n "$line" ]; do
                case "$line" in \#*|"") continue ;; esac
                
                # Sanitize input
                line=$(echo "$line" | tr -d '\r')
                
                TIP="${line%%@*}"
                TIP="${TIP%% }"
                TIP="${TIP## }"
                NAME="${line#*@}"
                NAME="${NAME## }"
                [ "$NAME" = "$line" ] && NAME="$TIP"
                
                if [ -n "$TIP" ]; then
                    if [ "$EXEC_METHOD" -eq 1 ]; then
                         check_ip_logic "$TIP" "$NAME" "Remote" "$REM_FAIL_THRESHOLD" "$REM_PING_COUNT" "$NOW_SEC" "$NOW_HUMAN" &
                    else
                         check_ip_logic "$TIP" "$NAME" "Remote" "$REM_FAIL_THRESHOLD" "$REM_PING_COUNT" "$NOW_SEC" "$NOW_HUMAN"
                    fi
                fi
            done < "$REMOTE_LIST_FILE"
            [ "$EXEC_METHOD" -eq 1 ] && wait
        fi
    fi
    sleep 1
done
EOF
chmod +x "$INSTALL_DIR/netwatchdta.sh"

# ==============================================================================
#  STEP 7: SERVICE CONFIGURATION (INIT.D)
# ==============================================================================
echo -e "\n${CYAN}⚙️  Configuring system service...${NC}"

cat <<EOF > "$SERVICE_PATH"
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

extra_command "check" "Check if monitor is running"
extra_command "logs" "View last 20 log entries"
extra_command "clear" "Clear the log file"
extra_command "discord" "Test Discord notification"
extra_command "telegram" "Test Telegram notification"
extra_command "credentials" "Update Discord/Telegram credentials"
extra_command "purge" "Interactive smart uninstaller"
extra_command "reload" "Reload configuration files"

start_service() {
    procd_open_instance
    procd_set_param command /bin/sh "$INSTALL_DIR/netwatchdta.sh"
    procd_set_param respawn
    procd_set_param stdout 0
    procd_set_param stderr 0
    procd_close_instance
}

check() {
    if pgrep -f "netwatchdta.sh" > /dev/null; then
        echo -e "\033[1;32m● netwatchdta is RUNNING.\033[0m"
        echo "   PID: \$(pgrep -f "netwatchdta.sh" | head -1)"
    else
        echo -e "\033[1;31m● netwatchdta is STOPPED.\033[0m"
    fi
}

logs() {
    if [ -f "/tmp/netwatchdta/nwdta_uptime.log" ]; then
        echo -e "\033[1;34m--- Recent Activity ---\033[0m"
        tail -n 20 /tmp/netwatchdta/nwdta_uptime.log
    else
        echo "No log found."
    fi
}

clear() {
    echo "\$(date '+%b %d %H:%M:%S') - [SYSTEM] Log cleared manually." > "/tmp/netwatchdta/nwdta_uptime.log"
    echo "Log file cleared."
}

load_functions() {
    if [ -f "$INSTALL_DIR/netwatchdta.sh" ]; then
        # FIXED: Safe config loading (ignores headers and Windows newlines)
        eval "\$(sed '/^\[.*\]/d' "$INSTALL_DIR/settings.conf" | sed 's/[ \t]*#.*//' | sed 's/[ \t]*$//' | tr -d '\r')"
    fi
}

get_hw_key() {
    local seed="nwdta_v1_secure_seed_2025"
    # FIXED: Robust parsing for all OpenWrt variants
    local cpu_serial=\$(grep -i "serial" /proc/cpuinfo | head -1 | awk -F: '{print \$2}' | tr -d ' ')
    [ -z "\$cpu_serial" ] && cpu_serial="unknown_serial"
    local mac_addr=\$(cat /sys/class/net/*/address 2>/dev/null | grep -v "00:00:00:00:00:00" | sort | head -1)
    [ -z "\$mac_addr" ] && mac_addr="00:00:00:00:00:00"
    echo -n "\${seed}\${cpu_serial}\${mac_addr}" | openssl dgst -sha256 | awk '{print \$2}'
}

get_decrypted_creds() {
    local vault="$INSTALL_DIR/.vault.enc"
    if [ ! -f "\$vault" ]; then return 1; fi
    local key=\$(get_hw_key)
    openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -iter 10000 -k "\$key" -in "\$vault" 2>/dev/null
}

discord() {
    load_functions
    local decrypted=\$(get_decrypted_creds)
    # Sanitize decrypted output
    decrypted=\$(echo "\$decrypted" | tr -d '\r')
    local webhook=\$(echo "\$decrypted" | cut -d'|' -f1)
    if [ -n "\$webhook" ]; then
        echo "Sending Discord test..."
        if command -v uclient-fetch >/dev/null 2>&1 && uclient-fetch --help 2>&1 | grep -q "\-\-header"; then
            uclient-fetch --no-check-certificate --header="Content-Type: application/json" --post-data="{\"embeds\": [{\"title\": \"🛠️ Discord Warning Test\", \"description\": \"**Router:** \$ROUTER_NAME\nManual warning triggered.\", \"color\": 16776960}]}" "\$webhook" -O /dev/null >/dev/null 2>&1
        else
            curl -s -k -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🛠️ Discord Warning Test\", \"description\": \"**Router:** \$ROUTER_NAME\nManual warning triggered.\", \"color\": 16776960}]}" "\$webhook" >/dev/null 2>&1
        fi
        echo "Sent."
    else
        echo "No Discord Webhook configured or vault locked."
    fi
}

telegram() {
    load_functions
    local decrypted=\$(get_decrypted_creds)
    decrypted=\$(echo "\$decrypted" | tr -d '\r')
    local token=\$(echo "\$decrypted" | cut -d'|' -f3)
    local chat=\$(echo "\$decrypted" | cut -d'|' -f4)
    if [ -n "\$token" ]; then
        echo "Sending Telegram test..."
        if command -v uclient-fetch >/dev/null 2>&1; then
             uclient-fetch --no-check-certificate --post-data="chat_id=\$chat&text=🛠️ Telegram Warning Test - \$ROUTER_NAME" "https://api.telegram.org/bot\$token/sendMessage" -O /dev/null >/dev/null 2>&1
        else
             curl -s -k -X POST "https://api.telegram.org/bot\$token/sendMessage" -d chat_id="\$chat" -d text="🛠️ Telegram Warning Test - \$ROUTER_NAME" >/dev/null 2>&1
        fi
        echo "Sent."
    else
        echo "No Telegram Token configured or vault locked."
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
    
    load_functions
    local current=\$(get_decrypted_creds)
    current=\$(echo "\$current" | tr -d '\r')
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
    local vault="$INSTALL_DIR/.vault.enc"
    local key=\$(get_hw_key)
    
    if echo -n "\$new_data" | openssl enc -aes-256-cbc -a -salt -pbkdf2 -iter 10000 -k "\$key" -out "\$vault" 2>/dev/null; then
        echo -e "\033[1;32m✅ Credentials updated and re-encrypted (OpenSSL).\033[0m"
        /etc/init.d/netwatchdta restart
    else
        echo -e "\033[1;31m❌ Encryption failed.\033[0m"
    fi
}

reload() {
    /etc/init.d/netwatchdta restart
}

purge() {
    echo ""
    echo -e "\033[1;31m=======================================================\033[0m"
    echo -e "\033[1;31m🗑️  netwatchdta Smart Uninstaller\033[0m"
    echo -e "\033[1;31m=======================================================\033[0m"
    echo ""
    echo -e "\033[1;37m1.\033[0m Full Uninstall (Remove everything)"
    echo -e "\033[1;37m2.\033[0m Keep Settings (Remove logic but keep config)"
    echo -e "\033[1;37m3.\033[0m Cancel"
    printf "\033[1mChoice [1-3]: \033[0m"
    read choice </dev/tty
    
    case "\$choice" in
        1)
            echo ""
            echo -e "\033[1;33m🛑 Stopping service...\033[0m"
            /etc/init.d/netwatchdta stop
            /etc/init.d/netwatchdta disable
            echo -e "\033[1;33m🧹 Cleaning up /tmp and buffers...\033[0m"
            rm -rf "/tmp/netwatchdta"
            echo -e "\033[1;33m🗑️  Removing installation directory...\033[0m"
            rm -rf "$INSTALL_DIR"
            echo -e "\033[1;33m🔥 Self-destructing service file...\033[0m"
            rm -f "$SERVICE_PATH"
            echo ""
            echo -e "\033[1;32m✅ netwatchdta has been completely removed.\033[0m"
            ;;
        2)
            echo ""
            echo -e "\033[1;33m🛑 Stopping service...\033[0m"
            /etc/init.d/netwatchdta stop
            /etc/init.d/netwatchdta disable
            echo -e "\033[1;33m🧹 Cleaning up /tmp...\033[0m"
            rm -rf "/tmp/netwatchdta"
            echo -e "\033[1;33m🗑️  Removing core script...\033[0m"
            rm -f "$INSTALL_DIR/netwatchdta.sh"
            echo -e "\033[1;33m🔥 Removing service file...\033[0m"
            rm -f "$SERVICE_PATH"
            echo ""
            echo -e "\033[1;33m✅ Logic removed. Settings preserved in $INSTALL_DIR\033[0m"
            ;;
        *)
            echo -e "\033[1;31m❌ Purge cancelled.\033[0m"
            exit 0
            ;;
    esac
}
EOF

chmod +x "$SERVICE_PATH"
"$SERVICE_PATH" enable >/dev/null 2>&1
"$SERVICE_PATH" start >/dev/null 2>&1

sleep 2
if pgrep -f "netwatchdta.sh" > /dev/null; then
    SERVICE_STATUS="${GREEN}ACTIVE (PID: $(pgrep -f "netwatchdta.sh" | head -1))${NC}"
else
    "$SERVICE_PATH" start >/dev/null 2>&1
    sleep 1
    if pgrep -f "netwatchdta.sh" > /dev/null; then
        SERVICE_STATUS="${GREEN}ACTIVE (Retried)${NC}"
    else
        SERVICE_STATUS="${RED}FAILED TO START (Check logs)${NC}"
    fi
fi

# ==============================================================================
#  STEP 8: FINAL SUCCESS MESSAGE
# ==============================================================================
NOW_FINAL=$(date '+%b %d, %Y %H:%M:%S')
MSG="**Router:** $router_name_input\n**Time:** $NOW_FINAL\n**Status:** Service Installed & Active"

if [ "$DISCORD_ENABLE_VAL" = "YES" ] && [ -n "$DISCORD_WEBHOOK" ]; then
    safe_fetch "$DISCORD_WEBHOOK" "{\"embeds\": [{\"title\": \"🚀 netwatchdta Service Started\", \"description\": \"$MSG\", \"color\": 1752220}]}" "Content-Type: application/json"
fi

if [ "$TELEGRAM_ENABLE_VAL" = "YES" ] && [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    safe_fetch "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" "{\"chat_id\": \"$TELEGRAM_CHAT_ID\", \"text\": \"🚀 netwatchdta Service Started - $router_name_input\"}" "Content-Type: application/json"
fi

echo ""
echo -e "${GREEN}=======================================================${NC}"
echo -e "${BOLD}${GREEN}✅ Installation complete!${NC}"
echo -e "${CYAN}📂 Folder :${NC} $INSTALL_DIR"
echo -e "${CYAN}⚙️  Service:${NC} $SERVICE_STATUS"
echo -e "${GREEN}=======================================================${NC}"
echo -e "\n${BOLD}Quick Commands:${NC}"
echo -e "  Status           : ${YELLOW}/etc/init.d/netwatchdta check${NC}"
echo -e "  Uninstall        : ${RED}/etc/init.d/netwatchdta purge${NC}"
echo -e "  Manage Creds     : ${YELLOW}/etc/init.d/netwatchdta credentials${NC}"
echo -e "  Edit Settings    : ${CYAN}$CONFIG_FILE${NC}"
echo -e "  Edit IP List     : ${CYAN}$IP_LIST_FILE${NC}"
echo -e "  Restart          : ${YELLOW}/etc/init.d/netwatchdta restart${NC}"
echo ""