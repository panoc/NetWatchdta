#!/bin/sh
# netwatchda Ultimate Installer - Hardened Network Monitoring for OpenWrt
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
RED='\033[1;31m'    
GREEN='\033[1;32m'  
BLUE='\033[1;34m'   
CYAN='\033[1;36m'   
YELLOW='\033[1;33m' 

# --- PATHS ---
INSTALL_DIR="/root/netwatchda"
CONFIG_FILE="$INSTALL_DIR/nwda_settings.conf"
IP_LIST_FILE="$INSTALL_DIR/nwda_ips.conf"
VAULT_FILE="$INSTALL_DIR/.vault.enc"
SEED_FILE="$INSTALL_DIR/.seed"
SERVICE_PATH="/etc/init.d/netwatchda"
LOG_DIR="/tmp/netwatchda"
UPTIME_LOG="$LOG_DIR/nwda_uptime.log"
PING_LOG="$LOG_DIR/nwda_ping.log"

# --- INITIAL HEADER ---
echo -e "${BLUE}=======================================================${NC}"
echo -e "${BOLD}${CYAN}🚀 netwatchda Ultimate Setup${NC} (by ${BOLD}panoc${NC})"
echo -e "${BLUE}⚖️  License: GNU GPLv3${NC}"
echo -e "${BLUE}=======================================================${NC}"
echo ""

# --- 0. PRE-INSTALLATION CONFIRMATION ---
while :; do
    printf "${BOLD}❓ This will begin the installation process. Continue? [y/n]: ${NC}"
    read -r start_confirm </dev/tty
    case "$start_confirm" in
        [Yy]*) break ;;
        [Nn]*) echo -e "${RED}❌ Installation aborted. Cleaning up...${NC}"; exit 0 ;;
        *) echo -e "${YELLOW}Please enter y or n.${NC}" ;;
    esac
done

# --- 1. SYSTEM READINESS & DEPENDENCIES ---
echo -e "\n${BOLD}📦 Checking system readiness...${NC}"

install_pkg() {
    echo -ne "${CYAN}📥 Installing $1... [          ]\r"
    opkg update > /dev/null 2>&1
    echo -ne "${CYAN}📥 Installing $1... [#####     ]\r"
    opkg install "$1" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}📥 Installing $1... [##########] Done.${NC}"
    else
        echo -e "${RED}❌ Failed to install $1. Check internet connection.${NC}"
        exit 1
    fi
}

command -v curl >/dev/null 2>&1 || install_pkg "curl ca-bundle"
command -v openssl >/dev/null 2>&1 || install_pkg "openssl-util"

mkdir -p "$INSTALL_DIR"
mkdir -p "$LOG_DIR"

# --- 2. HARDWARE LOCK GENERATION ---
if [ ! -f "$SEED_FILE" ]; then
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 > "$SEED_FILE"
fi

get_hw_key() {
    CPU_ID=$(grep -m1 "serial" /proc/cpuinfo | awk '{print $3}')
    [ -z "$CPU_ID" ] && CPU_ID=$(cat /sys/class/net/eth0/address 2>/dev/null || echo "NWDA_V1_KEY")
    SEED=$(cat "$SEED_FILE")
    echo "${CPU_ID}${SEED}" | sha256sum | awk '{print $1}'
}

# --- 3. NOTIFICATION STRATEGY MENU ---
echo -e "\n${BLUE}--- Notification Strategy ---${NC}"
echo -e "1. ${WHITE_BOLD}Enable Discord Notifications${NC}"
echo -e "2. ${WHITE_BOLD}Enable Telegram Notifications${NC}"
echo -e "3. ${WHITE_BOLD}Enable Both${NC}"
echo -e "4. ${WHITE_BOLD}None (In this case user should be informed that events can only be tracked through logs)${NC}"

while :; do
    printf "${BOLD}Enter choice [1-4]: ${NC}"
    read -r notify_choice </dev/tty
    case "$notify_choice" in
        1|2|3|4) break ;;
        *) echo -e "${RED}❌ Invalid selection. Please enter 1-4.${NC}" ;;
    esac
done

D_EN="NO"; T_EN="NO"
D_URL=""; D_ID=""; T_TOK=""; T_ID=""

if [ "$notify_choice" = "1" ] || [ "$notify_choice" = "3" ]; then
    D_EN="YES"
    printf "${BOLD}🔗 Enter Discord Webhook URL: ${NC}"
    read -r D_URL </dev/tty
    printf "${BOLD}👤 Enter Discord User ID (for @mentions): ${NC}"
    read -r D_ID </dev/tty
fi

if [ "$notify_choice" = "2" ] || [ "$notify_choice" = "3" ]; then
    T_EN="YES"
    printf "${BOLD}🤖 Enter Telegram Bot Token: ${NC}"
    read -r T_TOK </dev/tty
    printf "${BOLD}🆔 Enter Telegram Chat ID: ${NC}"
    read -r T_ID </dev/tty
fi

# --- 4. MONITORING MODE SELECTION ---
echo -e "\n${BLUE}--- Monitoring Mode ---${NC}"
echo -e "1. ${WHITE_BOLD}Aggressive${NC} (Check every 10s, Alert after 1 failure)"
echo -e "2. ${WHITE_BOLD}Balanced${NC} (Check every 60s, Alert after 3 failures)"
echo -e "3. ${WHITE_BOLD}Power Saver${NC} (Check every 5m, Alert after 5 failures)"

while :; do
    printf "${BOLD}Enter choice [1-3]: ${NC}"
    read -r mode_choice </dev/tty
    case "$mode_choice" in
        1) E_INT=10; D_INT=5; E_FAIL=1; D_FAIL=1; break ;;
        2) E_INT=60; D_INT=10; E_FAIL=1; D_FAIL=3; break ;;
        3) E_INT=300; D_INT=60; E_FAIL=3; D_FAIL=5; break ;;
        *) echo -e "${RED}❌ Invalid selection.${NC}" ;;
    esac
done

# --- 5. ENCRYPTION VAULT CREATION ---
HW_KEY=$(get_hw_key)
echo "D_URL='$D_URL'
D_ID='$D_ID'
T_TOK='$T_TOK'
T_ID='$T_ID'" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 10000 -k "$HW_KEY" -out "$VAULT_FILE"

# --- 6. SETTINGS GENERATOR ---
cat <<EOF > "$CONFIG_FILE"
# nwda_settings.conf - Configuration for netwatchda
# Note: Discord/Telegram tokens are stored encrypted in .vault.enc

[Log settings]
UPTIME_LOG_MAX_SIZE=51200 # Max log file size in bytes for uptime tracking. Default is 51200.
PING_LOG_ENABLE="NO" # Enable or disable detailed ping logging (YES/NO). Default is NO.

[Discord Settings]
DISCORD_ENABLE="$D_EN" # Global toggle for Discord notifications (YES/NO). Default is NO.
SILENT_ENABLE="NO" # Mutes Discord alerts during specific hours (YES/NO). Default is NO.
SILENT_START=23 # Hour to start silent mode (0-23). Default is 23.
SILENT_END=07 # Hour to end silent mode (0-23). Default is 07.

[TELEGRAM Settings]
TELEGRAM_ENABLE="$T_EN" # Global toggle for Telegram notifications (YES/NO). Default is NO.

[Monitoring Settings]
CPU_GUARD_THRESHOLD=2.0 # Max CPU load average allowed before skipping pings. Default is 2.0.
RAM_GUARD_MIN_FREE=4096 # Minimum free RAM in KB required to run alerts. Default is 4096.
HEARTBEAT="YES" # Periodic "I am alive" notification (YES/NO). Default is NO.
HB_INTERVAL=86400 # Seconds between heartbeat messages. Default is 86400.
HB_MENTION="NO" # Ping User ID in heartbeat messages (YES/NO). Default is NO.

[Internet Connectivity]
EXT_ENABLE="YES" # Global toggle for internet monitoring (YES/NO). Default is YES.
EXT_IP="1.1.1.1" # Primary external IP to monitor. Default is 1.1.1.1.
EXT_IP2="8.8.8.8" # Secondary external IP for redundancy. Default is 8.8.8.8.
EXT_SCAN_INTERVAL=$E_INT # Seconds between internet checks.
EXT_FAIL_THRESHOLD=$E_FAIL # Failed cycles before internet alert.
EXT_PING_COUNT=4 # Number of packets per internet check. Default is 4.
EXT_PING_TIMEOUT=1 # Seconds to wait for ping response. Default is 1.

[Local Device Monitoring]
DEVICE_MONITOR="YES" # Enable monitoring of local IPs (YES/NO). Default is YES.
DEV_SCAN_INTERVAL=$D_INT # Seconds between local device checks.
DEV_FAIL_THRESHOLD=$D_FAIL # Failed cycles before device alert.
DEV_PING_COUNT=4 # Number of packets per device check. Default is 4.
EOF

[ ! -f "$IP_LIST_FILE" ] && echo "8.8.8.8 @ Google_DNS" > "$IP_LIST_FILE"

# --- 7. LOGIC ENGINE GENERATION (nwda.sh) ---
cat <<'EOF' > "$INSTALL_DIR/nwda.sh"
#!/bin/sh
# netwatchda - The Engine
# Handles pings, state management, silence hours, and redundant alerts.

BASE_DIR="/root/netwatchda"
LOG_DIR="/tmp/netwatchda"
CONFIG_FILE="$BASE_DIR/nwda_settings.conf"
IP_LIST_FILE="$BASE_DIR/nwda_ips.conf"
UPTIME_LOG="$LOG_DIR/nwda_uptime.log"
PING_LOG="$LOG_DIR/nwda_ping.log"

mkdir -p "$LOG_DIR"

load_config() {
    eval "$(sed '/^\[.*\]/d; s/[[:space:]]*#.*//' "$CONFIG_FILE" | sed 's/=/="/;s/$/"/')"
}

send_notif() {
    TITLE="$1"; MSG="$2"; COLOR="$3"
    NOW_HUMAN=$(date '+%b %d %H:%M:%S')
    
    if [ "$DISCORD_ENABLE" = "YES" ] && [ -n "$D_URL" ]; then
        MENTION=""
        [ "$HB_MENTION" = "YES" ] && [ -n "$D_ID" ] && MENTION="<@$D_ID>"
        curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"$MENTION\", \"embeds\": [{\"title\": \"$TITLE\", \"description\": \"$MSG\n\n**Time:** $NOW_HUMAN\", \"color\": $COLOR}]}" "$D_URL" > /dev/null 2>&1
    fi
    
    if [ "$TELEGRAM_ENABLE" = "YES" ] && [ -n "$T_TOK" ]; then
        T_TEXT="📟 <b>$TITLE</b>\n$MSG\n\n<b>Time:</b> $NOW_HUMAN"
        curl -s "https://api.telegram.org/bot$T_TOK/sendMessage?chat_id=$T_ID&parse_mode=HTML&text=$(echo "$T_TEXT" | sed 's/ /%20/g; s/\\n/%0A/g')" > /dev/null 2>&1
    fi
}

LAST_EXT_CHECK=0; LAST_DEV_CHECK=0; LAST_HB_CHECK=$(date +%s)

while true; do
    load_config
    NOW_SEC=$(date +%s)
    CUR_H=$(date +%H)

    # 1. Silence Hours Logic
    IS_SILENT=0
    if [ "$SILENT_ENABLE" = "YES" ]; then
        if [ "$SILENT_START" -gt "$SILENT_END" ]; then
            [ "$CUR_H" -ge "$SILENT_START" ] || [ "$CUR_H" -lt "$SILENT_END" ] && IS_SILENT=1
        else
            [ "$CUR_H" -ge "$SILENT_START" ] && [ "$CUR_H" -lt "$SILENT_END" ] && IS_SILENT=1
        fi
    fi

    # 2. Heartbeat Logic
    if [ "$HEARTBEAT" = "YES" ] && [ $((NOW_SEC - LAST_HB_CHECK)) -ge "$HB_INTERVAL" ]; then
        LAST_HB_CHECK=$NOW_SEC
        send_notif "💓 Heartbeat" "System is alive and monitoring." 1752220
    fi

    # 3. Resource Guards
    CUR_LOAD=$(awk '{print $1}' /proc/loadavg)
    FREE_MEM=$(free | grep Mem | awk '{print $4}')
    if [ "$(echo "$CUR_LOAD > $CPU_GUARD_THRESHOLD" | bc)" -eq 1 ] || [ "$FREE_MEM" -lt "$RAM_GUARD_MIN_FREE" ]; then
        sleep 5; continue
    fi

    # 4. Internet Connectivity Logic
    if [ "$EXT_ENABLE" = "YES" ] && [ $((NOW_SEC - LAST_EXT_CHECK)) -ge "$EXT_SCAN_INTERVAL" ]; then
        LAST_EXT_CHECK=$NOW_SEC
        EXT_UP=0
        ping -q -c "$EXT_PING_COUNT" -W "$EXT_PING_TIMEOUT" "$EXT_IP" > /dev/null 2>&1 && EXT_UP=1
        [ "$EXT_UP" -eq 0 ] && ping -q -c "$EXT_PING_COUNT" -W "$EXT_PING_TIMEOUT" "$EXT_IP2" > /dev/null 2>&1 && EXT_UP=1
        
        FD="/tmp/nwda_ext_d"; FT="/tmp/nwda_ext_t"; FC="/tmp/nwda_ext_c"
        if [ "$EXT_UP" -eq 0 ]; then
            C=$(($(cat "$FC" 2>/dev/null || echo 0)+1)); echo "$C" > "$FC"
            if [ "$C" -ge "$EXT_FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                echo "$NOW_SEC" > "$FD"; date '+%b %d %H:%M:%S' > "$FT"
                echo "$(cat "$FT") - [ALERT] INTERNET DOWN" >> "$UPTIME_LOG"
                [ "$IS_SILENT" -eq 0 ] && send_notif "🔴 Internet Down" "Internet connectivity lost." 15548997
            fi
        else
            if [ -f "$FD" ]; then
                DUR=$((NOW_SEC - $(cat "$FD"))); D_STR="$((DUR/60))m $((DUR%60))s"
                echo "$(date '+%b %d %H:%M:%S') - [SUCCESS] INTERNET UP (Down $D_STR)" >> "$UPTIME_LOG"
                [ "$IS_SILENT" -eq 0 ] && send_notif "🟢 Internet Restored" "Connectivity restored.\n**Total Outage:** $D_STR" 3066993
                rm -f "$FD" "$FT"
            fi
            echo 0 > "$FC"
        fi
    fi

    # 5. Local Device Logic (Multi-threaded background)
    if [ "$DEVICE_MONITOR" = "YES" ] && [ $((NOW_SEC - LAST_DEV_CHECK)) -ge "$DEV_SCAN_INTERVAL" ]; then
        LAST_DEV_CHECK=$NOW_SEC
        sed -e '/^#/d' -e '/^$/d' "$IP_LIST_FILE" | while read -r line; do
            TIP=$(echo "$line" | cut -d'@' -f1 | tr -d ' ')
            NAME=$(echo "$line" | cut -d'@' -f2- | sed 's/^[ \t]*//')
            (
                ping -q -c "$DEV_PING_COUNT" -W 1 "$TIP" > /dev/null 2>&1
                RES=$?; S_ID=$(echo "$TIP" | tr '.' '_')
                FC="/tmp/nw_c_$S_ID"; FD="/tmp/nw_d_$S_ID"
                
                if [ $RES -eq 0 ]; then
                    if [ -f "$FD" ]; then
                        DUR=$(( $(date +%s) - $(cat "$FD") )); D_STR="$((DUR/60))m $((DUR%60))s"
                        echo "$(date '+%b %d %H:%M:%S') - [SUCCESS] Device: $NAME UP (Down $D_STR)" >> "$UPTIME_LOG"
                        [ "$IS_SILENT" -eq 0 ] && send_notif "🟢 Device Online" "**$NAME** ($TIP) back online.\n**Outage:** $D_STR" 3066993
                        rm -f "$FD"
                    fi
                    echo 0 > "$FC"
                else
                    C=$(($(cat "$FC" 2>/dev/null || echo 0)+1)); echo "$C" > "$FC"
                    if [ "$C" -ge "$DEV_FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                        echo "$(date +%s)" > "$FD"
                        echo "$(date '+%b %d %H:%M:%S') - [ALERT] Device: $NAME DOWN" >> "$UPTIME_LOG"
                        [ "$IS_SILENT" -eq 0 ] && send_notif "🔴 Device Down" "**$NAME** ($TIP) offline." 15548997
                    fi
                fi
            ) &
        done
    fi
    sleep 1
done
EOF
chmod +x "$INSTALL_DIR/nwda.sh"

# --- 8. SERVICE SCRIPT (SMART PURGE + TEST COMMANDS) ---
cat <<'EOF' > "$SERVICE_PATH"
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1
INSTALL_DIR="/root/netwatchda"

get_hw_key() {
    CPU_ID=$(grep -m1 "serial" /proc/cpuinfo | awk '{print $3}')
    [ -z "$CPU_ID" ] && CPU_ID=$(cat /sys/class/net/eth0/address 2>/dev/null || echo "NWDA_V1")
    SEED=$(cat "$INSTALL_DIR/.seed")
    echo "${CPU_ID}${SEED}" | sha256sum | awk '{print $1}'
}

extra_command "status" "Service status"
extra_command "logs" "View logs"
extra_command "purge" "Smart Uninstaller"

start_service() {
    HW_KEY=$(get_hw_key)
    eval "$(openssl enc -d -aes-256-cbc -pbkdf2 -iter 10000 -k "$HW_KEY" -in "$INSTALL_DIR/.vault.enc" 2>/dev/null)"
    procd_open_instance
    procd_set_param command /bin/sh "$INSTALL_DIR/nwda.sh"
    procd_set_param env D_URL="$D_URL" D_ID="$D_ID" T_TOK="$T_TOK" T_ID="$T_ID"
    procd_set_param respawn
    procd_close_instance
}

purge() {
    echo -e "\n${RED}${BOLD}--- SMART UNINSTALLER ---${NC}"
    echo -e "1. ${WHITE_BOLD}Full Uninstall${NC} (Delete all files, configs, and logs)"
    echo -e "2. ${WHITE_BOLD}Smart Uninstall${NC} (Keep configs and vault, only remove script/service)"
    printf "${BOLD}Choice [1-2]: ${NC}"; read -r p_choice </dev/tty
    case "$p_choice" in
        1)
            /etc/init.d/netwatchda stop
            rm -rf "$INSTALL_DIR" "$SERVICE_PATH"
            echo -e "${GREEN}✅ Everything purged.${NC}"
            ;;
        2)
            /etc/init.d/netwatchda stop
            rm -f "$INSTALL_DIR/nwda.sh" "$SERVICE_PATH"
            echo -e "${GREEN}✅ Logic removed. Settings preserved in $INSTALL_DIR${NC}"
            ;;
    esac
}
EOF
chmod +x "$SERVICE_PATH"
/etc/init.d/netwatchda enable
/etc/init.d/netwatchda restart

# --- FINAL OUTPUT ---
echo -e "\n${GREEN}=======================================================${NC}"
echo -e "${BOLD}${GREEN}✅ Installation complete!${NC}"
echo -e "${CYAN}📂 Folder:${NC} $INSTALL_DIR"
echo -e "${GREEN}=======================================================${NC}"
echo -e "\n${BOLD}Quick Commands:${NC}"
echo -e "  Logs: ${CYAN}/etc/init.d/netwatchda logs${NC}"
echo -e "  Uninstall: ${RED}/etc/init.d/netwatchda purge${NC}"
echo ""