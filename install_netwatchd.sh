#!/bin/sh

# --- CONFIGURATION ---
INSTALL_DIR="/root/netwatchd"
SERVICE_NAME="netwatchd"
SERVICE_PATH="/etc/init.d/$SERVICE_NAME"

echo "🚀 Starting netwatchd Automated Setup..."

# 1. Create the Directory Structure
if [ ! -d "$INSTALL_DIR" ]; then
    echo "📁 Creating directory $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR"
fi

# 2. Check Dependencies
if ! command -v curl >/dev/null 2>&1; then
    echo "📦 curl not found. Installing..."
    opkg update && opkg install curl ca-bundle
fi

# 3. Create netwatchd_settings.conf
cat <<EOF > "$INSTALL_DIR/netwatchd_settings.conf"
# Discord Settings
DISCORD_URL="https://discord.com/api/webhooks/your_id"
MY_ID="123456789012345678"

# Monitoring Settings
SCAN_INTERVAL=10
FAIL_THRESHOLD=3
MAX_SIZE=512000

# Internet Check
EXT_IP="1.1.1.1"
EXT_INTERVAL=60
EOF

# 4. Create netwatchd_ips.conf
cat <<EOF > "$INSTALL_DIR/netwatchd_ips.conf"
# Format: IP_ADDRESS # NAME
8.8.8.8 # Google DNS
1.1.1.1 # Cloudflare DNS
EOF

# 5. Create netwatchd.sh (The Brains)
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

    # --- Internet Check ---
    FILE_EXT_DOWN="/tmp/netwatchd_ext_down"
    if [ $((NOW_SEC - LAST_EXT_CHECK)) -ge "$EXT_INTERVAL" ]; then
        LAST_EXT_CHECK=$NOW_SEC
        if ! ping -q -c 1 -W 2 "$EXT_IP" > /dev/null 2>&1; then
            if [ ! -f "$FILE_EXT_DOWN" ]; then
                echo "$NOW_HUMAN - ⚠️ INTERNET DOWN" >> "$LOGFILE"
                echo "$NOW_SEC" > "$FILE_EXT_DOWN"
            fi
        else
            if [ -f "$FILE_EXT_DOWN" ]; then
                START_EXT=$(cat "$FILE_EXT_DOWN")
                D_EXT=$((NOW_SEC - START_EXT))
                DUR_EXT="$(($D_EXT / 60))m $(($D_EXT % 60))s"
                echo "$NOW_HUMAN - ✅ INTERNET RECOVERY (Down for $DUR_EXT)" >> "$LOGFILE"
                # Internet is back, we can send the recovery alert immediately
                curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"🌐 **Internet Restored**\n⏱️ **Outage Duration:** $DUR_EXT\"}" "$DISCORD_URL" > /dev/null 2>&1
                rm "$FILE_EXT_DOWN"
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
                    # Internet is UP: Send now
                    curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"✅ **RECOVERY**: **$NAME** is ONLINE\n⏱️ **Down for:** $DUR\"}" "$DISCORD_URL" > /dev/null 2>&1
                    rm -f "$F_DOWN" "$F_Q_FAIL" "$F_Q_REC"
                else
                    # Internet is DOWN: Queue it
                    touch "$F_Q_REC"
                    echo "$DUR" > "/tmp/nw_dur_$SAFE_IP"
                fi
            fi
            echo 0 > "$F_COUNT"
        else
            COUNT=$(($(cat "$F_COUNT" 2>/dev/null || echo 0) + 1)); echo "$COUNT" > "$F_COUNT"
            if [ "$COUNT" -eq "$FAIL_THRESHOLD" ] && [ ! -f "$F_DOWN" ]; then
                echo "$NOW_SEC" > "$F_DOWN"
                echo "$NOW_HUMAN - 🚨 DOWN: $NAME ($TARGET_IP)" >> "$LOGFILE"
                
                if [ "$IS_INTERNET_DOWN" -eq 0 ]; then
                    curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"🚨 **ALERT**: **$NAME** ($TARGET_IP) is DOWN!\"}" "$DISCORD_URL" > /dev/null 2>&1
                else
                    touch "$F_Q_FAIL"
                fi
            fi
        fi

        # --- Check Queue if Internet just came back ---
        if [ "$IS_INTERNET_DOWN" -eq 0 ]; then
            if [ -f "$F_Q_REC" ]; then
                DUR_VAL=$(cat "/tmp/nw_dur_$SAFE_IP")
                curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"🚨 **$NAME** ($TARGET_IP) was DOWN during outage.\n✅ Now ONLINE. (Total Down: $DUR_VAL)\"}" "$DISCORD_URL" > /dev/null 2>&1
                rm -f "$F_DOWN" "$F_Q_FAIL" "$F_Q_REC" "/tmp/nw_dur_$SAFE_IP"
            elif [ -f "$F_Q_FAIL" ]; then
                curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"🚨 **ALERT**: **$NAME** ($TARGET_IP) is DOWN! (Reported after internet recovery)\"}" "$DISCORD_URL" > /dev/null 2>&1
                rm -f "$F_Q_FAIL"
            fi
        fi
    done < "$IP_LIST_FILE"
    sleep "$SCAN_INTERVAL"
done
EOF

# 6. Service Setup
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

# 7. Start
"$SERVICE_PATH" enable
"$SERVICE_PATH" restart
echo "✅ Fixed! Alerts will now wait for Internet Connectivity."