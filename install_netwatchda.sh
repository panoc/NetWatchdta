#!/bin/sh
# netwatchda Installer - Automated Setup for OpenWrt (Turbo Edition)
# Copyright (C) 2025 panoc
# Licensed under the GNU General Public License v3.0

# Cleanup Trap
SCRIPT_NAME="$0"
cleanup() { rm -f "$SCRIPT_NAME"; exit; }
trap cleanup INT TERM EXIT

# Colors
NC='\033[0m'; BOLD='\033[1m'; RED='\033[1;31m'; GREEN='\033[1;32m'
BLUE='\033[1;34m'; CYAN='\033[1;36m'; YELLOW='\033[1;33m'; WHITE='\033[1;37m'

# Helpers
ask_yn() {
    local prompt="$1"
    while true; do
        printf "${BOLD}%s [y/n]: ${NC}" "$prompt"
        read input_val </dev/tty
        case "$input_val" in y|Y) ANSWER_YN="y"; return 0;; n|N) ANSWER_YN="n"; return 1;; esac
    done
}
ask_opt() {
    local prompt="$1"; local max="$2"
    while true; do
        printf "${BOLD}%s [1-%s]: ${NC}" "$prompt" "$max"
        read input_val </dev/tty
        if echo "$input_val" | grep -qE "^[1-$max]$"; then ANSWER_OPT="$input_val"; break; fi
    done
}

# Header
echo -e "${BLUE}=======================================================${NC}"
echo -e "${BOLD}${CYAN}🚀 netwatchda Optimized Setup${NC} (by ${BOLD}panoc${NC})"
echo -e "${BLUE}⚖️  License: GNU GPLv3${NC}"
echo -e "${BLUE}=======================================================${NC}"
echo ""

ask_yn "❓ Begin installation *************V10?"
[ "$ANSWER_YN" = "n" ] && exit 0

# Paths
INSTALL_DIR="/root/netwatchda"
TMP_DIR="/tmp/netwatchda"
CONFIG_FILE="$INSTALL_DIR/nwda_settings.conf"
IP_LIST_FILE="$INSTALL_DIR/nwda_ips.conf"
VAULT_FILE="$INSTALL_DIR/.vault.enc"
SERVICE_NAME="netwatchda"
SERVICE_PATH="/etc/init.d/$SERVICE_NAME"
mkdir -p "$TMP_DIR"

# Security Choice
echo -e "\n${BLUE}--- Security Preferences ---${NC}"
echo -e "${BOLD}${WHITE}1.${NC} OpenSSL (High Security) - ${GREEN}AES-256 Encrypted${NC}"
echo -e "${BOLD}${WHITE}2.${NC} Base64 (Low Security) - ${YELLOW}Fast & Low RAM${NC}"
ask_opt "Select Method" "2"
if [ "$ANSWER_OPT" = "1" ]; then ENCRYPTION_METHOD="OPENSSL"; else ENCRYPTION_METHOD="BASE64"; fi

# Checks
echo -e "\n${BOLD}📦 Checking system readiness...${NC}"
FREE_FLASH_KB=$(df / | awk 'NR==2 {print $4}')
FREE_RAM_KB=$(df /tmp | awk 'NR==2 {print $4}')
MISSING_DEPS=""
command -v curl >/dev/null 2>&1 || MISSING_DEPS="$MISSING_DEPS curl"
[ -f /etc/ssl/certs/ca-certificates.crt ] || command -v opkg >/dev/null && opkg list-installed | grep -q ca-bundle || MISSING_DEPS="$MISSING_DEPS ca-bundle"
[ "$ENCRYPTION_METHOD" = "OPENSSL" ] && { command -v openssl >/dev/null 2>&1 || MISSING_DEPS="$MISSING_DEPS openssl-util"; }

[ "$FREE_RAM_KB" -lt 4096 ] && { echo -e "${RED}❌ Low RAM!${NC}"; exit 1; }

if [ -n "$MISSING_DEPS" ]; then
    echo -e "${CYAN}Missing:${BOLD}$MISSING_DEPS${NC}"
    [ "$FREE_FLASH_KB" -lt 3072 ] && { echo -e "${RED}❌ Low Flash!${NC}"; exit 1; }
    ask_yn "❓ Install dependencies?"
    if [ "$ANSWER_YN" = "y" ]; then
        opkg update --no-check-certificate >/dev/null 2>&1
        opkg install --no-check-certificate $MISSING_DEPS >/tmp/nwda_inst.log 2>&1 || { cat /tmp/nwda_inst.log; exit 1; }
        echo -e "${GREEN}✅ Installed.${NC}"
    else exit 1; fi
else echo -e "${GREEN}✅ System Ready.${NC}"; fi

# Upgrade/Install
KEEP_CONFIG=0
if [ -f "$CONFIG_FILE" ]; then
    echo -e "\n${YELLOW}⚠️  Found existing install.${NC}"
    echo -e "1. Upgrade (Keep Settings)\n2. Clean Install"
    ask_opt "Choice" "2"
    [ "$ANSWER_OPT" = "1" ] && KEEP_CONFIG=1 || { /etc/init.d/netwatchda stop 2>/dev/null; rm -rf "$INSTALL_DIR"; }
fi
mkdir -p "$INSTALL_DIR"
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
    D_HOOK=""
    D_UID=""
    
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
        read D_HOOK </dev/tty
        printf "${BOLD}   > Enter Discord User ID (for @mentions): ${NC}"
        read D_UID </dev/tty
        
        # Test Loop
        ask_yn "   ❓ Send test notification to Discord now?"
        if [ "$ANSWER_YN" = "y" ]; then
             echo -e "${YELLOW}   🧪 Sending Discord test...${NC}"
             curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🧪 Setup Test\", \"description\": \"Discord configured successfully for **$router_name_input**.\", \"color\": 1752220}]}" "$D_HOOK"
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
                     D_HOOK=""
                     D_UID=""
                     break
                 fi
             fi
        else
            break
        fi
    done

    # 4c. Telegram Setup Loop
    TELEGRAM_ENABLE_VAL="NO"
    T_TOK=""
    T_CHAT=""
    
    while :; do
        ask_yn "2. Enable Telegram Notifications?"
        if [ "$ANSWER_YN" = "n" ]; then
            TELEGRAM_ENABLE_VAL="NO"
            break
        fi
        
        # User said YES
        TELEGRAM_ENABLE_VAL="YES"
        printf "${BOLD}   > Enter Telegram Bot Token: ${NC}"
        read T_TOK </dev/tty
        printf "${BOLD}   > Enter Telegram Chat ID: ${NC}"
        read T_CHAT </dev/tty
        
        # Test Loop
        ask_yn "   ❓ Send test notification to Telegram now?"
        if [ "$ANSWER_YN" = "y" ]; then
            echo -e "${YELLOW}   🧪 Sending Telegram test...${NC}"
            curl -s -X POST "https://api.telegram.org/bot$T_TOK/sendMessage" -d chat_id="$T_CHAT" -d text="🧪 Setup Test - Telegram configured successfully for $router_name_input." >/dev/null 2>&1
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
                    T_TOK=""
                    T_CHAT=""
                    break
                fi
            fi
        else
            break
        fi
    done
    
    # 4d. Summary Display
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

    # 4e. Silent Hours
    SILENT_ENABLE_VAL="NO"
    S_START="23"
    S_END="07"
    
    echo -e "\n${BLUE}--- Silent Hours (Mute Alerts) ---${NC}"
    ask_yn "🌙 Enable Silent Hours?"
    
    if [ "$ANSWER_YN" = "y" ]; then
        SILENT_ENABLE_VAL="YES"
        while :; do
            printf "${BOLD}   > Start Hour (0-23): ${NC}"
            read S_START </dev/tty
            if echo "$S_START" | grep -qE '^[0-9]+$' && [ "$S_START" -ge 0 ] && [ "$S_START" -le 23 ] 2>/dev/null; then break; else echo -e "${RED}   ❌ Invalid.${NC}"; fi
        done
        while :; do
            printf "${BOLD}   > End Hour (0-23): ${NC}"
            read S_END </dev/tty
            if echo "$S_END" | grep -qE '^[0-9]+$' && [ "$S_END" -ge 0 ] && [ "$S_END" -le 23 ] 2>/dev/null; then break; else echo -e "${RED}   ❌ Invalid.${NC}"; fi
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
             echo -e "${BOLD}${WHITE}   1.${NC} Discord Only"
             echo -e "${BOLD}${WHITE}   2.${NC} Telegram Only"
             echo -e "${BOLD}${WHITE}   3.${NC} Both"
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
    echo -e "${BOLD}${WHITE}1.${NC} Both: Full monitoring (Default)"
    echo -e "${BOLD}${WHITE}2.${NC} Device Connectivity only: Pings local network"
    echo -e "${BOLD}${WHITE}3.${NC} Internet Connectivity only: Pings external IP"
    
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
# Vault Gen
echo -e "\n${CYAN}🔐 Securing credentials...${NC}"

get_hw_key() {
    local seed="nwda_v1_secure_seed_2025"
    local cpu=$(grep -i "serial" /proc/cpuinfo | head -1 | awk '{print $3}')
    local mac=$(cat /sys/class/net/eth0/address 2>/dev/null || cat /sys/class/net/br-lan/address 2>/dev/null)
    echo -n "${seed}${cpu}${mac}" | openssl dgst -sha256 | awk '{print $2}'
}

if [ "$KEEP_CONFIG" -eq 0 ]; then
    VAULT_DATA="${D_HOOK}|${D_UID}|${T_TOK}|${T_CHAT}"
    if [ "$ENCRYPTION_METHOD" = "OPENSSL" ]; then
        if echo -n "$VAULT_DATA" | openssl enc -aes-256-cbc -a -salt -pbkdf2 -iter 10000 -k "$(get_hw_key)" -out "$VAULT_FILE" 2>/dev/null; then
            echo -e "${GREEN}✅ Credentials Encrypted (OpenSSL).${NC}"
        else echo -e "${RED}❌ Encryption Failed.${NC}"; fi
    else
        if echo -n "$VAULT_DATA" | base64 > "$VAULT_FILE"; then echo -e "${YELLOW}✅ Credentials Encoded (Base64).${NC}"; else echo -e "${RED}❌ Failed.${NC}"; fi
    fi
fi

echo -e "\n${CYAN}🛠️  Generating optimized core...${NC}"
cat <<'EOF' > "$INSTALL_DIR/netwatchda.sh"
#!/bin/sh
# netwatchda - Optimized Engine (High Fidelity)

# Paths & Init
BASE="/root/netwatchda"
CONF="$BASE/nwda_settings.conf"
IPS="$BASE/nwda_ips.conf"
VAULT="$BASE/.vault.enc"
TMP="/tmp/netwatchda"
mkdir -p "$TMP"
LOG="$TMP/nwda_uptime.log"; PINGLOG="$TMP/nwda_ping.log"; SBUF="$TMP/nwda_silent_buffer"
[ ! -f "$SBUF" ] && touch "$SBUF"; [ ! -f "$LOG" ] && touch "$LOG"

# State & Cache
LAST_EXT=0; LAST_DEV=0; LAST_HB=$(date +%s); HW_KEY_CACHE=""
CONF_MTIME=0

# --- FAST LOGGING ---
log_msg() {
    local m="$1" t="$2" ts=$(date '+%b %d %H:%M:%S')
    if [ "$t" = "P" ] && [ "$PING_LOG_ENABLE" = "YES" ]; then
        echo "$ts - $m" >> "$PINGLOG"
        [ -f "$PINGLOG" ] && [ $(wc -c < "$PINGLOG") -gt $UPTIME_LOG_MAX_SIZE ] && echo "$ts - [SYSTEM] Log rotated." > "$PINGLOG"
    elif [ "$t" = "U" ]; then
        echo "$ts - $m" >> "$LOG"
        [ -f "$LOG" ] && [ $(wc -c < "$LOG") -gt $UPTIME_LOG_MAX_SIZE ] && echo "$ts - [SYSTEM] Log rotated." > "$LOG"
    fi
}

# --- SMART CONFIG LOADER (Only reloads if changed) ---
check_config() {
    local curr_mtime=$(date -r "$CONF" +%s 2>/dev/null)
    if [ "$curr_mtime" != "$CONF_MTIME" ]; then
        eval "$(sed '/^\[.*\]/d' "$CONF" | sed 's/ #.*//')"
        CONF_MTIME="$curr_mtime"
        # Calculate HW Key once per config load to save CPU
        local s="nwda_v1_secure_seed_2025"
        local c=$(grep -i "serial" /proc/cpuinfo | head -1 | awk '{print $3}')
        local m=$(cat /sys/class/net/eth0/address 2>/dev/null || cat /sys/class/net/br-lan/address 2>/dev/null)
        HW_KEY_CACHE=$(echo -n "${s}${c}${m}" | openssl dgst -sha256 | awk '{print $2}')
    fi
}

# --- OPTIMIZED DECRYPTION (Shell Built-ins) ---
get_creds() {
    [ -f "$VAULT" ] || return 1
    local d=""
    if [ "$ENCRYPTION_METHOD" = "OPENSSL" ]; then
        d=$(openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -iter 10000 -k "$HW_KEY_CACHE" -in "$VAULT" 2>/dev/null)
    else d=$(cat "$VAULT" | base64 -d 2>/dev/null); fi
    
    [ -z "$d" ] && return 1
    
    # Pure Shell Parsing (Zero Forks) - Matches original structure
    local rem="$d"
    DISCORD_WEBHOOK="${rem%%|*}"; rem="${rem#*|}"
    DISCORD_USERID="${rem%%|*}"; rem="${rem#*|}"
    TELEGRAM_BOT_TOKEN="${rem%%|*}"; rem="${rem#*|}"
    TELEGRAM_CHAT_ID="$rem"
}

# --- SEND NOTIFICATION ---
notify() {
    local title="$1" desc="$2" color="$3" filter="$4"
    
    # RAM Guard (Integer Math)
    local fr=$(df /tmp | awk 'NR==2 {print $4}')
    [ "$fr" -lt "$RAM_GUARD_MIN_FREE" ] && { log_msg "[SYSTEM] RAM LOW ($fr). Notification skipped." "U"; return; }

    get_creds
    
    # Discord
    if [ "$DISCORD_ENABLE" = "YES" ] && [ -n "$DISCORD_WEBHOOK" ]; then
        if [ -z "$filter" ] || [ "$filter" = "BOTH" ] || [ "$filter" = "DISCORD" ]; then
            curl -s -H "Content-Type: application/json" -X POST \
            -d "{\"embeds\": [{\"title\": \"$title\", \"description\": \"$desc\", \"color\": $color}]}" \
            "$DISCORD_WEBHOOK" >/dev/null 2>&1
        fi
    fi
    
    # Telegram
    if [ "$TELEGRAM_ENABLE" = "YES" ] && [ -n "$TELEGRAM_BOT_TOKEN" ]; then
        if [ -z "$filter" ] || [ "$filter" = "BOTH" ] || [ "$filter" = "TELEGRAM" ]; then
            # Matches original formatting exactly
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" -d text="$title
$desc" >/dev/null 2>&1
        fi
    fi
    unset DISCORD_WEBHOOK DISCORD_USERID TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
}

# --- MAIN LOOP ---
while true; do
    check_config
    NOW=$(date +%s); DATE=$(date '+%b %d %H:%M:%S'); HR=$(date +%H)
    
    # CPU Check (Read /proc directly, no awk)
    read cpu_line < /proc/loadavg
    cpu_1min="${cpu_line%% *}" # Get first number
    cpu_int=$(echo "$cpu_1min" | tr -d '.') # Convert 1.23 -> 123
    # If load 2.00 (200), skip
    if [ "$cpu_int" -gt "$CPU_GUARD_THRESHOLD" ] 2>/dev/null; then
        log_msg "[SYSTEM] High Load ($cpu_1min). Skipping cycle." "U"; sleep 10; continue
    fi

    # HEARTBEAT
    if [ "$HEARTBEAT" = "YES" ] && [ $((NOW - LAST_HB)) -ge "$HB_INTERVAL" ]; then
        LAST_HB=$NOW
        # RESTORED: Exact original string
        HB_MSG="**Router:** $ROUTER_NAME\n**Status:** Systems Operational\n**Time:** $DATE"
        [ "$HB_MENTION" = "YES" ] && HB_MSG="$HB_MSG\n<@$DISCORD_USERID>"
        
        notify "💓 Heartbeat Report" "$HB_MSG" "1752220" "${HB_TARGET:-BOTH}"
        log_msg "[$ROUTER_NAME] Heartbeat sent (${HB_TARGET:-BOTH})." "U"
    fi

    # SILENT MODE
    SILENT=0
    if [ "$SILENT_ENABLE" = "YES" ]; then
        if [ "$SILENT_START" -gt "$SILENT_END" ]; then
            if [ "$HR" -ge "$SILENT_START" ] || [ "$HR" -lt "$SILENT_END" ]; then SILENT=1; fi
        else
            if [ "$HR" -ge "$SILENT_START" ] && [ "$HR" -lt "$SILENT_END" ]; then SILENT=1; fi
        fi
    fi
    
    # DUMP SILENT BUFFER
    if [ "$SILENT" -eq 0 ] && [ -s "$SBUF" ]; then
        clean_sum=$(sed ':a;N;$!ba;s/\n/\\n/g' "$SBUF")
        notify "🌙 Silent Hours Summary" "**Router:** $ROUTER_NAME\n$clean_sum" "10181046" "BOTH"
        > "$SBUF"
    fi

    # INTERNET CHECK
    if [ "$EXT_ENABLE" = "YES" ] && [ $((NOW - LAST_EXT)) -ge "$EXT_SCAN_INTERVAL" ]; then
        LAST_EXT=$NOW
        FD="$TMP/nwda_ext_d"; FT="$TMP/nwda_ext_t"; FC="$TMP/nwda_ext_c"
        UP=0
        ping -q -c $EXT_PING_COUNT -W $EXT_PING_TIMEOUT "$EXT_IP" >/dev/null 2>&1 && UP=1
        [ $UP -eq 0 ] && ping -q -c $EXT_PING_COUNT -W $EXT_PING_TIMEOUT "$EXT_IP2" >/dev/null 2>&1 && UP=1
        
        if [ $UP -eq 0 ]; then
            C=$(($(cat "$FC" 2>/dev/null || echo 0)+1)); echo "$C" > "$FC"
            if [ "$C" -ge "$EXT_FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                echo "$NOW" > "$FD"; echo "$DATE" > "$FT"
                log_msg "[ALERT] [$ROUTER_NAME] INTERNET DOWN" "U"
                
                # RESTORED: Exact original string
                MSG="**Router:** $ROUTER_NAME\n**Time:** $DATE"
                
                if [ $SILENT -eq 0 ]; then notify "🔴 Internet Down" "$MSG" "15548997" "BOTH";
                else echo "Internet Down: $DATE" >> "$SBUF"; fi
            fi
        else
            if [ -f "$FD" ]; then
                ST=$(cat "$FT"); SS=$(cat "$FD"); DUR=$((NOW - SS))
                STR="$((DUR/60))m $((DUR%60))s"
                log_msg "[SUCCESS] [$ROUTER_NAME] INTERNET UP (Down $STR)" "U"
                
                # RESTORED: Exact original string
                MSG="**Router:** $ROUTER_NAME\n**Down at:** $ST\n**Up at:** $DATE\n**Total Outage:** $STR"
                
                if [ $SILENT -eq 0 ]; then notify "🟢 Connectivity Restored" "$MSG" "3066993" "BOTH";
                else echo "Internet Restored: $DATE (Down $STR)" >> "$SBUF"; fi
                rm -f "$FD" "$FT"
            fi
            echo 0 > "$FC"
        fi
    fi

    # DEVICE CHECK
    if [ "$DEVICE_MONITOR" = "YES" ] && [ $((NOW - LAST_DEV)) -ge "$DEV_SCAN_INTERVAL" ]; then
        LAST_DEV=$NOW
        grep -vE '^#|^$' "$IPS" | while read -r line; do
            (
                TIP="${line%%@*}"; TIP=$(echo "$TIP" | tr -d ' ')
                NAME="${line#*@}"; NAME=$(echo "$NAME" | sed 's/^[ \t]*//')
                [ -z "$NAME" ] && NAME="$TIP"
                [ -z "$TIP" ] && exit
                SIP=$(echo "$TIP" | tr '.' '_')
                FC="$TMP/dev_${SIP}_c"; FD="$TMP/dev_${SIP}_d"; FT="$TMP/dev_${SIP}_t"
                
                if ping -q -c $DEV_PING_COUNT -W 1 "$TIP" >/dev/null 2>&1; then
                    log_msg "DEVICE - $NAME - $TIP: UP" "P"
                    if [ -f "$FD" ]; then
                        ST=$(cat "$FT"); SS=$(cat "$FD"); DUR=$(( $(date +%s) - SS ))
                        STR="$((DUR/60))m $((DUR%60))s"
                        log_msg "[SUCCESS] [$ROUTER_NAME] Device: $NAME ($TIP) Online (Down $STR)" "U"
                        
                        # RESTORED: Exact original string
                        D_MSG="**Router:** $ROUTER_NAME\n**Device:** $NAME ($TIP)\n**Down at:** $ST\n**Up at:** $(date '+%b %d %H:%M:%S')\n**Outage:** $STR"
                        
                        if [ $SILENT -eq 0 ]; then notify "🟢 Device Online" "$D_MSG" "3066993" "BOTH";
                        else echo "Device $NAME UP: $(date '+%b %d %H:%M:%S') (Down $STR)" >> "$SBUF"; fi
                        rm -f "$FD" "$FT"
                    fi
                    echo 0 > "$FC"
                else
                    log_msg "DEVICE - $NAME - $TIP: DOWN" "P"
                    C=$(($(cat "$FC" 2>/dev/null || echo 0)+1)); echo "$C" > "$FC"
                    if [ "$C" -ge "$DEV_FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                        TS=$(date '+%b %d %H:%M:%S')
                        echo "$(date +%s)" > "$FD"; echo "$TS" > "$FT"
                        log_msg "[ALERT] [$ROUTER_NAME] Device: $NAME ($TIP) Down" "U"
                        
                        # RESTORED: Exact original string
                        D_MSG="**Router:** $ROUTER_NAME\n**Device:** $NAME ($TIP)\n**Time:** $TS"
                        
                        if [ $SILENT -eq 0 ]; then notify "🔴 Device Down" "$D_MSG" "15548997" "BOTH";
                        else echo "Device $NAME DOWN: $TS" >> "$SBUF"; fi
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
# ==============================================================================
#  STEP 8: SERVICE CONFIGURATION
# ==============================================================================
echo -e "\n${CYAN}⚙️  Configuring service...${NC}"
cat <<EOF > "$SERVICE_PATH"
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

extra_command "status" "Status"; extra_command "logs" "Logs"
extra_command "discord" "Test Discord"; extra_command "telegram" "Test Telegram"
extra_command "credentials" "Manage Creds"; extra_command "purge" "Uninstall"
extra_command "reload" "Reload Config"

start_service() {
    procd_open_instance
    procd_set_param command /bin/sh "$INSTALL_DIR/netwatchda.sh"
    procd_set_param respawn
    procd_set_param stdout 0; procd_set_param stderr 0
    procd_close_instance
}

load_env() {
    [ -f "$INSTALL_DIR/nwda_settings.conf" ] && . "$INSTALL_DIR/nwda_settings.conf"
}

get_hw_key() {
    local s="nwda_v1_secure_seed_2025"
    local c=\$(grep -i "serial" /proc/cpuinfo | head -1 | awk '{print \$3}')
    local m=\$(cat /sys/class/net/eth0/address 2>/dev/null || cat /sys/class/net/br-lan/address 2>/dev/null)
    echo -n "\${s}\${c}\${m}" | openssl dgst -sha256 | awk '{print \$2}'
}

get_creds() {
    local v="$INSTALL_DIR/.vault.enc"; [ -f "\$v" ] || return 1
    local d=""
    if [ "\$ENCRYPTION_METHOD" = "OPENSSL" ]; then
        local k=\$(get_hw_key)
        d=\$(openssl enc -aes-256-cbc -a -d -salt -pbkdf2 -iter 10000 -k "\$k" -in "\$v" 2>/dev/null)
    else d=\$(cat "\$v" | base64 -d 2>/dev/null); fi
    echo "\$d"
}

discord() {
    load_env
    local d=\$(get_creds)
    local h=\$(echo "\$d" | cut -d'|' -f1)
    [ -n "\$h" ] && curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"Test\", \"description\": \"Manual Trigger\", \"color\": 16776960}]}" "\$h" && echo "Sent." || echo "Failed."
}

telegram() {
    load_env
    local d=\$(get_creds)
    local t=\$(echo "\$d" | cut -d'|' -f3); local c=\$(echo "\$d" | cut -d'|' -f4)
    [ -n "\$t" ] && curl -s -X POST "https://api.telegram.org/bot\$t/sendMessage" -d chat_id="\$c" -d text="Test Trigger" && echo "Sent." || echo "Failed."
}

credentials() {
    echo ""; echo "1. Discord  2. Telegram  3. Both"
    printf "Choice: "; read c </dev/tty
    load_env
    local cur=\$(get_creds)
    local d_h=\$(echo "\$cur" | cut -d'|' -f1); local d_u=\$(echo "\$cur" | cut -d'|' -f2)
    local t_t=\$(echo "\$cur" | cut -d'|' -f3); local t_c=\$(echo "\$cur" | cut -d'|' -f4)
    
    if [ "\$c" = "1" ] || [ "\$c" = "3" ]; then
        printf "Webhook: "; read d_h </dev/tty
        printf "User ID: "; read d_u </dev/tty
    fi
    if [ "\$c" = "2" ] || [ "\$c" = "3" ]; then
        printf "Bot Token: "; read t_t </dev/tty
        printf "Chat ID: "; read t_c </dev/tty
    fi
    
    local dat="\${d_h}|\${d_u}|\${t_t}|\${t_c}"
    local v="$INSTALL_DIR/.vault.enc"
    
    if [ "\$ENCRYPTION_METHOD" = "OPENSSL" ]; then
        local k=\$(get_hw_key)
        echo -n "\$dat" | openssl enc -aes-256-cbc -a -salt -pbkdf2 -iter 10000 -k "\$k" -out "\$v" 2>/dev/null && echo "Updated."
    else echo -n "\$dat" | base64 > "\$v" && echo "Updated."; fi
    /etc/init.d/netwatchda restart
}

status() {
    pgrep -f "netwatchda.sh" >/dev/null && echo -e "\033[1;32mRunning\033[0m" || echo -e "\033[1;31mStopped\033[0m"
}
logs() { tail -n 20 /tmp/netwatchda/nwda_uptime.log 2>/dev/null || echo "No logs."; }
reload() { /etc/init.d/netwatchda restart; }

purge() {
    echo "1. Full Uninstall  2. Keep Settings"
    printf "Choice: "; read c </dev/tty
    /etc/init.d/netwatchda stop; /etc/init.d/netwatchda disable
    [ "\$c" = "1" ] && rm -rf "$INSTALL_DIR"
    rm -rf "/tmp/netwatchda" "$SERVICE_PATH"
    echo "Removed."
}
EOF
chmod +x "$SERVICE_PATH"
"$SERVICE_PATH" enable >/dev/null 2>&1
"$SERVICE_PATH" restart >/dev/null 2>&1

# Final
MSG="**Router:** $router_name_input\n**Status:** Installed (Optimized)"
[ "$DISCORD_ENABLE_VAL" = "YES" ] && curl -s -H "Content-Type: application/json" -X POST -d "{\"embeds\": [{\"title\": \"🚀 Started\", \"description\": \"$MSG\", \"color\": 1752220}]}" "$D_HOOK" >/dev/null 2>&1

echo ""
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
echo -e "  Restart         :  ${YELLOW}/etc/init.d/netwatchda restart${NC}"
echo ""