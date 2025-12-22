# 📟 netwatchda

**netwatchda** is a lightweight, POSIX-compliant shell daemon for **OpenWrt routers** that monitors both internet connectivity and local LAN devices designed specifically for OpenWrt routers.  
It bridges the gap between your network hardware and your mobile device by sending real-time status updates via **Discord** Webhooks.

Designed for easy installation, reliability, minimal resource usage, and zero bloat.

---

## ✨ Features

- **Real-Time Discord Alerts**: Get notified instantly when a local device (Server, PC, IoT) or your entire Internet connection goes down. Silent hours supported.
- **Smart Recovery Notifications**: Not only tells you when things break but also calculates exactly how long the outage lasted once the connection returns.
- **System Heartbeat**: Optional periodic "I'm alive" messages so you know your router hasn't frozen or lost power.
- **Zero-Touch Management**: Includes a comprehensive automated installer and a "bulletproof" uninstaller.
- **Resource Efficient**: Written in pure POSIX sh for BusyBox, making it perfect for routers with limited flash memory (4MB/8MB+).
- **Log Rotation**: Automatically manages its own log size in /tmp to prevent filling up your router's RAM.
- **Ultra Lightweight** — Written in pure `sh`, using ~**1.2 MB RAM**
- **Dual Connectivity Monitoring**
- External internet availability
- Local LAN device reachability
- **LuCI Integration:** — Easy ways to view logs directly from the OpenWrt web interface.
  
---

## 🔔 Discord Configuration

**You need to configure discord with Webhook in order to get netwatchda send notificationn and you need to know your discord User ID to get mentions.**

###**Phase 1: Create the Discord Webhook**

A Webhook is like a private mailbox address that the script uses to send messages directly into your server.
* Open Discord on your computer.
* Pick a Server (or create a new one just for router logs).
* Right-click a Text Channel (e.g., #general or #logs) and select Edit Channel.
* On the left sidebar, click Integrations.
* Click the Webhooks button, then click New Webhook.
* (Optional) Give it a cool name like "Router Watchdog" and upload an icon.
* **Crucial Step:** Click the button that says Copy Webhook URL.
* It will look something like this: `https://discord.com/api/webhooks/123456...`
* **Keep this URL safe!** Anyone with this link can send messages to your channel.

###**Phase 2: Get your User ID (Optional)**

If you want the router to "ping" you (send a notification to your phone/PC) when the internet goes down, you need your numeric User ID.
* In Discord, go to User Settings (the gear icon at the bottom left).
* Go to Advanced (under App Settings).
* Turn **ON** "Developer Mode."
* Exit settings, Right-click your own name/avatar in any chat, and click Copy User ID.
* It will be a long string of numbers (e.g., `184000000000000000`).

---
> [!TIP]
> During netwatchda installation you will be asked for the above, copy-paste them. If you do not have them leave blanck and you can change them later in `netwatchda_config.conf`

---

## 🚀 Installation

**You need at least 3MB free storage space.**
The script itself is tiny (only a few KB), but it relies on curl to communicate with Discord. In OpenWrt, installing curl is a multi-step process that requires several libraries:

- curl binary: The core tool.
- libcurl: The logic library.
- ca-bundle / ca-certificates: These are essential for "HTTPS" security. Without them, your router cannot verify Discord’s identity, and the connection will fail.
- mbedtls or openssl: The encryption engine.

Combined, these packages require approximately 1.5MB to 2.2MB of permanent space. We set the guard at 3MB to allow room for the opkg package manager to download temporary files during installation without hitting 100% utilization.
Run the following command in your OpenWrt router’s terminal.  

**The installer is interactive and will guide you through setup.**

```sh
wget --no-check-certificate -qO /tmp/install_netwatchda.sh "https://raw.githubusercontent.com/panoc/NetWatch-Discord-Alerts-for-OpenWRT/refs/heads/main/install_netwatchda.sh" && sh /tmp/install_netwatchda.sh

```

### What the installer does

- Checks for required dependencies (`curl`)
- Prompts for:
- Discord Webhook URL
- Discord User ID (for mentions)
- Performs a live Discord connectivity test
- Registers `netwatchda` as a **procd service** (auto-start on boot)

---

## ⚙️ Configuration

All configuration files are located in:

```sh
/root/netwatchda/
```

---

### netwatchda_settings.conf
<details>
<summary>Adjust scan intervals, failure thresholds, and logging behavior.</summary>
<pre>
[Router Identification]
ROUTER_NAME="My_OpenWrt_Router" # Name that appears in Discord notifications.

[Discord Settings]
DISCORD_URL="" # Your Discord Webhook URL.
MY_ID="" # Your Discord User ID (for @mentions).
SILENT_ENABLE="OFF" # Set to ON to enable silent hours mode.
SILENT_START=23 # Hour to start silent mode (24H Format 0-23).
SILENT_END=07 # Hour to end silent mode (24H Format 0-23).

[Monitoring Settings]
MAX_SIZE=512000 # Max log file size in bytes for the log rotation.

[Heartbeat Settings]
HEARTBEAT="OFF" # Set to ON to receive a periodic check-in message.
HB_INTERVAL=86400 # Interval in seconds. Default is 86400
HB_MENTION="OFF" # Set to ON to include @mention in heartbeats.

[Internet Connectivity]
EXT_IP="1.1.1.1" # External IP to ping. Leave empty to disable.
EXT_SCAN_INTERVAL=60 # Seconds between internet checks. Default is 60.
EXT_FAIL_THRESHOLD=1 # Number of failed checks before alert. Default 1.
EXT_PING_COUNT=4 # Number of pings per check. Default 4.

[Local Device Monitoring]
DEVICE_MONITOR="ON" # Set to ON to enable local IP monitoring.
DEV_SCAN_INTERVAL=10 # Seconds between device pings. Default is 10.
DEV_FAIL_THRESHOLD=3 # Number of failed cycles before alert. Default 3.
DEV_PING_COUNT=4 # Number of pings per check. Default 4.```
</pre>
</details>

### netwatchda_ips.conf
<details>
<summary>Define LAN devices to monitor.</summary>
<pre>
# Format: IP_ADDRESS @ NAME
# Example: 192.168.1.50 @ Home Server
192.168.1.50  @ NAS Server
192.168.1.10  @ Smart Home Hub
</pre>
</details>

Restart the service after making changes:

```sh
/etc/init.d/netwatchda restart
```
---

## 🖥️ LuCI Web Interface Integration (Recommended)

If you prefer using the web interface over the command line, you can add control buttons to your router's dashboard.

### 1. Install Custom Commands
Navigate to **System** -> **Software**, update your lists, and install:
`luci-app-commands`

### 2. Configure Buttons
Navigate to **System** -> **Custom Commands** and add the following entries:

| Button Name | Command |
| :--- | :--- |
| **Check Status** | `/etc/init.d/netwatchda status` |
| **View Activity Logs** | `/etc/init.d/netwatchda logs` |
| **Test Discord Link** | `/etc/init.d/netwatchda discord` |
| **Restart Service** | `/etc/init.d/netwatchda restart` |

---

## 📊 Monitoring & Logs

View resource usage:

```sh
top -b -n 1 | grep netwatchda
```

### 🖥️ Option 1: LuCI (Web Interface)

To view logs without using a terminal:

- System Log: Go to Status > System Log. This shows service events (start/stop).

- Detailed History: If you have luci-app-commands installed:

   Go to System > Custom Commands.

   Click Add.
```sh
        Name: View NetWatch Logs
```
```sh
        Command: tail -n 50 /tmp/netwatchda_log.txt
```

  You can now check your monitoring history with one click from your browser.

### ⌨️ Option 2: Terminal 

Follow connectivity logs in real time:

```sh
tail -f /tmp/netwatchda_log.txt
```

## ⚙️ Configuration Files

All configuration is stored in `/root/netwatchda/`. You can edit these files via SSH or using the "Edit" feature in LuCI's File Browser:

* **`netwatchda_settings.conf`**: Main settings (Webhook URLs, timers, silent hours).
* **`netwatchda_ips.conf`**: List of devices to monitor. 
    * *Format:* `192.168.1.50 @ My Server`

---

## 📁 Management via Terminal
**You can manage the service manually using these commands:**
<details>
<summary><strong>Usage: /etc/init.d/netwatchda</strong> [command]</summary>
<pre>
  
-	**start**     - Start the service
- **stop**      - Stop the service
- **restart**   - Restart the service
- **reload**    - Reload configuration files (or restart if service does not implement reload)
- **enable**    - Enable service autostart
- **disable**   - Disable service autostart
- **enabled**   - Check if service is started on boot
- **status**    - Check if monitor is running
- **logs**      - View last 20 log entries
- **clear**     - Clear log file
- **discord**   - Test discord notification
- **purge**     - Interactive smart uninstaller
- **running**   - Check if service is running
- **status**    - Service status
- **help**	    - Display this help message
  </pre>
</details>

---

## 🌙 Understanding Silent Hours

If you enable Silent Hours (e.g., 23:00 to 07:00):
1.  Individual "Down/Up" alerts are **paused** during this window.
2.  All events are saved to a temporary buffer.
3.  At the end of the window (07:00), a single **Summary Message** is sent to Discord containing all outages that occurred overnight.

---

## ⚖️ License
Copyright (C) 2025 panoc.
This project is licensed under the **GNU General Public License v3.0**. 

---

## 🗑️ Uninstallation

To remove netwatchda, run the official uninstaller:

```sh
wget --no-check-certificate -qO /tmp/uninstall_netwatchda.sh "https://raw.githubusercontent.com/panoc/NetWatch-Discord-Alerts-for-OpenWRT/refs/heads/main/uninstall_netwatchda.sh" && sh /tmp/uninstall_netwatchda.sh
```
OR

```sh
/etc/init.d/netwatchda purge
```

You will be prompted to:
- Keep configuration files
- Or perform a full cleanup

---
 
## 🤝 Contributing

Contributions are welcome.  
Feel free to open an issue or submit a pull request for:

- Performance optimizations
- Additional notification platforms
- New monitoring features

---

## 📄 License

GPLv3
