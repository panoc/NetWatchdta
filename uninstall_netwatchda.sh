#!/bin/sh
# netwatchda Uninstaller - Bulletproof Version for OpenWrt
# Copyright (C) 2025 panoc

# --- INITIAL SPACING ---
echo ""
echo "-------------------------------------------------------"
echo "🗑️  Starting netwatchda Uninstallation..."
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
        3) echo "❌ Cancelled."; exit 0 ;;
        2) KEEP_CONF=1; echo "📂 Preservation Mode active." ;;
        *) KEEP_CONF=0; echo "🗑️  Full Uninstall active." ;;
    esac
else
    echo "ℹ️  No installation found."
    exit 1
fi

# --- 2. STOP AND DISABLE SERVICE (THE RIGHT ORDER) ---
if [ -f "$SERVICE_PATH" ]; then
    echo "🛑 Shutting down procd service..."
    # Disable first so it doesn't try to restart during the stop
    $SERVICE_PATH disable 2>/dev/null
    $SERVICE_PATH stop 2>/dev/null
    
    # Sniper Kill: Kill background script but NOT this uninstaller
    TARGET_PID=$(pgrep -f "netwatchda.sh" | grep -v "$$")
    [ -n "$TARGET_PID" ] && kill -9 $TARGET_PID 2>/dev/null
    
    # Cleanup orphaned pings to prevent "Zombie" processes
    killall -q ping 2>/dev/null 

    rm -f "$SERVICE_PATH"
    echo "✅ Service and symlinks removed."
fi

# --- 3. CLEAN UP TEMPORARY STATE ---
echo "🧹 Clearing RAM-based state files..."
rm -f /tmp/netwatchda_log.txt /tmp/nwda_ext_* /tmp/nwda_c_* /tmp/nwda_d_*
echo "✅ /tmp/ is clean."

# --- 4. REMOVE FILES ---
if [ "$KEEP_CONF" -eq 1 ]; then
    rm -f "$INSTALL_DIR/netwatchda.sh"
    echo "📂 Configuration preserved in $INSTALL_DIR"
else
    rm -rf "$INSTALL_DIR"
    # Verification check for Read-Only Filesystems
    if [ -d "$INSTALL_DIR" ]; then
        echo "❌ ERROR: Could not remove $INSTALL_DIR. Filesystem might be Read-Only!"
    else
        echo "✅ All files removed."
    fi
fi

# --- 5. FINAL CLEANUP ---
# Self-destruct
rm -- "$0"

echo "---"
echo "✨ Uninstallation complete!"
echo "-------------------------------------------------------"
echo ""