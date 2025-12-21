📟 netwatchd

A lightweight, POSIX-compliant shell script for OpenWrt routers that monitors internet and local device connectivity. It sends real-time status alerts and recovery notifications directly to your Discord channel using webhooks.
✨ Features

    Zero Bloat: Written in pure sh. Uses minimal RAM (~1.2MB).

    Dual Monitoring: Tracks both external internet stability and local LAN device connectivity.

    Smart Alerts: Only sends notifications when the internet is active (prevents "spam" when the whole network is down).

    Discord Integration: Uses Discord Webhooks with <@mention> support for immediate awareness.

    Auto-Recovery Tracking: Calculates and reports the total duration of an outage once a device comes back online.

    Log Rotation: Built-in protection to ensure log files don't consume your router's RAM.

🚀 Installation

Run the following command in your router's terminal. The installer is interactive and will guide you through the Discord setup and monitoring mode selection.
Bash

wget -qO- https://raw.githubusercontent.com/YOUR_USERNAME/netwatchd/main/install_netwatchd.sh | sh

What the installer does:

    Checks for dependencies (curl).

    Prompts for your Discord Webhook URL and User ID.

    Performs a Live Connectivity Test to verify your Discord settings.

    Configures netwatchd as a system service (procd) so it starts automatically on boot.

⚙️ Configuration

Files are located in /root/netwatchd/.
1. netwatchd_settings.conf

Adjust your ping intervals, failure thresholds, and log sizes here.
Bash

ROUTER_NAME="Home_Router"
SCAN_INTERVAL=10    # Ping every 10 seconds
FAIL_THRESHOLD=3    # Alert after 3 consecutive failures

2. netwatchd_ips.conf

Add the local devices you want to monitor.
Plaintext

# Format: IP_ADDRESS # NAME
192.168.1.50 # NAS Server
192.168.1.10 # Smart Home Hub

After editing, restart the service: /etc/init.d/netwatchd restart
🗑️ Uninstallation

If you wish to remove the service, use the official uninstaller. It will ask if you want to keep your configuration files or perform a full wipe.
Bash

wget -qO- https://raw.githubusercontent.com/YOUR_USERNAME/netwatchd/main/uninstall_netwatchd.sh | sh

📊 Monitoring Usage

To see the script's resource usage in real-time:
Bash

top -b -n 1 | grep netwatchd

To view the latest connectivity logs:
Bash

tail -f /tmp/netwatchd_log.txt

🤝 Contributing

Feel free to open an issue or submit a pull request if you have ideas for optimizations or new notification platforms!

License: MIT
