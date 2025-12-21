#!/bin/sh

# --- CONFIGURATION ---
INSTALL_DIR="/root/netwatchd"
SERVICE_NAME="netwatchd"
SERVICE_PATH="/etc/init.d/$SERVICE_NAME"

echo "🚀 Starting netwatchd Automated Setup..."

# 1. Create the Directory Structure first
if [ ! -d "$INSTALL_DIR" ]; then
    echo "📁 Creating directory $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR"
fi

# 2. Check Dependencies
if ! command -v curl >/dev/null 2>&1; then
    echo "📦 curl not found. Installing..."
    opkg update && opkg install curl ca-bundle
fi

# 3. Create netwatchd_settings.conf (with defaults)
cat <<EOF > "$INSTALL_DIR/netwatchd_settings.conf"
DISCORD_URL=""
MY_ID=""
EXT_IP="1.1.1.1"
EXT_INTERVAL=60
SCAN_INTERVAL=10
FAIL_THRESHOLD=3
MAX_SIZE=512000
EOF

# 4. Create netwatchd_ips.conf
cat <<EOF > "$INSTALL_DIR/netwatchd_ips.conf"
8.8.8.8 # Google DNS
1.1.1.1 # Cloudflare DNS
EOF

# 5. Create netwatchd.sh (The logic)
cat <<'EOF' > "$INSTALL_DIR/netwatchd.sh"
#!/bin/sh
BASE_DIR=$(cd "$(dirname "$0")" && pwd)
IP_LIST_FILE="$BASE_DIR/netwatchd_ips.conf"
CONFIG_FILE="$BASE_DIR/netwatchd_settings.conf"
LOGFILE="/tmp/netwatchd_log.txt"
# Logic follows... (use the logic from previous messages)
EOF

# 6. Install as Service
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

echo "✅ Done! Settings at $INSTALL_DIR/netwatchd_settings.conf"
