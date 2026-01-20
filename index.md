---
layout: default
title: NetWatchdta
description: Lightweight Network Monitor & Alerting for OpenWrt and Linux
---

# 🌐 NetWatchdta

> **The lightweight, automated network monitoring & alerting tool for OpenWrt, Linux, and Embedded Systems.**

[![OS](https://img.shields.io/badge/OS-OpenWrt%20%7C%20Linux-1272ba?style=flat-square&logo=openwrt&logoColor=white)](https://github.com/panoc/NetWatchdta)
[![Network Monitoring](https://img.shields.io/badge/Network-Monitoring%20and%20Logs-006400?style=flat-square&logo=activity&logoColor=white)](https://github.com/panoc/NetWatchdta)
[![Alerts](https://img.shields.io/badge/Alerts-Discord%20%26%20Telegram-7289da?style=flat-square&logo=discord&logoColor=white)](https://github.com/panoc/NetWatchdta)
[![License](https://img.shields.io/github/license/panoc/NetWatchdta?style=flat-square)](https://github.com/panoc/NetWatchdta/blob/main/LICENSE)

---

## 🚀 Why NetWatchdta?

**NetWatchdta** ensures your network connectivity is always monitored without consuming precious system resources. Originally built for OpenWrt, it has evolved into a universal tool that runs seamlessly on **Desktop Linux**, **VPS**, **Raspberry Pi**, and **Routers**.

It continuously watches your:
* **WAN** (Internet Connection)
* **LAN** (Local Devices)
* **Remote Servers** (IPs & Domains)

### ✨ Key Features

| Feature | Description |
| :--- | :--- |
| **🔔 Instant Alerts** | Get real-time notifications via **Discord** and **Telegram** when devices go down or come back online. |
| **⚡ Ultra Lightweight** | Written in POSIX-compliant Shell. Optimized for low-RAM devices (routers/IoT). |
| **🧠 Smart Detection** | Automatically detects hardware specs to switch between **High Performance** (Parallel) or **Safe Mode** (Batching). |
| **🛠️ Universal Install** | One script handles everything. Detects OS, installs dependencies, and configures `procd` or `systemd`. |
| **❤️ Auto-Healing** | The config file "heals" itself during updates, preserving your settings while adding new required defaults. |


---

## 📱 Alerts

*Visual feedback directly to your phone or desktop.*

* **🔴 Downtime Alert:** "Connection Lost: Primary WAN Gateway (8.8.8.8)"
* **🟢 Recovery Alert:** "Connection Restored: NAS Server (192.168.1.100) - Downtime: 5m 20s"
* **💓 Heartbeat:** Periodic summaries to let you know the monitor is alive.

---

## 🤝 Contributing

We welcome contributions! If you have ideas for new features or bug fixes, please open an issue or submit a pull request on GitHub.

[Report Bug](https://www.google.com/search?q=https://github.com/panoc/NetWatchdta/issues) · [Request Feature](https://www.google.com/search?q=https://github.com/panoc/NetWatchdta/issues)

