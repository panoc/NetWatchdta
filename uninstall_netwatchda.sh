#!/bin/sh
# netwatchda Uninstaller - Automated Removal for OpenWrt
# Copyright (C) 2025 panoc
# Licensed under the GNU General Public License v3.0

# --- INITIAL SPACING ---
echo ""
echo "-------------------------------------------------------"
echo "🗑️  Starting netwatchda Uninstallation..."
echo "👤 Author: panoc"
echo "-------------------------------------------------------"

INSTALL_DIR="/root/netwatchda"
SERVICE_NAME="netwatchda"
SERVICE_PATH="/etc/init.d/$SERVICE_NAME"

# --- 1. USER CHOICE MENU ---
if [ -d "$INSTALL_DIR" ] || [ -f "$SERVICE_PATH" ]; then
    echo "What would you like to do?"
    echo "1. Full Uninstall (Remove everything)"
    echo "2. Keep Settings (Remove script/service only)"
    echo "3. Cancel"
    printf "Enter choice [1-3]: "
    read choice </dev/tty

    case "$choice" in
        3)
            echo "❌ Uninstallation cancelled."
            echo ""
            exit 0
            ;;
        2)
            KEEP_CONF=1
            echo "📂 Preservation Mode: Configuration files will be kept."
            ;;
        *)
            KEEP_CONF=0
            echo "🗑️  Full Uninstall: All files and settings will be deleted."
            ;;
    esac
else
    echo "ℹ️  No installation found at $INSTALL_DIR. Nothing to do."
    exit 1
fi

# --- 2. STOP AND REMOVE SERVICE ---
if [ -f "$SERVICE_PATH" ]; then
    echo "🛑 Stopping and disabling service..."
    $SERVICE_PATH stop 2>/dev/null
    $SERVICE_PATH disable 2>/dev/null
    
    # Prevent self-killing: Find the background PID but ignore this script's PID ($$)
    TARGET_PID=$(pgrep -f "netwatchda.sh" | grep -v "$$")
    [ -n "$TARGET_PID" ] && kill -9 $TARGET_PID 2>/dev/null
    
    rm -f "$SERVICE_PATH"
    echo "✅ Service removed."
fi

# --- 3. CLEAN UP TEMPORARY STATE FILES ---
echo "🧹 Cleaning up temporary state files..."
rm -f /tmp/netwatchda_log.txt
rm -f /tmp/nwda_ext_d
rm -f /tmp/nwda_ext_t
rm -f /tmp/nwda_c_*
rm -f /tmp/nwda_d_*
echo "✅ Temp files cleared."

# --- 4. REMOVE INSTALLATION FILES ---
if [ "$KEEP_CONF" -eq 1 ]; then
    if [ -f "$INSTALL_DIR/netwatchda.sh" ]; then
        rm -f "$INSTALL_DIR/netwatchda.sh"
        echo "✅ Core script removed."
    fi
    echo "📂 Configuration preserved in $INSTALL_DIR"
else
    if [ -d "$INSTALL_DIR" ]; then
        echo "🗑️  Removing directory $INSTALL_DIR..."
        rm -rf "$INSTALL_DIR"
        echo "✅ All files removed."
    fi
fi

# --- 5. FINAL CLEANUP ---
rm -- "$0"

echo "---"
echo "✨ Uninstallation complete!"
echo "-------------------------------------------------------"
echo ""