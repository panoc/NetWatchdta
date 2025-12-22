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

## 🚀 Installation
**At least 3MB free storage space.**
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

Adjust scan intervals, failure thresholds, and logging behavior.

```sh
ROUTER_NAME="Home_Router"
SCAN_INTERVAL=10    # Ping every 10 seconds
FAIL_THRESHOLD=3    # Alert after 3 consecutive failures
```

---

### netwatchda_ips.conf

Define LAN devices to monitor.

```txt
# Format:
# IP_ADDRESS  # DEVICE NAME

192.168.1.50  # NAS Server
192.168.1.10  # Smart Home Hub
```

Restart the service after making changes:

```sh
/etc/init.d/netwatchda restart
```

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

        Name: View NetWatch Logs

        Command: tail -n 50 /tmp/netwatchda_log.txt

  You can now check your monitoring history with one click from your browser.

### ⌨️ Option 2: Terminal 

Follow connectivity logs in real time:

```sh
tail -f /tmp/netwatchda_log.txt
```

---

## 🗑️ Uninstallation

To remove netwatchda, run the official uninstaller:

```sh
wget --no-check-certificate -qO /tmp/uninstall_netwatchda.sh "https://raw.githubusercontent.com/panoc/NetWatch-Discord-Alerts-for-OpenWRT/refs/heads/main/uninstall_netwatchda.sh" && sh /tmp/uninstall_netwatchda.sh
```

You will be prompted to:
- Keep configuration files
- Or perform a full cleanup

---

## ⚙️ Service Management

Usage: /etc/init.d/netwatchda [command]

-	start           Start the service
- stop            Stop the service
- restart         Restart the service
- reload          Reload configuration files (or restart if service does not implement reload)
- enable          Enable service autostart
- disable         Disable service autostart
- discord         Test discord notification
- clear           Clear log file
- enabled         Check if service is started on boot
- status          Check if monitor is running
- logs            View last 20 log entries
- running         Check if service is running
- trace           Start with syscall trace
- info            Dump procd service info
- help			      Display this help message

## 🤝 Contributing

Contributions are welcome.  
Feel free to open an issue or submit a pull request for:

- Performance optimizations
- Additional notification platforms
- New monitoring features

---

## 📄 License

GPLv3
