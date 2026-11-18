#!/bin/sh
# netwatchdta Installer - Automated Setup for OpenWrt & Linux (Universal)
# Copyright (C) 2025-2026 panoc
# Licensed under the GNU General Public License v3.0
SCRIPT_VERSION="1.6.0"

# ==============================================================================
#  SELF-CLEANUP MECHANISM
# ==============================================================================
# This ensures the installer script deletes itself after execution to keep
# the /tmp directory clean.
SCRIPT_NAME="$0"
SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
cleanup() {
    # Only self-delete when the installer was run from /tmp
    case "$SCRIPT_DIR" in
        /tmp|/tmp/*) [ -f "$SCRIPT_NAME" ] && rm -f "$SCRIPT_NAME" ;;
    esac
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
#  OS DETECTION ENGINE
# ==============================================================================
# Detects if running on OpenWrt or Standard Linux (Systemd)
OS_TYPE="UNKNOWN"
PKG_MANAGER=""
INSTALL_DIR=""
SERVICE_TYPE=""

if [ -f /etc/openwrt_release ]; then
    OS_TYPE="OPENWRT"
    # Fallback to opkg if apk (OpenWrt 24.10+) is not present
    if command -v apk >/dev/null 2>&1; then
        PKG_MANAGER="apk"
    else
        PKG_MANAGER="opkg"
    fi
    INSTALL_DIR="/root/netwatchdta"
    SERVICE_TYPE="PROCD"
elif [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_TYPE="LINUX"
    INSTALL_DIR="/opt/netwatchdta"
    SERVICE_TYPE="SYSTEMD"
    
    # Detect Package Manager
    case "$ID" in
        debian|ubuntu|linuxmint|kali|raspbian|pop) PKG_MANAGER="apt" ;;
        fedora|centos|rhel|almalinux|rocky) PKG_MANAGER="dnf" ;;
        arch|manjaro|endeavouros) PKG_MANAGER="pacman" ;;
        opensuse*|sles) PKG_MANAGER="zypper" ;;
        alpine) PKG_MANAGER="apk" ;;
        *) PKG_MANAGER="unknown" ;;
    esac
else
    printf '%b\n' "${RED}❌ Critical Error: Unsupported Operating System.${NC}"
    printf '%b\n' "   Supported: OpenWrt, Ubuntu, Debian, CentOS, Fedora, Arch, etc."
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
safe_fetch() {
    local url="$1"
    local data="$2"   # JSON Payload
    local h1="$3"     # Header 1
    local h2="$4"     # Header 2
    local h3="$5"     # Header 3

    # STRATEGY 1: uclient-fetch (OpenWrt Native & Light)
    # Applied -qO- fix for reliability with POST bodies
    if [ "$OS_TYPE" = "OPENWRT" ] && (command -v uclient-fetch >/dev/null 2>&1 || [ -x /bin/uclient-fetch ]); then
        if uclient-fetch --help 2>&1 | grep -q "\-\-header"; then
            if [ -n "$h3" ]; then
                uclient-fetch --no-check-certificate -qO- --header="$h1" --header="$h2" --header="$h3" --post-data="$data" "$url" >/dev/null 2>&1
            elif [ -n "$h2" ]; then
                uclient-fetch --no-check-certificate -qO- --header="$h1" --header="$h2" --post-data="$data" "$url" >/dev/null 2>&1
            elif [ -n "$h1" ]; then
                uclient-fetch --no-check-certificate -qO- --header="$h1" --post-data="$data" "$url" >/dev/null 2>&1
            else
                uclient-fetch --no-check-certificate -qO- --post-data="$data" "$url" >/dev/null 2>&1
            fi
            return 0 
        fi
    fi

    # STRATEGY 2: Curl (Robust Fallback & Preferred on Linux)
    if command -v curl >/dev/null 2>&1; then
        if [ -n "$h3" ]; then
            curl -s -k -X POST -H "$h1" -H "$h2" -H "$h3" -d "$data" "$url" >/dev/null 2>&1
        elif [ -n "$h2" ]; then
            curl -s -k -X POST -H "$h1" -H "$h2" -d "$data" "$url" >/dev/null 2>&1
        elif [ -n "$h1" ]; then
            curl -s -k -X POST -H "$h1" -d "$data" "$url" >/dev/null 2>&1
        else
            curl -s -k -X POST -d "$data" "$url" >/dev/null 2>&1
        fi
        return 0
    fi

    # STRATEGY 3: Wget (Last Resort)
    if command -v wget >/dev/null 2>&1; then
        if [ -n "$h3" ]; then
            wget -q --no-check-certificate --header="$h1" --header="$h2" --header="$h3" --post-data="$data" "$url" -O /dev/null
        elif [ -n "$h2" ]; then
            wget -q --no-check-certificate --header="$h1" --header="$h2" --post-data="$data" "$url" -O /dev/null
        elif [ -n "$h1" ]; then
            wget -q --no-check-certificate --header="$h1" --post-data="$data" "$url" -O /dev/null
        else
            wget -q --no-check-certificate --post-data="$data" "$url" -O /dev/null
        fi
        return 0
    fi
    
    return 1 # Failure: No tool found
}

# ==============================================================================
#  INSTALLER HEADER
# ==============================================================================
printf '%b\n' "${BLUE}=======================================================${NC}"
printf '%b\n' "${BOLD}${CYAN}🚀 netwatchdta Universal Setup${NC} v$SCRIPT_VERSION"
printf '%b\n' "${BLUE}⚖️  License: GNU GPLv3${NC}"
printf '%b\n' "${BLUE}=======================================================${NC}"
printf '%b\n' "${WHITE}🖥️  System Detected : ${GREEN}$OS_TYPE${NC}"
printf '%b\n' "${WHITE}📦 Package Manager : ${GREEN}$PKG_MANAGER${NC}"
printf '%b\n' "${WHITE}📂 Install Path    : ${GREEN}$INSTALL_DIR${NC}"
printf '%b\n' "${WHITE}⚙️  Service Manager : ${GREEN}$SERVICE_TYPE${NC}"
echo ""

# Root Check
if [ "$(id -u)" -ne 0 ]; then
    printf '%b\n' "${RED}❌ Permission Denied!${NC}"
    printf '%b\n' "   You must run this installer as ${BOLD}root${NC} (or use sudo)."
    exit 1
fi

# --- 0. PRE-INSTALLATION CONFIRMATION ---
ask_yn "❓ This will begin the installation process. Continue?"
if [ "$ANSWER_YN" = "n" ]; then
    printf '%b\n' "${RED}❌ Installation aborted by user. Cleaning up...${NC}"
    exit 0
fi

# ==============================================================================
#  DIRECTORY & FILE PATH DEFINITIONS
# ==============================================================================
# Paths are set dynamically based on OS_TYPE in the block above
CONFIG_FILE="$INSTALL_DIR/settings.conf"
IP_LIST_FILE="$INSTALL_DIR/device_ips.conf"
REMOTE_LIST_FILE="$INSTALL_DIR/remote_ips.conf"
VAULT_FILE="$INSTALL_DIR/.vault.enc"   # legacy (<=1.5.x), migrated + removed on upgrade
CRED_FILE="$INSTALL_DIR/credentials.conf"
COMMON_LIB="$INSTALL_DIR/nwdta_common.sh"

# openssl is only needed to migrate an old encrypted vault (<=1.5.x) that hasn't been migrated yet
NEED_OPENSSL=0
if [ -f "$VAULT_FILE" ] && [ ! -f "$CRED_FILE" ] && ! command -v openssl >/dev/null 2>&1; then
    NEED_OPENSSL=1
fi
SERVICE_NAME="netwatchdta"
SERVICE_PATH="/etc/init.d/$SERVICE_NAME"

# Ensure temp directory exists for installation logs
mkdir -p "/tmp/netwatchdta"

# ==============================================================================
#  STEP 1: SYSTEM READINESS CHECKS
# ==============================================================================
printf '%b\n' "\n${BOLD}📦 Checking system readiness...${NC}"

# --- OPENWRT SPECIFIC CHECKS ---
if [ "$OS_TYPE" = "OPENWRT" ]; then
    # 1. Check Flash Storage (Root partition)
    FREE_FLASH_KB=$(df / | awk 'NR==2 {print $4}')
    MIN_FLASH_KB=3072 # 3MB Threshold

    # 2. Check RAM (/tmp partition)
    FREE_RAM_KB=$(df /tmp | awk 'NR==2 {print $4}')
    MIN_RAM_KB=4096 # 4MB Threshold

    # 3. Check Physical Memory for Execution Method Auto-Detection
    TOTAL_PHY_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    
    if [ "$TOTAL_PHY_MEM_KB" -ge 524288 ]; then
        AUTO_EXEC_METHOD="1"
        AUTO_BATCH_SIZE="0" # 0 means Unlimited/Parallel
        EXEC_MSG="High Performance (Parallel Scanning + Parallel Notif)"
    else
        AUTO_EXEC_METHOD="2"
        AUTO_BATCH_SIZE="AUTO" # Will trigger dynamic calculation with 10% Safety Net
        EXEC_MSG="Safe Mode (Smart Batching + Queue Notif)"
    fi

    # 4. Define Dependency List (OpenWrt)
    MISSING_DEPS=""
    # Discord/ntfy/Telegram need custom HTTP headers. Use uclient-fetch only if it supports them, else curl.
    if ! command -v curl >/dev/null 2>&1; then
        if ! { command -v uclient-fetch >/dev/null 2>&1 && uclient-fetch --help 2>&1 | grep -q -- "--header"; }; then
            MISSING_DEPS="$MISSING_DEPS curl"
        fi
    fi
    
    # Check for certificates regardless of package manager
    if [ ! -f /etc/ssl/certs/ca-certificates.crt ]; then
        if command -v apk >/dev/null 2>&1; then
            apk info -e ca-certificates >/dev/null 2>&1 || MISSING_DEPS="$MISSING_DEPS ca-certificates"
        else
            command -v opkg >/dev/null && opkg list-installed | grep -q ca-bundle || MISSING_DEPS="$MISSING_DEPS ca-bundle"
        fi
    fi
    

    if [ "$NEED_OPENSSL" -eq 1 ]; then
        if command -v apk >/dev/null 2>&1; then MISSING_DEPS="$MISSING_DEPS openssl"; else MISSING_DEPS="$MISSING_DEPS openssl-util"; fi
    fi

    # RAM Guard Check
    if [ "$FREE_RAM_KB" -lt "$MIN_RAM_KB" ]; then
        printf '%b\n' "${RED}❌ ERROR: Insufficient RAM for operations!${NC}"
        printf '%b\n' "${YELLOW}Available: $((FREE_RAM_KB / 1024))MB | Required: 4MB${NC}"
        exit 1
    fi

# --- STANDARD LINUX SPECIFIC CHECKS ---
else
    # Linux Desktop/Server always uses Full Parallel
    AUTO_EXEC_METHOD="1"
    AUTO_BATCH_SIZE="0"
    EXEC_MSG="High Performance (Parallel Mode)"
    
    MISSING_DEPS=""
    command -v curl >/dev/null 2>&1 || MISSING_DEPS="$MISSING_DEPS curl"
    [ "$NEED_OPENSSL" -eq 1 ] && MISSING_DEPS="$MISSING_DEPS openssl"
    # Ensure ping is available (some minimal containers miss it)
    if ! command -v ping >/dev/null 2>&1; then
        if [ "$PKG_MANAGER" = "apt" ]; then MISSING_DEPS="$MISSING_DEPS iputils-ping"; else MISSING_DEPS="$MISSING_DEPS iputils"; fi
    fi
fi

# --- DEPENDENCY INSTALLATION LOGIC ---
if [ -n "$MISSING_DEPS" ]; then
    printf '%b\n' "${CYAN}🔍 Missing dependencies found:${BOLD}$MISSING_DEPS${NC}"
    [ "$NEED_OPENSSL" -eq 1 ] && printf '%b\n' "${CYAN}   ℹ️  openssl is needed once, to move your old encrypted credentials (.vault.enc) to credentials.conf.${NC}"
    
    if [ "$OS_TYPE" = "OPENWRT" ] && [ "$FREE_FLASH_KB" -lt "$MIN_FLASH_KB" ]; then
        printf '%b\n' "${RED}❌ ERROR: Insufficient Flash storage to install dependencies!${NC}"
        printf '%b\n' "${YELLOW}Available: $((FREE_FLASH_KB / 1024))MB | Required: 3MB${NC}"
        exit 1
    fi
    
    ask_yn "❓ Install missing dependencies?"
    if [ "$ANSWER_YN" = "y" ]; then
         printf '%b\n' "${YELLOW}📥 Installing via $PKG_MANAGER...${NC}"
         
         case "$PKG_MANAGER" in
            opkg)
                opkg update --no-check-certificate > /dev/null 2>&1
                opkg install --no-check-certificate $MISSING_DEPS > /tmp/nwdta_install_err.log 2>&1
                ;;
            apk)
                if [ "$OS_TYPE" = "OPENWRT" ]; then
                    apk update > /dev/null 2>&1
                    apk add $MISSING_DEPS > /tmp/nwdta_install_err.log 2>&1
                else
                    apk add $MISSING_DEPS
                fi
                ;;
            apt)
                apt-get update && apt-get install -y $MISSING_DEPS
                ;;
            dnf)
                dnf install -y $MISSING_DEPS
                ;;
            pacman)
                pacman -Sy --noconfirm $MISSING_DEPS
                ;;
            zypper)
                zypper install -y $MISSING_DEPS
                ;;
            *)
                printf '%b\n' "${RED}❌ Auto-install not supported for this OS.${NC}"
                printf '%b\n' "   Please install manually: $MISSING_DEPS"
                exit 1
                ;;
         esac

         if [ $? -ne 0 ]; then
            printf '%b\n' "${RED}❌ Error installing dependencies.${NC}"
            [ -f /tmp/nwdta_install_err.log ] && cat /tmp/nwdta_install_err.log
            exit 1
         fi
         printf '%b\n' "${GREEN}✅ Dependencies installed successfully.${NC}"
    else
         printf '%b\n' "${RED}❌ Cannot proceed without dependencies. Aborting.${NC}"
         exit 1
    fi
else
    printf '%b\n' "${GREEN}✅ All dependencies are installed.${NC}"
    if [ "$OS_TYPE" = "OPENWRT" ]; then
        printf '%b\n' "${GREEN}✅ Flash storage check passed: $((FREE_FLASH_KB / 1024))MB available.${NC}"
    fi
fi

printf '%b\n' "${GREEN}✅ System Ready.${NC}"
printf '%b\n' "${GREEN}✅ Execution Mode Auto-Selected: ${BOLD}${WHITE}$EXEC_MSG${NC}"

# ==============================================================================
#  STEP 2: SMART UPGRADE / INSTALL CHECK
# ==============================================================================
KEEP_CONFIG=0
if [ -f "$CONFIG_FILE" ]; then
    printf '%b\n' "\n${YELLOW}⚠️  Existing installation found.${NC}"
    printf '%b\n' "${BOLD}${WHITE}1.${NC} Keep settings (Upgrade)"
    printf '%b\n' "${BOLD}${WHITE}2.${NC} Clean install"
    
    ask_opt "Enter choice" "2"
    
    if [ "$ANSWER_OPT" = "1" ]; then
        printf '%b\n' "${CYAN}🔧 Upgrading logic while keeping settings...${NC}"
        KEEP_CONFIG=1
    else
        printf '%b\n' "${RED}🧹 Performing clean install...${NC}"
        # Universal Stop Logic
        [ "$SERVICE_TYPE" = "PROCD" ] && /etc/init.d/netwatchdta stop >/dev/null 2>&1
        [ "$SERVICE_TYPE" = "SYSTEMD" ] && systemctl stop netwatchdta >/dev/null 2>&1
        rm -rf "$INSTALL_DIR"
    fi
fi

mkdir -p "$INSTALL_DIR"

# Function: get_hw_key  (only used to MIGRATE an old encrypted vault from <=1.5.x)
get_hw_key() {
    local seed="nwdta_v1_secure_seed_2025"
    if [ -f /proc/cpuinfo ]; then 
        local cpu_serial=$(grep -i "serial" /proc/cpuinfo | head -1 | awk -F: '{print $2}' | tr -d ' ')
        [ -z "$cpu_serial" ] && cpu_serial="unknown_serial"
    else 
        cpu_serial="generic_linux_machine"
    fi
    local mac_addr=$(cat /sys/class/net/*/address 2>/dev/null | grep -v "00:00" | head -1)
    echo -n "${seed}${cpu_serial}${mac_addr}" | openssl dgst -sha256 | awk '{print $2}'
}

# Function: get_hw_key_legacy
# Purpose:  Key used by the OpenWrt 'credentials' command before v1.5.2 (sorted MAC).
#           Only used to RECOVER a vault written by that bug during migration.
get_hw_key_legacy() {
    local seed="nwdta_v1_secure_seed_2025"
    local cpu_serial=$(grep -i "serial" /proc/cpuinfo 2>/dev/null | head -1 | awk -F: '{print $2}' | tr -d ' ')
    [ -z "$cpu_serial" ] && cpu_serial="unknown_serial"
    local mac_addr=$(cat /sys/class/net/*/address 2>/dev/null | grep -v "00:00:00:00:00:00" | sort | head -1)
    [ -z "$mac_addr" ] && mac_addr="00:00:00:00:00:00"
    echo -n "${seed}${cpu_serial}${mac_addr}" | openssl dgst -sha256 | awk '{print $2}'
}

# Function: decrypt_vault <key>
decrypt_vault() {
    command -v openssl >/dev/null 2>&1 || return 1
    # openssl prints partial garbage on a wrong key, so only trust its exit status
    local out
    out=$(openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -iter 10000 -k "$1" -in "$VAULT_FILE" 2>/dev/null) || return 1
    printf '%s' "$out" | tr -d '\r'
}

# Function: conf_get <KEY>   - first word of a setting's value (tolerates indentation/CRLF)
conf_get() {
    grep "^[[:space:]]*$1=" "$CONFIG_FILE" 2>/dev/null | head -1 | tr -d '\r' | cut -d'=' -f2- | awk '{print $1}'
}

# Function: conf_set <KEY> <VALUE>  - replace a setting's value, keep its comment
conf_set() {
    if grep -q "^[[:space:]]*$1=" "$CONFIG_FILE"; then
        sed -i "s/^\([[:space:]]*\)$1=[^[:space:]#]*/\1$1=$2/" "$CONFIG_FILE"
    fi
}

# ==============================================================================
#  STEP 3: CONFIGURATION INPUTS
# ==============================================================================
if [ "$KEEP_CONFIG" -eq 0 ]; then
    printf '%b\n' "\n${BLUE}--- Configuration ---${NC}"
    
    # 3a. Router Name
    printf "${BOLD}🏷️  Enter Router/Device Name (e.g., MyRouter): ${NC}"
    read router_name_input </dev/tty
    router_name_input=$(printf '%s' "$router_name_input" | tr -d '"\\`$')
    [ -z "$router_name_input" ] && router_name_input="MyRouter"
    
    # 3b. Discord Setup Loop
    DISCORD_ENABLE_VAL="NO"
    DISCORD_WEBHOOK=""
    DISCORD_USERID=""
    
    printf '%b\n' "\n${BLUE}--- Notification Settings ---${NC}"
    
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
             printf '%b\n' "${YELLOW}   🧪 Sending Discord test...${NC}"
             safe_fetch "$DISCORD_WEBHOOK" "{\"content\": \"<@$DISCORD_USERID>\", \"embeds\": [{\"title\": \"🧪 Setup Test\", \"description\": \"Discord configured successfully for **$router_name_input**.\", \"color\": 1752220}]}" "Content-Type: application/json"
             
             printf '%b\n' "${CYAN}   ℹ️  Signal sent. Please check your Discord channel.${NC}"
             ask_yn "   ❓ Did you receive the notification?"
             
             if [ "$ANSWER_YN" = "y" ]; then
                 printf '%b\n' "${GREEN}   ✅ Discord configured.${NC}"
                 break
             else
                 printf '%b\n' "${RED}   ❌ Test failed.${NC}"
                 printf '%b\n' "${BOLD}${WHITE}   1.${NC} Input credentials again"
                 printf '%b\n' "${BOLD}${WHITE}   2.${NC} Disable Discord and continue"
                 printf '%b\n' "${BOLD}${WHITE}   3.${NC} Cancel installation"
                 ask_opt "   Choice" "3"
                 if [ "$ANSWER_OPT" = "2" ]; then
                     DISCORD_ENABLE_VAL="NO"
                     break
                 fi
                 if [ "$ANSWER_OPT" = "3" ]; then
                     printf '%b\n' "${RED}❌ Installation cancelled by user.${NC}"
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
            printf '%b\n' "${YELLOW}   🧪 Sending Telegram test...${NC}"
            safe_fetch "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" "{\"chat_id\": \"$TELEGRAM_CHAT_ID\", \"text\": \"🧪 Setup Test - Telegram configured successfully for $router_name_input.\"}" "Content-Type: application/json"
            
            printf '%b\n' "${CYAN}   ℹ️  Signal sent. Please check your Telegram chat.${NC}"
            ask_yn "   ❓ Did you receive the notification?"
            
            if [ "$ANSWER_YN" = "y" ]; then
                printf '%b\n' "${GREEN}   ✅ Telegram configured.${NC}"
                break
            else
                printf '%b\n' "${RED}   ❌ Test failed.${NC}"
                printf '%b\n' "${BOLD}${WHITE}   1.${NC} Input credentials again"
                printf '%b\n' "${BOLD}${WHITE}   2.${NC} Disable Telegram and continue"
                printf '%b\n' "${BOLD}${WHITE}   3.${NC} Cancel installation"
                ask_opt "   Choice" "3"
                if [ "$ANSWER_OPT" = "2" ]; then
                    TELEGRAM_ENABLE_VAL="NO"
                    break
                fi
                if [ "$ANSWER_OPT" = "3" ]; then
                     printf '%b\n' "${RED}❌ Installation cancelled by user.${NC}"
                     exit 0
                fi
            fi
        else
            break
        fi
    done
    
    # 3d. ntfy Setup Loop
    NTFY_ENABLE_VAL="NO"
    NTFY_URL=""
    
    while :; do
        ask_yn "3. Enable ntfy Notifications?"
        if [ "$ANSWER_YN" = "n" ]; then
            NTFY_ENABLE_VAL="NO"
            break
        fi
        
        NTFY_ENABLE_VAL="YES"
        printf "${BOLD}   > Enter ntfy Topic Name (e.g., my_router_alerts): ${NC}"
        read NTFY_TOPIC </dev/tty
        NTFY_URL="https://ntfy.sh/$NTFY_TOPIC"
        
        ask_yn "   ❓ Send test notification to ntfy now?"
        if [ "$ANSWER_YN" = "y" ]; then
            printf '%b\n' "${YELLOW}   🧪 Sending ntfy test...${NC}"
            safe_fetch "$NTFY_URL" "🧪 Setup Test - ntfy configured successfully for $router_name_input." "Title: Setup Test" "Tags: white_check_mark" "Priority: default"
            
            printf '%b\n' "${CYAN}   ℹ️  Signal sent. Please check your ntfy client.${NC}"
            ask_yn "   ❓ Did you receive the notification?"
            
            if [ "$ANSWER_YN" = "y" ]; then
                printf '%b\n' "${GREEN}   ✅ ntfy configured.${NC}"
                break
            else
                printf '%b\n' "${RED}   ❌ Test failed.${NC}"
                printf '%b\n' "${BOLD}${WHITE}   1.${NC} Input Topic again"
                printf '%b\n' "${BOLD}${WHITE}   2.${NC} Disable ntfy and continue"
                printf '%b\n' "${BOLD}${WHITE}   3.${NC} Cancel installation"
                ask_opt "   Choice" "3"
                if [ "$ANSWER_OPT" = "2" ]; then
                    NTFY_ENABLE_VAL="NO"
                    break
                fi
                if [ "$ANSWER_OPT" = "3" ]; then
                     printf '%b\n' "${RED}❌ Installation cancelled by user.${NC}"
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
    
    printf '%b\n' "\n${BLUE}--- Silent Hours (Mute Alerts) ---${NC}"
    ask_yn "🌙 Enable Silent Hours?"
    
    if [ "$ANSWER_YN" = "y" ]; then
        SILENT_ENABLE_VAL="YES"
        while :; do
            printf "${BOLD}   > Start Hour (0-23): ${NC}"
            read user_silent_start </dev/tty
            if echo "$user_silent_start" | grep -qE '^[0-9]+$' && [ "$user_silent_start" -ge 0 ] && [ "$user_silent_start" -le 23 ] 2>/dev/null; then
                break
            else
                printf '%b\n' "${RED}   ❌ Invalid hour. Use 0-23.${NC}"
            fi
        done
        while :; do
            printf "${BOLD}   > End Hour (0-23): ${NC}"
            read user_silent_end </dev/tty
            if echo "$user_silent_end" | grep -qE '^[0-9]+$' && [ "$user_silent_end" -ge 0 ] && [ "$user_silent_end" -le 23 ] 2>/dev/null; then
                break
            else
                printf '%b\n' "${RED}   ❌ Invalid hour. Use 0-23.${NC}"
            fi
        done
    fi
    
    # 3f. Heartbeat Logic
    HB_VAL="NO"; HB_SEC="86400"; HB_TARGET="ALL"; HB_START_HOUR="12"; HB_START_MIN="00"
    printf '%b\n' "\n${BLUE}--- Heartbeat Settings ---${NC}"
    ask_yn "💓 Enable Heartbeat (System check-in)?"
    
    if [ "$ANSWER_YN" = "y" ]; then
        HB_VAL="YES"
        printf '%b\n' "${CYAN}   ℹ️  Interval can be in Hours or Minutes.${NC}"
        printf '%b\n' "   1. ${BOLD}${WHITE}Hours${NC} (e.g., every 12 hours)"
        printf '%b\n' "   2. ${BOLD}${WHITE}Minutes${NC} (e.g., every 30 minutes)"
        ask_opt "   Choice" "2"
        
        if [ "$ANSWER_OPT" = "1" ]; then HB_UNIT="HOURS"; HB_MULT=3600; else HB_UNIT="MINUTES"; HB_MULT=60; fi
        while :; do
            printf "${BOLD}   > Interval in $HB_UNIT: ${NC}"
            read val </dev/tty
            if echo "$val" | grep -qE '^[0-9]+$' && [ "$val" -gt 0 ]; then
                HB_SEC=$((val * HB_MULT))
                break
            fi
            printf '%b\n' "${RED}   ❌ Enter a whole number greater than 0.${NC}"
        done

        printf '%b\n' "${CYAN}   ℹ️  Set Start Time (Alignment Reference)${NC}"
        
        # Ask for Start Hour
        while :; do
            printf "${BOLD}   > Start Hour (0-23) [Default 12]: ${NC}"
            read HB_START_HOUR </dev/tty
            if [ -z "$HB_START_HOUR" ]; then HB_START_HOUR="12"; break; fi
            if echo "$HB_START_HOUR" | grep -qE '^[0-9]+$' && [ "$HB_START_HOUR" -ge 0 ] && [ "$HB_START_HOUR" -le 23 ]; then
                break
            fi
            printf '%b\n' "${RED}   ❌ Invalid hour.${NC}"
        done
        
        # Ask for Start Minute
        while :; do
            printf "${BOLD}   > Start Minute (0-59) [Default 00]: ${NC}"
            read HB_START_MIN </dev/tty
            if [ -z "$HB_START_MIN" ]; then HB_START_MIN="00"; break; fi
            if echo "$HB_START_MIN" | grep -qE '^[0-9]+$' && [ "$HB_START_MIN" -ge 0 ] && [ "$HB_START_MIN" -le 59 ]; then
                break
            fi
            printf '%b\n' "${RED}   ❌ Invalid minute.${NC}"
        done
        
        # --- HEARTBEAT TARGET SELECTOR ---
        if [ "$DISCORD_ENABLE_VAL" = "YES" ] || [ "$TELEGRAM_ENABLE_VAL" = "YES" ] || [ "$NTFY_ENABLE_VAL" = "YES" ]; then
             printf '%b\n' "${BOLD}${WHITE}   Where to send Heartbeat?${NC}"
             printf '%b\n' "   1. ${BOLD}${WHITE}Discord Only${NC}"
             printf '%b\n' "   2. ${BOLD}${WHITE}Telegram Only${NC}"
             printf '%b\n' "   3. ${BOLD}${WHITE}ntfy Only${NC}"
             printf '%b\n' "   4. ${BOLD}${WHITE}All Configured${NC}"
             ask_opt "   Choice" "4"
             case "$ANSWER_OPT" in
                 1) HB_TARGET="DISCORD" ;;
                 2) HB_TARGET="TELEGRAM" ;;
                 3) HB_TARGET="NTFY" ;;
                 4) HB_TARGET="ALL" ;;
             esac
        else
             HB_TARGET="NONE"
        fi
    fi

    # 3g. Summary Display
    printf '%b\n' "\n${BLUE}--- 📋 Configuration Summary ---${NC}"
    printf '%b\n' " • Router Name    : ${BOLD}${WHITE}$router_name_input${NC}"
    printf '%b\n' " • Discord        : ${BOLD}${WHITE}$DISCORD_ENABLE_VAL${NC}"
    printf '%b\n' " • Telegram       : ${BOLD}${WHITE}$TELEGRAM_ENABLE_VAL${NC}"
    printf '%b\n' " • ntfy           : ${BOLD}${WHITE}$NTFY_ENABLE_VAL${NC}"
    printf '%b\n' " • Silent Mode    : ${BOLD}${WHITE}$SILENT_ENABLE_VAL${NC}"
    printf '%b\n' "     - Start      : $user_silent_start:00"
    printf '%b\n' "     - End        : $user_silent_end:00"
    printf '%b\n' " • Heartbeat      : ${BOLD}${WHITE}$HB_VAL${NC}"
    printf '%b\n' "     - Interval   : ${BOLD}${WHITE}$HB_SEC${NC} seconds"
    printf '%b\n' "     - Start Time : ${BOLD}${WHITE}$HB_START_HOUR:$HB_START_MIN${NC}"
    printf '%b\n' " • Execution Mode : ${BOLD}${WHITE}$EXEC_MSG${NC}"
    
    UPDATE_CREDS=1

else
    # --- SCENARIO B: UPGRADE LOGIC (Check for new providers) ---
    printf '%b\n' "\n${CYAN}🔍 Analyzing existing deployment...${NC}"
    router_name_input=$(grep "^ROUTER_NAME=" "$CONFIG_FILE" | cut -d'"' -f2)
    UPDATE_CREDS=0
    
    # --- Load credentials: plain credentials.conf, or migrate the old encrypted vault ---
    DISCORD_WEBHOOK=""; DISCORD_USERID=""; TELEGRAM_BOT_TOKEN=""; TELEGRAM_CHAT_ID=""; NTFY_URL=""
    CRED_STATE="MISSING"
    if [ -f "$CRED_FILE" ]; then
        . "$CRED_FILE"
        CRED_STATE="OK"
    elif [ -f "$VAULT_FILE" ]; then
        old_vault_data=$(decrypt_vault "$(get_hw_key 2>/dev/null)") || old_vault_data=$(decrypt_vault "$(get_hw_key_legacy 2>/dev/null)") || old_vault_data=""
        if [ -n "$old_vault_data" ]; then
            DISCORD_WEBHOOK=$(echo "$old_vault_data" | cut -d'|' -f1)
            DISCORD_USERID=$(echo "$old_vault_data" | cut -d'|' -f2)
            TELEGRAM_BOT_TOKEN=$(echo "$old_vault_data" | cut -d'|' -f3)
            t3=$(echo "$old_vault_data" | cut -d'|' -f4-)
            TELEGRAM_CHAT_ID="${t3%%|*}"
            if echo "$t3" | grep -q "|"; then NTFY_URL="${t3#*|}"; fi
            CRED_STATE="MIGRATE"
            UPDATE_CREDS=1
            printf '%b\n' "${YELLOW}   🔓 Old encrypted vault unlocked - moving credentials to credentials.conf (root-only).${NC}"
        else
            CRED_STATE="LOCKED"
        fi
    fi
    
    has_ntfy=0
    [ -n "$NTFY_URL" ] && has_ntfy=1
    
    # Existing enable flags
    DISCORD_ENABLE_VAL=$(conf_get DISCORD_ENABLE)
    TELEGRAM_ENABLE_VAL=$(conf_get TELEGRAM_ENABLE)
    CUR_NTFY_ENABLE=$(conf_get NTFY_ENABLE)
    NTFY_ENABLE_VAL="$CUR_NTFY_ENABLE"
    
    if [ "$CRED_STATE" = "LOCKED" ] || [ "$CRED_STATE" = "MISSING" ]; then
        # --- No usable credentials: offer a full re-entry instead of looping on ntfy ---
        if [ "$CRED_STATE" = "LOCKED" ]; then
            printf '%b\n' "\n${RED}❌ The old encrypted vault can't be unlocked on this device.${NC}"
        else
            printf '%b\n' "\n${RED}❌ No saved credentials found.${NC}"
        fi
        printf '%b\n' "   Notifications cannot be sent until credentials are re-entered."
        printf '%b\n' "${BOLD}${WHITE}1.${NC} Re-enter all credentials now"
        printf '%b\n' "${BOLD}${WHITE}2.${NC} Skip (run 'credentials' later)"
        ask_opt "Enter choice" "2"
        if [ "$ANSWER_OPT" = "1" ]; then
            printf "${BOLD}   > Discord Webhook URL (blank = none): ${NC}"; read DISCORD_WEBHOOK </dev/tty
            DISCORD_USERID=""
            if [ -n "$DISCORD_WEBHOOK" ]; then printf "${BOLD}   > Discord User ID: ${NC}"; read DISCORD_USERID </dev/tty; fi
            printf "${BOLD}   > Telegram Bot Token (blank = none): ${NC}"; read TELEGRAM_BOT_TOKEN </dev/tty
            TELEGRAM_CHAT_ID=""
            if [ -n "$TELEGRAM_BOT_TOKEN" ]; then printf "${BOLD}   > Telegram Chat ID: ${NC}"; read TELEGRAM_CHAT_ID </dev/tty; fi
            printf "${BOLD}   > ntfy Topic (blank = none): ${NC}"; read NTFY_TOPIC </dev/tty
            if [ -n "$NTFY_TOPIC" ]; then NTFY_URL="https://ntfy.sh/$NTFY_TOPIC"; else NTFY_URL=""; fi
            
            if [ -n "$DISCORD_WEBHOOK" ]; then DISCORD_ENABLE_VAL="YES"; else DISCORD_ENABLE_VAL="NO"; fi
            if [ -n "$TELEGRAM_BOT_TOKEN" ]; then TELEGRAM_ENABLE_VAL="YES"; else TELEGRAM_ENABLE_VAL="NO"; fi
            if [ -n "$NTFY_URL" ]; then NTFY_ENABLE_VAL="YES"; else NTFY_ENABLE_VAL="NO"; fi
            conf_set DISCORD_ENABLE "$DISCORD_ENABLE_VAL"
            conf_set TELEGRAM_ENABLE "$TELEGRAM_ENABLE_VAL"
            conf_set NTFY_ENABLE "$NTFY_ENABLE_VAL"
            CRED_STATE="NEW"
            UPDATE_CREDS=1
        fi
    
    elif [ -z "$CUR_NTFY_ENABLE" ] || { [ "$CUR_NTFY_ENABLE" = "YES" ] && [ "$has_ntfy" -eq 0 ]; }; then
        # --- Vault OK: ask about ntfy only if never configured, or enabled without a topic ---
        printf '%b\n' "\n${BLUE}--- Upgrade: ntfy Configuration Missing ---${NC}"
        NTFY_ENABLE_VAL="NO"
        NTFY_URL=""
        while :; do
            ask_yn "✨ Would you like to enable ntfy push notifications?"
            if [ "$ANSWER_YN" = "n" ]; then 
                break 
            fi
            
            NTFY_ENABLE_VAL="YES"
            printf "${BOLD}   > Enter ntfy Topic (e.g., my_router_alerts): ${NC}"
            read NTFY_TOPIC </dev/tty
            NTFY_URL="https://ntfy.sh/$NTFY_TOPIC"
            
            ask_yn "   ❓ Send test notification to ntfy now?"
            if [ "$ANSWER_YN" = "y" ]; then
                printf '%b\n' "${YELLOW}   🧪 Sending ntfy test...${NC}"
                safe_fetch "$NTFY_URL" "🧪 Setup Test - ntfy configured successfully for $router_name_input." "Title: Setup Test" "Tags: white_check_mark" "Priority: default"
                
                printf '%b\n' "${CYAN}   ℹ️  Signal sent. Please check your ntfy client.${NC}"
                ask_yn "   ❓ Did you receive the notification?"
                
                if [ "$ANSWER_YN" = "y" ]; then
                    printf '%b\n' "${GREEN}   ✅ ntfy configured.${NC}"
                    break
                else
                    printf '%b\n' "${RED}   ❌ Test failed.${NC}"
                    printf '%b\n' "${BOLD}${WHITE}   1.${NC} Input Topic again"
                    printf '%b\n' "${BOLD}${WHITE}   2.${NC} Disable ntfy and continue"
                    ask_opt "   Choice" "2"
                    if [ "$ANSWER_OPT" = "2" ]; then
                        NTFY_ENABLE_VAL="NO"
                        NTFY_URL=""
                        break
                    fi
                fi
            else
                break
            fi
        done
        UPDATE_CREDS=1
        conf_set NTFY_ENABLE "$NTFY_ENABLE_VAL"
    fi
fi

# ==============================================================================
#  STEP 4: GENERATE OR PATCH CONFIGURATION FILES
# ==============================================================================

# Function: patch_param
# Purpose:  Injects missing parameters into settings.conf under the correct section
patch_param() {
    local key="$1"
    local default_val="$2"
    local section="$3"
    
    if ! grep -q "^[[:space:]]*$key=" "$CONFIG_FILE"; then
        printf '%b\n' "${YELLOW}   🔧 Upgrade: Restoring missing parameter '$key' to [$section]...${NC}"
        if grep -q "\[$section\]" "$CONFIG_FILE"; then
            sed "/\[$section\]/a $key=$default_val # Restored by v$SCRIPT_VERSION" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        else
            printf '%b\n' "\n[$section]" >> "$CONFIG_FILE"
            echo "$key=$default_val # Restored by v$SCRIPT_VERSION" >> "$CONFIG_FILE"
        fi
    fi
}

if [ "$KEEP_CONFIG" -eq 0 ]; then
    # --- SCENARIO A: CLEAN INSTALL (Generate Full File) ---
    
    if [ "$OS_TYPE" = "OPENWRT" ]; then F_TOOL="AUTO"; else F_TOOL="CURL"; fi

    cat <<EOF > "$CONFIG_FILE"
# settings.conf - Configuration for netwatchdta ($OS_TYPE Edition)
# Note: Credentials are stored in credentials.conf (plain text, root-only)

ROUTER_NAME="$router_name_input"

# FETCH_TOOL Options:
# AUTO    - Recommended. Automatically picks best tool available (uclient on OpenWrt, Curl on Linux).
# UCLIENT - (OpenWrt Only) Use uclient-fetch (Lightweight, RAM friendly).
# CURL    - Use Curl (Robust, recommended for Linux/Desktop).
# WGET    - Use Wget (Fallback).
# WARNING: Change only if you know what you are doing. Default: AUTO
FETCH_TOOL="$F_TOOL"

# EXEC_METHOD: Controls Notification Concurrency (Alerts)
# 1 = Parallel Mode (Fast, sends multiple alerts at once). Best for >=512MB RAM.
# 2 = Queue Mode (Safe, sends alerts one by one). Best for <512MB RAM.
EXEC_METHOD=$AUTO_EXEC_METHOD

# SCAN_BATCH_SIZE: Controls Scanning Concurrency (Pings)
# 0 = Unlimited (Full Parallel) - For High End devices (>=512MB)
# AUTO = Dynamically calculated based on Free RAM (Safe) - For Low End (<512MB)
# 10 = Fixed batch size (Process 10 at a time)
SCAN_BATCH_SIZE=$AUTO_BATCH_SIZE

[Log Settings]
UPTIME_LOG_MAX_SIZE=51200 # Max log file size in bytes for uptime tracking. Default is 51200.
PING_LOG_ENABLE=NO # Enable or disable detailed ping logging (YES/NO). Default is NO.

[Notification Settings]
DISCORD_ENABLE=$DISCORD_ENABLE_VAL # Global toggle for Discord notifications (YES/NO).
TELEGRAM_ENABLE=$TELEGRAM_ENABLE_VAL # Global toggle for Telegram notifications (YES/NO).
NTFY_ENABLE=$NTFY_ENABLE_VAL # Global toggle for ntfy notifications (YES/NO).
SILENT_ENABLE=$SILENT_ENABLE_VAL # Mutes Discord alerts during specific hours (YES/NO).
SILENT_START=$user_silent_start # Hour to start silent mode (0-23). Default: 23.
SILENT_END=$user_silent_end # Hour to end silent mode (0-23). Default: 07.

[Discord]
DISCORD_MENTION_LOCAL=YES # Mention on Local Device Down/Up events. Default is YES.
DISCORD_MENTION_REMOTE=YES # Mention on Remote Device Down/Up events. Default is YES.
DISCORD_MENTION_NET=YES # Mention on Internet Connectivity loss/restore. Default is YES.
DISCORD_MENTION_HB=NO # Mention inside Heartbeat reports. Default is NO.

[ntfy]
NTFY_MENTION_LOCAL=YES # Push urgent priority on Local Device events. Default is YES.
NTFY_MENTION_REMOTE=YES # Push urgent priority on Remote Device events. Default is YES.
NTFY_MENTION_NET=YES # Push urgent priority on Internet Connectivity events. Default is YES.
NTFY_MENTION_HB=NO # Push urgent priority inside Heartbeat reports. Default is NO.

[Performance Settings]
CPU_GUARD_THRESHOLD=2.0 # Max CPU load average allowed before skipping pings. Default is 2.0.
RAM_GUARD_MIN_FREE=4096 # Minimum free RAM in KB required to run alerts. Default is 4096.

[Heartbeat]
HEARTBEAT=$HB_VAL # Periodic I am alive notification (YES/NO).
HB_INTERVAL=$HB_SEC # Seconds between heartbeat messages. Default is 86400.
HB_TARGET=$HB_TARGET # Target for Heartbeat: DISCORD, TELEGRAM, NTFY, ALL
HB_START_HOUR=$HB_START_HOUR # Time of Heartbeat will start. Default is 12.
HB_START_MIN=$HB_START_MIN # Minute of Heartbeat will start. Default is 00.

[Internet Connectivity]
# SMART DEFAULT: Robust settings to prevent false alarms
EXT_ENABLE=YES # Global toggle for internet monitoring (YES/NO). Default is YES.
EXT_IP=1.1.1.1 # Primary external IP to monitor. Default is 1.1.1.1.
EXT_IP2=8.8.8.8 # Secondary external IP for redundancy. Default is 8.8.8.8.
EXT_SCAN_INTERVAL=60 # Seconds between internet checks. Default is 60.
EXT_FAIL_THRESHOLD=1 # Failed cycles before internet alert. Default is 1.
EXT_PING_COUNT=4 # Number of packets per internet check. Default is 4.
EXT_PING_TIMEOUT=5 # Seconds to wait for ping response. Default is 5.

[Local Device Monitoring]
# SMART DEFAULT: Fast settings for LAN
DEVICE_MONITOR=YES # Enable monitoring of local IPs (YES/NO). Default is YES.
DEV_SCAN_INTERVAL=10 # Seconds between local device checks. Default is 10.
DEV_FAIL_THRESHOLD=2 # Failed cycles before device alert. Default is 2.
DEV_PING_COUNT=2 # Number of packets per device check. Default is 2.
DEV_PING_TIMEOUT=1 # Seconds to wait for device ping response. Default is 1.

[Remote Device Monitoring]
# SMART DEFAULT: Robust settings for Remote/WAN
REMOTE_MONITOR=YES # Enable monitoring of Remote IPs (YES/NO). Default is YES.
REM_SCAN_INTERVAL=30 # Seconds between remote device checks. Default is 30.
REM_FAIL_THRESHOLD=1 # Failed cycles before remote alert. Default is 1.
REM_PING_COUNT=4 # Number of packets per remote check. Default is 4.
REM_PING_TIMEOUT=5 # Seconds to wait for remote ping response. Default is 5.
EOF

    # Generate default IP list
    cat <<EOF > "$IP_LIST_FILE"
# Format: IP_ADDRESS / DOMAIN @ NAME
# Example: 192.168.1.50 @ Home Server
# Example: www.test123.com @ test-server
EOF

    # Generate default Remote IP list
    cat <<EOF > "$REMOTE_LIST_FILE"
# Format: IP_ADDRESS / DOMAIN @ NAME
# Example: 142.250.180.206 @ Google Server
# Example: www.test123.com @ test-server
# Note: These are ONLY checked if Internet is UP (Strict Dependency).
EOF

else
    # --- SCENARIO B: UPGRADE MODE (Full Self-Healing) ---
    printf '%b\n' "${CYAN}♻️  Auditing configuration file for missing parameters...${NC}"
    sed -i 's/^# Note: Credentials are stored in .vault.enc.*/# Note: Credentials are stored in credentials.conf (plain text, root-only)/' "$CONFIG_FILE"
    
    # 1. Log Settings
    patch_param "UPTIME_LOG_MAX_SIZE" "51200" "Log Settings"
    patch_param "PING_LOG_ENABLE" "NO" "Log Settings"

    # 2. Notification Settings
    patch_param "NTFY_ENABLE" "${NTFY_ENABLE_VAL:-NO}" "Notification Settings"
    patch_param "SILENT_ENABLE" "NO" "Notification Settings"
    patch_param "SILENT_START" "23" "Notification Settings"
    patch_param "SILENT_END" "07" "Notification Settings"

    # 3. Discord
    patch_param "DISCORD_MENTION_LOCAL" "YES" "Discord"
    patch_param "DISCORD_MENTION_REMOTE" "YES" "Discord"
    patch_param "DISCORD_MENTION_NET" "YES" "Discord"
    patch_param "DISCORD_MENTION_HB" "NO" "Discord"
    
    # 4. ntfy
    patch_param "NTFY_MENTION_LOCAL" "YES" "ntfy"
    patch_param "NTFY_MENTION_REMOTE" "YES" "ntfy"
    patch_param "NTFY_MENTION_NET" "YES" "ntfy"
    patch_param "NTFY_MENTION_HB" "NO" "ntfy"

    # 5. Performance Settings
    patch_param "CPU_GUARD_THRESHOLD" "2.0" "Performance Settings"
    patch_param "RAM_GUARD_MIN_FREE" "4096" "Performance Settings"

    # 6. Heartbeat
    patch_param "HEARTBEAT" "NO" "Heartbeat"
    patch_param "HB_INTERVAL" "86400" "Heartbeat"
    patch_param "HB_TARGET" "ALL" "Heartbeat"
    patch_param "HB_START_HOUR" "12" "Heartbeat"
    patch_param "HB_START_MIN" "00" "Heartbeat"

    # 7. Internet Connectivity
    patch_param "EXT_ENABLE" "YES" "Internet Connectivity"
    patch_param "EXT_IP" "1.1.1.1" "Internet Connectivity"
    patch_param "EXT_IP2" "8.8.8.8" "Internet Connectivity"
    patch_param "EXT_SCAN_INTERVAL" "60" "Internet Connectivity"
    patch_param "EXT_FAIL_THRESHOLD" "1" "Internet Connectivity"
    patch_param "EXT_PING_COUNT" "4" "Internet Connectivity"
    patch_param "EXT_PING_TIMEOUT" "5" "Internet Connectivity"

    # 8. Local Device Monitoring
    patch_param "DEVICE_MONITOR" "YES" "Local Device Monitoring"
    patch_param "DEV_SCAN_INTERVAL" "10" "Local Device Monitoring"
    patch_param "DEV_FAIL_THRESHOLD" "2" "Local Device Monitoring"
    patch_param "DEV_PING_COUNT" "2" "Local Device Monitoring"
    patch_param "DEV_PING_TIMEOUT" "1" "Local Device Monitoring"

    # 9. Remote Device Monitoring
    patch_param "REMOTE_MONITOR" "YES" "Remote Device Monitoring"
    patch_param "REM_SCAN_INTERVAL" "30" "Remote Device Monitoring"
    patch_param "REM_FAIL_THRESHOLD" "1" "Remote Device Monitoring"
    patch_param "REM_PING_COUNT" "4" "Remote Device Monitoring"
    patch_param "REM_PING_TIMEOUT" "5" "Remote Device Monitoring"
    
    # 10. Global Variables (Top of file - special handling)
    if ! grep -q "^EXEC_METHOD=" "$CONFIG_FILE"; then
        sed -i "2i EXEC_METHOD=$AUTO_EXEC_METHOD" "$CONFIG_FILE"
        printf '%b\n' "${YELLOW}   🔧 Restored missing EXEC_METHOD.${NC}"
    fi
    if ! grep -q "^SCAN_BATCH_SIZE=" "$CONFIG_FILE"; then
        sed -i "3i SCAN_BATCH_SIZE=$AUTO_BATCH_SIZE" "$CONFIG_FILE"
        printf '%b\n' "${YELLOW}   🔧 Restored missing SCAN_BATCH_SIZE.${NC}"
    fi
    if ! grep -q "^FETCH_TOOL=" "$CONFIG_FILE"; then
        if [ "$OS_TYPE" = "OPENWRT" ]; then FT="AUTO"; else FT="CURL"; fi
        sed -i "2i FETCH_TOOL=$FT" "$CONFIG_FILE"
        printf '%b\n' "${YELLOW}   🔧 Restored missing FETCH_TOOL.${NC}"
    fi
    
    printf '%b\n' "${GREEN}✅ Configuration audit complete. File is compliant with v$SCRIPT_VERSION.${NC}"
fi

# ==============================================================================
#  STEP 5: SAVE CREDENTIALS (credentials.conf, root-only)
# ==============================================================================
cat <<'EOF' > "$COMMON_LIB"
# nwdta_common.sh - shared helpers for the netwatchdta service/CLI (generated by installer)
# Caller sets BASE_DIR before sourcing.
CONFIG_FILE="$BASE_DIR/settings.conf"
CRED_FILE="$BASE_DIR/credentials.conf"

nw_load_settings() {
    [ -f "$CONFIG_FILE" ] && eval "$(sed '/^\[.*\]/d' "$CONFIG_FILE" | sed 's/[ \t]*#.*//' | sed 's/[ \t]*$//' | tr -d '\r')"
    return 0
}

nw_load_creds() {
    DISCORD_WEBHOOK=""; DISCORD_USERID=""; TELEGRAM_BOT_TOKEN=""; TELEGRAM_CHAT_ID=""; NTFY_URL=""
    [ -f "$CRED_FILE" ] && . "$CRED_FILE"
    return 0
}

# single-quote a value safely for the credentials file
nw_q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

nw_save_creds() {
    ( umask 077
      {
        echo "# netwatchdta credentials - plain text, readable by root only."
        echo "# Change with the 'credentials' command, or edit by hand and restart the service."
        echo "DISCORD_WEBHOOK=$(nw_q "$DISCORD_WEBHOOK")"
        echo "DISCORD_USERID=$(nw_q "$DISCORD_USERID")"
        echo "TELEGRAM_BOT_TOKEN=$(nw_q "$TELEGRAM_BOT_TOKEN")"
        echo "TELEGRAM_CHAT_ID=$(nw_q "$TELEGRAM_CHAT_ID")"
        echo "NTFY_URL=$(nw_q "$NTFY_URL")"
      } > "$CRED_FILE.tmp" ) && mv "$CRED_FILE.tmp" "$CRED_FILE" && chmod 600 "$CRED_FILE"
}

nw_conf_set() {
    if grep -q "^[[:space:]]*$1=" "$CONFIG_FILE" 2>/dev/null; then
        sed -i "s/^\([[:space:]]*\)$1=[^[:space:]#]*/\1$1=$2/" "$CONFIG_FILE"
    fi
}

# Turn each service on/off in settings.conf to match the saved credentials
nw_sync_flags() {
    if [ -n "$DISCORD_WEBHOOK" ]; then nw_conf_set DISCORD_ENABLE YES; else nw_conf_set DISCORD_ENABLE NO; fi
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then nw_conf_set TELEGRAM_ENABLE YES; else nw_conf_set TELEGRAM_ENABLE NO; fi
    if [ -n "$NTFY_URL" ]; then nw_conf_set NTFY_ENABLE YES; else nw_conf_set NTFY_ENABLE NO; fi
}

# nw_post URL DATA [HEADER...]  -> 0 on success; sets NW_ERR with the real reason on failure
nw_post() {
    _url="$1"; _data="$2"; shift 2
    NW_ERR=""
    _resp="/tmp/nwdta_resp.$$"
    _n=$#
    if command -v curl >/dev/null 2>&1; then
        for _h in "$@"; do set -- "$@" -H "$_h"; done
        shift "$_n"
        _code=$(curl -s -k -o "$_resp" -w '%{http_code}' -X POST "$@" --data-binary "$_data" "$_url" 2>/dev/null)
        _rc=$?
        if [ "$_rc" -eq 0 ]; then
            case "$_code" in 2??) rm -f "$_resp"; return 0 ;; esac
        fi
        if [ -z "$_code" ] || [ "$_code" = "000" ]; then
            NW_ERR="could not connect (curl exit $_rc) - check DNS / internet / URL"
        else
            NW_ERR="HTTP $_code - $(head -c 200 "$_resp" 2>/dev/null)"
        fi
        rm -f "$_resp"
        return 1
    fi
    if command -v uclient-fetch >/dev/null 2>&1; then
        if [ "$_n" -gt 0 ] && ! uclient-fetch --help 2>&1 | grep -q -- "--header"; then
            NW_ERR="uclient-fetch can't send headers and curl is not installed (install curl)"
            return 1
        fi
        for _h in "$@"; do set -- "$@" "--header=$_h"; done
        shift "$_n"
        _out=$(uclient-fetch --no-check-certificate -O "$_resp" "$@" --post-data="$_data" "$_url" 2>&1)
        _rc=$?
        rm -f "$_resp"
        [ "$_rc" -eq 0 ] && return 0
        case "$_out" in *" 204"*|*"204 "*) return 0 ;; esac   # Discord answers 204 No Content
        NW_ERR="uclient-fetch exit $_rc: $(echo "$_out" | tail -n 2 | tr '\n' ' ')"
        return 1
    fi
    NW_ERR="no HTTP tool found (install curl)"
    return 1
}

# nw_test DISCORD|TELEGRAM|NTFY  - real send with a real result
nw_test() {
    nw_load_settings
    nw_load_creds
    _rc=1
    case "$1" in
        DISCORD)
            [ -z "$DISCORD_WEBHOOK" ] && { echo "No Discord webhook saved (run: credentials)."; return 1; }
            echo "Sending Discord test..."
            nw_post "$DISCORD_WEBHOOK" "{\"embeds\": [{\"title\": \"🛠️ Discord Test\", \"description\": \"**Router:** $ROUTER_NAME\\nManual test triggered.\", \"color\": 16776960}]}" "Content-Type: application/json"
            _rc=$?; _flag="$DISCORD_ENABLE"; _key="DISCORD_ENABLE" ;;
        TELEGRAM)
            if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then echo "No Telegram token/chat ID saved (run: credentials)."; return 1; fi
            echo "Sending Telegram test..."
            nw_post "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" "{\"chat_id\": \"$TELEGRAM_CHAT_ID\", \"text\": \"🛠️ Telegram Test - $ROUTER_NAME\"}" "Content-Type: application/json"
            _rc=$?; _flag="$TELEGRAM_ENABLE"; _key="TELEGRAM_ENABLE" ;;
        NTFY)
            [ -z "$NTFY_URL" ] && { echo "No ntfy topic saved (run: credentials)."; return 1; }
            echo "Sending ntfy test to $NTFY_URL ..."
            nw_post "$NTFY_URL" "Router: $ROUTER_NAME - manual test triggered." "Title: ntfy Test" "Tags: warning" "Priority: high"
            _rc=$?; _flag="$NTFY_ENABLE"; _key="NTFY_ENABLE" ;;
    esac
    if [ "$_rc" -eq 0 ]; then
        printf '%b\n' "\033[1;32m✅ Accepted by the server - check your app.\033[0m"
    else
        printf '%b\n' "\033[1;31m❌ Failed: $NW_ERR\033[0m"
    fi
    [ "$_flag" != "YES" ] && printf '%b\n' "\033[1;33mℹ️  $_key is not YES in settings.conf, so real alerts won't use this service.\033[0m"
    return "$_rc"
}

_nw_state() { [ -n "$1" ] && echo "set" || echo "-"; }

# nw_creds_menu "<restart command>"
nw_creds_menu() {
    nw_load_creds
    echo ""
    printf '%b\n' "\033[1;33m🔐 Credential Manager\033[0m  ($CRED_FILE)"
    echo "   Discord: $(_nw_state "$DISCORD_WEBHOOK")   Telegram: $(_nw_state "$TELEGRAM_BOT_TOKEN")   ntfy: ${NTFY_URL:--}"
    echo "1. Change Discord"
    echo "2. Change Telegram"
    echo "3. Change ntfy"
    echo "4. Change All"
    echo "5. Cancel"
    printf "Choice [1-5]: "
    read c_choice </dev/tty
    case "$c_choice" in 1|2|3|4) ;; *) echo "Cancelled."; return 0 ;; esac
    echo "(Leave a field blank to turn that service off.)"
    if [ "$c_choice" = "1" ] || [ "$c_choice" = "4" ]; then
        printf "Discord Webhook URL: "; read DISCORD_WEBHOOK </dev/tty
        DISCORD_USERID=""
        if [ -n "$DISCORD_WEBHOOK" ]; then printf "Discord User ID (for @mentions, optional): "; read DISCORD_USERID </dev/tty; fi
    fi
    if [ "$c_choice" = "2" ] || [ "$c_choice" = "4" ]; then
        printf "Telegram Bot Token: "; read TELEGRAM_BOT_TOKEN </dev/tty
        TELEGRAM_CHAT_ID=""
        if [ -n "$TELEGRAM_BOT_TOKEN" ]; then printf "Telegram Chat ID: "; read TELEGRAM_CHAT_ID </dev/tty; fi
    fi
    if [ "$c_choice" = "3" ] || [ "$c_choice" = "4" ]; then
        printf "ntfy topic (or full URL for a self-hosted server): "; read n_topic </dev/tty
        case "$n_topic" in
            "") NTFY_URL="" ;;
            http://*|https://*) NTFY_URL="$n_topic" ;;
            *) NTFY_URL="https://ntfy.sh/$n_topic" ;;
        esac
    fi
    if nw_save_creds; then
        nw_sync_flags
        printf '%b\n' "\033[1;32m✅ Credentials saved.\033[0m Discord: $(_nw_state "$DISCORD_WEBHOOK")  Telegram: $(_nw_state "$TELEGRAM_BOT_TOKEN")  ntfy: ${NTFY_URL:--}"
        echo "   (settings.conf on/off switches updated to match)"
        [ -n "$1" ] && eval "$1"
    else
        printf '%b\n' "\033[1;31m❌ Could not write $CRED_FILE\033[0m"
    fi
}
EOF
chmod 644 "$COMMON_LIB"

printf '%b\n' "\n${CYAN}💾 Saving credentials...${NC}"
BASE_DIR="$INSTALL_DIR"
. "$COMMON_LIB"

if [ "$UPDATE_CREDS" -eq 1 ]; then
    if nw_save_creds; then
        printf '%b\n' "${GREEN}✅ Credentials saved to $CRED_FILE (readable by root only).${NC}"
    else
        printf '%b\n' "${RED}❌ Could not write $CRED_FILE${NC}"
    fi
else
    printf '%b\n' "${CYAN}   ℹ️  Credentials unchanged.${NC}"
fi
# The old encrypted vault is no longer used once credentials.conf exists
if [ -f "$CRED_FILE" ] && [ -f "$VAULT_FILE" ]; then
    rm -f "$VAULT_FILE"
    printf '%b\n' "${CYAN}   🧹 Removed old encrypted vault (.vault.enc).${NC}"
fi

# ==============================================================================
#  STEP 6: GENERATE CORE SCRIPT (THE ENGINE)
# ==============================================================================
printf '%b\n' "\n${CYAN}🛠️  Generating core script ($OS_TYPE Mode)...${NC}"

cat <<EOF > "$INSTALL_DIR/netwatchdta.sh"
#!/bin/sh
# netwatchdta - Network Monitoring for OpenWrt & Linux (Core Engine)
# Generated for: $OS_TYPE
# Directory: $INSTALL_DIR
VERSION="$SCRIPT_VERSION"

# --- DIRECTORY DEFS ---
BASE_DIR="$INSTALL_DIR"
IP_LIST_FILE="\$BASE_DIR/device_ips.conf"
REMOTE_LIST_FILE="\$BASE_DIR/remote_ips.conf"
CONFIG_FILE="\$BASE_DIR/settings.conf"
CRED_FILE="\$BASE_DIR/credentials.conf"

# Flash Paths
SILENT_BUFFER="\$BASE_DIR/nwdta_silent_buffer"
OFFLINE_BUFFER="\$BASE_DIR/nwdta_offline_buffer"

# RAM Paths
TMP_DIR="/tmp/netwatchdta"
LOGFILE="\$TMP_DIR/nwdta_uptime.log"
PINGLOG="\$TMP_DIR/nwdta_ping.log"
NET_STATUS_FILE="\$TMP_DIR/nwdta_net_status"

# Initialization
mkdir -p "\$TMP_DIR"
if [ ! -f "\$SILENT_BUFFER" ]; then touch "\$SILENT_BUFFER"; fi
if [ ! -f "\$LOGFILE" ]; then touch "\$LOGFILE"; fi
if [ ! -f "\$NET_STATUS_FILE" ]; then echo "UP" > "\$NET_STATUS_FILE"; fi

# uclient-fetch is only usable if it supports custom headers (needed for JSON / ntfy)
UCLIENT_HDR=0
if command -v uclient-fetch >/dev/null 2>&1 && uclient-fetch --help 2>&1 | grep -q -- "--header"; then UCLIENT_HDR=1; fi

# Tracking Variables
LAST_EXT_CHECK=0
LAST_DEV_CHECK=0
LAST_REM_CHECK=0
LAST_HB_CHECK=0
EXT_UP_GLOBAL=1
LAST_CFG_LOAD=0

# --- HELPER: LOGGING ---
log_msg() {
    local msg="\$1"
    local type="\$2" # UPTIME or PING
    local ts="\$3"   # Passed from main loop
    
    if [ "\$type" = "PING" ] && [ "\$PING_LOG_ENABLE" = "YES" ]; then
        echo "\$ts - \$msg" >> "\$PINGLOG"
        if [ -f "\$PINGLOG" ] && [ \$(wc -c < "\$PINGLOG") -gt "\$UPTIME_LOG_MAX_SIZE" ]; then
            echo "\$ts - [SYSTEM] Log rotated." > "\$PINGLOG"
        fi
    elif [ "\$type" = "UPTIME" ]; then
        echo "\$ts - \$msg" >> "\$LOGFILE"
        if [ -f "\$LOGFILE" ] && [ \$(wc -c < "\$LOGFILE") -gt "\$UPTIME_LOG_MAX_SIZE" ]; then
            echo "\$ts - [SYSTEM] Log rotated." > "\$LOGFILE"
        fi
    fi
}

# --- HELPER: CONFIG LOADER (NUCLEAR FIX) ---
load_config() {
    if [ -f "\$CONFIG_FILE" ]; then
        local cur_cfg_sig=\$(ls -l --time-style=+%s "\$CONFIG_FILE" 2>/dev/null || ls -l "\$CONFIG_FILE")
        if [ "\$cur_cfg_sig" != "\$LAST_CFG_LOAD" ]; then
            eval "\$(sed '/^\[.*\]/d' "\$CONFIG_FILE" | sed 's/[ \t]*#.*//' | sed 's/[ \t]*$//' | tr -d '\r')"
            LAST_CFG_LOAD="\$cur_cfg_sig"
        fi
    fi
}

# --- HELPER: LOAD CREDENTIALS (plain file, root-only) ---
load_credentials() {
    DISCORD_WEBHOOK=""; DISCORD_USERID=""; TELEGRAM_BOT_TOKEN=""; TELEGRAM_CHAT_ID=""; NTFY_URL=""
    if [ -f "\$CRED_FILE" ]; then
        . "\$CRED_FILE"
        return 0
    fi
    return 1
}

# ==============================================================================
#  PORTABLE FETCH WRAPPER (CORE ENGINE VERSION)
# ==============================================================================
# Includes Toggle Support, Auto-Priority, Discord 204 Fix, Multiple Headers, and -qO- fix for ntfy
safe_fetch() {
    local url="\$1"
    local data="\$2"
    local h1="\$3"
    local h2="\$4"
    local h3="\$5"

    # --- 1. CHECK FORCED TOOL ---
    if [ "\$FETCH_TOOL" = "CURL" ] && command -v curl >/dev/null 2>&1; then
        if [ -n "\$h3" ]; then
            curl -s -k -X POST -H "\$h1" -H "\$h2" -H "\$h3" -d "\$data" "\$url" >/dev/null 2>&1
        elif [ -n "\$h2" ]; then
            curl -s -k -X POST -H "\$h1" -H "\$h2" -d "\$data" "\$url" >/dev/null 2>&1
        elif [ -n "\$h1" ]; then
            curl -s -k -X POST -H "\$h1" -d "\$data" "\$url" >/dev/null 2>&1
        else
            curl -s -k -X POST -d "\$data" "\$url" >/dev/null 2>&1
        fi
        return 0
    fi
    
    if [ "\$FETCH_TOOL" = "UCLIENT" ] && [ "\$UCLIENT_HDR" = "1" ]; then
        if [ -n "\$h3" ]; then
            uclient-fetch --no-check-certificate -qO- --header="\$h1" --header="\$h2" --header="\$h3" --post-data="\$data" "\$url" >/dev/null 2>&1
        elif [ -n "\$h2" ]; then
            uclient-fetch --no-check-certificate -qO- --header="\$h1" --header="\$h2" --post-data="\$data" "\$url" >/dev/null 2>&1
        elif [ -n "\$h1" ]; then
            uclient-fetch --no-check-certificate -qO- --header="\$h1" --post-data="\$data" "\$url" >/dev/null 2>&1
        else
            uclient-fetch --no-check-certificate -qO- --post-data="\$data" "\$url" >/dev/null 2>&1
        fi
        return 0
    fi
    
    if [ "\$FETCH_TOOL" = "WGET" ] && command -v wget >/dev/null 2>&1; then
        if [ -n "\$h3" ]; then
            wget -q --no-check-certificate --header="\$h1" --header="\$h2" --header="\$h3" --post-data="\$data" "\$url" -O /dev/null
        elif [ -n "\$h2" ]; then
            wget -q --no-check-certificate --header="\$h1" --header="\$h2" --post-data="\$data" "\$url" -O /dev/null
        elif [ -n "\$h1" ]; then
            wget -q --no-check-certificate --header="\$h1" --post-data="\$data" "\$url" -O /dev/null
        else
            wget -q --no-check-certificate --post-data="\$data" "\$url" -O /dev/null
        fi
        return 0
    fi

    # --- 2. AUTO PRIORITY (OS Aware) ---
    if [ "$OS_TYPE" = "OPENWRT" ]; then
        # Priority A: uclient-fetch (Lightweight) - only if it supports --header
        if [ "\$UCLIENT_HDR" = "1" ]; then
            if [ -n "\$h3" ]; then
                uclient-fetch --no-check-certificate -qO- --header="\$h1" --header="\$h2" --header="\$h3" --post-data="\$data" "\$url" >/dev/null 2>&1
            elif [ -n "\$h2" ]; then
                uclient-fetch --no-check-certificate -qO- --header="\$h1" --header="\$h2" --post-data="\$data" "\$url" >/dev/null 2>&1
            elif [ -n "\$h1" ]; then
                uclient-fetch --no-check-certificate -qO- --header="\$h1" --post-data="\$data" "\$url" >/dev/null 2>&1
            else
                uclient-fetch --no-check-certificate -qO- --post-data="\$data" "\$url" >/dev/null 2>&1
            fi
            return 0 # Force success for Discord 204 bug
        fi
    fi

    # Priority B: Curl (Robust)
    if command -v curl >/dev/null 2>&1; then
        if [ -n "\$h3" ]; then
            curl -s -k -X POST -H "\$h1" -H "\$h2" -H "\$h3" -d "\$data" "\$url" >/dev/null 2>&1
        elif [ -n "\$h2" ]; then
            curl -s -k -X POST -H "\$h1" -H "\$h2" -d "\$data" "\$url" >/dev/null 2>&1
        elif [ -n "\$h1" ]; then
            curl -s -k -X POST -H "\$h1" -d "\$data" "\$url" >/dev/null 2>&1
        else
            curl -s -k -X POST -d "\$data" "\$url" >/dev/null 2>&1
        fi
        return 0
    fi

    # Priority C: Wget (Fallback)
    if command -v wget >/dev/null 2>&1; then
        if [ -n "\$h3" ]; then
            wget -q --no-check-certificate --header="\$h1" --header="\$h2" --header="\$h3" --post-data="\$data" "\$url" -O /dev/null
        elif [ -n "\$h2" ]; then
            wget -q --no-check-certificate --header="\$h1" --header="\$h2" --post-data="\$data" "\$url" -O /dev/null
        elif [ -n "\$h1" ]; then
            wget -q --no-check-certificate --header="\$h1" --post-data="\$data" "\$url" -O /dev/null
        else
            wget -q --no-check-certificate --post-data="\$data" "\$url" -O /dev/null
        fi
        return 0
    fi
    
    return 1 # Failure
}

# --- INTERNAL: SEND PAYLOAD ---
send_payload() {
    local title="\$1"
    local desc="\$2"
    local color="\$3"
    local filter="\$4"
    local telegram_text="\$5" 
    local do_mention="\$6"
    local success=0

    # 1. DISCORD
    if [ "\$DISCORD_ENABLE" = "YES" ] && [ -n "\$DISCORD_WEBHOOK" ]; then
        if [ -z "\$filter" ] || [ "\$filter" = "ALL" ] || [ "\$filter" = "BOTH" ] || [ "\$filter" = "DISCORD" ]; then
             local json_desc=\$(echo "\$desc" | sed 's/"/\\\\"/g' | awk '{printf "%s\\\\n", \$0}' | sed 's/\\\\n$//')
             local json_title=\$(echo "\$title" | sed 's/"/\\\\"/g')
             local d_payload
             if [ "\$do_mention" = "YES" ] && [ -n "\$DISCORD_USERID" ]; then
                d_payload="{\"content\": \"<@\$DISCORD_USERID>\", \"embeds\": [{\"title\": \"\$json_title\", \"description\": \"\$json_desc\", \"color\": \$color}]}"
             else
                d_payload="{\"embeds\": [{\"title\": \"\$json_title\", \"description\": \"\$json_desc\", \"color\": \$color}]}"
             fi
             
             if safe_fetch "\$DISCORD_WEBHOOK" "\$d_payload" "Content-Type: application/json"; then 
                 success=1
             else 
                 # Explicit Error Suppression for uclient-fetch (Double Safety)
                 if [ "$OS_TYPE" = "OPENWRT" ] && [ "\$UCLIENT_HDR" = "1" ] && [ "\$FETCH_TOOL" != "CURL" ]; then 
                     success=1
                 else
                     log_msg "[ERROR] Discord send failed." "UPTIME" "\$NOW_HUMAN"
                 fi
             fi
        fi
    fi

    # 2. TELEGRAM
    if [ "\$TELEGRAM_ENABLE" = "YES" ] && [ -n "\$TELEGRAM_BOT_TOKEN" ] && [ -n "\$TELEGRAM_CHAT_ID" ]; then
        if [ -z "\$filter" ] || [ "\$filter" = "ALL" ] || [ "\$filter" = "BOTH" ] || [ "\$filter" = "TELEGRAM" ]; then
             local t_msg="\$title\n\$desc"; [ -n "\$telegram_text" ] && t_msg="\$telegram_text"
             local t_safe=\$(echo "\$t_msg" | sed 's/"/\\\\"/g' | awk '{printf "%s\\\\n", \$0}')
             
             if safe_fetch "https://api.telegram.org/bot\$TELEGRAM_BOT_TOKEN/sendMessage" "{\"chat_id\": \"\$TELEGRAM_CHAT_ID\", \"text\": \"\$t_safe\"}" "Content-Type: application/json"; then 
                 success=1
             else 
                 log_msg "[ERROR] Telegram send failed." "UPTIME" "\$NOW_HUMAN"
             fi
        fi
    fi

    # 3. NTFY
    if [ "\$NTFY_ENABLE" = "YES" ] && [ -n "\$NTFY_URL" ]; then
        if [ -z "\$filter" ] || [ "\$filter" = "ALL" ] || [ "\$filter" = "BOTH" ] || [ "\$filter" = "NTFY" ]; then
             # Sanitize title for ntfy header
             local n_title=\$(echo "\$title" | sed 's/[^a-zA-Z0-9 -]//g') 
             
             local n_tags="bell"
             local n_prio="default"
             
             # Map Discord colors to ntfy tags and priorities
             [ "\$color" = "15548997" ] && { n_tags="rotating_light,alert"; n_prio="high"; } 
             [ "\$color" = "3066993" ] && { n_tags="white_check_mark"; n_prio="default"; } 
             [ "\$color" = "1752220" ] && { n_tags="information_source"; n_prio="default"; } 
             
             # If mention is requested, bump ntfy priority to urgent
             [ "\$do_mention" = "YES" ] && n_prio="urgent"
             
             local n_msg="\$desc"
             [ -n "\$telegram_text" ] && n_msg="\$telegram_text"
             local n_safe=\$(echo "\$n_msg" | awk '{printf "%s\n", \$0}') 
             
             if safe_fetch "\$NTFY_URL" "\$n_safe" "Title: \$n_title" "Tags: \$n_tags" "Priority: \$n_prio"; then 
                 success=1
             else 
                 log_msg "[ERROR] ntfy send failed." "UPTIME" "\$NOW_HUMAN"
             fi
        fi
    fi

    return \$((1 - success))
}
EOF
chmod +x "$INSTALL_DIR/netwatchdta.sh"
cat <<'EOF' >> "$INSTALL_DIR/netwatchdta.sh"

# --- HELPER: NOTIFICATION SENDER (WITH LOW-RAM LOCK) ---
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
    
    # --- SEQUENTIAL LOCK (Method 2 Only) ---
    local got_lock=0
    if [ "$EXEC_METHOD" -eq 2 ]; then
        local w_count=0
        while :; do
            if mkdir "/tmp/nwdta.lock" 2>/dev/null; then got_lock=1; break; fi
            sleep 1
            w_count=$((w_count + 1))
            if [ "$w_count" -ge 20 ]; then break; fi # Prevent infinite hang (send without lock)
        done
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
    
    # --- RELEASE LOCK (Method 2 Only) ---
    if [ "$got_lock" -eq 1 ]; then
        rmdir "/tmp/nwdta.lock" 2>/dev/null
    fi
}

# --- HELPER: FLUSH BUFFER ---
flush_buffer() {
    if [ -f "$OFFLINE_BUFFER" ]; then
        log_msg "[SYSTEM] Internet Restored. Flushing buffer..." "UPTIME" "$NOW_HUMAN"
        local b_line b_rest b_title b_desc_raw b_color b_filter b_tel_raw b_mention
        while IFS= read -r b_line || [ -n "$b_line" ]; do
             [ -z "$b_line" ] && continue
             b_title="${b_line%%|||*}";  b_rest="${b_line#*|||}"
             b_desc_raw="${b_rest%%|||*}"; b_rest="${b_rest#*|||}"
             b_color="${b_rest%%|||*}";  b_rest="${b_rest#*|||}"
             b_filter="${b_rest%%|||*}"; b_rest="${b_rest#*|||}"
             b_tel_raw="${b_rest%%|||*}"; b_rest="${b_rest#*|||}"
             b_mention="$b_rest"
             local b_desc=$(echo "$b_desc_raw" | sed 's/__BR__/\\n/g')
             local b_tel=$(echo "$b_tel_raw" | sed 's/__BR__/\n/g')
             sleep 1 
             send_payload "$b_title" "$b_desc" "$b_color" "$b_filter" "$b_tel" "$b_mention"
        done < "$OFFLINE_BUFFER"
        rm -f "$OFFLINE_BUFFER"
        log_msg "[SYSTEM] Buffer flushed." "UPTIME" "$NOW_HUMAN"
    fi
}

# --- SHARED CHECK FUNCTION (AUTO-TIMEOUT) ---
check_ip_logic() {
    local TIP="$1"
    local NAME="$2"
    local TYPE="$3"
    local THRESH="${4:-3}"
    local P_COUNT="${5:-1}"
    local TO="$6"
    [ "$TO" -le "$P_COUNT" ] && TO=$((P_COUNT + 1))
    
    local SAFE_IP=$(echo "$TIP" | tr '.' '_')
    local FD="$TMP_DIR/${TYPE}_${SAFE_IP}_d"
    local FC="$TMP_DIR/${TYPE}_${SAFE_IP}_c"
    local FT="$TMP_DIR/${TYPE}_${SAFE_IP}_t"
    
    local M_FLAG="NO"
    if [ "$TYPE" = "Device" ]; then
        if [ "$DISCORD_MENTION_LOCAL" = "YES" ] || [ "$NTFY_MENTION_LOCAL" = "YES" ]; then M_FLAG="YES"; fi
    elif [ "$TYPE" = "Remote" ]; then
        if [ "$DISCORD_MENTION_REMOTE" = "YES" ] || [ "$NTFY_MENTION_REMOTE" = "YES" ]; then M_FLAG="YES"; fi
    fi
    
    # --- PERFORM PING ---
    if ping -q -c "$P_COUNT" -w "$TO" "$TIP" >/dev/null 2>&1; then
        # 1. SUCCESS: Log to Ping Log if enabled
        if [ "$PING_LOG_ENABLE" = "YES" ]; then
            log_msg "[$TYPE] $NAME ($TIP) - OK" "PING" "$NOW_HUMAN"
        fi

        # 2. SUCCESS: Recovery Logic (Main Log)
        if [ -f "$FD" ]; then
            read DSTART < "$FT"
            read DSSEC < "$FD"
            local DUR=$(( NOW_SEC - DSSEC ))
            local DR_STR="$((DUR/60))m $((DUR%60))s"
            
            # -- CUSTOMIZE SUCCESS MESSAGES HERE --
            local D_MSG="**Router:** $ROUTER_NAME\n**${TYPE}:** $NAME ($TIP)\n**Down at:** $DSTART\n**Outage:** $DR_STR"
            local T_MSG="🟢 ${TYPE} UP* $ROUTER_NAME - $NAME - $TIP - $NOW_HUMAN - Downtime: $DR_STR"
            log_msg "[SUCCESS] ${TYPE}: $NAME Online - Downtime: $DR_STR)" "UPTIME" "$NOW_HUMAN"
            
            if [ "$IS_SILENT" -eq 1 ]; then
                 [ -f "$SILENT_BUFFER" ] && [ $(wc -c < "$SILENT_BUFFER") -lt 5120 ] && echo "${TYPE} $NAME UP: $NOW_HUMAN (Down $DR_STR)" >> "$SILENT_BUFFER"
            else
                 send_notification "🟢 ${TYPE} Online" "$D_MSG" "3066993" "SUCCESS" "ALL" "NO" "$T_MSG" "$M_FLAG"
            fi
            rm -f "$FD" "$FT"
        fi
        echo 0 > "$FC"
    else
        # 1. FAILURE: Log to Ping Log if enabled
        if [ "$PING_LOG_ENABLE" = "YES" ]; then
            log_msg "[$TYPE] $NAME ($TIP) - FAIL / NO RESPONSE" "PING" "$NOW_HUMAN"
        fi

        # 2. FAILURE: Alert Logic (Main Log)
        local C=0
        [ -f "$FC" ] && read C < "$FC"
        C=$((C+1))
        echo "$C" > "$FC"
        
        if [ "$C" -ge "$THRESH" ] && [ ! -f "$FD" ]; then
             echo "$NOW_SEC" > "$FD"
             echo "$NOW_HUMAN" > "$FT"
             
             # -- CUSTOMIZE ALERT MESSAGES HERE --
             local D_MSG="**Router:** $ROUTER_NAME\n**${TYPE}:** $NAME ($TIP)\n**Time:** $NOW_HUMAN"
             local T_MSG="🔴 ${TYPE} Down * $ROUTER_NAME - $NAME - $TIP - $NOW_HUMAN"
             log_msg "[ALERT] ${TYPE}: $NAME Down" "UPTIME" "$NOW_HUMAN"
             
             if [ "$IS_SILENT" -eq 1 ]; then
                 [ -f "$SILENT_BUFFER" ] && [ $(wc -c < "$SILENT_BUFFER") -lt 5120 ] && echo "${TYPE} $NAME DOWN: $NOW_HUMAN" >> "$SILENT_BUFFER"
             else
                 send_notification "🔴 ${TYPE} Down" "$D_MSG" "15548997" "ALERT" "ALL" "NO" "$T_MSG" "$M_FLAG"
             fi
        fi
    fi
}

# --- SMART HEARTBEAT ALIGNMENT ---
align_heartbeat() {
    # Calculate midnight timestamp for today
    local now=$(date +%s)
    local h=$(date +%H)
    local m=$(date +%M)
    local s=$(date +%S)
    
    # Strip leading zeros to avoid octal interpretation issues
    h=${h#0}
    m=${m#0}
    s=${s#0}
    
    local sec_today=$((h * 3600 + m * 60 + s))
    local midnight=$((now - sec_today))
    
    # Get user target time (default 12:00)
    local start_h=${HB_START_HOUR:-12}
    start_h=${start_h#0}
    local start_m=${HB_START_MIN:-00}
    start_m=${start_m#0}
    
    # Calculate target start timestamp for today
    local target=$((midnight + start_h * 3600 + start_m * 60))
    
    # Adjust target backwards or forwards to find the last theoretical heartbeat
    # This aligns future heartbeats to the exact minute requested.
    if [ "$target" -gt "$now" ]; then
        # Target is in future today. Go back intervals until we are in the past.
        local diff=$((target - now))
        local intervals=$(((diff + HB_INTERVAL - 1) / HB_INTERVAL))
        LAST_HB_CHECK=$((target - (intervals * HB_INTERVAL)))
    else
        # Target passed today. Find most recent interval point.
        local diff=$((now - target))
        local intervals=$((diff / HB_INTERVAL))
        LAST_HB_CHECK=$((target + (intervals * HB_INTERVAL)))
    fi
    
    log_msg "[SYSTEM] Heartbeat aligned to start sequence at: $start_h:$start_m" "UPTIME" "$NOW_HUMAN"
}

# --- INITIAL STARTUP ---
load_config
load_credentials
if [ $? -eq 0 ]; then
    log_msg "[SYSTEM] Credentials loaded." "UPTIME" "$(date '+%b %d %H:%M:%S')"
else
    log_msg "[WARNING] credentials.conf missing - run the 'credentials' command." "UPTIME" "$(date '+%b %d %H:%M:%S')"
fi

# Initialize Heartbeat Alignment
[ "$HEARTBEAT" = "YES" ] && align_heartbeat

# --- MAIN LOGIC LOOP ---
while true; do
    load_config
    NOW_HUMAN=$(date '+%b %d %H:%M:%S')
    NOW_SEC=$(date +%s)
    CUR_HOUR=$(date +%H)
    
    # Resource Check (Universal)
    if [ -f /proc/meminfo ] && grep -q MemAvailable /proc/meminfo; then
        CUR_FREE_RAM=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        # Capture Total RAM for Safety Calculation (Only possible via meminfo)
        TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    else
        CUR_FREE_RAM=$(free | awk '/Mem:/ {print $4}')
        # Estimate Total from free+used (Less accurate fallback for non-meminfo systems)
        TOTAL_RAM_KB=$((CUR_FREE_RAM + 51200)) 
    fi
    
    CPU_LOAD=$(cat /proc/loadavg | awk '{print $1}')
    CPU_LOAD=${CPU_LOAD:-0.00}
    
    if awk "BEGIN {exit !($CPU_LOAD > $CPU_GUARD_THRESHOLD)}"; then
        log_msg "[SYSTEM] High Load ($CPU_LOAD). Skipping." "UPTIME" "$NOW_HUMAN"
        sleep 10
        continue
    fi

    # 1. HEARTBEAT (UPDATED LOGIC V1.3.8)
    if [ "$HEARTBEAT" = "YES" ]; then 
        if [ $((NOW_SEC - LAST_HB_CHECK)) -ge "$HB_INTERVAL" ]; then
            # Drift Correction: Advance timer by exactly one interval
            # This ensures we stay locked to the HH:MM schedule and don't drift.
            LAST_HB_CHECK=$((LAST_HB_CHECK + HB_INTERVAL))
            
            # Safety Catch-up: If system was off for a long time, reset alignment
            if [ $((NOW_SEC - LAST_HB_CHECK)) -ge "$HB_INTERVAL" ]; then
                 align_heartbeat 
            fi
            
            M_HB="NO"
            if [ "$DISCORD_MENTION_HB" = "YES" ] || [ "$NTFY_MENTION_HB" = "YES" ]; then M_HB="YES"; fi
            
            send_notification "💓 Heartbeat Report" "**Router:** $ROUTER_NAME\n**Status:** Operational\n**Time:** $NOW_HUMAN" "1752220" "INFO" "${HB_TARGET:-ALL}" "NO" "💓 Heartbeat - $ROUTER_NAME - $NOW_HUMAN" "$M_HB"
            log_msg "Heartbeat sent ($HB_TARGET)." "UPTIME" "$NOW_HUMAN"
        fi
    fi

    # 2. SILENT MODE
    IS_SILENT=0
    if [ "$SILENT_ENABLE" = "YES" ]; then
        if [ "$SILENT_START" -gt "$SILENT_END" ]; then
            if [ "$CUR_HOUR" -ge "$SILENT_START" ] || [ "$CUR_HOUR" -lt "$SILENT_END" ]; then IS_SILENT=1; fi
        else
            if [ "$CUR_HOUR" -ge "$SILENT_START" ] && [ "$CUR_HOUR" -lt "$SILENT_END" ]; then IS_SILENT=1; fi
        fi
    fi
    if [ "$IS_SILENT" -eq 0 ] && [ -s "$SILENT_BUFFER" ]; then
        S_CONTENT=$(cat "$SILENT_BUFFER")
        CLEAN_S=$(echo "$S_CONTENT" | sed ':a;N;$!ba;s/\n/\\n/g')
        send_notification "🌙 Silent Hours Summary" "**Router:** $ROUTER_NAME\n$CLEAN_S" "10181046" "SUMMARY" "ALL" "NO" "🌙 Silent Hours Summary - $ROUTER_NAME\n$S_CONTENT" "NO"
        > "$SILENT_BUFFER"
        log_msg "[SYSTEM] Silent buffer dumped." "UPTIME" "$NOW_HUMAN"
    fi
    if [ "$IS_SILENT" -eq 0 ] && [ -s "$OFFLINE_BUFFER" ]; then
        NET_NOW="UP"
        [ -f "$NET_STATUS_FILE" ] && read NET_NOW < "$NET_STATUS_FILE"
        [ "$NET_NOW" = "UP" ] && flush_buffer
    fi

    # 3. INTERNET MONITOR
    if [ "$EXT_ENABLE" = "YES" ]; then
        if [ $((NOW_SEC - LAST_EXT_CHECK)) -ge "$EXT_SCAN_INTERVAL" ]; then
            LAST_EXT_CHECK=$NOW_SEC
            FD="$TMP_DIR/nwdta_ext_d"
            FT="$TMP_DIR/nwdta_ext_t"
            FC="$TMP_DIR/nwdta_ext_c"
            TO="${EXT_PING_TIMEOUT:-1}"
            [ "$TO" -le "$EXT_PING_COUNT" ] && TO=$((EXT_PING_COUNT + 1))
            
            EXT_UP=0
            if [ -n "$EXT_IP" ] && ping -q -c "$EXT_PING_COUNT" -w "$TO" "$EXT_IP" > /dev/null 2>&1; then
                EXT_UP=1
            elif [ -n "$EXT_IP2" ] && ping -q -c "$EXT_PING_COUNT" -w "$TO" "$EXT_IP2" > /dev/null 2>&1; then
                EXT_UP=1
            fi
            
            EXT_UP_GLOBAL=$EXT_UP

            if [ "$EXT_UP" -eq 0 ]; then
                C=0
                [ -f "$FC" ] && read C < "$FC"
                C=$((C+1))
                echo "$C" > "$FC"
                
                if [ "$C" -ge "$EXT_FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                    echo "$NOW_SEC" > "$FD"
                    echo "$NOW_HUMAN" > "$FT"
                    echo "DOWN" > "$NET_STATUS_FILE"
                    log_msg "[ALERT] INTERNET DOWN" "UPTIME" "$NOW_HUMAN"
                    [ "$IS_SILENT" -ne 0 ] && echo "Internet Down: $NOW_HUMAN" >> "$SILENT_BUFFER"
                fi
            else
                if [ -f "$FD" ]; then
                    echo "UP" > "$NET_STATUS_FILE"
                    read START_TIME < "$FT"
                    read START_SEC < "$FD"
                    DUR=$((NOW_SEC - START_SEC))
                    DR="$((DUR/60))m $((DUR%60))s"
                    MSG_D="**Router:** $ROUTER_NAME\n**Down at:** $START_TIME\n**Up at:** $NOW_HUMAN\n**Total Outage:** $DR"
                    MSG_T="🟢 Connectivity Restored * $ROUTER_NAME - Down time: $START_TIME - UP time: $NOW_HUMAN - Duration: $DR"
                    log_msg "[SUCCESS] INTERNET UP - Downtime: $DR" "UPTIME" "$NOW_HUMAN"
                    
                    M_NET="NO"
                    if [ "$DISCORD_MENTION_NET" = "YES" ] || [ "$NTFY_MENTION_NET" = "YES" ]; then M_NET="YES"; fi
                    
                    if [ "$IS_SILENT" -eq 0 ]; then
                        send_notification "🟢 Connectivity Restored" "$MSG_D" "3066993" "SUCCESS" "ALL" "YES" "$MSG_T" "$M_NET"
                        flush_buffer
                    else
                         echo "Internet Restored: $NOW_HUMAN (Down $DR)" >> "$SILENT_BUFFER"
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

    # --- DYNAMIC BATCH CONFIGURATION (V1.3.9 UPDATE WITH CPU AWARENESS) ---
    # Calculates how many devices to ping in parallel based on RAM AND CPU Cores
    BATCH_LIMIT=50 # Hard cap default
    
    if [ "$SCAN_BATCH_SIZE" = "0" ] || [ -z "$SCAN_BATCH_SIZE" ]; then
        BATCH_LIMIT=999 # Effectively unlimited (Full Parallel)
    elif [ "$SCAN_BATCH_SIZE" = "AUTO" ]; then
        # 1. RAM Safety Calculation (Reserve 10% Total RAM)
        SAFETY_MARGIN=$((TOTAL_RAM_KB / 10))
        USABLE_FREE=$((CUR_FREE_RAM - SAFETY_MARGIN))
        
        if [ "$USABLE_FREE" -le 0 ]; then
             RAM_BATCH_LIMIT=1 
        else
             # Approx 4000KB per ping process overhead
             RAM_BATCH_LIMIT=$((USABLE_FREE / 4000)) 
        fi
        
        # 2. CPU Safety Calculation (Core Count Limiter)
        CPU_CORES=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
        [ "$CPU_CORES" -lt 1 ] && CPU_CORES=1
        
        if [ "$CPU_CORES" -eq 1 ]; then
            CPU_BATCH_LIMIT=10  # Single Core = Low Concurrency
        elif [ "$CPU_CORES" -eq 2 ]; then
            CPU_BATCH_LIMIT=25  # Dual Core = Medium Concurrency
        else
            CPU_BATCH_LIMIT=50  # Quad Core+ = High Concurrency
        fi
        
        # 3. Select the Lower Limit (The Bottleneck Wins)
        if [ "$RAM_BATCH_LIMIT" -lt "$CPU_BATCH_LIMIT" ]; then
            BATCH_LIMIT=$RAM_BATCH_LIMIT
        else
            BATCH_LIMIT=$CPU_BATCH_LIMIT
        fi
        
        # 4. Final Sanity Clamps
        if [ "$BATCH_LIMIT" -lt 5 ]; then BATCH_LIMIT=5; fi
        if [ "$BATCH_LIMIT" -gt 50 ]; then BATCH_LIMIT=50; fi
    else
        # User defined fixed number
        if echo "$SCAN_BATCH_SIZE" | grep -qE '^[0-9]+$'; then
            BATCH_LIMIT=$SCAN_BATCH_SIZE
        fi
    fi

    # 4. DEVICE MONITOR (WITH BATCH LOGIC)
    if [ "$DEVICE_MONITOR" = "YES" ]; then
        if [ $((NOW_SEC - LAST_DEV_CHECK)) -ge "$DEV_SCAN_INTERVAL" ]; then
            LAST_DEV_CHECK=$NOW_SEC
            CURRENT_JOBS=0
            
            while read -r line || [ -n "$line" ]; do
                case "$line" in \#*|"") continue ;; esac
                line=$(echo "$line" | tr -d '\r')
                IP="${line%%@*}"
                IP="${IP%% }"
                IP="${IP## }"
                NAME="${line#*@}"
                NAME="${NAME## }"
                [ "$NAME" = "$line" ] && NAME="$IP"
                
                if [ -n "$IP" ]; then
                    check_ip_logic "$IP" "$NAME" "Device" "$DEV_FAIL_THRESHOLD" "$DEV_PING_COUNT" "$DEV_PING_TIMEOUT" &
                    CURRENT_JOBS=$((CURRENT_JOBS + 1))
                    
                    if [ "$CURRENT_JOBS" -ge "$BATCH_LIMIT" ]; then
                        wait
                        CURRENT_JOBS=0
                    fi
                fi
            done < "$IP_LIST_FILE"
            wait # Catch stragglers
        fi
    fi

    # 5. REMOTE MONITOR (WITH BATCH LOGIC)
    if [ "$REMOTE_MONITOR" = "YES" ] && [ "$EXT_UP_GLOBAL" -eq 1 ]; then
        if [ $((NOW_SEC - LAST_REM_CHECK)) -ge "$REM_SCAN_INTERVAL" ]; then
            LAST_REM_CHECK=$NOW_SEC
            CURRENT_JOBS=0
            
            while read -r line || [ -n "$line" ]; do
                case "$line" in \#*|"") continue ;; esac
                line=$(echo "$line" | tr -d '\r')
                IP="${line%%@*}"
                IP="${IP%% }"
                IP="${IP## }"
                NAME="${line#*@}"
                NAME="${NAME## }"
                [ "$NAME" = "$line" ] && NAME="$IP"
                
                if [ -n "$IP" ]; then
                    check_ip_logic "$IP" "$NAME" "Remote" "$REM_FAIL_THRESHOLD" "$REM_PING_COUNT" "$REM_PING_TIMEOUT" &
                    CURRENT_JOBS=$((CURRENT_JOBS + 1))
                    
                    if [ "$CURRENT_JOBS" -ge "$BATCH_LIMIT" ]; then
                        wait
                        CURRENT_JOBS=0
                    fi
                fi
            done < "$REMOTE_LIST_FILE"
            wait # Catch stragglers
        fi
    fi
    
    sleep 1
done
EOF
chmod +x "$INSTALL_DIR/netwatchdta.sh"

## ==============================================================================
#  STEP 7: SERVICE CONFIGURATION (MULTI-OS)
# ==============================================================================
printf '%b\n' "\n${CYAN}⚙️  Configuring system service ($SERVICE_TYPE)...${NC}"

if [ "$SERVICE_TYPE" = "PROCD" ]; then
    # --- OPENWRT PROCD SERVICE (Interactive Edit Added) ---
    cat <<EOF > "$SERVICE_PATH"
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

extra_command "check" "Check if monitor is running"
extra_command "logs" "View last 20 log entries"
extra_command "clear" "Clear the log file"
extra_command "discord" "Test Discord notification"
extra_command "telegram" "Test Telegram notification"
extra_command "ntfy" "Test ntfy notification"
extra_command "credentials" "Update Notification credentials"
extra_command "edit" "Edit configuration files"
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
    local v=\$(grep "^VERSION=" "$INSTALL_DIR/netwatchdta.sh" | cut -d'"' -f2)
    if pgrep -f "netwatchdta.sh" > /dev/null; then
        printf '%b\n' "\033[1;32m● netwatchdta is RUNNING.\033[0m (v\$v)"
        echo "   PID: \$(pgrep -f "netwatchdta.sh" | head -1)"
    else
        printf '%b\n' "\033[1;31m● netwatchdta is STOPPED.\033[0m (v\$v)"
    fi
}

logs() {
    if [ -f "/tmp/netwatchdta/nwdta_uptime.log" ]; then
        printf '%b\n' "\033[1;34m--- Recent Activity ---\033[0m"
        tail -n 20 /tmp/netwatchdta/nwdta_uptime.log
    else
        echo "No log found."
    fi
}

clear() {
    echo "\$(date '+%b %d %H:%M:%S') - [SYSTEM] Log cleared manually." > "/tmp/netwatchdta/nwdta_uptime.log"
    echo "Log file cleared."
}

edit() {
    echo ""
    printf '%b\n' "\033[1;36m📝 Configuration Editor\033[0m"
    
    local editor="vi"
    if command -v nano >/dev/null 2>&1; then editor="nano"; fi
    
    while true; do
        echo "1. Edit Settings (settings.conf)"
        echo "2. Edit Device IPs (device_ips.conf)"
        echo "3. Edit Remote IPs (remote_ips.conf)"
        echo "4. Edit Credentials (credentials.conf)"
        echo "5. Exit"
        printf "\033[1mChoice [1-5]: \033[0m"
        read choice </dev/tty
        case "\$choice" in
            1) \$editor "$INSTALL_DIR/settings.conf"; break ;;
            2) \$editor "$INSTALL_DIR/device_ips.conf"; break ;;
            3) \$editor "$INSTALL_DIR/remote_ips.conf"; break ;;
            4) \$editor "$INSTALL_DIR/credentials.conf"; break ;;
            5) echo "Cancelled."; exit 0 ;;
            *) echo "Invalid choice." ;;
        esac
    done
    echo ""
    printf '%b\n' "\033[1;33m⚠️  If you made changes, run: /etc/init.d/netwatchdta restart\033[0m"
}

purge() {
    echo ""
    printf '%b\n' "\033[1;31m=======================================================\033[0m"
    printf '%b\n' "\033[1;31m🗑️  netwatchdta Smart Uninstaller\033[0m"
    printf '%b\n' "\033[1;31m=======================================================\033[0m"
    echo ""
    printf '%b\n' "\033[1;37m1.\033[0m Full Uninstall (Remove everything)"
    printf '%b\n' "\033[1;37m2.\033[0m Keep Settings (Remove logic but keep config)"
    printf '%b\n' "\033[1;37m3.\033[0m Cancel"
    printf "\033[1mChoice [1-3]: \033[0m"
    read choice </dev/tty
    
    case "\$choice" in
        1)
            echo ""
            printf '%b\n' "\033[1;33m🛑 Stopping service...\033[0m"
            /etc/init.d/netwatchdta stop
            /etc/init.d/netwatchdta disable
            printf '%b\n' "\033[1;33m🧹 Cleaning up /tmp and buffers...\033[0m"
            rm -rf "/tmp/netwatchdta"
            rm -rf "$INSTALL_DIR"
            printf '%b\n' "\033[1;33m🔥 Self-destructing service file...\033[0m"
            rm -f "$SERVICE_PATH"
            echo ""
            printf '%b\n' "\033[1;32m✅ netwatchdta has been completely removed.\033[0m"
            ;;
        2)
            echo ""
            printf '%b\n' "\033[1;33m🛑 Stopping service...\033[0m"
            /etc/init.d/netwatchdta stop
            /etc/init.d/netwatchdta disable
            printf '%b\n' "\033[1;33m🧹 Cleaning up /tmp...\033[0m"
            rm -rf "/tmp/netwatchdta"
            printf '%b\n' "\033[1;33m🗑️  Removing core script...\033[0m"
            rm -f "$INSTALL_DIR/netwatchdta.sh" "$INSTALL_DIR/nwdta_common.sh"
            printf '%b\n' "\033[1;33m🔥 Removing service file...\033[0m"
            rm -f "$SERVICE_PATH"
            echo ""
            printf '%b\n' "\033[1;33m✅ Logic removed. Settings preserved in $INSTALL_DIR\033[0m"
            ;;
        *)
            printf '%b\n' "\033[1;31m❌ Purge cancelled.\033[0m"
            exit 0
            ;;
    esac
}

load_functions() {
    BASE_DIR="$INSTALL_DIR"
    . "$INSTALL_DIR/nwdta_common.sh"
    nw_load_settings
}

discord()     { load_functions; nw_test DISCORD; }
telegram()    { load_functions; nw_test TELEGRAM; }
ntfy()        { load_functions; nw_test NTFY; }
credentials() { load_functions; nw_creds_menu "/etc/init.d/netwatchdta restart"; }
EOF
    chmod +x "$SERVICE_PATH"
    "$SERVICE_PATH" enable >/dev/null 2>&1
    "$SERVICE_PATH" restart >/dev/null 2>&1

elif [ "$SERVICE_TYPE" = "SYSTEMD" ]; then
    # --- LINUX SYSTEMD SERVICE ---
    cat <<EOF > /etc/systemd/system/netwatchdta.service
[Unit]
Description=netwatchdta Network Monitor
After=network.target

[Service]
ExecStart=/bin/sh $INSTALL_DIR/netwatchdta.sh
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable netwatchdta >/dev/null 2>&1
    systemctl restart netwatchdta

    # --- LINUX CLI WRAPPER (Updated with Functions for Local Fix) ---
    CLI_PATH="/usr/local/bin/netwatchdta"
    cat <<EOF > "$CLI_PATH"
#!/bin/sh
# CLI Wrapper for netwatchdta on Linux
INSTALL_DIR="$INSTALL_DIR"
CONF="\$INSTALL_DIR/settings.conf"

# --- HELPER FUNCTIONS FOR LINUX CLI ---
BASE_DIR="\$INSTALL_DIR"
[ -f "\$INSTALL_DIR/nwdta_common.sh" ] && . "\$INSTALL_DIR/nwdta_common.sh"

run_discord_test()       { nw_test DISCORD; }
run_telegram_test()      { nw_test TELEGRAM; }
run_ntfy_test()          { nw_test NTFY; }
run_credentials_update() { nw_creds_menu "systemctl restart netwatchdta"; }

case "\$1" in
    start) 
        systemctl start netwatchdta
        echo "Started." 
        ;;
    stop) 
        systemctl stop netwatchdta
        echo "Stopped." 
        ;;
    restart) 
        systemctl restart netwatchdta
        echo "Restarted." 
        ;;
    status|check) 
        v=\$(grep "^VERSION=" "$INSTALL_DIR/netwatchdta.sh" | cut -d'"' -f2)
        if systemctl is-active --quiet netwatchdta; then
            printf '%b\n' "\033[1;32m● netwatchdta is RUNNING.\033[0m (v\$v)"
        else
            printf '%b\n' "\033[1;31m● netwatchdta is STOPPED.\033[0m (v\$v)"
        fi
        systemctl status netwatchdta --no-pager | head -n 5
        ;;
    logs) 
        tail -n 30 /tmp/netwatchdta/nwdta_uptime.log 
        ;;
    clear)
        echo "\$(date '+%b %d %H:%M:%S') - [SYSTEM] Log cleared manually." > "/tmp/netwatchdta/nwdta_uptime.log"
        echo "Log file cleared."
        ;;
    edit) 
        echo ""
        printf '%b\n' "\033[1;36m📝 Configuration Editor\033[0m"
        while true; do
            echo "1. Edit Settings (settings.conf)"
            echo "2. Edit Device IPs (device_ips.conf)"
            echo "3. Edit Remote IPs (remote_ips.conf)"
            echo "4. Edit Credentials (credentials.conf)"
            echo "5. Exit"
            printf "\033[1mChoice [1-5]: \033[0m"
            read choice </dev/tty
            case "\$choice" in
                1) nano "\$INSTALL_DIR/settings.conf"; break ;;
                2) nano "\$INSTALL_DIR/device_ips.conf"; break ;;
                3) nano "\$INSTALL_DIR/remote_ips.conf"; break ;;
                4) nano "\$INSTALL_DIR/credentials.conf"; break ;;
                5) echo "Cancelled."; exit 0 ;;
                *) echo "Invalid choice." ;;
            esac
        done
        echo ""
        printf '%b\n' "\033[1;33m⚠️  If you made changes, run: netwatchdta restart\033[0m"
        ;;
    discord) 
        run_discord_test 
        ;;
    telegram) 
        run_telegram_test 
        ;;
    ntfy) 
        run_ntfy_test 
        ;;
    credentials) 
        run_credentials_update 
        ;;
    purge) 
        echo ""
        printf '%b\n' "\033[1;31m=======================================================\033[0m"
        printf '%b\n' "\033[1;31m🗑️  netwatchdta Smart Uninstaller\033[0m"
        printf '%b\n' "\033[1;31m=======================================================\033[0m"
        echo ""
        printf '%b\n' "\033[1;37m1.\033[0m Full Uninstall (Remove everything)"
        printf '%b\n' "\033[1;37m2.\033[0m Keep Settings (Remove logic but keep config)"
        printf '%b\n' "\033[1;37m3.\033[0m Cancel"
        printf "\033[1mChoice [1-3]: \033[0m"
        read choice </dev/tty
        
        case "\$choice" in
            1)
                echo ""
                printf '%b\n' "\033[1;33m🛑 Stopping service...\033[0m"
                systemctl stop netwatchdta
                systemctl disable netwatchdta
                printf '%b\n' "\033[1;33m🧹 Cleaning up /tmp and files...\033[0m"
                rm -rf "/tmp/netwatchdta"
                rm -rf "\$INSTALL_DIR"
                printf '%b\n' "\033[1;33m🔥 Removing service...\033[0m"
                rm -f /etc/systemd/system/netwatchdta.service /usr/local/bin/netwatchdta
                systemctl daemon-reload
                echo ""
                printf '%b\n' "\033[1;32m✅ netwatchdta has been completely removed.\033[0m"
                ;;
            2)
                echo ""
                printf '%b\n' "\033[1;33m🛑 Stopping service...\033[0m"
                systemctl stop netwatchdta
                systemctl disable netwatchdta
                printf '%b\n' "\033[1;33m🧹 Cleaning up /tmp...\033[0m"
                rm -rf "/tmp/netwatchdta"
                printf '%b\n' "\033[1;33m🗑️  Removing core script...\033[0m"
                rm -f "\$INSTALL_DIR/netwatchdta.sh" "\$INSTALL_DIR/nwdta_common.sh"
                printf '%b\n' "\033[1;33m🔥 Removing service file...\033[0m"
                rm -f /etc/systemd/system/netwatchdta.service /usr/local/bin/netwatchdta
                systemctl daemon-reload
                echo ""
                printf '%b\n' "\033[1;32m✅ Logic removed. Settings preserved in \$INSTALL_DIR\033[0m"
                ;;
            *)
                printf '%b\n' "\033[1;31m❌ Purge cancelled.\033[0m"
                exit 0
                ;;
        esac
        ;;
    *) 
        echo "Usage: netwatchdta {start|stop|restart|status|logs|clear|discord|telegram|ntfy|credentials|edit|purge}" 
        ;;
esac
EOF
    chmod +x "$CLI_PATH"
    printf '%b\n' "${GREEN}✅ CLI Command installed: 'netwatchdta'${NC}"
fi

# ==============================================================================
#  STEP 8: FINAL SUCCESS MESSAGE
# ==============================================================================
sleep 2
if pgrep -f "netwatchdta.sh" > /dev/null; then STATUS="${GREEN}ACTIVE${NC}"; else STATUS="${RED}FAILED (Check Logs)${NC}"; fi

NOW_FINAL=$(date '+%b %d, %Y %H:%M:%S')
MSG="**Router/Device:** $router_name_input\n**Time:** $NOW_FINAL\n**Status:** Service Installed & Active"

if [ "$DISCORD_ENABLE_VAL" = "YES" ] && [ -n "$DISCORD_WEBHOOK" ]; then
    safe_fetch "$DISCORD_WEBHOOK" "{\"embeds\": [{\"title\": \"🚀 netwatchdta Service Started\", \"description\": \"$MSG\", \"color\": 1752220}]}" "Content-Type: application/json"
fi

if [ "$TELEGRAM_ENABLE_VAL" = "YES" ] && [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    safe_fetch "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" "{\"chat_id\": \"$TELEGRAM_CHAT_ID\", \"text\": \"🚀 netwatchdta Service Started - $router_name_input\"}" "Content-Type: application/json"
fi

if [ "$NTFY_ENABLE_VAL" = "YES" ] && [ -n "$NTFY_URL" ]; then
    safe_fetch "$NTFY_URL" "🚀 netwatchdta Service Started - $router_name_input" "Title: 🚀 netwatchdta Started" "Tags: rocket" "Priority: default"
fi

printf '%b\n' "\n${GREEN}=======================================================${NC}"
printf '%b\n' "${BOLD}${GREEN}✅ Installation complete!${NC}"
printf '%b\n' "${CYAN}📂 Folder :${NC} $INSTALL_DIR"
printf '%b\n' "${CYAN}⚙️  Service:${NC} $STATUS"
printf '%b\n' "${GREEN}=======================================================${NC}"
printf '%b\n' "\n${BOLD}Quick Commands:${NC}"
if [ "$SERVICE_TYPE" = "PROCD" ]; then
    printf '%b\n' "  Status           : ${YELLOW}/etc/init.d/netwatchdta check${NC}"
    printf '%b\n' "  Logs             : ${YELLOW}/etc/init.d/netwatchdta logs${NC}"
    printf '%b\n' "  Uninstall        : ${RED}/etc/init.d/netwatchdta purge${NC}"
    printf '%b\n' "  Edit Settings    : ${YELLOW}/etc/init.d/netwatchdta edit${NC}"
    printf '%b\n' "  Change ntfy/bot  : ${YELLOW}/etc/init.d/netwatchdta credentials${NC}"
    printf '%b\n' "  Restart          : ${YELLOW}/etc/init.d/netwatchdta restart${NC}"
else
    printf '%b\n' "  Status           : ${YELLOW}netwatchdta check${NC}"
    printf '%b\n' "  Logs             : ${YELLOW}netwatchdta logs${NC}"
    printf '%b\n' "  Uninstall        : ${RED}netwatchdta purge${NC}"
    printf '%b\n' "  Edit Settings    : ${YELLOW}netwatchdta edit${NC}"
    printf '%b\n' "  Change ntfy/bot  : ${YELLOW}netwatchdta credentials${NC}"
    printf '%b\n' "  Restart          : ${YELLOW}netwatchdta restart${NC}"
fi
echo ""