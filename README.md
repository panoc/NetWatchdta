# 📟 netwatchd

**netwatchd** is a lightweight, POSIX-compliant shell daemon for **OpenWrt routers** that monitors both internet connectivity and local LAN devices.  
It sends **real-time outage and recovery alerts** directly to your **Discord channel** using webhooks.

Designed for reliability, minimal resource usage, and zero bloat.

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

---

## 🚀 Installation

Run the following command in your OpenWrt router’s terminal.  
The installer is interactive and will guide you through setup.

```sh
wget -qO /tmp/install_netwatchd.sh "https://raw.githubusercontent.com/panoc/Net-Watch-Discord-Alerts/refs/heads/main/install_netwatchd.sh" && sh /tmp/install_netwatchd.sh

```

### What the installer does

- Checks for required dependencies (`curl`)
- Prompts for:
  - Discord Webhook URL
  - Discord User ID (for mentions)
- Performs a live Discord connectivity test
- Registers `netwatchd` as a **procd service** (auto-start on boot)

---

## ⚙️ Configuration

All configuration files are located in:

```sh
/root/netwatchd/
```

---

### netwatchd_settings.conf

Adjust scan intervals, failure thresholds, and logging behavior.

```sh
ROUTER_NAME="Home_Router"
SCAN_INTERVAL=10    # Ping every 10 seconds
FAIL_THRESHOLD=3    # Alert after 3 consecutive failures
```

---

### netwatchd_ips.conf

Define LAN devices to monitor.

```txt
# Format:
# IP_ADDRESS  # DEVICE NAME

192.168.1.50  # NAS Server
192.168.1.10  # Smart Home Hub
```

Restart the service after making changes:

```sh
/etc/init.d/netwatchd restart
```

---

## 📊 Monitoring & Logs

View resource usage:

```sh
top -b -n 1 | grep netwatchd
```

Follow connectivity logs in real time:

```sh
tail -f /tmp/netwatchd_log.txt
```

---

## 🗑️ Uninstallation

To remove netwatchd, run the official uninstaller:

```sh
wget -qO- \
"wget -qO- https://raw.githubusercontent.com/panoc/Net-Watch-Discord-Alerts/refs/heads/main/uninstall_netwatchd.sh | sh" \
| sh
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

MIT License
