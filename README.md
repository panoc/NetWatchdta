# 📟 netwatchda

**netwatchda** is a lightweight, POSIX-compliant shell daemon for **OpenWrt routers** that monitors both internet connectivity and local LAN devices.  
It sends **real-time outage and recovery alerts** directly to your **Discord channel** using webhooks.

Designed for easy installation, reliability, minimal resource usage, and zero bloat.

---

## ✨ Features

- **Ultra Lightweight** — Written in pure `sh`, using ~**1.2 MB RAM**
- **Dual Connectivity Monitoring**
  - External internet availability
  - Local LAN device reachability
- **Smart Alert Logic** — Prevents notification spam when the entire network is offline
- **Discord Webhook Integration** — Supports **@mentions** for instant awareness
- **Automatic Recovery Reports** — Calculates and reports total downtime once a device reconnects
- **Built-in Log Rotation** — Protects router RAM from excessive log growth
- **Customizable Heartbeat** — Choose your check-in frequency (e.g., every 12h, 24h, or even 1h) and toggle mentions specifically for heartbeats to keep your phone quiet while still knowing the system is alive.
- **LuCI Integration:** — Easy ways to view logs directly from the OpenWrt web interface.
  
---

## 🚀 Installation

Run the following command in your OpenWrt router’s terminal.  
The installer is interactive and will guide you through setup.

```sh
wget --no-check-certificate -qO /tmp/install_netwatchda.sh "https://raw.githubusercontent.com/panoc/Net-Watch-Discord-Alerts-for-OpenWRT/refs/heads/main/install_netwatchda.sh" && sh /tmp/install_netwatchda.sh

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
wget --no-check-certificate -qO /tmp/uninstall_netwatchda.sh "https://raw.githubusercontent.com/panoc/Net-Watch-Discord-Alerts-for-OpenWRT/refs/heads/main/uninstall_netwatchda.sh" && sh /tmp/uninstall_netwatchda.sh
```

You will be prompted to:
- Keep configuration files
- Or perform a full cleanup

---

## ⚙️ Service Management

- Apply Settings: /etc/init.d/netwatchda restart
- Stop Monitoring: /etc/init.d/netwatchda stop
- Start Monitoring: /etc/init.d/netwatchda start
- Check If Running: /etc/init.d/netwatchda status
- View Live Logs: tail -f /tmp/netwatchda_log.txt

## 🤝 Contributing

Contributions are welcome.  
Feel free to open an issue or submit a pull request for:

- Performance optimizations
- Additional notification platforms
- New monitoring features

---

## 📄 License

GPLv3
