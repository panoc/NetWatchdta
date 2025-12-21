#!/bin/sh

# --- INITIAL SPACING ---
echo ""
echo "-------------------------------------------------------"
echo "🗑️  netwatchd Uninstaller (GitHub Version)"
echo "-------------------------------------------------------"

INSTALL_DIR="/root/netwatchd"
SERVICE_NAME="netwatchd"
SERVICE_PATH="/etc/init.d/$SERVICE_NAME"

# --- 1. STOP AND DISABLE SERVICE ---
if [ -f "$SERVICE_PATH" ]; then
    echo "🛑 Stopping and disabling $SERVICE_NAME service..."
    $SERVICE_PATH stop 2>/dev/null
    $SERVICE_PATH disable 2>/dev/null
    rm -f "$SERVICE_PATH"
    echo "✅ System service entry removed."
else
    echo "ℹ️  No active service found in $SERVICE_PATH."
fi

# --- 2. ASK TO KEEP SETTINGS ---
if [ -d "$INSTALL_DIR" ]; then
    echo "---"
    printf "❓ Keep configuration files (settings & IP list)? [y/n]: "
    read keep_choice

    case "$keep_choice" in
        y|Y ) 
            echo "💾 Preserving configuration in $INSTALL_DIR"
            # Remove only the binary/script and logs
            rm -f "$INSTALL_DIR/netwatchd.sh"
            rm -f "$INSTALL_DIR/*.txt" 2>/dev/null
            echo "✅ Core script removed. Settings files remain."
            ;;
        * ) 
            echo "🧹 Removing all files in $INSTALL_DIR..."
            rm -rf "$INSTALL_DIR"
            echo "✅ Entire directory deleted."
            ;;
    esac
else
    echo "❌ Directory $INSTALL_DIR not found. Nothing to remove."
fi

# --- 3. CLEAN UP TEMP FILES ---
echo "🧹 Purging temporary state files from RAM..."
rm -f /tmp/nw_cnt_* 2>/dev/null
rm -f /tmp/nw_down_* 2>/dev/null
rm -f /tmp/netwatchd_* 2>/dev/null

echo "---"
echo "✨ netwatchd has been successfully uninstalled."
echo "-------------------------------------------------------"
echo ""

# Optional: Self-destruct after running
# rm -- "$0"