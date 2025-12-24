#!/bin/bash
# netwatchdta Installer - Universal Linux Edition
# Copyright (C) 2025 panoc
# Licensed under the GNU General Public License v3.0

# ==============================================================================
#  SHELL COMPATIBILITY GUARD
# ==============================================================================
# This automatically re-launches the script with bash if executed via sh/dash.
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

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
#  ROOT PRIVILEGE CHECK
# ==============================================================================
if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}❌ Error: This script must be run as root.${NC}"
  echo -e "${YELLOW}👉 Please run: sudo bash $SCRIPT_NAME${NC}"
  exit 1
fi

# ==============================================================================
#  INPUT VALIDATION HELPER FUNCTIONS
# ==============================================================================

# Function: ask_yn
# Purpose:  Forces the user to answer 'y' or 'n'. Ignores all other keys.
ask_yn() {
    local prompt="$1"
    while true; do
        printf "${BOLD}%s [y/n]: ${NC}" "$prompt"
        read input_val
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
        read input_val
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
echo -e "${BOLD}${CYAN}🚀 netwatchdta Automated Setup${NC} v1.2 (Universal Linux by ${BOLD}panoc${NC})"
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
INSTALL_DIR="/opt/netwatchdta"
TMP_DIR="/tmp/netwatchdta"
CONFIG_FILE="$INSTALL_DIR/nwdta_settings.conf"
IP_LIST_FILE="$INSTALL_DIR/nwdta_ips.conf"
VAULT_FILE="$INSTALL_DIR/.vault.enc"
SERVICE_NAME="netwatchdta"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
CLI_WRAPPER="/usr/local/bin/netwatchdta"

# Ensure temp directory exists for installation logs
mkdir -p "$TMP_DIR"

# ==============================================================================
#  STEP 1: SYSTEM READINESS CHECKS
# ==============================================================================
echo -e "\n${BOLD}📦 Checking system readiness...${NC}"

# 1. Distro & Package Manager Detection
PKG_MAN=""
INSTALL_CMD=""
UPDATE_CMD=""
PKG_LIST="curl openssl ca-certificates iputils-ping bc" 

if command -v apt-get >/dev/null; then
    PKG_MAN="apt"
    INSTALL_CMD="apt-get install -y"
    UPDATE_CMD="apt-get update"
elif command -v dnf >/dev/null; then
    PKG_MAN="dnf"
    INSTALL_CMD="dnf install -y"
    UPDATE_CMD="dnf check-update"
    PKG_LIST="curl openssl ca-certificates iputils bc"
elif command -v pacman >/dev/null; then
    PKG_MAN="pacman"
    INSTALL_CMD="pacman -S --noconfirm"
    UPDATE_CMD="pacman -Sy"
    PKG_LIST="curl openssl ca-certificates iputils bc"
elif command -v yum >/dev/null; then
    PKG_MAN="yum"
    INSTALL_CMD="yum install -y"
    UPDATE_CMD="yum check-update"
    PKG_LIST="curl openssl ca-certificates iputils bc"
else
    echo -e "${RED}❌ Error: Unsupported Linux Distribution.${NC}"
    echo -e "${YELLOW}Could not detect apt, dnf, pacman, or yum.${NC}"
    exit 1
fi

# 2. Check Disk Space (Root partition)
FREE_DISK_KB=$(df / | awk 'NR==2 {print $4}')
MIN_DISK_KB=10240 # 10MB Threshold for Linux

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

# 4. Check Dependencies
MISSING_DEPS=""
NEEDS_UPDATE=0

for pkg in $PKG_LIST; do
    # Check if command exists (fastest) or package is installed
    BASE_CMD=$(echo "$pkg" | cut -d'-' -f1) # grab 'curl' from 'curl'
    if ! command -v "$BASE_CMD" >/dev/null 2>&1; then
        # If command check fails, try basic package manager query
        if [ "$PKG_MAN" = "apt" ]; then
             dpkg -s "$pkg" >/dev/null 2>&1 || MISSING_DEPS="$MISSING_DEPS $pkg"
        elif [ "$PKG_MAN" = "rpm" ] || [ "$PKG_MAN" = "dnf" ] || [ "$PKG_MAN" = "yum" ]; then
             rpm -q "$pkg" >/dev/null 2>&1 || MISSING_DEPS="$MISSING_DEPS $pkg"
        else
             # For others, assume missing if command missing
             MISSING_DEPS="$MISSING_DEPS $pkg"
        fi
    fi
done

# Disk Guard Check
if [ "$FREE_DISK_KB" -lt "$MIN_DISK_KB" ]; then
    echo -e "${RED}❌ ERROR: Insufficient Disk Space!${NC}"
    echo -e "${YELLOW}Available: $((FREE_DISK_KB / 1024))MB | Required: 10MB${NC}"
    exit 1
fi

# Dependency Installation Logic
if [ -n "$MISSING_DEPS" ]; then
    echo -e "${CYAN}🔍 Missing dependencies found:${BOLD}$MISSING_DEPS${NC}"
    
    ask_yn "❓ Download missing dependencies?"
    if [ "$ANSWER_YN" = "y" ]; then
            echo -e "${YELLOW}📥 Updating package lists ($PKG_MAN)...${NC}"
            $UPDATE_CMD > /dev/null 2>&1
            
            echo -e "${YELLOW}📥 Installing:$MISSING_DEPS...${NC}"
            $INSTALL_CMD $MISSING_DEPS > /tmp/nwdta_install_err.log 2>&1
            
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
else
    echo -e "${GREEN}✅ All dependencies are installed.${NC}"
    echo -e "${GREEN}✅ Disk storage check passed: $((FREE_DISK_KB / 1024))MB available.${NC}"
fi

echo -e "${GREEN}✅ System Ready.${NC}"
echo -e "${GREEN}✅ Execution Mode Auto-Selected: ${BOLD}${WHITE}$EXEC_MSG${NC}"

# ==============================================================================
#  STEP 2: SMART UPGRADE / INSTALL CHECK
# ==============================================================================
KEEP_CONFIG=0
if [ -f "$CONFIG_FILE" ]; then
    echo -e "\n${YELLOW}⚠️  Existing installation found.${NC}"
    echo -e "   1. ${BOLD}${WHITE}Keep settings (Upgrade)${NC}"
    echo -e "   2. ${BOLD}${WHITE}Clean install${NC}"
    
    ask_opt "Enter choice" "2"
    
    if [ "$ANSWER_OPT" = "1" ]; then
        echo -e "${CYAN}🔧 Upgrading logic while keeping settings...${NC}"
        KEEP_CONFIG=1
    else
        echo -e "${RED}🧹 Performing clean install...${NC}"
        systemctl stop "$SERVICE_NAME" >/dev/null 2>&1
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
    DEF_HOST=$(hostname)
    printf "${BOLD}🏷️  Enter Router/System Name [Default: $DEF_HOST]: ${NC}"
    read router_name_input
    if [ -z "$router_name_input" ]; then router_name_input="$DEF_HOST"; fi
    
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
        read DISCORD_WEBHOOK
        printf "${BOLD}   > Enter Discord User ID (for @mentions): ${NC}"
        read DISCORD_USERID
        
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
                 echo -e "   1. ${BOLD}${WHITE}Input credentials again${NC}"
                 echo -e "   2. ${BOLD}${WHITE}Disable Discord and continue${NC}"
                 ask_opt "   Choice" "2"
                 if [ "$ANSWER_OPT" = "2" ]; then
                     DISCORD_ENABLE_VAL="NO"
                     break
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
        read TELEGRAM_BOT_TOKEN
        printf "${BOLD}   > Enter Telegram Chat ID: ${NC}"
        read TELEGRAM_CHAT_ID
        
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
                echo -e "   1. ${BOLD}${WHITE}Input credentials again${NC}"
                echo -e "   2. ${BOLD}${WHITE}Disable Telegram and continue${NC}"
                ask_opt "   Choice" "2"
                if [ "$ANSWER_OPT" = "2" ]; then
                    TELEGRAM_ENABLE_VAL="NO"
                    break
                fi
            fi
        else
            break
        fi
    done
    
    # 3d. Summary Display
    echo -e "\n${BOLD}${WHITE}Selected Notification Strategy:${NC}"
    if [ "$DISCORD_ENABLE_VAL" = "YES" ] && [ "$TELEGRAM_ENABLE_VAL" = "YES" ]; then
        echo -e "   • ${BOLD}${WHITE}BOTH${NC}"
    elif [ "$DISCORD_ENABLE_VAL" = "YES" ]; then
         echo -e "   • ${BOLD}${WHITE}Discord Only${NC}"
    elif [ "$TELEGRAM_ENABLE_VAL" = "YES" ]; then
         echo -e "   • ${BOLD}${WHITE}Telegram Only${NC}"
    else
         echo -e "   • ${BOLD}${WHITE}NONE (Log only mode)${NC}"
    fi

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
            read user_silent_start
            if echo "$user_silent_start" | grep -qE '^[0-9]+$' && [ "$user_silent_start" -ge 0 ] && [ "$user_silent_start" -le 23 ] 2>/dev/null; then
                break
            else
                echo -e "${RED}   ❌ Invalid hour. Use 0-23.${NC}"
            fi
        done
        while :; do
            printf "${BOLD}   > End Hour (0-23): ${NC}"
            read user_silent_end
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
    HB_MENTION="NO"
    HB_TARGET="BOTH"
    HB_START_HOUR="12"
    
    echo -e "\n${BLUE}--- Heartbeat Settings ---${NC}"
    ask_yn "💓 Enable Heartbeat (System check-in)?"
    
    if [ "$ANSWER_YN" = "y" ]; then
        HB_VAL="YES"
        printf "${BOLD}   > Interval in HOURS (e.g., 24): ${NC}"
        read hb_hours
        if echo "$hb_hours" | grep -qE '^[0-9]+$'; then
             HB_SEC=$((hb_hours * 3600))
        else
             HB_SEC=86400 # Default fallback
        fi

        # New: Ask for Start Hour
        while :; do
            printf "${BOLD}   > Start Hour (0-23) [Default 12]: ${NC}"
            read HB_START_HOUR
            if [ -z "$HB_START_HOUR" ]; then HB_START_HOUR="12"; break; fi
            if echo "$HB_START_HOUR" | grep -qE '^[0-9]+$' && [ "$HB_START_HOUR" -ge 0 ] && [ "$HB_START_HOUR" -le 23 ]; then
                break
            fi
            echo -e "${RED}   ❌ Invalid hour.${NC}"
        done
        
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

    # 3g. Monitoring Mode Selection
    echo -e "\n${BLUE}--- Monitoring Mode ---${NC}"
    echo -e "   1. ${BOLD}${WHITE}Both (Default)${NC}"
    echo -e "   2. ${BOLD}${WHITE}Device Connectivity only${NC}"
    echo -e "   3. ${BOLD}${WHITE}Internet Connectivity only${NC}"
    
    ask_opt "Enter choice" "3"

    case "$ANSWER_OPT" in
        2) EXT_VAL="NO";  DEV_VAL="YES" ;;
        3) EXT_VAL="YES"; DEV_VAL="NO"  ;;
        *) EXT_VAL="YES"; DEV_VAL="YES" ;;
    esac

    # ==============================================================================
    #  STEP 4: GENERATE CONFIGURATION FILES
    # ==============================================================================
    cat <<EOF > "$CONFIG_FILE"
# nwdta_settings.conf - Configuration for netwatchdta
# Note: Credentials are stored in .vault.enc (Method: OPENSSL)
ROUTER_NAME="$router_name_input"
EXEC_METHOD=$AUTO_EXEC_METHOD # 1 = Parallel (Fast, High RAM > 256MB), 2 = Sequential (Safe, Low RAM < 256MB)

[Log Settings]
UPTIME_LOG_MAX_SIZE=512000 # Increased buffer for Linux systems
PING_LOG_ENABLE=NO # Enable or disable detailed ping logging (YES/NO). Default is NO.

[Notification Settings]
DISCORD_ENABLE=$DISCORD_ENABLE_VAL # Global toggle for Discord notifications (YES/NO). Default is NO.
TELEGRAM_ENABLE=$TELEGRAM_ENABLE_VAL # Global toggle for Telegram notifications (YES/NO). Default is NO.
SILENT_ENABLE=$SILENT_ENABLE_VAL # Mutes Discord alerts during specific hours (YES/NO). Default is NO.
SILENT_START=$user_silent_start # Hour to start silent mode (0-23). Default is 23.
SILENT_END=$user_silent_end # Hour to end silent mode (0-23). Default is 07.

[Performance Settings]
CPU_GUARD_THRESHOLD=4.0 # Higher threshold for multi-core Linux systems
RAM_GUARD_MIN_FREE=20480 # 20MB guard for Linux

[Heartbeat]
HEARTBEAT=$HB_VAL # Periodic I am alive notification (YES/NO). Default is NO.
HB_INTERVAL=$HB_SEC # Seconds between heartbeat messages. Default is 86400.
HB_MENTION=$HB_MENTION # Ping User ID in heartbeat messages (YES/NO). Default is NO.
HB_TARGET=$HB_TARGET # Target for Heartbeat: DISCORD, TELEGRAM, BOTH
HB_START_HOUR=$HB_START_HOUR # Time of Heartbeat will start, also if 24H interval is selected time of day Heartbeat will notify. Default is 12.

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
    # Attempt to auto-detect local gateway IP for user convenience on Linux
    LOCAL_IP=$(ip route | grep default | awk '{print $3}' | head -1)
    [ -n "$LOCAL_IP" ] && echo "$LOCAL_IP @ Network Gateway" >> "$IP_LIST_FILE"
fi

# ==============================================================================
#  STEP 5: SECURE CREDENTIAL VAULT (OPENSSL ENFORCED)
# ==============================================================================
echo -e "\n${CYAN}🔐 Securing credentials (OpenSSL AES-256)...${NC}"

# Function: get_hw_key (Linux Universal Variant)
get_hw_key() {
    local seed="nwdta_v1_linux_secure_seed_2025"
    
    # Method 1: Machine ID (Systemd Standard)
    local machine_id=""
    if [ -f /etc/machine-id ]; then
        machine_id=$(cat /etc/machine-id)
    elif [ -f /var/lib/dbus/machine-id ]; then
        machine_id=$(cat /var/lib/dbus/machine-id)
    fi
    
    # Method 2: Product UUID (Backup for non-systemd)
    if [ -z "$machine_id" ]; then
        machine_id=$(cat /sys/class/dmi/id/product_uuid 2>/dev/null)
    fi
    
    # Method 3: Fallback to MAC Address
    if [ -z "$machine_id" ]; then
        machine_id=$(cat /sys/class/net/*/address 2>/dev/null | grep -v "00:00:00:00:00:00" | sort | head -1)
    fi
    
    [ -z "$machine_id" ] && machine_id="unknown_linux_host"
    
    echo -n "${seed}${machine_id}" | openssl dgst -sha256 | awk '{print $2}'
}

# Create the Vault Data String
# Format: DISCORD_WEBHOOK|DISCORD_USERID|TELEGRAM_BOT_TOKEN|TELEGRAM_CHAT_ID
if [ "$KEEP_CONFIG" -eq 0 ]; then
    VAULT_DATA="${DISCORD_WEBHOOK}|${DISCORD_USERID}|${TELEGRAM_BOT_TOKEN}|${TELEGRAM_CHAT_ID}"
    
    # FORCED OPENSSL AES-256-CBC
    HW_KEY=$(get_hw_key)
    if echo -n "$VAULT_DATA" | openssl enc -aes-256-cbc -a -salt -pbkdf2 -iter 10000 -k "$HW_KEY" -out "$VAULT_FILE" 2>/dev/null; then
        echo -e "${GREEN}✅ Credentials Encrypted and locked to this machine ID.${NC}"
    else
        echo -e "${RED}❌ OpenSSL Encryption failed! Check openssl installation.${NC}"
    fi
fi

# ==============================================================================
#  STEP 6: GENERATE CORE SCRIPT (THE ENGINE)
# ==============================================================================
echo -e "\n${CYAN}🛠️  Generating core script...${NC}"

cat <<'EOF' > "$INSTALL_DIR/netwatchdta.sh"
#!/bin/bash
# netwatchdta - Network Monitoring for Linux (Core Engine)

# --- DIRECTORY DEFS ---
BASE_DIR="/opt/netwatchdta"
IP_LIST_FILE="$BASE_DIR/nwdta_ips.conf"
CONFIG_FILE="$BASE_DIR/nwdta_settings.conf"
VAULT_FILE="$BASE_DIR/.vault.enc"

# Persistent Buffers
SILENT_BUFFER="$BASE_DIR/nwdta_silent_buffer"
OFFLINE_BUFFER="$BASE_DIR/nwdta_offline_buffer"

# RAM/Temp Paths
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
LAST_HB_CHECK=0 # Initialized to 0 to trigger check logic immediately

# --- HELPER: LOGGING ---
log_msg() {
    local msg="$1"
    local type="$2" # UPTIME or PING
    local ts=$(date '+%b %d %H:%M:%S')
    
    if [ "$type" = "PING" ] && [ "$PING_LOG_ENABLE" = "YES" ]; then
        echo "$ts - $msg" >> "$PINGLOG"
        # Check size (Linux stat)
        local fsize=$(stat -c%s "$PINGLOG" 2>/dev/null || echo 0)
        if [ "$fsize" -gt "$UPTIME_LOG_MAX_SIZE" ]; then
            echo "$ts - [SYSTEM] Log rotated." > "$PINGLOG"
        fi
    elif [ "$type" = "UPTIME" ]; then
        echo "$ts - $msg" >> "$LOGFILE"
        local fsize=$(stat -c%s "$LOGFILE" 2>/dev/null || echo 0)
        if [ "$fsize" -gt "$UPTIME_LOG_MAX_SIZE" ]; then
            echo "$ts - [SYSTEM] Log rotated." > "$LOGFILE"
        fi
    fi
}

# --- HELPER: CONFIG LOADER ---
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        eval "$(grep -E '^[A-Z0-9_]+=' "$CONFIG_FILE" | sed 's/ #.*//')"
    fi
}

# --- HELPER: HW KEY GENERATION ---
get_hw_key() {
    local seed="nwdta_v1_linux_secure_seed_2025"
    local machine_id=""
    if [ -f /etc/machine-id ]; then machine_id=$(cat /etc/machine-id)
    elif [ -f /var/lib/dbus/machine-id ]; then machine_id=$(cat /var/lib/dbus/machine-id)
    fi
    if [ -z "$machine_id" ]; then machine_id=$(cat /sys/class/dmi/id/product_uuid 2>/dev/null); fi
    if [ -z "$machine_id" ]; then machine_id=$(cat /sys/class/net/*/address 2>/dev/null | grep -v "00:00:00:00:00:00" | sort | head -1); fi
    [ -z "$machine_id" ] && machine_id="unknown_linux_host"
    echo -n "${seed}${machine_id}" | openssl dgst -sha256 | awk '{print $2}'
}

# --- HELPER: CREDENTIAL DECRYPTION (OPTIMIZED ONCE-AT-STARTUP) ---
load_credentials() {
    if [ -f "$VAULT_FILE" ]; then
        local decrypted=""
        local key=$(get_hw_key)
        
        decrypted=$(openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -iter 10000 -k "$key" -in "$VAULT_FILE" 2>/dev/null)
        
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
    local telegram_text="$5" 
    local success=0

    # 1. DISCORD
    if [ "$DISCORD_ENABLE" = "YES" ] && [ -n "$DISCORD_WEBHOOK" ]; then
        if [ -z "$filter" ] || [ "$filter" = "BOTH" ] || [ "$filter" = "DISCORD" ]; then
             local json_desc=$(echo "$desc" | sed ':a;N;$!ba;s/\n/\\n/g')
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
    
    return $((1 - success))
}

# --- HELPER: NOTIFICATION SENDER ---
send_notification() {
    local title="$1"; local desc="$2"; local color="$3"; local type="$4"; local filter="$5"; local force="$6"; local tel_text="$7"
    
    # RAM Guard (Linux adaptation)
    local free_ram=$(free -k | awk '/^Mem:/ {print $4}')
    if [ "$free_ram" -lt "$RAM_GUARD_MIN_FREE" ]; then
        log_msg "[SYSTEM] RAM LOW ($free_ram KB). Notification skipped." "UPTIME"
        return
    fi
    
    sleep 1

    local net_stat="UP"
    if [ -f "$NET_STATUS_FILE" ]; then net_stat=$(cat "$NET_STATUS_FILE"); fi

    # IF Internet is DOWN and not forced -> BUFFER IT
    if [ "$net_stat" = "DOWN" ] && [ "$force" != "YES" ]; then
        if [ -f "$OFFLINE_BUFFER" ] && [ $(stat -c%s "$OFFLINE_BUFFER" 2>/dev/null || echo 0) -ge 10240 ]; then
             log_msg "[BUFFER] Buffer full. Dropped." "UPTIME"
             return
        fi
        local clean_desc=$(echo "$desc" | sed ':a;N;$!ba;s/\n/__BR__/g')
        local clean_tel=$(echo "$tel_text" | sed ':a;N;$!ba;s/\n/__BR__/g')
        echo "${title}|||${clean_desc}|||${color}|||${filter}|||${clean_tel}" >> "$OFFLINE_BUFFER"
        log_msg "[BUFFER] Internet Down. Notification buffered." "UPTIME"
        return
    fi

    # Try sending
    if ! send_payload "$title" "$desc" "$color" "$filter" "$tel_text"; then
        if [ -f "$OFFLINE_BUFFER" ] && [ $(stat -c%s "$OFFLINE_BUFFER" 2>/dev/null || echo 0) -ge 10240 ]; then
             log_msg "[BUFFER] Buffer full. Failed." "UPTIME"
        else
             local clean_desc=$(echo "$desc" | sed ':a;N;$!ba;s/\n/__BR__/g')
             local clean_tel=$(echo "$tel_text" | sed ':a;N;$!ba;s/\n/__BR__/g')
             echo "${title}|||${clean_desc}|||${color}|||${filter}|||${clean_tel}" >> "$OFFLINE_BUFFER"
             log_msg "[BUFFER] Send failed. Buffered." "UPTIME"
        fi
    fi
}

# --- HELPER: FLUSH BUFFER ---
flush_buffer() {
    if [ -f "$OFFLINE_BUFFER" ]; then
        log_msg "[SYSTEM] Internet Restored. Flushing buffer..." "UPTIME"
        while read -r line; do
             local b_title=$(echo "$line" | awk -F '\\|\\|\\|' '{print $1}')
             local b_desc_raw=$(echo "$line" | awk -F '\\|\\|\\|' '{print $2}')
             local b_color=$(echo "$line" | awk -F '\\|\\|\\|' '{print $3}')
             local b_filter=$(echo "$line" | awk -F '\\|\\|\\|' '{print $4}')
             local b_tel_raw=$(echo "$line" | awk -F '\\|\\|\\|' '{print $5}')
             
             local b_desc=$(echo "$b_desc_raw" | sed 's/__BR__/\\n/g')
             local b_tel=$(echo "$b_tel_raw" | sed 's/__BR__/\n/g')
             
             sleep 1 
             send_payload "$b_title" "$b_desc" "$b_color" "$b_filter" "$b_tel"
        done < "$OFFLINE_BUFFER"
        rm -f "$OFFLINE_BUFFER"
        log_msg "[SYSTEM] Buffer flushed." "UPTIME"
    fi
}
# --- STARTUP SEQUENCE ---
load_config
load_credentials
if [ $? -eq 0 ]; then
    log_msg "[SYSTEM] Credentials loaded and decrypted." "UPTIME"
else
    log_msg "[WARNING] Vault error or missing." "UPTIME"
fi

# Initial Heartbeat Logic to handle HB_START_HOUR
if [ "$HEARTBEAT" = "YES" ]; then
    # Fake the last check to be 'now' so the loop calculates from this point
    # We will let the specific hour logic inside the loop handle the first trigger
    LAST_HB_CHECK=$(date +%s)
fi

# --- MAIN LOGIC LOOP ---
while true; do
    load_config
    NOW_HUMAN=$(date '+%b %d %H:%M:%S'); NOW_SEC=$(date +%s); CUR_HOUR=$(date +%H)
    
    # CPU Guard (Linux loadavg)
    CPU_LOAD=$(cat /proc/loadavg | awk '{print $1}')
    if (( $(echo "$CPU_LOAD > $CPU_GUARD_THRESHOLD" | bc -l) )); then
        log_msg "[SYSTEM] High Load ($CPU_LOAD). Skipping." "UPTIME"
        sleep 10
        continue
    fi

    # --- HEARTBEAT LOGIC WITH START HOUR ---
    if [ "$HEARTBEAT" = "YES" ]; then 
        HB_DIFF=$((NOW_SEC - LAST_HB_CHECK))
        if [ "$HB_DIFF" -ge "$HB_INTERVAL" ]; then
            CAN_SEND=0
            # If default interval (24h), align with hour
            if [ "$HB_INTERVAL" -ge 86000 ]; then
                 # If we are in the correct hour (allow match)
                 if [ "$CUR_HOUR" -eq "$HB_START_HOUR" ]; then CAN_SEND=1; fi
                 # Force send if we missed it by a lot (drift safety)
                 if [ "$HB_DIFF" -gt 90000 ]; then CAN_SEND=1; fi
            else
                 # Non-24h interval: Just respect the timer
                 CAN_SEND=1
            fi
            
            if [ "$CAN_SEND" -eq 1 ]; then
                LAST_HB_CHECK=$NOW_SEC
                HB_MSG="**Router:** $ROUTER_NAME\n**Status:** Systems Operational\n**Time:** $NOW_HUMAN"
                if [ "$HB_MENTION" = "YES" ]; then HB_MSG="$HB_MSG\n<@$DISCORD_USERID>"; fi
                TARGET=${HB_TARGET:-BOTH}
                send_notification "💓 Heartbeat Report" "$HB_MSG" "1752220" "INFO" "$TARGET" "NO" "💓 Heartbeat - $ROUTER_NAME - $NOW_HUMAN"
                log_msg "Heartbeat sent ($TARGET)." "UPTIME"
            fi
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
        log_msg "[SYSTEM] Silent buffer dumped." "UPTIME"
    fi

    # --- INTERNET MONITORING ---
    if [ "$EXT_ENABLE" = "YES" ]; then
        if [ $((NOW_SEC - LAST_EXT_CHECK)) -ge "$EXT_SCAN_INTERVAL" ]; then
            LAST_EXT_CHECK=$NOW_SEC
            FD="$TMP_DIR/nwdta_ext_d"; FT="$TMP_DIR/nwdta_ext_t"; FC="$TMP_DIR/nwdta_ext_c"
            
            EXT_UP=0
            if [ -n "$EXT_IP" ] && ping -c "$EXT_PING_COUNT" -W "$EXT_PING_TIMEOUT" "$EXT_IP" > /dev/null 2>&1; then EXT_UP=1;
            elif [ -n "$EXT_IP2" ] && ping -c "$EXT_PING_COUNT" -W "$EXT_PING_TIMEOUT" "$EXT_IP2" > /dev/null 2>&1; then EXT_UP=1; fi

            if [ "$EXT_UP" -eq 0 ]; then
                C=$(($(cat "$FC" 2>/dev/null || echo 0)+1)); echo "$C" > "$FC"
                if [ "$C" -ge "$EXT_FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                    echo "$NOW_SEC" > "$FD"; echo "$NOW_HUMAN" > "$FT"; echo "DOWN" > "$NET_STATUS_FILE"
                    log_msg "[ALERT] INTERNET DOWN" "UPTIME"
                    
                    if [ "$IS_SILENT" -ne 0 ]; then
                         if [ -f "$SILENT_BUFFER" ] && [ $(stat -c%s "$SILENT_BUFFER" 2>/dev/null || echo 0) -ge 10240 ]; then :; else
                             echo "Internet Down: $NOW_HUMAN" >> "$SILENT_BUFFER"
                         fi
                    else
                         # Alert logic logic handles buffering via send_notification if truly down
                         # But since net_stat is DOWN, send_notification will buffer it automatically.
                         # This block is just for logging mainly.
                         :
                    fi
                fi
            else
                if [ -f "$FD" ]; then
                    echo "UP" > "$NET_STATUS_FILE"
                    START_TIME=$(cat "$FT"); START_SEC=$(cat "$FD")
                    DURATION_SEC=$((NOW_SEC - START_SEC))
                    DR="$((DURATION_SEC/60))m $((DURATION_SEC%60))s"
                    MSG_D="**Router:** $ROUTER_NAME\n**Down at:** $START_TIME\n**Up at:** $NOW_HUMAN\n**Total Outage:** $DR"
                    MSG_T="🟢 Connectivity Restored * $ROUTER_NAME - $START_TIME - $NOW_HUMAN - $DR"
                    log_msg "[SUCCESS] INTERNET UP (Down $DR)" "UPTIME"
                    
                    if [ "$IS_SILENT" -eq 0 ]; then
                        send_notification "🟢 Connectivity Restored" "$MSG_D" "3066993" "SUCCESS" "BOTH" "YES" "$MSG_T"
                        flush_buffer
                    else
                         if [ -f "$SILENT_BUFFER" ] && [ $(stat -c%s "$SILENT_BUFFER" 2>/dev/null || echo 0) -ge 10240 ]; then :; else
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
            
            check_device_logic() {
                TIP=$1; NAME=$2
                SIP=$(echo "$TIP" | tr '.' '_')
                FC="$TMP_DIR/dev_${SIP}_c"; FD="$TMP_DIR/dev_${SIP}_d"; FT="$TMP_DIR/dev_${SIP}_t"
                
                if ping -c "$DEV_PING_COUNT" -W 1 "$TIP" > /dev/null 2>&1; then
                    if [ -f "$FD" ]; then
                        DSTART=$(cat "$FT"); DSSEC=$(cat "$FD"); DUR=$(( $(date +%s) - DSSEC ))
                        DR_STR="$((DUR/60))m $((DUR%60))s"
                        CUR_TIME=$(date '+%b %d %H:%M:%S')
                        D_MSG="**Router:** $ROUTER_NAME\n**Device:** $NAME ($TIP)\n**Down at:** $DSTART\n**Up at:** $CUR_TIME\n**Outage:** $DR_STR"
                        T_MSG="🟢 Device UP* $ROUTER_NAME - $NAME - $TIP - $CUR_TIME - $DR_STR"
                        log_msg "[SUCCESS] Device: $NAME Online ($DR_STR)" "UPTIME"
                        
                        if [ "$IS_SILENT" -eq 1 ]; then
                             if [ -f "$SILENT_BUFFER" ] && [ $(stat -c%s "$SILENT_BUFFER" 2>/dev/null || echo 0) -ge 10240 ]; then :; else
                                 echo "Device $NAME UP: $CUR_TIME (Down $DR_STR)" >> "$SILENT_BUFFER"
                             fi
                        else
                             send_notification "🟢 Device Online" "$D_MSG" "3066993" "SUCCESS" "BOTH" "NO" "$T_MSG"
                        fi
                        rm -f "$FD" "$FT"
                    fi
                    echo 0 > "$FC"
                else
                    C=$(($(cat "$FC" 2>/dev/null || echo 0)+1)); echo "$C" > "$FC"
                    if [ "$C" -ge "$DEV_FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                         TS=$(date '+%b %d %H:%M:%S'); echo "$(date +%s)" > "$FD"; echo "$TS" > "$FT"
                         log_msg "[ALERT] Device: $NAME Down" "UPTIME"
                         D_MSG="**Router:** $ROUTER_NAME\n**Device:** $NAME ($TIP)\n**Time:** $TS"
                         T_MSG="🔴 Device Down * $ROUTER_NAME - $NAME - $TIP - $TS"
                         
                         if [ "$IS_SILENT" -eq 1 ]; then
                             if [ -f "$SILENT_BUFFER" ] && [ $(stat -c%s "$SILENT_BUFFER" 2>/dev/null || echo 0) -ge 10240 ]; then :; else
                                 echo "Device $NAME DOWN: $TS" >> "$SILENT_BUFFER"
                             fi
                         else
                             send_notification "🔴 Device Down" "$D_MSG" "15548997" "ALERT" "BOTH" "NO" "$T_MSG"
                         fi
                    fi
                fi
            }

            if [ "$EXEC_METHOD" -eq 1 ]; then
                # PARALLEL EXECUTION
                grep -vE '^#|^$' "$IP_LIST_FILE" | while read -r line; do
                    (
                        TIP=$(echo "$line" | cut -d'@' -f1 | tr -d ' ')
                        NAME=$(echo "$line" | cut -d'@' -f2- | sed 's/^[ \t]*//')
                        [ -z "$NAME" ] && NAME="$TIP"
                        [ -n "$TIP" ] && check_device_logic "$TIP" "$NAME"
                    ) &
                done; wait
            else
                # SEQUENTIAL EXECUTION
                grep -vE '^#|^$' "$IP_LIST_FILE" | while read -r line; do
                    TIP=$(echo "$line" | cut -d'@' -f1 | tr -d ' ')
                    NAME=$(echo "$line" | cut -d'@' -f2- | sed 's/^[ \t]*//')
                    [ -z "$NAME" ] && NAME="$TIP"
                    [ -n "$TIP" ] && check_device_logic "$TIP" "$NAME"
                done
            fi
        fi
    fi
    sleep 1
done
EOF
chmod +x "$INSTALL_DIR/netwatchdta.sh"
# ==============================================================================
#  STEP 7: SERVICE CONFIGURATION (CLI WRAPPER + SYSTEMD)
# ==============================================================================
echo -e "\n${CYAN}⚙️  Configuring system service and CLI wrapper...${NC}"

# 1. Create CLI Wrapper (Simulates the old init.d script behavior)
cat <<EOF > "$CLI_WRAPPER"
#!/bin/bash
# netwatchdta CLI Wrapper for Linux

INSTALL_DIR="/opt/netwatchdta"
CONFIG_FILE="\$INSTALL_DIR/nwdta_settings.conf"
VAULT_FILE="\$INSTALL_DIR/.vault.enc"

# Colors
GREEN='\033[1;32m'; RED='\033[1;31m'; BLUE='\033[1;34m'; NC='\033[0m'

help() {
    echo "Usage: netwatchdta {start|stop|restart|status|logs|clear|discord|telegram|credentials|purge}"
}

get_hw_key() {
    local seed="nwdta_v1_linux_secure_seed_2025"
    local machine_id=\$(cat /etc/machine-id 2>/dev/null)
    [ -z "\$machine_id" ] && machine_id=\$(cat /sys/class/dmi/id/product_uuid 2>/dev/null)
    [ -z "\$machine_id" ] && machine_id=\$(cat /sys/class/net/*/address 2>/dev/null | grep -v "00:00:00:00:00:00" | sort | head -1)
    echo -n "\${seed}\${machine_id}" | openssl dgst -sha256 | awk '{print \$2}'
}

get_decrypted_creds() {
    local key=\$(get_hw_key)
    openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -iter 10000 -k "\$key" -in "\$VAULT_FILE" 2>/dev/null
}

load_vars() {
    [ -f "\$CONFIG_FILE" ] && eval "\$(grep -E '^[A-Z0-9_]+=' "\$CONFIG_FILE" | sed 's/ #.*//')"
}

case "\$1" in
    start)
        systemctl start netwatchdta
        echo -e "\${GREEN}Service started.\${NC}"
        ;;
    stop)
        systemctl stop netwatchdta
        echo -e "\${RED}Service stopped.\${NC}"
        ;;
    restart)
        systemctl restart netwatchdta
        echo -e "\${GREEN}Service restarted.\${NC}"
        ;;
    status)
        systemctl status netwatchdta
        ;;
    logs)
        if [ -f "/tmp/netwatchdta/nwdta_uptime.log" ]; then
            echo -e "\${BLUE}--- Recent Activity ---\${NC}"
            tail -n 20 /tmp/netwatchdta/nwdta_uptime.log
        else
            echo "No log found."
        fi
        ;;
    clear)
        echo "\$(date '+%b %d %H:%M:%S') - [SYSTEM] Log cleared manually." > "/tmp/netwatchdta/nwdta_uptime.log"
        echo "Log file cleared."
        ;;
    discord)
        load_vars
        decrypted=\$(get_decrypted_creds)
        webhook=\$(echo "\$decrypted" | cut -d'|' -f1)
        if [ -n "\$webhook" ]; then
            echo "Sending Discord test..."
            curl -s -k -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🛠️ Discord Warning Test\", \"description\": \"**Router:** \$ROUTER_NAME\nManual warning triggered.\", \"color\": 16776960}]}" "\$webhook"
            echo "Sent."
        else
            echo "No Discord Webhook configured."
        fi
        ;;
    telegram)
        load_vars
        decrypted=\$(get_decrypted_creds)
        token=\$(echo "\$decrypted" | cut -d'|' -f3)
        chat=\$(echo "\$decrypted" | cut -d'|' -f4)
        if [ -n "\$token" ]; then
            echo "Sending Telegram test..."
            curl -s -k -X POST "https://api.telegram.org/bot\$token/sendMessage" -d chat_id="\$chat" -d text="🛠️ Telegram Warning Test - \$ROUTER_NAME"
            echo "Sent."
        else
            echo "No Telegram Token configured."
        fi
        ;;
    credentials)
        echo ""
        echo -e "\${BLUE}🔐 Credential Manager\${NC}"
        echo "1. Change Discord Credentials"
        echo "2. Change Telegram Credentials"
        echo "3. Change Both"
        printf "Choice [1-3]: "
        read c_choice
        
        load_vars
        current=\$(get_decrypted_creds)
        d_hook=\$(echo "\$current" | cut -d'|' -f1)
        d_uid=\$(echo "\$current" | cut -d'|' -f2)
        t_tok=\$(echo "\$current" | cut -d'|' -f3)
        t_chat=\$(echo "\$current" | cut -d'|' -f4)
        
        if [ "\$c_choice" = "1" ] || [ "\$c_choice" = "3" ]; then
            printf "New Discord Webhook: "; read d_hook
            printf "New Discord User ID: "; read d_uid
        fi
        if [ "\$c_choice" = "2" ] || [ "\$c_choice" = "3" ]; then
            printf "New Telegram Token: "; read t_tok
            printf "New Telegram Chat ID: "; read t_chat
        fi
        
        new_data="\${d_hook}|\${d_uid}|\${t_tok}|\${t_chat}"
        key=\$(get_hw_key)
        if echo -n "\$new_data" | openssl enc -aes-256-cbc -a -salt -pbkdf2 -iter 10000 -k "\$key" -out "\$VAULT_FILE" 2>/dev/null; then
            echo -e "\${GREEN}✅ Credentials updated and re-encrypted (OpenSSL).\${NC}"
            systemctl restart netwatchdta
        else
            echo -e "\${RED}❌ Encryption failed.\${NC}"
        fi
        ;;
    purge)
        echo ""
        echo -e "\${RED}=======================================================\${NC}"
        echo -e "\${RED}🗑️  netwatchdta Smart Uninstaller\${NC}"
        echo -e "\${RED}=======================================================\${NC}"
        echo "1. Full Uninstall (Remove everything)"
        echo "2. Keep Settings (Remove logic but keep config)"
        echo "3. Cancel"
        printf "Choice [1-3]: "
        read choice
        
        case "\$choice" in
            1)
                echo "🛑 Stopping service..."
                systemctl stop netwatchdta
                systemctl disable netwatchdta
                rm /etc/systemd/system/netwatchdta.service
                systemctl daemon-reload
                
                echo "🧹 Cleaning up..."
                rm -rf "/tmp/netwatchdta"
                rm -rf "$INSTALL_DIR"
                rm -f "$CLI_WRAPPER"
                echo -e "\${GREEN}✅ netwatchdta has been completely removed.\${NC}"
                ;;
            2)
                echo "🛑 Stopping service..."
                systemctl stop netwatchdta
                systemctl disable netwatchdta
                rm /etc/systemd/system/netwatchdta.service
                systemctl daemon-reload
                rm -rf "/tmp/netwatchdta"
                rm -f "$INSTALL_DIR/netwatchdta.sh"
                rm -f "$CLI_WRAPPER"
                echo -e "\${BLUE}✅ Logic removed. Settings preserved in $INSTALL_DIR\${NC}"
                ;;
            *)
                echo "❌ Purge cancelled."
                exit 0
                ;;
        esac
        ;;
    *)
        help
        ;;
esac
EOF
chmod +x "$CLI_WRAPPER"

# 2. Create Systemd Service File
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=netwatchdta Network Monitor
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash $INSTALL_DIR/netwatchdta.sh
Restart=always
RestartSec=5
StandardOutput=null
StandardError=null

[Install]
WantedBy=multi-user.target
EOF

# 3. Enable and Start Service
systemctl daemon-reload
systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
systemctl restart "$SERVICE_NAME" >/dev/null 2>&1

# ==============================================================================
#  STEP 8: FINAL SUCCESS MESSAGE
# ==============================================================================
NOW_FINAL=$(date '+%b %d, %Y %H:%M:%S')
MSG="**Router:** $router_name_input\n**Time:** $NOW_FINAL\n**Status:** Service Installed & Active (Linux)"

if [ "$DISCORD_ENABLE_VAL" = "YES" ] && [ -n "$DISCORD_WEBHOOK" ]; then
    curl -s -k -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🚀 netwatchdta Service Started\", \"description\": \"$MSG\", \"color\": 1752220}]}" "$DISCORD_WEBHOOK" >/dev/null 2>&1
fi

if [ "$TELEGRAM_ENABLE_VAL" = "YES" ] && [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    curl -s -k -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d chat_id="$TELEGRAM_CHAT_ID" -d text="🚀 netwatchdta Service Started - $router_name_input" >/dev/null 2>&1
fi

# ==============================================================================
#  FINAL OUTPUT
# ==============================================================================
echo ""
echo -e "${GREEN}=======================================================${NC}"
echo -e "${BOLD}${GREEN}✅ Installation complete!${NC}"
echo -e "${CYAN}📂 Folder:${NC} $INSTALL_DIR"
echo -e "${CYAN}⌨️  Command:${NC} netwatchdta [status|logs|discord|purge]"
echo -e "${GREEN}=======================================================${NC}"
echo -e "\n${BOLD}Quick Commands:${NC}"
echo -e "  Uninstall        : ${RED}netwatchdta purge${NC}"
echo -e "  Manage Creds     : ${YELLOW}netwatchdta credentials${NC}"
echo -e "  Edit Settings    : ${CYAN}$CONFIG_FILE${NC}"
echo -e "  Edit IP List     : ${CYAN}$IP_LIST_FILE${NC}"
echo -e "  Restart          : ${YELLOW}netwatchdta restart${NC}"
echo ""