#!/bin/sh
# netwatchda Installer - Automated Setup for OpenWrt
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
# Usage:    ask_yn "Question Text"
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
# Usage:    ask_opt "Prompt Text" "Max Option Number"
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
#  INSTALLER HEADER
# ==============================================================================
echo -e "${BLUE}=======================================================${NC}"
echo -e "${BOLD}${CYAN}🚀 netwatchda Automated Setup${NC} dasdsadadsadaas(by ${BOLD}panoc${NC})"
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
INSTALL_DIR="/root/netwatchda"
TMP_DIR="/tmp/netwatchda"
CONFIG_FILE="$INSTALL_DIR/nwda_settings.conf"
IP_LIST_FILE="$INSTALL_DIR/nwda_ips.conf"
VAULT_FILE="$INSTALL_DIR/.vault.enc"
SERVICE_NAME="netwatchda"
SERVICE_PATH="/etc/init.d/$SERVICE_NAME"

# Ensure temp directory exists for installation logs
mkdir -p "$TMP_DIR"

# ==============================================================================
#  STEP 1: SECURITY PREFERENCES (ENCRYPTION SELECTION)
# ==============================================================================
echo -e "\n${BLUE}--- Security Preferences ---${NC}"
echo -e "Choose how to store your Discord/Telegram credentials:"
echo -e ""
echo -e "${BOLD}${WHITE}1.${NC} OpenSSL (High Security)"
echo -e "   • ${GREEN}Pros:${NC} AES-256 Encryption. Very secure. Requires 'openssl-util' (~500KB)."
echo -e "   • ${RED}Cons:${NC} More Ram usage during outage 2-4MB for each event, if happen on the same time needs a lot of RAM. Heavier on old CPUs."
echo -e "   • ${RED}Cons:${NC} Heavier on old CPUs when sending notifications."
echo -e ""
echo -e "${BOLD}${WHITE}2.${NC} Base64 (Low Security)"
echo -e "   • ${GREEN}Pros:${NC} No extra dependencies. Instant. Very low RAM usage."
echo -e "   • ${RED}Cons:${NC} Not encryption (just encoding). Can be decoded by anyone."

ask_opt "Select Method" "2"
if [ "$ANSWER_OPT" = "1" ]; then
    ENCRYPTION_METHOD="OPENSSL"
    echo -e "${CYAN}🔒 Selected: OpenSSL (High Security)${NC}"
else
    ENCRYPTION_METHOD="BASE64"
    echo -e "${YELLOW}🔓 Selected: Base64 (Low Security)${NC}"
fi

# ==============================================================================
#  STEP 2: SYSTEM READINESS CHECKS
# ==============================================================================
echo -e "\n${BOLD}📦 Checking system readiness...${NC}"

# 1. Check Flash Storage (Root partition)
FREE_FLASH_KB=$(df / | awk 'NR==2 {print $4}')
MIN_FLASH_KB=3072 # 3MB Threshold

# 2. Check RAM (/tmp partition)
FREE_RAM_KB=$(df /tmp | awk 'NR==2 {print $4}')
MIN_RAM_KB=4096 # 4MB Threshold

# 3. Define Dependency List
MISSING_DEPS=""
# Check for curl
command -v curl >/dev/null 2>&1 || MISSING_DEPS="$MISSING_DEPS curl"
# Check for CA Certificates (needed for secure curl)
[ -f /etc/ssl/certs/ca-certificates.crt ] || command -v opkg >/dev/null && opkg list-installed | grep -q ca-bundle || MISSING_DEPS="$MISSING_DEPS ca-bundle"

# Dynamic Check: Only check OpenSSL if user selected High Security
if [ "$ENCRYPTION_METHOD" = "OPENSSL" ]; then
    command -v openssl >/dev/null 2>&1 || MISSING_DEPS="$MISSING_DEPS openssl-util"
fi

# RAM Guard Check
if [ "$FREE_RAM_KB" -lt "$MIN_RAM_KB" ]; then
    echo -e "${RED}❌ ERROR: Insufficient RAM for operations!${NC}"
    echo -e "${YELLOW}Available: $((FREE_RAM_KB / 1024))MB | Required: 4MB${NC}"
    exit 1
fi

# Dependency Installation Logic
if [ -n "$MISSING_DEPS" ]; then
    echo -e "${CYAN}🔍 Missing dependencies found:${BOLD}$MISSING_DEPS${NC}"
    
    # Check if we have enough Flash space to install them
    if [ "$FREE_FLASH_KB" -lt "$MIN_FLASH_KB" ]; then
        echo -e "${RED}❌ ERROR: Insufficient Flash storage to install dependencies!${NC}"
        echo -e "${YELLOW}Available: $((FREE_FLASH_KB / 1024))MB | Required: 3MB${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ Sufficient Flash space found: $((FREE_FLASH_KB / 1024))MB available.${NC}"
        
        # Ask User Permission
        ask_yn "❓ Download missing dependencies?"
        if [ "$ANSWER_YN" = "y" ]; then
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
    echo -e "${GREEN}✅ All dependencies are installed.${NC}"
    echo -e "${GREEN}✅ Flash storage check passed: $((FREE_FLASH_KB / 1024))MB available.${NC}"
fi

echo -e "${GREEN}✅ System Ready.${NC}"
# ==============================================================================
#  STEP 3: SMART UPGRADE / INSTALL CHECK
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
        /etc/init.d/netwatchda stop >/dev/null 2>&1
        rm -rf "$INSTALL_DIR"
    fi
fi

mkdir -p "$INSTALL_DIR"

# ==============================================================================
#  STEP 4: CONFIGURATION INPUTS
# ==============================================================================
if [ "$KEEP_CONFIG" -eq 0 ]; then
    echo -e "\n${BLUE}--- Configuration ---${NC}"
    
    # 4a. Router Name
    printf "${BOLD}🏷️  Enter Router Name (e.g., MyRouter): ${NC}"
    read router_name_input </dev/tty
    
    # 4b. Discord Setup Loop
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
        
        # User said YES
        DISCORD_ENABLE_VAL="YES"
        printf "${BOLD}   > Enter Discord Webhook URL: ${NC}"
        read DISCORD_WEBHOOK </dev/tty
        printf "${BOLD}   > Enter Discord User ID (for @mentions): ${NC}"
        read DISCORD_USERID </dev/tty
        
        # Test Loop
        ask_yn "   ❓ Send test notification to Discord now?"
        if [ "$ANSWER_YN" = "y" ]; then
             echo -e "${YELLOW}   🧪 Sending Discord test...${NC}"
             curl -s -k -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🧪 Setup Test\", \"description\": \"Discord configured successfully for **$router_name_input**.\", \"color\": 1752220}]}" "$DISCORD_WEBHOOK"
             echo ""
             ask_yn "   ❓ Did you receive the notification?"
             
             if [ "$ANSWER_YN" = "y" ]; then
                 echo -e "${GREEN}   ✅ Discord configured.${NC}"
                 break
             else
                 echo -e "${RED}   ❌ Test failed.${NC}"
                 echo -e "${BOLD}${WHITE}   1.${NC} Input credentials again"
                 echo -e "${BOLD}${WHITE}   2.${NC} Disable Discord and continue"
                 ask_opt "   Choice" "2"
                 if [ "$ANSWER_OPT" = "2" ]; then
                     DISCORD_ENABLE_VAL="NO"
                     DISCORD_WEBHOOK=""
                     DISCORD_USERID=""
                     break
                 fi
                 # Loop continues (Retry credentials)
             fi
        else
            break
        fi
    done

    # 4c. Telegram Setup Loop
    TELEGRAM_ENABLE_VAL="NO"
    TELEGRAM_BOT_TOKEN=""
    TELEGRAM_CHAT_ID=""
    
    while :; do
        ask_yn "2. Enable Telegram Notifications?"
        if [ "$ANSWER_YN" = "n" ]; then
            TELEGRAM_ENABLE_VAL="NO"
            break
        fi
        
        # User said YES
        TELEGRAM_ENABLE_VAL="YES"
        printf "${BOLD}   > Enter Telegram Bot Token: ${NC}"
        read TELEGRAM_BOT_TOKEN </dev/tty
        printf "${BOLD}   > Enter Telegram Chat ID: ${NC}"
        read TELEGRAM_CHAT_ID </dev/tty
        
        # Test Loop
        ask_yn "   ❓ Send test notification to Telegram now?"
        if [ "$ANSWER_YN" = "y" ]; then
            echo -e "${YELLOW}   🧪 Sending Telegram test...${NC}"
            curl -s -k -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d chat_id="$TELEGRAM_CHAT_ID" -d text="🧪 Setup Test - Telegram configured successfully for $router_name_input." >/dev/null 2>&1
            echo ""
            ask_yn "   ❓ Did you receive the notification?"
            
            if [ "$ANSWER_YN" = "y" ]; then
                echo -e "${GREEN}   ✅ Telegram configured.${NC}"
                break
            else
                echo -e "${RED}   ❌ Test failed.${NC}"
                echo -e "${BOLD}${WHITE}   1.${NC} Input credentials again"
                echo -e "${BOLD}${WHITE}   2.${NC} Disable Telegram and continue"
                ask_opt "   Choice" "2"
                if [ "$ANSWER_OPT" = "2" ]; then
                    TELEGRAM_ENABLE_VAL="NO"
                    TELEGRAM_BOT_TOKEN=""
                    TELEGRAM_CHAT_ID=""
                    break
                fi
                # Loop continues
            fi
        else
            break
        fi
    done
    
    # 4d. Summary Display
    echo -e "\n${BOLD}${WHITE}Selected Notification Strategy:${NC}"
    if [ "$DISCORD_ENABLE_VAL" = "YES" ] && [ "$TELEGRAM_ENABLE_VAL" = "YES" ]; then
        echo -e "   • ${BOLD}${WHITE}BOTH (Redundant)${NC}"
    elif [ "$DISCORD_ENABLE_VAL" = "YES" ]; then
         echo -e "   • ${BOLD}${WHITE}Discord Only${NC}"
    elif [ "$TELEGRAM_ENABLE_VAL" = "YES" ]; then
         echo -e "   • ${BOLD}${WHITE}Telegram Only${NC}"
    else
         echo -e "   • ${BOLD}${WHITE}NONE (Log only mode)${NC}"
    fi

    # 4e. Silent Hours
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
    
    # 4f. Heartbeat Logic
    HB_VAL="NO"
    HB_SEC="86400"
    HB_MENTION="NO"
    HB_TARGET="BOTH"
    
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
        
        ask_yn "   > Mention in Heartbeat?"
        if [ "$ANSWER_YN" = "y" ]; then
            HB_MENTION="YES"
        fi
        
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

    # 4g. Monitoring Mode Selection
    echo -e "\n${BLUE}--- Monitoring Mode ---${NC}"
    echo -e "   1. ${BOLD}${WHITE}Both: Full monitoring (Default)${NC}"
    echo -e "   2. ${BOLD}${WHITE}Device Connectivity only: Pings local network${NC}"
    echo -e "   3. ${BOLD}${WHITE}Internet Connectivity only: Pings external IP${NC}"
    
    ask_opt "Enter choice" "3"

    case "$ANSWER_OPT" in
        2) EXT_VAL="NO";  DEV_VAL="YES" ;;
        3) EXT_VAL="YES"; DEV_VAL="NO"  ;;
        *) EXT_VAL="YES"; DEV_VAL="YES" ;;
    esac

    # ==============================================================================
    #  STEP 5: GENERATE CONFIGURATION FILES
    # ==============================================================================
    cat <<EOF > "$CONFIG_FILE"
# nwda_settings.conf - Configuration for netwatchda
# Note: Credentials are stored in .vault.enc (Method: $ENCRYPTION_METHOD)
ROUTER_NAME="$router_name_input"
ENCRYPTION_METHOD="$ENCRYPTION_METHOD" # Options: OPENSSL, BASE64

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
HB_TARGET=$HB_TARGET # Target for Heartbeat: DISCORD, TELEGRAM, BOTH

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

    # Generate default IP list
    cat <<EOF > "$IP_LIST_FILE"
# Format: IP_ADDRESS @ NAME
# Example: 192.168.1.50 @ Home Server
EOF
    # Attempt to auto-detect local gateway IP for user convenience
    LOCAL_IP=$(uci -q get network.lan.ipaddr || ip addr show br-lan | grep -oE 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 | awk '{print $2}')
    [ -n "$LOCAL_IP" ] && echo "$LOCAL_IP @ Router Gateway" >> "$IP_LIST_FILE"
fi
# ==============================================================================
#  STEP 6: SECURE CREDENTIAL VAULT
# ==============================================================================
echo -e "\n${CYAN}🔐 Securing credentials...${NC}"

# Function: get_hw_key
# Purpose:  Generates a unique hardware signature.
get_hw_key() {
    local seed="nwda_v1_secure_seed_2025"
    local cpu_serial=$(grep -i "serial" /proc/cpuinfo | head -1 | awk '{print $3}')
    [ -z "$cpu_serial" ] && cpu_serial="unknown_serial"
    
    local mac_addr=$(cat /sys/class/net/eth0/address 2>/dev/null)
    [ -z "$mac_addr" ] && mac_addr=$(cat /sys/class/net/br-lan/address 2>/dev/null)
    [ -z "$mac_addr" ] && mac_addr="00:00:00:00:00:00"

    # Use openssl to hash the hardware info into a key
    echo -n "${seed}${cpu_serial}${mac_addr}" | openssl dgst -sha256 | awk '{print $2}'
}

# Create the Vault Data String
# Format: DISCORD_WEBHOOK|DISCORD_USERID|TELEGRAM_BOT_TOKEN|TELEGRAM_CHAT_ID
if [ "$KEEP_CONFIG" -eq 0 ]; then
    VAULT_DATA="${DISCORD_WEBHOOK}|${DISCORD_USERID}|${TELEGRAM_BOT_TOKEN}|${TELEGRAM_CHAT_ID}"
    
    if [ "$ENCRYPTION_METHOD" = "OPENSSL" ]; then
        # HIGH SECURITY: OpenSSL AES-256-CBC
        HW_KEY=$(get_hw_key)
        if echo -n "$VAULT_DATA" | openssl enc -aes-256-cbc -a -salt -pbkdf2 -iter 10000 -k "$HW_KEY" -out "$VAULT_FILE" 2>/dev/null; then
            echo -e "${GREEN}✅ Credentials Encrypted (OpenSSL) and locked to this hardware.${NC}"
        else
            echo -e "${RED}❌ OpenSSL Encryption failed! Check openssl-util.${NC}"
        fi
    else
        # LOW SECURITY: Base64 Encoding
        if echo -n "$VAULT_DATA" | base64 > "$VAULT_FILE"; then
            echo -e "${YELLOW}✅ Credentials Encoded (Base64).${NC}"
        else
            echo -e "${RED}❌ Base64 Encoding failed!${NC}"
        fi
    fi
fi
# ==============================================================================
#  STEP 7: GENERATE CORE SCRIPT (THE ENGINE)
# ==============================================================================
echo -e "\n${CYAN}🛠️  Generating core script...${NC}"

cat <<'EOF' > "$INSTALL_DIR/netwatchda.sh"
#!/bin/sh
# netwatchda - Network Monitoring for OpenWrt (Core Engine)

# --- DIRECTORY DEFS ---
BASE_DIR="/root/netwatchda"
IP_LIST_FILE="$BASE_DIR/nwda_ips.conf"
CONFIG_FILE="$BASE_DIR/nwda_settings.conf"
VAULT_FILE="$BASE_DIR/.vault.enc"

# Flash Paths (Persistent Buffers, 5KB limit enforced)
SILENT_BUFFER="$BASE_DIR/nwda_silent_buffer"
OFFLINE_BUFFER="$BASE_DIR/nwda_offline_buffer"

# RAM Paths (Reduce Flash Writes)
TMP_DIR="/tmp/netwatchda"
LOGFILE="$TMP_DIR/nwda_uptime.log"
PINGLOG="$TMP_DIR/nwda_ping.log"
NET_STATUS_FILE="$TMP_DIR/nwda_net_status" # UP or DOWN

# Initialization
mkdir -p "$TMP_DIR"
if [ ! -f "$SILENT_BUFFER" ]; then touch "$SILENT_BUFFER"; fi
if [ ! -f "$LOGFILE" ]; then touch "$LOGFILE"; fi
# Default network status to UP to allow initial attempts
if [ ! -f "$NET_STATUS_FILE" ]; then echo "UP" > "$NET_STATUS_FILE"; fi

# Tracking Variables
LAST_EXT_CHECK=0
LAST_DEV_CHECK=0
LAST_HB_CHECK=$(date +%s)

# --- HELPER: LOGGING ---
log_msg() {
    local msg="$1"
    local type="$2" # UPTIME or PING
    local ts=$(date '+%b %d %H:%M:%S')
    
    if [ "$type" = "PING" ] && [ "$PING_LOG_ENABLE" = "YES" ]; then
        echo "$ts - $msg" >> "$PINGLOG"
        # Log Rotation
        if [ -f "$PINGLOG" ] && [ $(wc -c < "$PINGLOG") -gt "$UPTIME_LOG_MAX_SIZE" ]; then
            echo "$ts - [SYSTEM] Log rotated." > "$PINGLOG"
        fi
    elif [ "$type" = "UPTIME" ]; then
        echo "$ts - $msg" >> "$LOGFILE"
        # Log Rotation
        if [ -f "$LOGFILE" ] && [ $(wc -c < "$LOGFILE") -gt "$UPTIME_LOG_MAX_SIZE" ]; then
            echo "$ts - [SYSTEM] Log rotated." > "$LOGFILE"
        fi
    fi
}

# --- HELPER: CONFIG LOADER ---
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        eval "$(sed '/^\[.*\]/d' "$CONFIG_FILE" | sed 's/ #.*//')"
    fi
}

# --- HELPER: HW KEY GENERATION ---
get_hw_key() {
    local seed="nwda_v1_secure_seed_2025"
    local cpu_serial=$(grep -i "serial" /proc/cpuinfo | head -1 | awk '{print $3}')
    [ -z "$cpu_serial" ] && cpu_serial="unknown_serial"
    local mac_addr=$(cat /sys/class/net/eth0/address 2>/dev/null)
    [ -z "$mac_addr" ] && mac_addr=$(cat /sys/class/net/br-lan/address 2>/dev/null)
    echo -n "${seed}${cpu_serial}${mac_addr}" | openssl dgst -sha256 | awk '{print $2}'
}

# --- HELPER: CREDENTIAL DECRYPTION ---
load_credentials() {
    if [ -f "$VAULT_FILE" ]; then
        local decrypted=""
        
        # Check Encryption Method
        if [ "$ENCRYPTION_METHOD" = "OPENSSL" ]; then
            local key=$(get_hw_key)
            decrypted=$(openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -iter 10000 -k "$key" -in "$VAULT_FILE" 2>/dev/null)
        else
            # Default to Base64
            decrypted=$(cat "$VAULT_FILE" | base64 -d 2>/dev/null)
        fi
        
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

# --- INTERNAL: SEND PAYLOAD ---
send_payload() {
    local title="$1"
    local desc="$2"
    local color="$3"
    local filter="$4"
    local telegram_text="$5" # Specialized text for Telegram
    local success=0

    # 1. DISCORD
    if [ "$DISCORD_ENABLE" = "YES" ] && [ -n "$DISCORD_WEBHOOK" ]; then
        if [ -z "$filter" ] || [ "$filter" = "BOTH" ] || [ "$filter" = "DISCORD" ]; then
             # Use standard desc for Discord
             # Ensure proper JSON formatting for description
             # Replace literal newlines with \n for JSON
             local json_desc=$(echo "$desc" | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
             
             if curl -s -k -f -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"$title\", \"description\": \"$json_desc\", \"color\": $color}]}" "$DISCORD_WEBHOOK" >/dev/null 2>&1; then
                success=1
             else
                log_msg "[ERROR] Discord send failed." "UPTIME"
             fi
        fi
    fi

    # 2. TELEGRAM
    if [ "$TELEGRAM_ENABLE" = "YES" ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        if [ -z "$filter" ] || [ "$filter" = "BOTH" ] || [ "$filter" = "TELEGRAM" ]; then
             # Use specialized text if available, otherwise use title+desc
             local t_msg="$title
$desc"
             if [ -n "$telegram_text" ]; then t_msg="$telegram_text"; fi
             
             if curl -s -k -f -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
                -d chat_id="$TELEGRAM_CHAT_ID" \
                -d text="$t_msg" >/dev/null 2>&1; then
                success=1
             else
                log_msg "[ERROR] Telegram send failed." "UPTIME"
             fi
        fi
    fi
    
    return $((1 - success)) # Returns 0 on success, 1 on failure
}

# --- HELPER: NOTIFICATION SENDER ---
# Usage: send_notification "Title" "Desc" "Color" "Type" "TARGET_FILTER" "FORCE_SEND" "TELEGRAM_TEXT"
send_notification() {
    local title="$1"
    local desc="$2"
    local color="$3"
    local type="$4" # "ALERT", "SUCCESS", "INFO", "WARNING", "SUMMARY"
    local filter="$5" # "DISCORD", "TELEGRAM", "BOTH", or empty
    local force="$6" # "YES" to bypass buffer check
    local tel_text="$7" # Optional specialized text for Telegram
    
    # RAM Guard
    local free_ram=$(df /tmp | awk 'NR==2 {print $4}')
    if [ "$free_ram" -lt "$RAM_GUARD_MIN_FREE" ]; then
        log_msg "[SYSTEM] RAM LOW ($free_ram KB). Notification skipped." "UPTIME"
        return
    fi
    
    # 1 SEC DELAY REQUIREMENT
    sleep 1

    # Check Internet Status
    local net_stat="UP"
    if [ -f "$NET_STATUS_FILE" ]; then
        net_stat=$(cat "$NET_STATUS_FILE")
    fi

    # IF Internet is DOWN and not forced -> BUFFER IT
    if [ "$net_stat" = "DOWN" ] && [ "$force" != "YES" ]; then
        # Check Buffer Size (5KB Limit = 5120 bytes)
        if [ -f "$OFFLINE_BUFFER" ] && [ $(wc -c < "$OFFLINE_BUFFER") -ge 5120 ]; then
             log_msg "[BUFFER] Buffer full (5KB). Notification dropped." "UPTIME"
             return
        fi

        # Format: TITLE|||DESC|||COLOR|||FILTER|||TELEGRAM_TEXT
        # Flatten newlines to __BR__ for storage
        local clean_desc=$(echo "$desc" | sed ':a;N;$!ba;s/\n/__BR__/g')
        local clean_tel=$(echo "$tel_text" | sed ':a;N;$!ba;s/\n/__BR__/g')
        
        echo "${title}|||${clean_desc}|||${color}|||${filter}|||${clean_tel}" >> "$OFFLINE_BUFFER"
        log_msg "[BUFFER] Internet Down. Notification buffered." "UPTIME"
        return
    fi

    # Try sending (creds must be loaded)
    if ! send_payload "$title" "$desc" "$color" "$filter" "$tel_text"; then
        # If CURL fails despite status being UP, buffer it as safety net
        # Check Buffer Size (5KB Limit)
        if [ -f "$OFFLINE_BUFFER" ] && [ $(wc -c < "$OFFLINE_BUFFER") -ge 5120 ]; then
             log_msg "[BUFFER] Buffer full (5KB). Send failed & dropped." "UPTIME"
        else
             local clean_desc=$(echo "$desc" | sed ':a;N;$!ba;s/\n/__BR__/g')
             local clean_tel=$(echo "$tel_text" | sed ':a;N;$!ba;s/\n/__BR__/g')
             echo "${title}|||${clean_desc}|||${color}|||${filter}|||${clean_tel}" >> "$OFFLINE_BUFFER"
             log_msg "[BUFFER] Send failed (Curl error). Notification buffered." "UPTIME"
        fi
    fi
}

# --- HELPER: FLUSH BUFFER ---
flush_buffer() {
    if [ -f "$OFFLINE_BUFFER" ]; then
        log_msg "[SYSTEM] Internet Restored. Flushing buffer..." "UPTIME"
        
        # Read file line by line
        while IFS= read -r line; do
             # Split by ||| delimiter
             local b_title=$(echo "$line" | awk -F'|||' '{print $1}')
             local b_desc_raw=$(echo "$line" | awk -F'|||' '{print $2}')
             local b_color=$(echo "$line" | awk -F'|||' '{print $3}')
             local b_filter=$(echo "$line" | awk -F'|||' '{print $4}')
             local b_tel_raw=$(echo "$line" | awk -F'|||' '{print $5}')
             
             # Restore newlines from __BR__ placeholder
             local b_desc=$(echo "$b_desc_raw" | sed 's/__BR__/\n/g')
             local b_tel=$(echo "$b_tel_raw" | sed 's/__BR__/\n/g')
             
             sleep 1 # Maintain delay for buffered messages too
             send_payload "$b_title" "$b_desc" "$b_color" "$b_filter" "$b_tel"
        done < "$OFFLINE_BUFFER"
        
        rm -f "$OFFLINE_BUFFER"
        log_msg "[SYSTEM] Buffer flushed and cleared." "UPTIME"
    fi
}

# --- MAIN LOGIC LOOP ---
while true; do
    load_config
    load_credentials # Load creds at start of loop
    
    NOW_HUMAN=$(date '+%b %d %H:%M:%S')
    NOW_SEC=$(date +%s)
    CUR_HOUR=$(date +%H)
    
    # CPU Guard
    CPU_LOAD=$(cat /proc/loadavg | awk '{print $1}')
    if awk "BEGIN {exit !($CPU_LOAD > $CPU_GUARD_THRESHOLD)}"; then
        log_msg "[SYSTEM] High Load ($CPU_LOAD). Skipping cycle." "UPTIME"
        sleep 10
        continue
    fi

    # --- HEARTBEAT ---
    if [ "$HEARTBEAT" = "YES" ]; then 
        if [ $((NOW_SEC - LAST_HB_CHECK)) -ge "$HB_INTERVAL" ]; then
            LAST_HB_CHECK=$NOW_SEC
            HB_MSG="**Router:** $ROUTER_NAME\n**Status:** Systems Operational\n**Time:** $NOW_HUMAN"
            
            if [ "$HB_MENTION" = "YES" ]; then
                HB_MSG="$HB_MSG\n<@$DISCORD_USERID>"
            fi
            
            # Target Filter
            TARGET=${HB_TARGET:-BOTH}
            send_notification "💓 Heartbeat Report" "$HB_MSG" "1752220" "INFO" "$TARGET" "NO" "💓 Heartbeat - $ROUTER_NAME - $NOW_HUMAN"
            log_msg "[$ROUTER_NAME] Heartbeat sent ($TARGET)." "UPTIME"
        fi
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

    # --- SILENT SUMMARY DUMP ---
    if [ "$IS_SILENT" -eq 0 ] && [ -s "$SILENT_BUFFER" ]; then
        SUMMARY_CONTENT=$(cat "$SILENT_BUFFER")
        CLEAN_SUMMARY=$(echo "$SUMMARY_CONTENT" | sed ':a;N;$!ba;s/\n/\\n/g')
        send_notification "🌙 Silent Hours Summary" "**Router:** $ROUTER_NAME\n$CLEAN_SUMMARY" "10181046" "SUMMARY" "BOTH" "NO" "🌙 Silent Hours Summary - $ROUTER_NAME
$SUMMARY_CONTENT"
        > "$SILENT_BUFFER"
        log_msg "[SYSTEM] Silent buffer dumped and cleared." "UPTIME"
    fi

    # --- INTERNET MONITORING ---
    if [ "$EXT_ENABLE" = "YES" ]; then
        if [ $((NOW_SEC - LAST_EXT_CHECK)) -ge "$EXT_SCAN_INTERVAL" ]; then
            LAST_EXT_CHECK=$NOW_SEC
            FD="$TMP_DIR/nwda_ext_d"; FT="$TMP_DIR/nwda_ext_t"; FC="$TMP_DIR/nwda_ext_c"
            
            EXT_UP=0
            if [ -n "$EXT_IP" ] && ping -q -c "$EXT_PING_COUNT" -W "$EXT_PING_TIMEOUT" "$EXT_IP" > /dev/null 2>&1; then
                EXT_UP=1
                log_msg "INTERNET_CHECK ($EXT_IP): UP" "PING"
            elif [ -n "$EXT_IP2" ] && ping -q -c "$EXT_PING_COUNT" -W "$EXT_PING_TIMEOUT" "$EXT_IP2" > /dev/null 2>&1; then
                EXT_UP=1
                log_msg "INTERNET_CHECK ($EXT_IP2): UP" "PING"
            else
                log_msg "INTERNET_CHECK: DOWN" "PING"
            fi

            if [ "$EXT_UP" -eq 0 ]; then
                C=$(($(cat "$FC" 2>/dev/null || echo 0)+1)); echo "$C" > "$FC"
                if [ "$C" -ge "$EXT_FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                    echo "$NOW_SEC" > "$FD"; echo "$NOW_HUMAN" > "$FT"
                    # CRITICAL: SET STATUS DOWN
                    echo "DOWN" > "$NET_STATUS_FILE"
                    
                    log_msg "[ALERT] [$ROUTER_NAME] INTERNET DOWN" "UPTIME"
                    
                    if [ "$IS_SILENT" -ne 0 ]; then
                         if [ -f "$SILENT_BUFFER" ] && [ $(wc -c < "$SILENT_BUFFER") -ge 5120 ]; then
                             : # Drop
                         else
                             echo "Internet Down: $NOW_HUMAN" >> "$SILENT_BUFFER"
                         fi
                    fi
                fi
            else
                if [ -f "$FD" ]; then
                    # CRITICAL: SET STATUS UP
                    echo "UP" > "$NET_STATUS_FILE"
                    
                    START_TIME=$(cat "$FT"); START_SEC=$(cat "$FD")
                    DURATION_SEC=$((NOW_SEC - START_SEC))
                    DR="$((DURATION_SEC/60))m $((DURATION_SEC%60))s"
                    
                    # DISCORD FORMAT
                    MSG_D="**Router:** $ROUTER_NAME\n**Down at:** $START_TIME\n**Up at:** $NOW_HUMAN\n**Total Outage:** $DR"
                    
                    # TELEGRAM FORMAT
                    MSG_T="🟢 Connectivity Restored * $ROUTER_NAME - $START_TIME - $NOW_HUMAN - $DR"
                    
                    log_msg "[SUCCESS] [$ROUTER_NAME] INTERNET UP (Down $DR)" "UPTIME"
                    
                    if [ "$IS_SILENT" -eq 0 ]; then
                        # 1. SEND INTERNET RESTORED NOTIFICATION
                        send_notification "🟢 Connectivity Restored" "$MSG_D" "3066993" "SUCCESS" "BOTH" "YES" "$MSG_T"
                        
                        # 2. FLUSH BUFFER (Send queued device alerts)
                        flush_buffer
                    else
                         if [ -f "$SILENT_BUFFER" ] && [ $(wc -c < "$SILENT_BUFFER") -ge 5120 ]; then
                             : # Drop
                         else
                             echo -e "Internet Restored: $NOW_HUMAN (Down $DR)" >> "$SILENT_BUFFER"
                         fi
                    fi
                    rm -f "$FD" "$FT"
                else
                     echo "UP" > "$NET_STATUS_FILE"
                fi
                echo 0 > "$FC"
            fi
        fi
    fi

    # --- DEVICE MONITORING ---
    if [ "$DEVICE_MONITOR" = "YES" ]; then
        if [ $((NOW_SEC - LAST_DEV_CHECK)) -ge "$DEV_SCAN_INTERVAL" ]; then
            LAST_DEV_CHECK=$NOW_SEC
            
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
                            CUR_TIME=$(date '+%b %d %H:%M:%S')
                            
                            # DISCORD
                            D_MSG="**Router:** $ROUTER_NAME\n**Device:** $NAME ($TIP)\n**Down at:** $DSTART\n**Up at:** $CUR_TIME\n**Outage:** $DR_STR"
                            # TELEGRAM
                            T_MSG="🟢 Device UP* $ROUTER_NAME - $NAME - $TIP - $CUR_TIME - $DR_STR"
                            
                            log_msg "[SUCCESS] [$ROUTER_NAME] Device: $NAME ($TIP) Online (Down $DR_STR)" "UPTIME"
                            
                            if [ "$SILENT_ENABLE" = "YES" ] && [ "$IS_SILENT" -eq 1 ]; then
                                 if [ -f "$SILENT_BUFFER" ] && [ $(wc -c < "$SILENT_BUFFER") -ge 5120 ]; then :; else
                                     echo "Device $NAME UP: $CUR_TIME (Down $DR_STR)" >> "$SILENT_BUFFER"
                                 fi
                            else
                                 send_notification "🟢 Device Online" "$D_MSG" "3066993" "SUCCESS" "BOTH" "NO" "$T_MSG"
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
                             
                             # DISCORD
                             D_MSG="**Router:** $ROUTER_NAME\n**Device:** $NAME ($TIP)\n**Time:** $TS"
                             # TELEGRAM
                             T_MSG="🔴 Device Down * $ROUTER_NAME - $NAME - $TIP - $TS"
                             
                             if [ "$SILENT_ENABLE" = "YES" ] && [ "$IS_SILENT" -eq 1 ]; then
                                 if [ -f "$SILENT_BUFFER" ] && [ $(wc -c < "$SILENT_BUFFER") -ge 5120 ]; then :; else
                                     echo "Device $NAME DOWN: $TS" >> "$SILENT_BUFFER"
                                 fi
                             else
                                 send_notification "🔴 Device Down" "$D_MSG" "15548997" "ALERT" "BOTH" "NO" "$T_MSG"
                             fi
                        fi
                    fi
                ) &
            done
            wait
        fi
    fi
    sleep 1
done
EOF
chmod +x "$INSTALL_DIR/netwatchda.sh"
# ==============================================================================
#  STEP 8: SERVICE CONFIGURATION (INIT.D)
# ==============================================================================
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

# Shared Helper to load Settings
load_functions() {
    if [ -f "$INSTALL_DIR/netwatchda.sh" ]; then
        . "$INSTALL_DIR/nwda_settings.conf" 2>/dev/null
    fi
}

get_hw_key() {
    local seed="nwda_v1_secure_seed_2025"
    local cpu_serial=\$(grep -i "serial" /proc/cpuinfo | head -1 | awk '{print \$3}')
    [ -z "\$cpu_serial" ] && cpu_serial="unknown_serial"
    local mac_addr=\$(cat /sys/class/net/eth0/address 2>/dev/null)
    [ -z "\$mac_addr" ] && mac_addr=\$(cat /sys/class/net/br-lan/address 2>/dev/null)
    echo -n "\${seed}\${cpu_serial}\${mac_addr}" | openssl dgst -sha256 | awk '{print \$2}'
}

# Helper to Decrypt based on chosen method
get_decrypted_creds() {
    local vault="$INSTALL_DIR/.vault.enc"
    
    if [ ! -f "\$vault" ]; then
        return 1
    fi
    
    # Check Settings if not loaded
    if [ -z "\$ENCRYPTION_METHOD" ]; then
        . "$INSTALL_DIR/nwda_settings.conf" 2>/dev/null
    fi

    local decrypted=""
    if [ "\$ENCRYPTION_METHOD" = "OPENSSL" ]; then
        local key=\$(get_hw_key)
        decrypted=\$(openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -iter 10000 -k "\$key" -in "\$vault" 2>/dev/null)
    else
        # Base64 Fallback
        decrypted=\$(cat "\$vault" | base64 -d 2>/dev/null)
    fi
    echo "\$decrypted"
}

discord() {
    load_functions
    local decrypted=\$(get_decrypted_creds)
    local webhook=\$(echo "\$decrypted" | cut -d'|' -f1)
    
    if [ -n "\$webhook" ]; then
        echo "Sending Discord test..."
        curl -s -k -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🛠️ Discord Warning Test\", \"description\": \"**Router:** \$ROUTER_NAME\nManual warning triggered.\", \"color\": 16776960}]}" "\$webhook"
        echo "Sent."
    else
        echo "No Discord Webhook configured or vault locked."
    fi
}

telegram() {
    load_functions
    local decrypted=\$(get_decrypted_creds)
    local token=\$(echo "\$decrypted" | cut -d'|' -f3)
    local chat=\$(echo "\$decrypted" | cut -d'|' -f4)
    
    if [ -n "\$token" ]; then
        echo "Sending Telegram test..."
        curl -s -k -X POST "https://api.telegram.org/bot\$token/sendMessage" -d chat_id="\$chat" -d text="🛠️ Telegram Warning Test - \$ROUTER_NAME"
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
    
    if [ "\$ENCRYPTION_METHOD" = "OPENSSL" ]; then
        local key=\$(get_hw_key)
        if echo -n "\$new_data" | openssl enc -aes-256-cbc -a -salt -pbkdf2 -iter 10000 -k "\$key" -out "\$vault" 2>/dev/null; then
            echo -e "\033[1;32m✅ Credentials updated and re-encrypted (OpenSSL).\033[0m"
            /etc/init.d/netwatchda restart
        else
            echo -e "\033[1;31m❌ Encryption failed.\033[0m"
        fi
    else
        if echo -n "\$new_data" | base64 > "\$vault"; then
            echo -e "\033[1;32m✅ Credentials updated (Base64).\033[0m"
            /etc/init.d/netwatchda restart
        else
            echo -e "\033[1;31m❌ Encoding failed.\033[0m"
        fi
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

# ==============================================================================
#  STEP 9: FINAL SUCCESS MESSAGE & TEST NOTIFICATION
# ==============================================================================
NOW_FINAL=$(date '+%b %d, %Y %H:%M:%S')
MSG="**Router:** $router_name_input\n**Time:** $NOW_FINAL\n**Status:** Service Installed & Active"

if [ "$DISCORD_ENABLE_VAL" = "YES" ] && [ -n "$DISCORD_WEBHOOK" ]; then
    curl -s -k -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🚀 netwatchda Service Started\", \"description\": \"$MSG\", \"color\": 1752220}]}" "$DISCORD_WEBHOOK" >/dev/null 2>&1
fi

if [ "$TELEGRAM_ENABLE_VAL" = "YES" ] && [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    curl -s -k -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d chat_id="$TELEGRAM_CHAT_ID" -d text="🚀 netwatchda Service Started - $router_name_input" >/dev/null 2>&1
fi

# ==============================================================================
#  FINAL OUTPUT
# ==============================================================================
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