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
# --- Discord Settings ---
DISCORD_URL=""
MY_ID=""

# --- Internet Check ---
EXT_IP="1.1.1.1"
EXT_INTERVAL=60

# --- Logic Settings ---
SCAN_INTERVAL=10
FAIL_THRESHOLD=3
MAX_SIZE=512000
EOF

# 4. Create netwatchd_ips.conf
cat <<EOF > "$INSTALL_DIR/netwatchd_ips.conf"
# Format: IP_ADDRESS # NAME
8.8.8.8 # Google DNS
1.1.1.1 # Cloudflare DNS
EOF

# 5. Create netwatchd.sh
cat <<'EOF' > "$INSTALL_DIR/netwatchd.sh"
#!/bin/sh
BASE_DIR=$(cd "$(dirname "$0")" && pwd)
IP_LIST_FILE="$BASE_DIR/netwatchd_ips.conf"
CONFIG_FILE="$BASE_DIR/netwatchd_settings.conf"
LOGFILE="/tmp/netwatchd_log.txt"

SCAN_INTERVAL=10; EXT_INTERVAL=30; FAIL_THRESHOLD=3; MAX_SIZE=512000; LAST_EXT_CHECK=0

while true; do
    [ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"
    NOW_SEC=$(date +%s); NOW_HUMAN=$(date '+%b %d, %H:%M:%S')

    if [ -f "$LOGFILE" ] && [ $(wc -c < "$LOGFILE") -gt "$MAX_SIZE" ]; then
        echo "--- Log limit reached, cleared at $NOW_HUMAN ---" > "$LOGFILE"
    fi

    if [ -n "$EXT_IP" ] && [ $((NOW_SEC - LAST_EXT_CHECK)) -ge "$EXT_INTERVAL" ]; then
        LAST_EXT_CHECK=$NOW_SEC
        FILE_EXT_DOWN="/tmp/netwatchd_ext_down"
        if ! ping -q -c 1 -W 2 "$EXT_IP" > /dev/null 2>&1; then
            if [ ! -f "$FILE_EXT_DOWN" ]; then
                echo "$NOW_HUMAN - ⚠️ INTERNET DOWN" >> "$LOGFILE"
                echo "$NOW_SEC" > "$FILE_EXT_DOWN"
            fi
        else
            if [ -f "$FILE_EXT_DOWN" ]; then
                START_EXT=$(cat "$FILE_EXT_DOWN")
                DUR_EXT="$(( (NOW_SEC - START_EXT) / 60 ))m $(( (NOW_SEC - START_EXT) % 60 ))s"
                echo "$NOW_HUMAN - ✅ INTERNET RECOVERY (Down for $DUR_EXT)" >> "$LOGFILE"
                [ -n "$DISCORD_URL" ] && curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"🌐 **Network Restored**: **$EXT_IP**\n⏱️ **Outage:** $DUR_EXT\"}" "$DISCORD_URL" > /dev/null 2>&1
                rm "$FILE_EXT_DOWN"
            fi
        fi
    fi

    IS_INTERNET_DOWN=0
    [ -f "/tmp/netwatchd_ext_down" ] && IS_INTERNET_DOWN=1

    while IFS= read -r line || [ -n "$line" ]; do
        line=$(echo "$line" | tr -d '\r' | xargs 2>/dev/null || echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -z "$line" ] || [ "${line#\#}" != "$line" ] && continue
        TARGET_IP=$(echo "$line" | cut -d'#' -f1 | sed 's/[[:space:]]*$//')
        NAME=$(echo "$line" | cut -s -d'#' -f2- | sed 's/^[[:space:]]*//')
        [ -z "$NAME" ] && NAME="Unknown"
        ping -q -c 1 -W 2 "$TARGET_IP" > /dev/null 2>&1
        STATUS=$?
        SAFE_IP=$(echo "$TARGET_IP" | tr '.' '_')
        F_COUNT="/tmp/nw_cnt_$SAFE_IP"; F_DOWN="/tmp/nw_down_$SAFE_IP"; F_Q_FAIL="/tmp/nw_q_fail_$SAFE_IP"; F_Q_REC="/tmp/nw_q_rec_$SAFE_IP"
        if [ "$STATUS" -eq 0 ]; then
            if [ -f "$F_DOWN" ]; then
                START=$(cat "$F_DOWN"); DUR="$(( (NOW_SEC - START) / 60 ))m $(( (NOW_SEC - START) % 60 ))s"
                echo "$NOW_HUMAN - ✅ RECOVERY: $NAME ($TARGET_IP) - Down for $DUR" >> "$LOGFILE"
                if [ "$IS_INTERNET_DOWN" -eq 0 ]; then
                    [ -f "$F_Q_FAIL" ] && { curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"🚨 **$NAME** went DOWN (Delayed)\"}" "$DISCORD_URL" > /dev/null 2>&1; rm "$F_Q_FAIL"; sleep 1; }
                    curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"✅ **RECOVERY**: **$NAME** is ONLINE\n⏱️ **Down for:** $DUR\"}" "$DISCORD_URL" > /dev/null 2>&1
                    rm "$F_DOWN"
                else
                    [ ! -f "$F_Q_FAIL" ] && touch "$F_Q_FAIL"
                    echo "$DUR" > "$F_Q_REC"
                fi
            fi
            echo 0 > "$F_COUNT"
        else
            COUNT=$(($(cat "$F_COUNT" 2>/dev/null || echo 0) + 1)); echo "$COUNT" > "$F_COUNT"
            if [ "$COUNT" -eq "$FAIL_THRESHOLD" ] && [ ! -f "$F_DOWN" ]; then
                echo "$NOW_SEC" > "$F_DOWN"; echo "$NOW_HUMAN - 🚨 DOWN: $NAME" >> "$LOGFILE"
                if [ "$IS_INTERNET_DOWN" -eq 0 ]; then
                    curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"🚨 **ALERT**: **$NAME** is DOWN!\"}" "$DISCORD_URL" > /dev/null 2>&1
                else
                    touch "$F_Q_FAIL"
                fi
            fi
        fi
        if [ "$IS_INTERNET_DOWN" -eq 0 ]; then
            if [ -f "$F_Q_REC" ]; then
                DUR_REC=$(cat "$F_Q_REC")
                curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"🚨 **$NAME** went DOWN (Queued)\"}" "$DISCORD_URL" > /dev/null 2>&1; sleep 1
                curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"✅ **RECOVERY**: **$NAME** is ONLINE\n⏱️ **Down for:** $DUR_REC\"}" "$DISCORD_URL" > /dev/null 2>&1
                rm -f "$F_DOWN" "$F_Q_REC" "$F_Q_FAIL"
            elif [ -f "$F_Q_FAIL" ]; then
                curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"🚨 **$NAME** is DOWN! (Delayed)\"}" "$DISCORD_URL" > /dev/null 2>&1; rm "$F_Q_FAIL"
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
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}
EOF
chmod +x "$SERVICE_PATH"
"$SERVICE_PATH" enable
"$SERVICE_PATH" start

echo "---"
echo "✅ Installation complete!"
echo "📂 Folder: $INSTALL_DIR"
echo "🚀 Service is running."
echo "---"
echo "Opening settings file in 3 seconds... (Paste your Discord URL then save)"
sleep 3
vi "$INSTALL_DIR/netwatchd_settings.conf"

# After user closes vi, remind them to restart
echo "---"
echo "💡 To apply your new settings, run: /etc/init.d/netwatchd restart"
