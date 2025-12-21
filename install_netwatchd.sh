#!/bin/sh

# --- CONFIGURATION ---
INSTALL_DIR="/root/netwatchd"
SERVICE_NAME="netwatchd"
SERVICE_PATH="/etc/init.d/$SERVICE_NAME"

echo "🚀 Starting netwatchd Automated Setup..."

# --- 1. CHECK FOR EXISTING INSTALLATION ---
KEEP_CONFIG=0
if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️ Existing installation found at $INSTALL_DIR"
    printf "Do you want to (c)lean install or (k)eep existing settings? [c/k]: "
    read choice
    case "$choice" in
        k|K ) 
            echo "💾 Keeping existing configuration files."
            KEEP_CONFIG=1
            ;;
        * ) 
            echo "🗑️ Performing clean install..."
            /etc/init.d/netwatchd stop 2>/dev/null
            rm -rf "$INSTALL_DIR"
            ;;
    esac
fi

# Create the Directory Structure
if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
fi

# --- 2. CHECK DEPENDENCIES ---
if ! command -v curl >/dev/null 2>&1; then
    echo "📦 curl not found. Installing..."
    opkg update && opkg install curl ca-bundle
fi

# --- 3. CREATE/PRESERVE SETTINGS ---
if [ "$KEEP_CONFIG" -eq 0 ]; then
    cat <<EOF > "$INSTALL_DIR/netwatchd_settings.conf"
# Router Identification
ROUTER_NAME="My_OpenWrt_Router" # This name will now appear at the top of every Discord notification, making it easy to identify which device is reporting if you manage multiple routers.

# Discord Settings
DISCORD_URL="https://discord.com/api/webhooks/Your_Discord IP"
MY_ID="123456789123456789"

# Monitoring Settings
SCAN_INTERVAL=10 # Default 10
FAIL_THRESHOLD=3 # Default 3
MAX_SIZE=512000  # Default 512000

# Internet Check
EXT_IP="1.1.1.1" 
EXT_INTERVAL=60
EOF

    cat <<EOF > "$INSTALL_DIR/netwatchd_ips.conf"
# Format: IP_ADDRESS # NAME
8.8.8.8 # Google DNS
1.1.1.1 # Cloudflare DNS
EOF
else
    echo "✅ Preserved: netwatchd_settings.conf & netwatchd_ips.conf"
fi

# --- 4. CREATE SCRIPT (THE BRAINS) ---
# This part always updates to ensure you have the latest logic
cat <<'EOF' > "$INSTALL_DIR/netwatchd.sh"
#!/bin/sh
BASE_DIR=$(cd "$(dirname "$0")" && pwd)
IP_LIST_FILE="$BASE_DIR/netwatchd_ips.conf"
CONFIG_FILE="$BASE_DIR/netwatchd_settings.conf"
LOGFILE="/tmp/netwatchd_log.txt"

LAST_EXT_CHECK=0

while true; do
    [ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"
    
    NOW_SEC=$(date +%s)
    NOW_HUMAN=$(date '+%b %d, %H:%M:%S')
    PREFIX="📟 **Router:** $ROUTER_NAME\n"
    MENTION="\n🔔 **Attention:** <@$MY_ID>"

    # --- Internet Check ---
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
                START_EXT=$(cat "$FILE_EXT_DOWN")
                TIME_LOST=$(cat "$FILE_EXT_TIME")
                D_EXT=$((NOW_SEC - START_EXT))
                DUR_EXT="$(($D_EXT / 60))m $(($D_EXT % 60))s"
                
                echo "$NOW_HUMAN - ✅ INTERNET RECOVERY" >> "$LOGFILE"
                curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"$PREFIX🌐 **Internet Restored**\n❌ **Lost at:** $TIME_LOST\n✅ **Restored at:** $NOW_HUMAN\n**Total Outage:** $DUR_EXT$MENTION\"}" "$DISCORD_URL" > /dev/null 2>&1
                rm "$FILE_EXT_DOWN" "$FILE_EXT_TIME"
            fi
        fi
    fi

    IS_INTERNET_DOWN=0
    [ -f "$FILE_EXT_DOWN" ] && IS_INTERNET_DOWN=1

    # --- Device Scan ---
    while IFS= read -r line || [ -n "$line" ]; do
        line=$(echo "$line" | tr -d '\r' | xargs 2>/dev/null)
        [ -z "$line" ] || [ "${line#\#}" != "$line" ] && continue
        
        TARGET_IP=$(echo "$line" | cut -d'#' -f1 | sed 's/[[:space:]]*$//')
        NAME=$(echo "$line" | cut -s -d'#' -f2- | sed 's/^[[:space:]]*//')
        [ -z "$NAME" ] && NAME="Unknown"

        SAFE_IP=$(echo "$TARGET_IP" | tr '.' '_')
        F_COUNT="/tmp/nw_cnt_$SAFE_IP"; F_DOWN="/tmp/nw_down_$SAFE_IP"; F_Q_FAIL="/tmp/nw_q_fail_$SAFE_IP"; F_Q_REC="/tmp/nw_q_rec_$SAFE_IP"

        if ping -q -c 1 -W 2 "$TARGET_IP" > /dev/null 2>&1; then
            if [ -f "$F_DOWN" ]; then
                START=$(cat "$F_DOWN"); D=$((NOW_SEC - START)); DUR="$(($D / 60))m $(($D % 60))s"
                echo "$NOW_HUMAN - ✅ RECOVERY: $NAME ($TARGET_IP)" >> "$LOGFILE"
                if [ "$IS_INTERNET_DOWN" -eq 0 ]; then
                    curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"$PREFIX✅ **RECOVERY**: **$NAME** is ONLINE\n**Time:** $NOW_HUMAN\n**Down for:** $DUR$MENTION\"}" "$DISCORD_URL" > /dev/null 2>&1
                    rm -f "$F_DOWN" "$F_Q_FAIL" "$F_Q_REC"
                else
                    touch "$F_Q_REC"
                    echo "$DUR" > "/tmp/nw_dur_$SAFE_IP"
                    echo "$NOW_HUMAN" > "/tmp/nw_time_$SAFE_IP"
                fi
            fi
            echo 0 > "$F_COUNT"
        else
            COUNT=$(($(cat "$F_COUNT" 2>/dev/null || echo 0) + 1)); echo "$COUNT" > "$F_COUNT"
            if [ "$COUNT" -eq "$FAIL_THRESHOLD" ] && [ ! -f "$F_DOWN" ]; then
                echo "$NOW_SEC" > "$F_DOWN"
                echo "$NOW_HUMAN - 🔴 DOWN: $NAME ($TARGET_IP)" >> "$LOGFILE"
                if [ "$IS_INTERNET_DOWN" -eq 0 ]; then
                    curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"$PREFIX🔴 **ALERT**: **$NAME** ($TARGET_IP) is DOWN!\n**Time:** $NOW_HUMAN$MENTION\"}" "$DISCORD_URL" > /dev/null 2>&1
                else
                    touch "$F_Q_FAIL"
                    echo "$NOW_HUMAN" > "/tmp/nw_time_$SAFE_IP"
                fi
            fi
        fi

        if [ "$IS_INTERNET_DOWN" -eq 0 ]; then
            if [ -f "$F_Q_REC" ]; then
                DUR_VAL=$(cat "/tmp/nw_dur_$SAFE_IP"); T_VAL=$(cat "/tmp/nw_time_$SAFE_IP")
                curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"$PREFIX🔴 **$NAME** ($TARGET_IP) was DOWN.\n**Detected at:** $T_VAL\n✅ **Now ONLINE** (Total: $DUR_VAL)$MENTION\"}" "$DISCORD_URL" > /dev/null 2>&1
                rm -f "$F_DOWN" "$F_Q_FAIL" "$F_Q_REC" "/tmp/nw_dur_$SAFE_IP" "/tmp/nw_time_$SAFE_IP"
            elif [ -f "$F_Q_FAIL" ]; then
                T_VAL=$(cat "/tmp/nw_time_$SAFE_IP")
                curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"$PREFIX🔴 **ALERT**: **$NAME** ($TARGET_IP) is DOWN!\n**Detected at:** $T_VAL$MENTION\"}" "$DISCORD_URL" > /dev/null 2>&1
                rm -f "$F_Q_FAIL" "/tmp/nw_time_$SAFE_IP"
            fi
        fi
    done < "$IP_LIST_FILE"
    sleep "$SCAN_INTERVAL"
done
EOF

# --- 5. SERVICE SETUP ---
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

# --- 6. START & CLEANUP ---
"$SERVICE_PATH" enable
"$SERVICE_PATH" restart
rm -- "$0"

echo "---"
echo "✅ Installation complete!"
echo "📂 Folder: $INSTALL_DIR"
if [ "$KEEP_CONFIG" -eq 1 ]; then
    echo "ℹ️  Settings were preserved."
fi
echo "---"