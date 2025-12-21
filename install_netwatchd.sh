#!/bin/sh

# --- INITIAL SPACING ---
echo ""
echo "-------------------------------------------------------"
echo "🚀 Starting netwatchd Automated Setup..."
echo "-------------------------------------------------------"

# --- CONFIGURATION ---
INSTALL_DIR="/root/netwatchd"
SERVICE_NAME="netwatchd"
SERVICE_PATH="/etc/init.d/$SERVICE_NAME"
BACKUP_DIR="/tmp/netwatchd_backup"

# --- 1. SAFETY BACKUP ---
if [ -d "$INSTALL_DIR" ]; then
    echo "💾 Creating safety backup in $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    cp "$INSTALL_DIR"/*.conf "$BACKUP_DIR/" 2>/dev/null
fi

# --- 2. CHECK DEPENDENCIES ---
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

# --- 3. CHECK FOR EXISTING INSTALLATION ---
KEEP_CONFIG=0
if [ -d "$INSTALL_DIR" ] || [ -f "$SERVICE_PATH" ]; then
    echo "⚠️ Existing installation found."
    printf "Do you want to (c)lean install or (k)eep existing settings? [c/k]: "
    read choice </dev/tty
    case "$choice" in
        k|K ) KEEP_CONFIG=1 ;;
        * ) 
            /etc/init.d/netwatchd stop 2>/dev/null
            rm -f "$SERVICE_PATH"
            rm -rf "$INSTALL_DIR"
            ;;
    esac
fi

mkdir -p "$INSTALL_DIR"

# --- 4. CLEAN INSTALL INPUTS & VALIDATION ---
if [ "$KEEP_CONFIG" -eq 0 ]; then
    echo "---"
    printf "🔗 Enter Discord Webhook URL: "
    read user_webhook </dev/tty
    printf "👤 Enter Discord User ID (for @mentions): "
    read user_id </dev/tty
    
    echo "🧪 Sending test notification to Discord..."
    TEST_PAYLOAD="{\"content\": \"📟 **Router Setup**: Connectivity test successful! <@$user_id>\"}"
    curl -s -H "Content-Type: application/json" -X POST -d "$TEST_PAYLOAD" "$user_webhook" > /dev/null
    
    echo "---"
    printf "❓ Did you receive the Discord notification? [y/n]: "
    read confirm_test </dev/tty
    
    if [ "$confirm_test" != "y" ] && [ "$confirm_test" != "Y" ]; then
        echo "❌ Installation Aborted. Please check your Webhook URL and try again."
        rm -rf "$INSTALL_DIR"
        exit 1
    fi
    echo "✅ Connectivity confirmed."

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
    echo "✅ Mode set to: $MODE"
fi

# --- 5. CREATE SETTINGS ---
if [ "$KEEP_CONFIG" -eq 0 ]; then
    cat <<EOF > "$INSTALL_DIR/netwatchd_settings.conf"
# Router Identification
ROUTER_NAME="My_OpenWrt_Router" # This name appears in Discord notifications to identify which device is reporting.

# Discord Settings
DISCORD_URL="$user_webhook" # Your Discord Webhook URL.
MY_ID="$user_id" # Your Discord User ID (for @mentions).

# Monitoring Settings
SCAN_INTERVAL=10 # Seconds between pings. Default is 10.
FAIL_THRESHOLD=3 # Number of failed pings before sending an alert. Default is 3.
MAX_SIZE=512000 # Max log file size in bytes for the log rotation in bytes. Default is 512KB

# Internet Connectivity Check
EXT_IP="$EXT_VAL" # External IP to ping (e.g., 1.1.1.1). Leave empty to disable.
EXT_INTERVAL=60 # Seconds between internet checks. Default is 60.

# Local Device Monitoring
DEVICE_MONITOR="$DEV_VAL" # Set to ON to enable local IP monitoring from netwatchd_ips.conf.
EOF

    cat <<EOF > "$INSTALL_DIR/netwatchd_ips.conf"
# Format: IP_ADDRESS # NAME
# Example: 192.168.1.50 # Home Server
EOF

    if [ "$DEV_VAL" = "ON" ]; then
        LOCAL_IP=$(uci -q get network.lan.ipaddr || ip addr show br-lan | grep -oE 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 | awk '{print $2}')
        if [ -n "$LOCAL_IP" ]; then
            echo "$LOCAL_IP # Router Gateway" >> "$INSTALL_DIR/netwatchd_ips.conf"
            echo "🏠 Added local IP ($LOCAL_IP) to monitor list."
        fi
    fi
fi

# --- 6. CREATE SCRIPT ---
cat <<'EOF' > "$INSTALL_DIR/netwatchd.sh"
#!/bin/sh
BASE_DIR=$(cd "$(dirname "$0")" && pwd)
IP_LIST_FILE="$BASE_DIR/netwatchd_ips.conf"
CONFIG_FILE="$BASE_DIR/netwatchd_settings.conf"
LOGFILE="/tmp/netwatchd_log.txt"
LAST_EXT_CHECK=0

while true; do
    [ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"
    
    if [ -f "$LOGFILE" ]; then
        FILESIZE=$(wc -c < "$LOGFILE")
        if [ "$FILESIZE" -gt "$MAX_SIZE" ]; then
            echo "$(date '+%b %d, %H:%M:%S') - Log rotated" > "$LOGFILE"
        fi
    fi

    NOW_SEC=$(date +%s)
    NOW_HUMAN=$(date '+%b %d, %H:%M:%S')
    PREFIX="📟 **Router:** $ROUTER_NAME\n"
    MENTION="\n🔔 **Attention:** <@$MY_ID>"
    IS_INTERNET_DOWN=0

    if [ -n "$EXT_IP" ]; then
        FILE_EXT_DOWN="/tmp/netwatchd_ext_down"
        FILE_EXT_TIME="/tmp/netwatchd_ext_time"
        if [ $((NOW_SEC - LAST_EXT_CHECK)) -ge "$EXT_INTERVAL" ]; then
            LAST_EXT_CHECK=$NOW_SEC
            if ! ping -q -c 1 -W 2 "$EXT_IP" > /dev/null 2>&1; then
                if [ ! -f "$FILE_EXT_DOWN" ]; then
                    echo "$NOW_HUMAN - ⚠️ INTERNET DOWN" >> "$LOGFILE"
                    echo "$NOW_SEC" > "$FILE_EXT_DOWN"
                    echo "$NOW_HUMAN" > "$FILE_EXT_TIME"
                fi
            else
                if [ -f "$FILE_EXT_DOWN" ]; then
                    START_EXT=$(cat "$FILE_EXT_DOWN"); TIME_LOST=$(cat "$FILE_EXT_TIME")
                    D_EXT=$((NOW_SEC - START_EXT)); DUR_EXT="$(($D_EXT / 60))m $(($D_EXT % 60))s"
                    echo "$NOW_HUMAN - ✅ INTERNET RECOVERY" >> "$LOGFILE"
                    curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"$PREFIX🌐 **Internet Restored**\n❌ **Lost at:** $TIME_LOST\n✅ **Restored at:** $NOW_HUMAN\n**Total Outage:** $DUR_EXT$MENTION\"}" "$DISCORD_URL" > /dev/null 2>&1
                    rm -f "$FILE_EXT_DOWN" "$FILE_EXT_TIME"
                fi
            fi
        fi
        [ -f "$FILE_EXT_DOWN" ] && IS_INTERNET_DOWN=1
    fi

    if [ "$DEVICE_MONITOR" = "ON" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            line=$(echo "$line" | tr -d '\r' | xargs 2>/dev/null)
            [ -z "$line" ] || [ "${line#\#}" != "$line" ] && continue
            TARGET_IP=$(echo "$line" | cut -d'#' -f1 | sed 's/[[:space:]]*$//')
            NAME=$(echo "$line" | cut -s -d'#' -f2- | sed 's/^[[:space:]]*//')
            [ -z "$NAME" ] && NAME="Unknown"
            SAFE_IP=$(echo "$TARGET_IP" | tr '.' '_')
            F_COUNT="/tmp/nw_cnt_$SAFE_IP"; F_DOWN="/tmp/nw_down_$SAFE_IP"

            if ping -q -c 1 -W 2 "$TARGET_IP" > /dev/null 2>&1; then
                if [ -f "$F_DOWN" ]; then
                    START=$(cat "$F_DOWN"); D=$((NOW_SEC - START)); DUR="$(($D / 60))m $(($D % 60))s"
                    echo "$NOW_HUMAN - ✅ RECOVERY: $NAME" >> "$LOGFILE"
                    if [ "$IS_INTERNET_DOWN" -eq 0 ]; then
                        curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"$PREFIX✅ **RECOVERY**: **$NAME** is ONLINE\n**Time:** $NOW_HUMAN\n**Down for:** $DUR$MENTION\"}" "$DISCORD_URL" > /dev/null 2>&1
                        rm -f "$F_DOWN"
                    fi
                fi
                echo 0 > "$F_COUNT"
            else
                COUNT=$(($(cat "$F_COUNT" 2>/dev/null || echo 0) + 1)); echo "$COUNT" > "$F_COUNT"
                if [ "$COUNT" -eq "$FAIL_THRESHOLD" ] && [ ! -f "$F_DOWN" ]; then
                    echo "$NOW_SEC" > "$F_DOWN"
                    echo "$NOW_HUMAN - 🔴 DOWN: $NAME" >> "$LOGFILE"
                    if [ "$IS_INTERNET_DOWN" -eq 0 ]; then
                        curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"$PREFIX🔴 **ALERT**: **$NAME** ($TARGET_IP) is DOWN!\n**Time:** $NOW_HUMAN$MENTION\"}" "$DISCORD_URL" > /dev/null 2>&1
                    fi
                fi
            fi
        done < "$IP_LIST_FILE"
    fi
    sleep "$SCAN_INTERVAL"
done
EOF

# --- 7. SERVICE SETUP ---
chmod +x "$INSTALL_DIR/netwatchd.sh"
cat <<EOF > "$SERVICE_PATH"
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1
start_service() {
    procd_open_instance
    procd_set_param command /bin/sh "$INSTALL_DIR/netwatchd.sh"
    procd_set_param respawn
    procd_close_instance
}
EOF
chmod +x "$SERVICE_PATH"

# --- 8. START & FINAL MESSAGE ---
"$SERVICE_PATH" enable
"$SERVICE_PATH" restart
rm -- "$0"

echo "---"
echo "✅ Installation complete!"
echo "📂 Folder: $INSTALL_DIR"
echo "---"
echo "Next Steps:"
echo "1. Edit Settings: $INSTALL_DIR/netwatchd_settings.conf"
echo "2. Edit IP List:  $INSTALL_DIR/netwatchd_ips.conf"
echo "3. Restart:       /etc/init.d/netwatchd restart"
echo ""