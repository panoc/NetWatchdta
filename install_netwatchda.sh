#!/bin/sh
# netwatchda Installer - Automated Setup for OpenWrt
# Copyright (C) 2025 panoc
# Licensed under the GNU General Public License v3.0

# --- INITIAL SPACING ---
echo ""
echo "-------------------------------------------------------"
echo "🚀 netwatchda Automated Setup (by panoc)"
echo "⚖️  License: GNU GPLv3"
echo "-------------------------------------------------------"

# --- 0. PRE-INSTALLATION CONFIRMATION ---
printf "This will begin the installation process. Continue? [y/n]: "
read start_confirm </dev/tty
if [ "$start_confirm" != "y" ] && [ "$start_confirm" != "Y" ]; then
    echo "❌ Installation aborted by user."
    echo ""
    exit 0
fi

INSTALL_DIR="/root/netwatchda"
CONFIG_FILE="$INSTALL_DIR/netwatchda_settings.conf"
IP_LIST_FILE="$INSTALL_DIR/netwatchda_ips.conf"
SERVICE_NAME="netwatchda"
SERVICE_PATH="/etc/init.d/$SERVICE_NAME"

# --- 1. CHECK DEPENDENCIES ---
echo "📦 Checking dependencies..."
if ! command -v curl >/dev/null 2>&1; then
    echo "📥 curl not found. Attempting to install..."
    opkg update && opkg install curl ca-bundle
    if [ $? -ne 0 ]; then
        echo "❌ Error: Failed to install curl. Aborting."
        exit 1
    fi
fi
echo "✅ curl is ready."

# --- 2. SMART UPGRADE / INSTALL CHECK ---
KEEP_CONFIG=0
if [ -f "$CONFIG_FILE" ]; then
    echo "⚠️  Existing installation found."
    echo "1. Keep settings (Upgrade)"
    echo "2. Clean install"
    printf "Enter choice [1-2]: "
    read choice </dev/tty
    
    if [ "$choice" = "1" ]; then
        echo "🔧 Scanning for missing configuration lines..."
        
        add_if_missing() {
            if ! grep -q "^$1=" "$CONFIG_FILE"; then
                echo "$1=$2 $3" >> "$CONFIG_FILE"
                echo "  ➕ Added missing line: $1"
            fi
        }

        add_if_missing "ROUTER_NAME" "\"My_OpenWrt_Router\"" "# Router ID for Discord"
        add_if_missing "SCAN_INTERVAL" "10" "# Seconds between pings"
        add_if_missing "FAIL_THRESHOLD" "3" "# Retries before alert"
        add_if_missing "MAX_SIZE" "512000" "# Log rotation size in bytes"
        add_if_missing "HEARTBEAT" "\"OFF\"" "# Daily check-in toggle"
        add_if_missing "HB_INTERVAL" "86400" "# Heartbeat frequency in seconds"
        add_if_missing "HB_MENTION" "\"OFF\"" "# Heartbeat tagging toggle"
        add_if_missing "EXT_IP" "\"1.1.1.1\"" "# Internet check IP"
        add_if_missing "EXT_INTERVAL" "60" "# Internet check frequency"
        add_if_missing "DEVICE_MONITOR" "\"ON\"" "# Local monitoring toggle"

        echo "✅ Configuration patch complete."
        KEEP_CONFIG=1
    else
        echo "🧹 Performing clean install..."
        /etc/init.d/netwatchda stop 2>/dev/null
        rm -rf "$INSTALL_DIR"
    fi
fi

mkdir -p "$INSTALL_DIR"

# --- 3. CLEAN INSTALL INPUTS ---
if [ "$KEEP_CONFIG" -eq 0 ]; then
    echo "---"
    printf "🔗 Enter Discord Webhook URL: "
    read user_webhook </dev/tty
    printf "👤 Enter Discord User ID (for @mentions): "
    read user_id </dev/tty
    printf "🏷️  Enter Router Name (e.g., Panoc_WRT): "
    read router_name_input </dev/tty
    
    NOW_HUMAN=$(date '+%b %d, %Y %H:%M:%S')

    echo "🧪 Sending initial test notification..."
    curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"📟 **Router Setup**: Basic connectivity test successful for **$router_name_input**! <@$user_id>\"}" "$user_webhook" > /dev/null
    
    printf "❓ Received basic notification? [y/n]: "
    read confirm_test </dev/tty
    [ "$confirm_test" != "y" ] && [ "$confirm_test" != "Y" ] && echo "❌ Aborted." && exit 1

    echo "---"
    printf "💓 Enable Heartbeat (System check-in)? [y/n]: "
    read hb_enabled </dev/tty
    if [ "$hb_enabled" = "y" ] || [ "$hb_enabled" = "Y" ]; then
        HB_VAL="ON"
        printf "⏰ Interval in HOURS (e.g., 24): "
        read hb_hours </dev/tty
        HB_SEC=$((hb_hours * 3600))
        printf "🔔 Mention in Heartbeat? [y/n]: "
        read hb_m </dev/tty
        [ "$hb_m" = "y" ] || [ "$hb_m" = "Y" ] && HB_MENTION="ON" || HB_MENTION="OFF"
    else
        HB_VAL="OFF"; HB_SEC="86400"; HB_MENTION="OFF"
    fi

    echo "---"
    echo "Select Monitoring Mode:"
    echo "1. Both: Full monitoring (Default)"
    echo "2. Device Connectivity only: Pings local network"
    echo "3. Internet Connectivity only: Pings external IP"
    printf "Enter choice [1-3]: "
    read mode_choice </dev/tty

    case "$mode_choice" in
        2) MODE="DEVICES";  EXT_VAL="";        DEV_VAL="ON"  ;;
        3) MODE="INTERNET"; EXT_VAL="1.1.1.1"; DEV_VAL="OFF" ;;
        *) MODE="BOTH";     EXT_VAL="1.1.1.1"; DEV_VAL="ON"  ;;
    esac

    cat <<EOF > "$CONFIG_FILE"
# Router Identification
ROUTER_NAME="$router_name_input" # Name that appears in Discord notifications.

# Discord Settings
DISCORD_URL="$user_webhook" # Your Discord Webhook URL.
MY_ID="$user_id" # Your Discord User ID (for @mentions).

# Monitoring Settings
SCAN_INTERVAL=10 # Seconds between pings. Default is 10.
FAIL_THRESHOLD=3 # Number of failed pings before sending an alert. Default is 3.
MAX_SIZE=512000 # Max log file size in bytes for the log rotation. Default 512KB.

# Heartbeat Settings
HEARTBEAT="$HB_VAL" # Set to ON to receive a periodic check-in message.
HB_INTERVAL=$HB_SEC # Interval in seconds. Default is 86400
HB_MENTION="$HB_MENTION" # Set to ON to include @mention in heartbeats.

# Internet Connectivity Check
EXT_IP="$EXT_VAL" # External IP to ping. Leave empty to disable.
EXT_INTERVAL=60 # Seconds between internet checks. Default is 60.

# Local Device Monitoring
DEVICE_MONITOR="$DEV_VAL" # Set to ON to enable local IP monitoring.
EOF

    cat <<EOF > "$IP_LIST_FILE"
# Format: IP_ADDRESS # NAME
# Example: 192.168.1.50 # Home Server
EOF
    
    LOCAL_IP=$(uci -q get network.lan.ipaddr || ip addr show br-lan | grep -oE 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 | awk '{print $2}')
    [ -n "$LOCAL_IP" ] && echo "$LOCAL_IP # Router Gateway" >> "$IP_LIST_FILE"
fi

# --- 4. CORE SCRIPT GENERATION ---
cat <<'EOF' > "$INSTALL_DIR/netwatchda.sh"
#!/bin/sh
# netwatchda - Network Monitoring for OpenWrt
# Copyright (C) 2025 panoc
# Licensed under the GNU General Public License v3.0

BASE_DIR=$(cd "$(dirname "$0")" && pwd)
IP_LIST_FILE="$BASE_DIR/netwatchda_ips.conf"
CONFIG_FILE="$BASE_DIR/netwatchda_settings.conf"
LOGFILE="/tmp/netwatchda_log.txt"
LAST_EXT_CHECK=0
LAST_HB_CHECK=$(date +%s)

while true; do
    [ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"
    
    NOW_HUMAN=$(date '+%b %d, %Y %H:%M:%S')
    NOW_SEC=$(date +%s)

    if [ -f "$LOGFILE" ] && [ $(wc -c < "$LOGFILE") -gt "$MAX_SIZE" ]; then
        echo "$NOW_HUMAN - Log rotated" > "$LOGFILE"
    fi

    PREFIX="📟 **Router:** $ROUTER_NAME\n"
    MENTION="\n🔔 **Attention:** <@$MY_ID>"
    IS_INT_DOWN=0

    # Heartbeat Logic
    if [ "$HEARTBEAT" = "ON" ] && [ $((NOW_SEC - LAST_HB_CHECK)) -ge "$HB_INTERVAL" ]; then
        LAST_HB_CHECK=$NOW_SEC
        HB_MSG="$NOW_HUMAN | $ROUTER_NAME | Router Online"
        if [ "$HB_MENTION" = "ON" ]; then
            P="{\"content\": \"💓 **Heartbeat**: $HB_MSG$MENTION\"}"
        else
            P="{\"content\": \"💓 **Heartbeat**: $HB_MSG\"}"
        fi
        curl -s -H "Content-Type: application/json" -X POST -d "$P" "$DISCORD_URL" > /dev/null 2>&1
    fi

    # Internet Check
    if [ -n "$EXT_IP" ] && [ $((NOW_SEC - LAST_EXT_CHECK)) -ge "$EXT_INTERVAL" ]; then
        LAST_EXT_CHECK=$NOW_SEC
        FD="/tmp/nwda_ext_d"; FT="/tmp/nwda_ext_t"
        if ! ping -q -c 1 -W 2 "$EXT_IP" > /dev/null 2>&1; then
            if [ ! -f "$FD" ]; then
                echo "$NOW_SEC" > "$FD"; echo "$NOW_HUMAN" > "$FT"
                echo "$NOW_HUMAN - ⚠️ INTERNET DOWN" >> "$LOGFILE"
            fi
        else
            if [ -f "$FD" ]; then
                S=$(cat "$FD"); T=$(cat "$FT"); D=$((NOW_SEC-S)); DR="$(($D/60))m $(($D%60))s"
                curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"$PREFIX🌐 **Internet Restored**\n❌ **Lost:** $T\n✅ **Restored:** $NOW_HUMAN\n**Outage:** $DR$MENTION\"}" "$DISCORD_URL" > /dev/null 2>&1
                rm -f "$FD" "$FT"
            fi
        fi
    fi
    [ -f "/tmp/nwda_ext_d" ] && IS_INT_DOWN=1

    # Local Device Check
    if [ "$DEVICE_MONITOR" = "ON" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in ""|\#*) continue ;; esac
            TIP=$(echo "$line" | cut -d'#' -f1 | xargs); NAME=$(echo "$line" | cut -s -d'#' -f2- | xargs)
            [ -z "$NAME" ] && NAME="Unknown"
            SIP=$(echo "$TIP" | tr '.' '_'); FC="/tmp/nwda_c_$SIP"; FD="/tmp/nwda_d_$SIP"
            if ping -q -c 1 -W 2 "$TIP" > /dev/null 2>&1; then
                if [ -f "$FD" ]; then
                    S=$(cat "$FD"); D=$((NOW_SEC-S)); DR="$(($D/60))m $(($D%60))s"
                    [ "$IS_INT_DOWN" -eq 0 ] && curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"$PREFIX✅ **RECOVERY**: **$NAME** is ONLINE\n**Down for:** $DR$MENTION\"}" "$DISCORD_URL" > /dev/null 2>&1
                    rm -f "$FD"
                fi
                echo 0 > "$FC"
            else
                C=$(($(cat "$FC" 2>/dev/null || echo 0)+1)); echo "$C" > "$FC"
                if [ "$C" -eq "$FAIL_THRESHOLD" ] && [ ! -f "$FD" ]; then
                    echo "$NOW_SEC" > "$FD"
                    [ "$IS_INT_DOWN" -eq 0 ] && curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"$PREFIX🔴 **ALERT**: **$NAME** ($TIP) is DOWN!$MENTION\"}" "$DISCORD_URL" > /dev/null 2>&1
                fi
            fi
        done < "$IP_LIST_FILE"
    fi
    sleep "$SCAN_INTERVAL"
done
EOF

# --- 5. SERVICE SETUP ---
chmod +x "$INSTALL_DIR/netwatchda.sh"
cat <<EOF > "$SERVICE_PATH"
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1
start_service() {
    procd_open_instance
    procd_set_param command /bin/sh "$INSTALL_DIR/netwatchda.sh"
    procd_set_param respawn
    procd_close_instance
}
EOF
chmod +x "$SERVICE_PATH"
"$SERVICE_PATH" enable
"$SERVICE_PATH" restart

# --- 6. SUCCESS NOTIFICATION ---
. "$CONFIG_FILE"
NOW_FINAL=$(date '+%b %d, %Y %H:%M:%S')
curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"✅ **netwatchda Service Started**\n**Router:** $ROUTER_NAME\n**Time:** $NOW_FINAL\nMonitoring is active in the background.\"}" "$DISCORD_URL" > /dev/null

rm -- "$0"

# --- FINAL OUTPUT ---
echo "---"
echo "✅ Installation complete!"
echo "📂 Folder: $INSTALL_DIR"
echo "---"
echo "Next Steps:"
echo "1. Edit Settings: $CONFIG_FILE"
echo "2. Edit IP List:  $IP_LIST_FILE"
echo "3. Restart:       /etc/init.d/netwatchda restart"
echo " "
echo "Monitoring logs: tail -f /tmp/netwatchda_log.txt"
echo "-------------------------------------------------------"
echo ""