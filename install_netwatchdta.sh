#!/bin/sh
# netwatchdta Installer - Automated Setup for OpenWrt & Linux (Universal)
# Copyright (C) 2025 panoc
# Licensed under the GNU General Public License v3.0
SCRIPT_VERSION="1.3.9"

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
#  OS DETECTION ENGINE
# ==============================================================================
# Detects if running on OpenWrt or Standard Linux (Systemd)
OS_TYPE="UNKNOWN"
PKG_MANAGER=""
INSTALL_DIR=""
SERVICE_TYPE=""

if [ -f /etc/openwrt_release ]; then
    OS_TYPE="OPENWRT"
    PKG_MANAGER="opkg"
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
    echo -e "${RED}❌ Critical Error: Unsupported Operating System.${NC}"
    echo -e "   Supported: OpenWrt, Ubuntu, Debian, CentOS, Fedora, Arch, etc."
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
# Defined early so the installer can use it for connectivity tests.
# FIX: Prioritizes uclient-fetch (OpenWrt) or Curl (Linux)
safe_fetch() {
    local url="$1"
    local data="$2"   # JSON Payload
    local header="$3" # e.g. "Content-Type: application/json"

    # STRATEGY 1: uclient-fetch (OpenWrt Native & Light - Preferred on OpenWrt)
    # We check OS_TYPE to ensure we only prefer this on OpenWrt
    if [ "$OS_TYPE" = "OPENWRT" ] && (command -v uclient-fetch >/dev/null 2>&1 || [ -x /bin/uclient-fetch ]); then
        if uclient-fetch --help 2>&1 | grep -q "\-\-header"; then
            uclient-fetch --no-check-certificate --header="$header" --post-data="$data" "$url" -O /dev/null >/dev/null 2>&1
            return 0 # Force success to handle Discord 204
        fi
    fi

    # STRATEGY 2: Curl (Robust Fallback & Preferred on Linux)
    if command -v curl >/dev/null 2>&1; then
        curl -s -k -X POST -H "$header" -d "$data" "$url" >/dev/null 2>&1
        return 0
    fi

    # STRATEGY 3: Wget (Last Resort)
    if command -v wget >/dev/null 2>&1; then
        wget -q --no-check-certificate --header="$header" \
             --post-data="$data" "$url" -O /dev/null
        return 0
    fi
    
    return 1 # Failure: No tool found
}

# ==============================================================================
#  INSTALLER HEADER
# ==============================================================================
echo -e "${BLUE}=======================================================${NC}"
echo -e "${BOLD}${CYAN}🚀 netwatchdta Universal Setup${NC} v$SCRIPT_VERSION"
echo -e "${BLUE}⚖️  License: GNU GPLv3${NC}"
echo -e "${BLUE}=======================================================${NC}"
echo -e "${WHITE}🖥️  System Detected : ${GREEN}$OS_TYPE${NC}"
echo -e "${WHITE}📦 Package Manager : ${GREEN}$PKG_MANAGER${NC}"
echo -e "${WHITE}📂 Install Path    : ${GREEN}$INSTALL_DIR${NC}"
echo -e "${WHITE}⚙️  Service Manager : ${GREEN}$SERVICE_TYPE${NC}"
echo ""

# Root Check
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ Permission Denied!${NC}"
    echo -e "   You must run this installer as ${BOLD}root${NC} (or use sudo)."
    exit 1
fi

# --- 0. PRE-INSTALLATION CONFIRMATION ---
ask_yn "❓ This will begin the installation process. Continue?"
if [ "$ANSWER_YN" = "n" ]; then
    echo -e "${RED}❌ Installation aborted by user. Cleaning up...${NC}"
    exit 0
fi

# ==============================================================================
#  DIRECTORY & FILE PATH DEFINITIONS
# ==============================================================================
# Paths are set dynamically based on OS_TYPE in the block above
CONFIG_FILE="$INSTALL_DIR/settings.conf"
IP_LIST_FILE="$INSTALL_DIR/device_ips.conf"
REMOTE_LIST_FILE="$INSTALL_DIR/remote_ips.conf"
VAULT_FILE="$INSTALL_DIR/.vault.enc"
SERVICE_NAME="netwatchdta"
SERVICE_PATH="/etc/init.d/$SERVICE_NAME"

# Ensure temp directory exists for installation logs
mkdir -p "/tmp/netwatchdta"
# ==============================================================================
#  STEP 1: SYSTEM READINESS CHECKS
# ==============================================================================
echo -e "\n${BOLD}📦 Checking system readiness...${NC}"

# --- OPENWRT SPECIFIC CHECKS ---
if [ "$OS_TYPE" = "OPENWRT" ]; then
    # 1. Check Flash Storage (Root partition)
    FREE_FLASH_KB=$(df / | awk 'NR==2 {print $4}')
    MIN_FLASH_KB=3072 # 3MB Threshold

    # 2. Check RAM (/tmp partition)
    FREE_RAM_KB=$(df /tmp | awk 'NR==2 {print $4}')
    MIN_RAM_KB=4096 # 4MB Threshold

    # 3. Check Physical Memory for Execution Method Auto-Detection
    # UPDATED LOGIC v1.3.9:
    # >= 512MB (524288 kB) = High End (Full Parallel, No Batching)
    # <  512MB = Low End (Smart Batching, Queue Notifications)
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
    if ! command -v uclient-fetch >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then MISSING_DEPS="$MISSING_DEPS curl"; fi
    [ -f /etc/ssl/certs/ca-certificates.crt ] || command -v opkg >/dev/null && opkg list-installed | grep -q ca-bundle || MISSING_DEPS="$MISSING_DEPS ca-bundle"
    command -v openssl >/dev/null 2>&1 || MISSING_DEPS="$MISSING_DEPS openssl-util"

    # RAM Guard Check
    if [ "$FREE_RAM_KB" -lt "$MIN_RAM_KB" ]; then
        echo -e "${RED}❌ ERROR: Insufficient RAM for operations!${NC}"
        echo -e "${YELLOW}Available: $((FREE_RAM_KB / 1024))MB | Required: 4MB${NC}"
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
    command -v openssl >/dev/null 2>&1 || MISSING_DEPS="$MISSING_DEPS openssl"
    # Ensure ping is available (some minimal containers miss it)
    command -v ping >/dev/null 2>&1 || MISSING_DEPS="$MISSING_DEPS iputils-ping" 
fi

# --- DEPENDENCY INSTALLATION LOGIC ---
if [ -n "$MISSING_DEPS" ]; then
    echo -e "${CYAN}🔍 Missing dependencies found:${BOLD}$MISSING_DEPS${NC}"
    
    if [ "$OS_TYPE" = "OPENWRT" ] && [ "$FREE_FLASH_KB" -lt "$MIN_FLASH_KB" ]; then
        echo -e "${RED}❌ ERROR: Insufficient Flash storage to install dependencies!${NC}"
        echo -e "${YELLOW}Available: $((FREE_FLASH_KB / 1024))MB | Required: 3MB${NC}"
        exit 1
    fi
    
    ask_yn "❓ Install missing dependencies?"
    if [ "$ANSWER_YN" = "y" ]; then
         echo -e "${YELLOW}📥 Installing via $PKG_MANAGER...${NC}"
         
         case "$PKG_MANAGER" in
            opkg)
                opkg update --no-check-certificate > /dev/null 2>&1
                opkg install --no-check-certificate $MISSING_DEPS > /tmp/nwdta_install_err.log 2>&1
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
            apk)
                apk add $MISSING_DEPS
                ;;
            *)
                echo -e "${RED}❌ Auto-install not supported for this OS.${NC}"
                echo -e "   Please install manually: $MISSING_DEPS"
                exit 1
                ;;
         esac

         if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Error installing dependencies.${NC}"
            [ -f /tmp/nwdta_install_err.log ] && cat /tmp/nwdta_install_err.log
            exit 1
         fi
         echo -e "${GREEN}✅ Dependencies installed successfully.${NC}"
    else
         echo -e "${RED}❌ Cannot proceed without dependencies. Aborting.${NC}"
         exit 1
    fi
else
    echo -e "${GREEN}✅ All dependencies are installed.${NC}"
    if [ "$OS_TYPE" = "OPENWRT" ]; then
        echo -e "${GREEN}✅ Flash storage check passed: $((FREE_FLASH_KB / 1024))MB available.${NC}"
    fi
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
        # Universal Stop Logic
        [ "$SERVICE_TYPE" = "PROCD" ] && /etc/init.d/netwatchdta stop >/dev/null 2>&1
        [ "$SERVICE_TYPE" = "SYSTEMD" ] && systemctl stop netwatchdta >/dev/null 2>&1
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
    printf "${BOLD}🏷️  Enter Router/Device Name (e.g., MyRouter): ${NC}"
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
    HB_VAL="NO"; HB_SEC="86400"; HB_TARGET="BOTH"; HB_START_HOUR="12"; HB_START_MIN="00"
    echo -e "\n${BLUE}--- Heartbeat Settings ---${NC}"
    ask_yn "💓 Enable Heartbeat (System check-in)?"
    
    if [ "$ANSWER_YN" = "y" ]; then
        HB_VAL="YES"
        echo -e "${CYAN}   ℹ️  Interval can be in Hours or Minutes.${NC}"
        echo -e "   1. ${BOLD}${WHITE}Hours${NC} (e.g., every 12 hours)"
        echo -e "   2. ${BOLD}${WHITE}Minutes${NC} (e.g., every 30 minutes)"
        ask_opt "   Choice" "2"
        
        if [ "$ANSWER_OPT" = "1" ]; then
            printf "${BOLD}   > Interval in HOURS: ${NC}"
            read val </dev/tty
            HB_SEC=$((val * 3600))
        else
            printf "${BOLD}   > Interval in MINUTES: ${NC}"
            read val </dev/tty
            HB_SEC=$((val * 60))
        fi

        echo -e "${CYAN}   ℹ️  Set Start Time (Alignment Reference)${NC}"
        
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
        
        # Ask for Start Minute
        while :; do
            printf "${BOLD}   > Start Minute (0-59) [Default 00]: ${NC}"
            read HB_START_MIN </dev/tty
            if [ -z "$HB_START_MIN" ]; then HB_START_MIN="00"; break; fi
            if echo "$HB_START_MIN" | grep -qE '^[0-9]+$' && [ "$HB_START_MIN" -ge 0 ] && [ "$HB_START_MIN" -le 59 ]; then
                break
            fi
            echo -e "${RED}   ❌ Invalid minute.${NC}"
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

    # 3g. Summary Display (Vertical List)
    echo -e "\n${BLUE}--- 📋 Configuration Summary ---${NC}"
    echo -e " • Router Name    : ${BOLD}${WHITE}$router_name_input${NC}"
    echo -e " • Discord        : ${BOLD}${WHITE}$DISCORD_ENABLE_VAL${NC}"
    echo -e " • Telegram       : ${BOLD}${WHITE}$TELEGRAM_ENABLE_VAL${NC}"
    echo -e " • Silent Mode    : ${BOLD}${WHITE}$SILENT_ENABLE_VAL${NC}"
    echo -e "     - Start      : $user_silent_start:00"
    echo -e "     - End        : $user_silent_end:00"
    echo -e " • Heartbeat      : ${BOLD}${WHITE}$HB_VAL${NC}"
    echo -e "     - Interval   : ${BOLD}${WHITE}$HB_SEC${NC} seconds"
    echo -e "     - Start Time : ${BOLD}${WHITE}$HB_START_HOUR:$HB_START_MIN${NC}"
    echo -e " • Execution Mode : ${BOLD}${WHITE}$EXEC_MSG${NC}"
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
    
    # Check if the key already exists (start of line, ignoring whitespace)
    if ! grep -q "^[[:space:]]*$key=" "$CONFIG_FILE"; then
        echo -e "${YELLOW}   🔧 Upgrade: Restoring missing parameter '$key' to [$section]...${NC}"
        
        # Check if the section header exists
        if grep -q "\[$section\]" "$CONFIG_FILE"; then
            # Insert the parameter immediately after the section header
            # We use a temp file to ensure safety across all 'sed' versions
            sed "/\[$section\]/a $key=$default_val # Restored by v$SCRIPT_VERSION" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        else
            # If section is missing entirely, append both section and key to the end
            echo -e "\n[$section]" >> "$CONFIG_FILE"
            echo "$key=$default_val # Restored by v$SCRIPT_VERSION" >> "$CONFIG_FILE"
        fi
    fi
}

if [ "$KEEP_CONFIG" -eq 0 ]; then
    # --- SCENARIO A: CLEAN INSTALL (Generate Full File) ---
    
    if [ "$OS_TYPE" = "OPENWRT" ]; then F_TOOL="AUTO"; else F_TOOL="CURL"; fi

    cat <<EOF > "$CONFIG_FILE"
# settings.conf - Configuration for netwatchdta ($OS_TYPE Edition)
# Note: Credentials are stored in .vault.enc (Method: OPENSSL)

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
SILENT_ENABLE=$SILENT_ENABLE_VAL # Mutes Discord alerts during specific hours (YES/NO).
SILENT_START=$user_silent_start # Hour to start silent mode (0-23). Default: 23.
SILENT_END=$user_silent_end # Hour to end silent mode (0-23). Default: 07.

[Discord]
DISCORD_MENTION_LOCAL=YES # Mention on Local Device Down/Up events. Default is YES.
DISCORD_MENTION_REMOTE=YES # Mention on Remote Device Down/Up events. Default is YES.
DISCORD_MENTION_NET=YES # Mention on Internet Connectivity loss/restore. Default is YES.
DISCORD_MENTION_HB=NO # Mention inside Heartbeat reports. Default is NO.

[Performance Settings]
CPU_GUARD_THRESHOLD=2.0 # Max CPU load average allowed before skipping pings. Default is 2.0.
RAM_GUARD_MIN_FREE=4096 # Minimum free RAM in KB required to run alerts. Default is 4096.

[Heartbeat]
HEARTBEAT=$HB_VAL # Periodic I am alive notification (YES/NO).
HB_INTERVAL=$HB_SEC # Seconds between heartbeat messages. Default is 86400.
HB_TARGET=$HB_TARGET # Target for Heartbeat: DISCORD, TELEGRAM, BOTH
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

    # Generate default IP list (CLEAN - NO AUTO DETECT)
    cat <<EOF > "$IP_LIST_FILE"
# Format: IP_ADDRESS @ NAME
# Example: 192.168.1.50 @ Home Server
EOF

    # Generate default Remote IP list
    cat <<EOF > "$REMOTE_LIST_FILE"
# Format: IP_ADDRESS @ NAME
# Example: 142.250.180.206 @ Google Server
# Note: These are ONLY checked if Internet is UP (Strict Dependency).
EOF

else
    # --- SCENARIO B: UPGRADE MODE (Full Self-Healing) ---
    echo -e "${CYAN}♻️  Auditing configuration file for missing parameters...${NC}"
    
    # 1. Log Settings
    patch_param "UPTIME_LOG_MAX_SIZE" "51200" "Log Settings"
    patch_param "PING_LOG_ENABLE" "NO" "Log Settings"

    # 2. Notification Settings
    patch_param "DISCORD_ENABLE" "$DISCORD_ENABLE_VAL" "Notification Settings"
    patch_param "TELEGRAM_ENABLE" "$TELEGRAM_ENABLE_VAL" "Notification Settings"
    patch_param "SILENT_ENABLE" "$SILENT_ENABLE_VAL" "Notification Settings"
    patch_param "SILENT_START" "$user_silent_start" "Notification Settings"
    patch_param "SILENT_END" "$user_silent_end" "Notification Settings"

    # 3. Discord
    patch_param "DISCORD_MENTION_LOCAL" "YES" "Discord"
    patch_param "DISCORD_MENTION_REMOTE" "YES" "Discord"
    patch_param "DISCORD_MENTION_NET" "YES" "Discord"
    patch_param "DISCORD_MENTION_HB" "NO" "Discord"

    # 4. Performance Settings
    patch_param "CPU_GUARD_THRESHOLD" "2.0" "Performance Settings"
    patch_param "RAM_GUARD_MIN_FREE" "4096" "Performance Settings"

    # 5. Heartbeat
    patch_param "HEARTBEAT" "$HB_VAL" "Heartbeat"
    patch_param "HB_INTERVAL" "$HB_SEC" "Heartbeat"
    patch_param "HB_TARGET" "$HB_TARGET" "Heartbeat"
    patch_param "HB_START_HOUR" "$HB_START_HOUR" "Heartbeat"
    patch_param "HB_START_MIN" "$HB_START_MIN" "Heartbeat"

    # 6. Internet Connectivity
    patch_param "EXT_ENABLE" "YES" "Internet Connectivity"
    patch_param "EXT_IP" "1.1.1.1" "Internet Connectivity"
    patch_param "EXT_IP2" "8.8.8.8" "Internet Connectivity"
    patch_param "EXT_SCAN_INTERVAL" "60" "Internet Connectivity"
    patch_param "EXT_FAIL_THRESHOLD" "1" "Internet Connectivity"
    patch_param "EXT_PING_COUNT" "4" "Internet Connectivity"
    patch_param "EXT_PING_TIMEOUT" "5" "Internet Connectivity"

    # 7. Local Device Monitoring
    patch_param "DEVICE_MONITOR" "YES" "Local Device Monitoring"
    patch_param "DEV_SCAN_INTERVAL" "10" "Local Device Monitoring"
    patch_param "DEV_FAIL_THRESHOLD" "2" "Local Device Monitoring"
    patch_param "DEV_PING_COUNT" "2" "Local Device Monitoring"
    patch_param "DEV_PING_TIMEOUT" "1" "Local Device Monitoring"

    # 8. Remote Device Monitoring
    patch_param "REMOTE_MONITOR" "YES" "Remote Device Monitoring"
    patch_param "REM_SCAN_INTERVAL" "30" "Remote Device Monitoring"
    patch_param "REM_FAIL_THRESHOLD" "1" "Remote Device Monitoring"
    patch_param "REM_PING_COUNT" "4" "Remote Device Monitoring"
    patch_param "REM_PING_TIMEOUT" "5" "Remote Device Monitoring"
    
    # 9. Global Variables (Top of file - special handling)
    if ! grep -q "^EXEC_METHOD=" "$CONFIG_FILE"; then
        sed -i "2i EXEC_METHOD=$AUTO_EXEC_METHOD" "$CONFIG_FILE"
        echo -e "${YELLOW}   🔧 Restored missing EXEC_METHOD.${NC}"
    fi
    if ! grep -q "^SCAN_BATCH_SIZE=" "$CONFIG_FILE"; then
        sed -i "3i SCAN_BATCH_SIZE=$AUTO_BATCH_SIZE" "$CONFIG_FILE"
        echo -e "${YELLOW}   🔧 Restored missing SCAN_BATCH_SIZE.${NC}"
    fi
    if ! grep -q "^FETCH_TOOL=" "$CONFIG_FILE"; then
        if [ "$OS_TYPE" = "OPENWRT" ]; then FT="AUTO"; else FT="CURL"; fi
        sed -i "2i FETCH_TOOL=$FT" "$CONFIG_FILE"
        echo -e "${YELLOW}   🔧 Restored missing FETCH_TOOL.${NC}"
    fi
    
    echo -e "${GREEN}✅ Configuration audit complete. File is compliant with v$SCRIPT_VERSION.${NC}"
fi

# ==============================================================================
#  STEP 5: SECURE CREDENTIAL VAULT (OPENSSL ENFORCED)
# ==============================================================================
echo -e "\n${CYAN}🔐 Securing credentials (OpenSSL AES-256)...${NC}"

# Function: get_hw_key (ROBUST FIX)
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
echo -e "\n${CYAN}🛠️  Generating core script ($OS_TYPE Mode)...${NC}"

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
VAULT_FILE="\$BASE_DIR/.vault.enc"

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

# --- HELPER: HW KEY GENERATION (ROBUST) ---
get_hw_key() {
    local seed="nwdta_v1_secure_seed_2025"
    if [ -f /proc/cpuinfo ]; then 
        local cpu_serial=\$(grep -i "serial" /proc/cpuinfo | head -1 | awk -F: '{print \$2}' | tr -d ' ')
        [ -z "\$cpu_serial" ] && cpu_serial="unknown_serial"
    else 
        cpu_serial="generic_linux_machine"
    fi
    local mac_addr=\$(cat /sys/class/net/*/address 2>/dev/null | grep -v "00:00" | head -1)
    echo -n "\${seed}\${cpu_serial}\${mac_addr}" | openssl dgst -sha256 | awk '{print \$2}'
}

# --- HELPER: CREDENTIAL DECRYPTION ---
load_credentials() {
    if [ -f "\$VAULT_FILE" ]; then
        local key=\$(get_hw_key)
        local decrypted=\$(openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -iter 10000 -k "\$key" -in "\$VAULT_FILE" 2>/dev/null)
        if [ -n "\$decrypted" ]; then
            decrypted=\$(echo "\$decrypted" | tr -d '\r')
            export DISCORD_WEBHOOK="\${decrypted%%|*}"
            local temp1="\${decrypted#*|}"
            export DISCORD_USERID="\${temp1%%|*}"
            local temp2="\${temp1#*|}"
            export TELEGRAM_BOT_TOKEN="\${temp2%%|*}"
            export TELEGRAM_CHAT_ID="\${temp2#*|}"
            return 0
        fi
    fi
    return 1
}

# ==============================================================================
#  PORTABLE FETCH WRAPPER (CORE ENGINE VERSION)
# ==============================================================================
# Includes Toggle Support, Auto-Priority, and Discord 204 Fix
safe_fetch() {
    local url="\$1"
    local data="\$2"
    local header="\$3"

    # --- 1. CHECK FORCED TOOL ---
    if [ "\$FETCH_TOOL" = "CURL" ] && command -v curl >/dev/null 2>&1; then
        curl -s -k -X POST -H "\$header" -d "\$data" "\$url" >/dev/null 2>&1
        return 0
    fi
    if [ "\$FETCH_TOOL" = "UCLIENT" ] && (command -v uclient-fetch >/dev/null 2>&1 || [ -x /bin/uclient-fetch ]); then
        uclient-fetch --no-check-certificate --header="\$header" --post-data="\$data" "\$url" -O /dev/null >/dev/null 2>&1
        return 0
    fi
    if [ "\$FETCH_TOOL" = "WGET" ] && command -v wget >/dev/null 2>&1; then
        wget -q --no-check-certificate --header="\$header" --post-data="\$data" "\$url" -O /dev/null
        return 0
    fi

    # --- 2. AUTO PRIORITY (OS Aware) ---
    if [ "$OS_TYPE" = "OPENWRT" ]; then
        # Priority A: uclient-fetch (Lightweight)
        if command -v uclient-fetch >/dev/null 2>&1 || [ -x /bin/uclient-fetch ]; then
            uclient-fetch --no-check-certificate --header="\$header" --post-data="\$data" "\$url" -O /dev/null >/dev/null 2>&1
            return 0 # Force success for Discord 204 bug
        fi
    fi

    # Priority B: Curl (Robust)
    if command -v curl >/dev/null 2>&1; then
        curl -s -k -X POST -H "\$header" -d "\$data" "\$url" >/dev/null 2>&1
        return 0
    fi

    # Priority C: Wget (Fallback)
    if command -v wget >/dev/null 2>&1; then
        wget -q --no-check-certificate --header="\$header" --post-data="\$data" "\$url" -O /dev/null
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
        if [ -z "\$filter" ] || [ "\$filter" = "BOTH" ] || [ "\$filter" = "DISCORD" ]; then
             local json_desc=\$(echo "\$desc" | awk '{printf "%s\\\\n", \$0}' | sed 's/\\\\n$//')
             local d_payload
             if [ "\$mention" = "YES" ] && [ -n "\$DISCORD_USERID" ]; then
                d_payload="{\"content\": \"<@\$DISCORD_USERID>\", \"embeds\": [{\"title\": \"\$title\", \"description\": \"\$json_desc\", \"color\": \$color}]}"
             else
                d_payload="{\"embeds\": [{\"title\": \"\$title\", \"description\": \"\$json_desc\", \"color\": \$color}]}"
             fi
             
             if safe_fetch "\$DISCORD_WEBHOOK" "\$d_payload" "Content-Type: application/json"; then 
                 success=1
             else 
                 # Explicit Error Suppression for uclient-fetch (Double Safety)
                 if [ "$OS_TYPE" = "OPENWRT" ] && (command -v uclient-fetch >/dev/null 2>&1 || [ -x /bin/uclient-fetch ]) && [ "\$FETCH_TOOL" != "CURL" ]; then 
                     success=1
                 else
                     log_msg "[ERROR] Discord send failed." "UPTIME" "\$NOW_HUMAN"
                 fi
             fi
        fi
    fi

    # 2. TELEGRAM
    if [ "\$TELEGRAM_ENABLE" = "YES" ] && [ -n "\$TELEGRAM_BOT_TOKEN" ] && [ -n "\$TELEGRAM_CHAT_ID" ]; then
        if [ -z "\$filter" ] || [ "\$filter" = "BOTH" ] || [ "\$filter" = "TELEGRAM" ]; then
             local t_msg="\$title\n\$desc"; [ -n "\$telegram_text" ] && t_msg="\$telegram_text"
             local t_safe=\$(echo "\$t_msg" | sed 's/"/\\\\"/g' | awk '{printf "%s\\\\n", \$0}')
             if safe_fetch "https://api.telegram.org/bot\$TELEGRAM_BOT_TOKEN/sendMessage" "{\"chat_id\": \"\$TELEGRAM_CHAT_ID\", \"text\": \"\$t_safe\"}" "Content-Type: application/json"; then success=1; else log_msg "[ERROR] Telegram send failed." "UPTIME" "\$NOW_HUMAN"; fi
        fi
    fi
    return \$((1 - success))
}
EOF
chmod +x "$INSTALL_DIR/netwatchdta.sh"
cat <<'EOF' >> "$INSTALL_DIR/netwatchdta.sh"

# --- HELPER: NOTIFICATION SENDER (WITH LOW-RAM LOCK) ---
send_notification() {
    local title="$1"; local desc="$2"; local color="$3"; local type="$4"; local filter="$5"; local force="$6"; local tel_text="$7"; local mention="$8"
    
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
    if [ "$EXEC_METHOD" -eq 2 ]; then
        local w_count=0
        while ! mkdir "/tmp/nwdta.lock" 2>/dev/null; do
            sleep 1
            w_count=$((w_count + 1))
            if [ "$w_count" -ge 20 ]; then break; fi # Prevent infinite hang
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
    if [ "$EXEC_METHOD" -eq 2 ]; then
        rmdir "/tmp/nwdta.lock" 2>/dev/null
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

# --- SHARED CHECK FUNCTION (AUTO-TIMEOUT) ---
check_ip_logic() {
    local TIP="$1"; local NAME="$2"; local TYPE="$3"; local THRESH="${4:-3}"; local P_COUNT="${5:-1}"; local TO="$6"
    [ "$TO" -le "$P_COUNT" ] && TO=$((P_COUNT + 1))
    
    local SAFE_IP=$(echo "$TIP" | tr '.' '_')
    local FD="$TMP_DIR/${TYPE}_${SAFE_IP}_d"; local FC="$TMP_DIR/${TYPE}_${SAFE_IP}_c"; local FT="$TMP_DIR/${TYPE}_${SAFE_IP}_t"
    local M_FLAG="NO"; [ "$TYPE" = "Device" ] && M_FLAG="$DISCORD_MENTION_LOCAL"; [ "$TYPE" = "Remote" ] && M_FLAG="$DISCORD_MENTION_REMOTE"
    
    if ping -q -c "$P_COUNT" -w "$TO" "$TIP" >/dev/null 2>&1; then
        if [ -f "$FD" ]; then
            read DSTART < "$FT"; read DSSEC < "$FD"
            local DUR=$(( NOW_SEC - DSSEC )); local DR_STR="$((DUR/60))m $((DUR%60))s"
            
            # -- CUSTOMIZE SUCCESS MESSAGES HERE --
            local D_MSG="**Router:** $ROUTER_NAME\n**${TYPE}:** $NAME ($TIP)\n**Down at:** $DSTART\n**Outage:** $DR_STR"
            local T_MSG="🟢 ${TYPE} UP* $ROUTER_NAME - $NAME - $TIP - $NOW_HUMAN - Downtime: $DR_STR"
            log_msg "[SUCCESS] ${TYPE}: $NAME Online - Downtime: $DR_STR)" "UPTIME" "$NOW_HUMAN"
            
            if [ "$IS_SILENT" -eq 1 ]; then
                 [ -f "$SILENT_BUFFER" ] && [ $(wc -c < "$SILENT_BUFFER") -lt 5120 ] && echo "${TYPE} $NAME UP: $NOW_HUMAN (Down $DR_STR)" >> "$SILENT_BUFFER"
            else
                 send_notification "🟢 ${TYPE} Online" "$D_MSG" "3066993" "SUCCESS" "BOTH" "NO" "$T_MSG" "$M_FLAG"
            fi
            rm -f "$FD" "$FT"
        fi
        echo 0 > "$FC"
    else
        local C=0; [ -f "$FC" ] && read C < "$FC"; C=$((C+1)); echo "$C" > "$FC"
        if [ "$C" -ge "$THRESH" ] && [ ! -f "$FD" ]; then
             echo "$NOW_SEC" > "$FD"; echo "$NOW_HUMAN" > "$FT"
             
             # -- CUSTOMIZE ALERT MESSAGES HERE --
             local D_MSG="**Router:** $ROUTER_NAME\n**${TYPE}:** $NAME ($TIP)\n**Time:** $NOW_HUMAN"
             local T_MSG="🔴 ${TYPE} Down * $ROUTER_NAME - $NAME - $TIP - $NOW_HUMAN"
             log_msg "[ALERT] ${TYPE}: $NAME Down" "UPTIME" "$NOW_HUMAN"
             
             if [ "$IS_SILENT" -eq 1 ]; then
                 [ -f "$SILENT_BUFFER" ] && [ $(wc -c < "$SILENT_BUFFER") -lt 5120 ] && echo "${TYPE} $NAME DOWN: $NOW_HUMAN" >> "$SILENT_BUFFER"
             else
                 send_notification "🔴 ${TYPE} Down" "$D_MSG" "15548997" "ALERT" "BOTH" "NO" "$T_MSG" "$M_FLAG"
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
    h=${h#0}; m=${m#0}; s=${s#0}
    
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
load_config; load_credentials
if [ $? -eq 0 ]; then log_msg "[SYSTEM] Credentials loaded." "UPTIME" "$(date '+%b %d %H:%M:%S')"; else log_msg "[WARNING] Vault error or missing." "UPTIME" "$(date '+%b %d %H:%M:%S')"; fi

# Initialize Heartbeat Alignment
[ "$HEARTBEAT" = "YES" ] && align_heartbeat

# --- MAIN LOGIC LOOP ---
while true; do
    load_config
    NOW_HUMAN=$(date '+%b %d %H:%M:%S'); NOW_SEC=$(date +%s); CUR_HOUR=$(date +%H)
    
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
    CPU_LOAD=$(cat /proc/loadavg | awk '{print $1}'); CPU_LOAD=${CPU_LOAD:-0.00}
    
    if awk "BEGIN {exit !($CPU_LOAD > $CPU_GUARD_THRESHOLD)}"; then log_msg "[SYSTEM] High Load ($CPU_LOAD). Skipping." "UPTIME" "$NOW_HUMAN"; sleep 10; continue; fi

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
            
            send_notification "💓 Heartbeat Report" "**Router:** $ROUTER_NAME\n**Status:** Operational\n**Time:** $NOW_HUMAN" "1752220" "INFO" "${HB_TARGET:-BOTH}" "NO" "💓 Heartbeat - $ROUTER_NAME - $NOW_HUMAN" "$DISCORD_MENTION_HB"
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
        S_CONTENT=$(cat "$SILENT_BUFFER"); CLEAN_S=$(echo "$S_CONTENT" | sed ':a;N;$!ba;s/\n/\\n/g')
        send_notification "🌙 Silent Hours Summary" "**Router:** $ROUTER_NAME\n$CLEAN_S" "10181046" "SUMMARY" "BOTH" "NO" "🌙 Silent Hours Summary - $ROUTER_NAME\n$S_CONTENT" "NO"
        > "$SILENT_BUFFER"
        log_msg "[SYSTEM] Silent buffer dumped." "UPTIME" "$NOW_HUMAN"
    fi

    # 3. INTERNET MONITOR
    if [ "$EXT_ENABLE" = "YES" ]; then
        if [ $((NOW_SEC - LAST_EXT_CHECK)) -ge "$EXT_SCAN_INTERVAL" ]; then
            LAST_EXT_CHECK=$NOW_SEC; FD="$TMP_DIR/nwdta_ext_d"; FT="$TMP_DIR/nwdta_ext_t"; FC="$TMP_DIR/nwdta_ext_c"
            TO="${EXT_PING_TIMEOUT:-1}"; [ "$TO" -le "$EXT_PING_COUNT" ] && TO=$((EXT_PING_COUNT + 1))
            
            EXT_UP=0
            if [ -n "$EXT_IP" ] && ping -q -c "$EXT_PING_COUNT" -w "$TO" "$EXT_IP" > /dev/null 2>&1; then EXT_UP=1;
            elif [ -n "$EXT_IP2" ] && ping -q -c "$EXT_PING_COUNT" -w "$TO" "$EXT_IP2" > /dev/null 2>&1; then EXT_UP=1; fi
            EXT_UP_GLOBAL=$EXT_UP

            if [ "$EXT_UP" -eq 0 ]; then
                C=0; [ -f "$FC" ] && read C < "$FC"; C=$((C+1)); echo "$C" > "$FC"
                if [ "$C" -ge "$EXT_FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                    echo "$NOW_SEC" > "$FD"; echo "$NOW_HUMAN" > "$FT"; echo "DOWN" > "$NET_STATUS_FILE"
                    log_msg "[ALERT] INTERNET DOWN" "UPTIME" "$NOW_HUMAN"
                    [ "$IS_SILENT" -ne 0 ] && echo "Internet Down: $NOW_HUMAN" >> "$SILENT_BUFFER"
                fi
            else
                if [ -f "$FD" ]; then
                    echo "UP" > "$NET_STATUS_FILE"
                    read START_TIME < "$FT"; read START_SEC < "$FD"
                    DUR=$((NOW_SEC - START_SEC)); DR="$((DUR/60))m $((DUR%60))s"
                    MSG_D="**Router:** $ROUTER_NAME\n**Down at:** $START_TIME\n**Up at:** $NOW_HUMAN\n**Total Outage:** $DR"
                    MSG_T="🟢 Connectivity Restored * $ROUTER_NAME - Down time: $START_TIME - UP time: $NOW_HUMAN - Duration: $DR"
                    log_msg "[SUCCESS] INTERNET UP - Downtime: $DR" "UPTIME" "$NOW_HUMAN"
                    if [ "$IS_SILENT" -eq 0 ]; then
                        send_notification "🟢 Connectivity Restored" "$MSG_D" "3066993" "SUCCESS" "BOTH" "YES" "$MSG_T" "$DISCORD_MENTION_NET"
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
    else EXT_UP_GLOBAL=1; fi

    # --- DYNAMIC BATCH CONFIGURATION (V1.3.9 UPDATE) ---
    # Calculates how many devices to ping in parallel based on RAM
    BATCH_LIMIT=50 # Hard cap default
    
    if [ "$SCAN_BATCH_SIZE" = "0" ] || [ -z "$SCAN_BATCH_SIZE" ]; then
        BATCH_LIMIT=999 # Effectively unlimited (Full Parallel)
    elif [ "$SCAN_BATCH_SIZE" = "AUTO" ]; then
        # Safety Net: Reserve 10% of Total RAM
        SAFETY_MARGIN=$((TOTAL_RAM_KB / 10))
        USABLE_FREE=$((CUR_FREE_RAM - SAFETY_MARGIN))
        
        if [ "$USABLE_FREE" -le 0 ]; then
             BATCH_LIMIT=1 # Critical mode: 1 by 1
        else
             # Rule: Use remaining RAM for scanning. Approx 4000KB per ping process.
             BATCH_LIMIT=$((USABLE_FREE / 4000)) 
        fi
        
        # Clamp Values
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
                line=$(echo "$line" | tr -d '\r'); IP="${line%%@*}"; IP="${IP%% }"; IP="${IP## }"; NAME="${line#*@}"; NAME="${NAME## }"; [ "$NAME" = "$line" ] && NAME="$IP"
                
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
                line=$(echo "$line" | tr -d '\r'); IP="${line%%@*}"; IP="${IP%% }"; IP="${IP## }"; NAME="${line#*@}"; NAME="${NAME## }"; [ "$NAME" = "$line" ] && NAME="$IP"
                
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
echo -e "\n${CYAN}⚙️  Configuring system service ($SERVICE_TYPE)...${NC}"

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
extra_command "credentials" "Update Discord/Telegram credentials"
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
        echo -e "\033[1;32m● netwatchdta is RUNNING.\033[0m (v\$v)"
        echo "   PID: \$(pgrep -f "netwatchdta.sh" | head -1)"
    else
        echo -e "\033[1;31m● netwatchdta is STOPPED.\033[0m (v\$v)"
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

edit() {
    echo ""
    echo -e "\033[1;36m📝 Configuration Editor\033[0m"
    
    local editor="vi"
    if command -v nano >/dev/null 2>&1; then editor="nano"; fi
    
    while true; do
        echo "1. Edit Settings (settings.conf)"
        echo "2. Edit Device IPs (device_ips.conf)"
        echo "3. Edit Remote IPs (remote_ips.conf)"
        echo "4. Exit"
        printf "\033[1mChoice [1-4]: \033[0m"
        read choice </dev/tty
        case "\$choice" in
            1) \$editor "$INSTALL_DIR/settings.conf"; break ;;
            2) \$editor "$INSTALL_DIR/device_ips.conf"; break ;;
            3) \$editor "$INSTALL_DIR/remote_ips.conf"; break ;;
            4) echo "Cancelled."; exit 0 ;;
            *) echo "Invalid choice." ;;
        esac
    done
    echo ""
    echo -e "\033[1;33m⚠️  If you made changes, run: /etc/init.d/netwatchdta restart\033[0m"
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

load_functions() {
    if [ -f "$INSTALL_DIR/netwatchdta.sh" ]; then
        eval "\$(sed '/^\[.*\]/d' "$INSTALL_DIR/settings.conf" | sed 's/[ \t]*#.*//' | sed 's/[ \t]*$//' | tr -d '\r')"
    fi
}

get_hw_key() {
    local seed="nwdta_v1_secure_seed_2025"
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
    local current=\$(get_decrypted_creds); current=\$(echo "\$current" | tr -d '\r')
    local d_hook=\$(echo "\$current" | cut -d'|' -f1); local d_uid=\$(echo "\$current" | cut -d'|' -f2); local t_tok=\$(echo "\$current" | cut -d'|' -f3); local t_chat=\$(echo "\$current" | cut -d'|' -f4)
    if [ "\$c_choice" = "1" ] || [ "\$c_choice" = "3" ]; then printf "New Discord Webhook: "; read d_hook </dev/tty; printf "New Discord User ID: "; read d_uid </dev/tty; fi
    if [ "\$c_choice" = "2" ] || [ "\$c_choice" = "3" ]; then printf "New Telegram Token: "; read t_tok </dev/tty; printf "New Telegram Chat ID: "; read t_chat </dev/tty; fi
    local new_data="\${d_hook}|\${d_uid}|\${t_tok}|\${t_chat}"; local vault="$INSTALL_DIR/.vault.enc"; local key=\$(get_hw_key)
    if echo -n "\$new_data" | openssl enc -aes-256-cbc -a -salt -pbkdf2 -iter 10000 -k "\$key" -out "\$vault" 2>/dev/null; then echo -e "\033[1;32m✅ Credentials updated.\033[0m"; /etc/init.d/netwatchdta restart; else echo -e "\033[1;31m❌ Encryption failed.\033[0m"; fi
}
EOF
    chmod +x "$SERVICE_PATH"
    "$SERVICE_PATH" enable >/dev/null 2>&1
    "$SERVICE_PATH" start >/dev/null 2>&1

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
    systemctl start netwatchdta

    # --- LINUX CLI WRAPPER (Updated with Functions for Local Fix) ---
    CLI_PATH="/usr/local/bin/netwatchdta"
    cat <<EOF > "$CLI_PATH"
#!/bin/sh
# CLI Wrapper for netwatchdta on Linux
INSTALL_DIR="$INSTALL_DIR"
CONF="\$INSTALL_DIR/settings.conf"

# --- HELPER FUNCTIONS FOR LINUX CLI ---
load_functions() {
    if [ -f "\$INSTALL_DIR/netwatchdta.sh" ]; then
        eval "\$(sed '/^\[.*\]/d' "\$INSTALL_DIR/settings.conf" | sed 's/[ \t]*#.*//' | sed 's/[ \t]*$//' | tr -d '\r')"
    fi
}
get_hw_key() {
    local seed="nwdta_v1_secure_seed_2025"
    if [ -f /proc/cpuinfo ]; then 
        local cpu_serial=\$(grep -i "serial" /proc/cpuinfo | head -1 | awk -F: '{print \$2}' | tr -d ' ')
        [ -z "\$cpu_serial" ] && cpu_serial="unknown_serial"
    else 
        cpu_serial="generic_linux_machine"
    fi
    local mac_addr=\$(cat /sys/class/net/*/address 2>/dev/null | grep -v "00:00" | head -1)
    echo -n "\${seed}\${cpu_serial}\${mac_addr}" | openssl dgst -sha256 | awk '{print \$2}'
}
get_decrypted_creds() {
    local vault="\$INSTALL_DIR/.vault.enc"
    if [ ! -f "\$vault" ]; then return 1; fi
    local key=\$(get_hw_key)
    openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -iter 10000 -k "\$key" -in "\$vault" 2>/dev/null
}

run_discord_test() {
    load_functions
    local decrypted=\$(get_decrypted_creds)
    decrypted=\$(echo "\$decrypted" | tr -d '\r')
    local webhook=\$(echo "\$decrypted" | cut -d'|' -f1)
    if [ -n "\$webhook" ]; then
        echo "Sending Discord test..."
        curl -s -k -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🛠️ Discord Warning Test\", \"description\": \"**Router:** \$ROUTER_NAME\nManual warning triggered.\", \"color\": 16776960}]}" "\$webhook" >/dev/null 2>&1
        echo "Sent."
    else
        echo "No Discord Webhook configured or vault locked."
    fi
}

run_telegram_test() {
    load_functions
    local decrypted=\$(get_decrypted_creds)
    decrypted=\$(echo "\$decrypted" | tr -d '\r')
    local token=\$(echo "\$decrypted" | cut -d'|' -f3)
    local chat=\$(echo "\$decrypted" | cut -d'|' -f4)
    if [ -n "\$token" ]; then
        echo "Sending Telegram test..."
        curl -s -k -X POST "https://api.telegram.org/bot\$token/sendMessage" -d chat_id="\$chat" -d text="🛠️ Telegram Warning Test - \$ROUTER_NAME" >/dev/null 2>&1
        echo "Sent."
    else
        echo "No Telegram Token configured or vault locked."
    fi
}

run_credentials_update() {
    echo ""
    echo -e "\033[1;33m🔐 Credential Manager\033[0m"
    echo "1. Change Discord Credentials"
    echo "2. Change Telegram Credentials"
    echo "3. Change Both"
    printf "Choice [1-3]: "
    read c_choice </dev/tty
    
    load_functions
    local current=\$(get_decrypted_creds); current=\$(echo "\$current" | tr -d '\r')
    local d_hook=\$(echo "\$current" | cut -d'|' -f1); local d_uid=\$(echo "\$current" | cut -d'|' -f2); local t_tok=\$(echo "\$current" | cut -d'|' -f3); local t_chat=\$(echo "\$current" | cut -d'|' -f4)
    if [ "\$c_choice" = "1" ] || [ "\$c_choice" = "3" ]; then printf "New Discord Webhook: "; read d_hook </dev/tty; printf "New Discord User ID: "; read d_uid </dev/tty; fi
    if [ "\$c_choice" = "2" ] || [ "\$c_choice" = "3" ]; then printf "New Telegram Token: "; read t_tok </dev/tty; printf "New Telegram Chat ID: "; read t_chat </dev/tty; fi
    local new_data="\${d_hook}|\${d_uid}|\${t_tok}|\${t_chat}"; local vault="\$INSTALL_DIR/.vault.enc"; local key=\$(get_hw_key)
    if echo -n "\$new_data" | openssl enc -aes-256-cbc -a -salt -pbkdf2 -iter 10000 -k "\$key" -out "\$vault" 2>/dev/null; then echo -e "\033[1;32m✅ Credentials updated.\033[0m"; systemctl restart netwatchdta; else echo -e "\033[1;31m❌ Encryption failed.\033[0m"; fi
}

case "\$1" in
    start) systemctl start netwatchdta; echo "Started." ;;
    stop) systemctl stop netwatchdta; echo "Stopped." ;;
    restart) systemctl restart netwatchdta; echo "Restarted." ;;
    status|check) 
        local v=\$(grep "^VERSION=" "$INSTALL_DIR/netwatchdta.sh" | cut -d'"' -f2)
        if systemctl is-active --quiet netwatchdta; then
            echo -e "\033[1;32m● netwatchdta is RUNNING.\033[0m (v\$v)"
        else
            echo -e "\033[1;31m● netwatchdta is STOPPED.\033[0m (v\$v)"
        fi
        systemctl status netwatchdta --no-pager | head -n 5
        ;;
    logs) tail -n 30 /tmp/netwatchdta/nwdta_uptime.log ;;
    clear)
        echo "\$(date '+%b %d %H:%M:%S') - [SYSTEM] Log cleared manually." > "/tmp/netwatchdta/nwdta_uptime.log"
        echo "Log file cleared."
        ;;
    edit) 
        echo ""
        echo -e "\033[1;36m📝 Configuration Editor\033[0m"
        while true; do
            echo "1. Edit Settings (settings.conf)"
            echo "2. Edit Device IPs (device_ips.conf)"
            echo "3. Edit Remote IPs (remote_ips.conf)"
            echo "4. Exit"
            printf "\033[1mChoice [1-4]: \033[0m"
            read choice </dev/tty
            case "\$choice" in
                1) nano "\$INSTALL_DIR/settings.conf"; break ;;
                2) nano "\$INSTALL_DIR/device_ips.conf"; break ;;
                3) nano "\$INSTALL_DIR/remote_ips.conf"; break ;;
                4) echo "Cancelled."; exit 0 ;;
                *) echo "Invalid choice." ;;
            esac
        done
        echo ""
        echo -e "\033[1;33m⚠️  If you made changes, run: netwatchdta restart\033[0m"
        ;;
    discord) run_discord_test ;;
    telegram) run_telegram_test ;;
    credentials) run_credentials_update ;;
    purge) 
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
                systemctl stop netwatchdta; systemctl disable netwatchdta
                echo -e "\033[1;33m🧹 Cleaning up /tmp and files...\033[0m"
                rm -rf "/tmp/netwatchdta"
                rm -rf "\$INSTALL_DIR"
                echo -e "\033[1;33m🔥 Removing service...\033[0m"
                rm -f /etc/systemd/system/netwatchdta.service /usr/local/bin/netwatchdta
                systemctl daemon-reload
                echo ""
                echo -e "\033[1;32m✅ netwatchdta has been completely removed.\033[0m"
                ;;
            2)
                echo ""
                echo -e "\033[1;33m🛑 Stopping service...\033[0m"
                systemctl stop netwatchdta; systemctl disable netwatchdta
                echo -e "\033[1;33m🧹 Cleaning up /tmp...\033[0m"
                rm -rf "/tmp/netwatchdta"
                echo -e "\033[1;33m🗑️  Removing core script...\033[0m"
                rm -f "\$INSTALL_DIR/netwatchdta.sh"
                echo -e "\033[1;33m🔥 Removing service file...\033[0m"
                rm -f /etc/systemd/system/netwatchdta.service /usr/local/bin/netwatchdta
                systemctl daemon-reload
                echo ""
                echo -e "\033[1;32m✅ Logic removed. Settings preserved in \$INSTALL_DIR\033[0m"
                ;;
            *)
                echo -e "\033[1;31m❌ Purge cancelled.\033[0m"
                exit 0
                ;;
        esac
        ;;
    *) echo "Usage: netwatchdta {start|stop|restart|status|logs|clear|discord|telegram|credentials|edit|purge}" ;;
esac
EOF
    chmod +x "$CLI_PATH"
    echo -e "${GREEN}✅ CLI Command installed: 'netwatchdta'${NC}"
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

echo -e "\n${GREEN}=======================================================${NC}"
echo -e "${BOLD}${GREEN}✅ Installation complete!${NC}"
echo -e "${CYAN}📂 Folder :${NC} $INSTALL_DIR"
echo -e "${CYAN}⚙️  Service:${NC} $STATUS"
echo -e "${GREEN}=======================================================${NC}"
echo -e "\n${BOLD}Quick Commands:${NC}"
if [ "$SERVICE_TYPE" = "PROCD" ]; then
    echo -e "  Status           : ${YELLOW}/etc/init.d/netwatchdta check${NC}"
    echo -e "  Logs             : ${YELLOW}/etc/init.d/netwatchdta logs${NC}"
    echo -e "  Uninstall        : ${RED}/etc/init.d/netwatchdta purge${NC}"
    echo -e "  Edit Settings    : ${YELLOW}/etc/init.d/netwatchdta edit${NC}"
    echo -e "  Restart          : ${YELLOW}/etc/init.d/netwatchdta restart${NC}"
else
    echo -e "  Status           : ${YELLOW}netwatchdta check${NC}"
    echo -e "  Logs             : ${YELLOW}netwatchdta logs${NC}"
    echo -e "  Uninstall        : ${RED}netwatchdta purge${NC}"
    echo -e "  Edit Settings    : ${YELLOW}netwatchdta edit${NC}"
    echo -e "  Restart          : ${YELLOW}netwatchdta restart${NC}"
fi
echo ""