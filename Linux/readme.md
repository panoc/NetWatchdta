Here is the updated, professional `README.md` for your GitHub repository. I have restructured it to clearly distinguish between **OpenWrt** (Embedded) and **Universal Linux** (Server/Desktop) usage, incorporated your new one-line commands, and refined the formatting.

---

```markdown
# ![](https://icongr.am/octicons/broadcast.svg?size=24&color=0366d6) NetWatchdta
![License](https://img.shields.io/badge/license-GPLv3-blue.svg) ![Platform](https://img.shields.io/badge/platform-OpenWrt%20%7C%20Linux-red.svg) ![Network](https://img.shields.io/badge/Network-Monitoring-orange.svg) ![Version](https://img.shields.io/badge/version-1.2-green.svg)

### Advanced Network Monitoring & Alerting for OpenWrt & Linux

**netwatchdta** is a lightweight, POSIX-compliant network monitor designed for **OpenWrt routers** and **Linux servers**. It bridges the gap between your network hardware and your mobile device by sending real-time status **notifications** via **Discord** and/or **Telegram**.

Designed for reliability, minimal resource usage, and zero bloat, it features **smart resource management** that automatically adjusts its execution strategy based on available RAM and CPU load. Whether you are running a tiny travel router with 64MB RAM or a powerful Ubuntu server, NetWatchdta adapts to fit.

---

## ✨ Key Features

* **🔔 Rich Notifications**
    * Real-time alerts via **Discord** (Embeds) and **Telegram**.
    * **Silent Hours:** Pauses alerts during the night and sends a single summary in the morning.
    * **Heartbeat:** Optional "I'm alive" periodic check-ins.
* **📡 Dual-Stack Monitoring**
    * **Internet Watchdog:** Monitors external IPs (default 1.1.1.1/8.8.8.8) to detect ISP outages.
    * **Device Watchdog:** Monitors specific local IPs (servers, cameras, IoT) and alerts when they go offline.
* **🧠 Smart Resource Management**
    * **Parallel Mode:** Automatically enables on systems with **≥ 256MB RAM** for ultra-fast, simultaneous scanning.
    * **Sequential Mode:** Automatically enables on low-memory devices (< 256MB) to prevent system instability.
* **🔐 OpenSSL Security**
    * Credentials are **never** stored in plain text.
    * Uses **AES-256 Encryption (OpenSSL)** locked to your specific hardware signature (CPU Serial/Machine ID).
* **🛡️ Resilience**
    * **Offline Buffering:** If the internet cuts out, alerts are saved (up to 500KB) and sent immediately when connectivity is restored.
    * **Resource Guards:** Pauses monitoring if system CPU load is too high or RAM is critically low.

---

## 🚀 Installation

### Option A: OpenWrt (Routers)
**Requirement:** OpenWrt 19.07+ and ~3MB free storage.
Run this command in your router terminal:

```sh
wget --no-check-certificate -qO /tmp/install_netwatchdta.sh "[https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/OpenWRT/install_netwatchdta_wrt.sh](https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/OpenWRT/install_netwatchdta_wrt.sh)" && sh /tmp/install_netwatchdta.sh

```

### Option B: Universal Linux (Debian, Ubuntu, Arch, Fedora, Pi)

**Requirement:** `sudo` privileges. The script auto-detects your package manager (apt/dnf/pacman) to install dependencies.

```sh
sudo wget --no-check-certificate -qO /tmp/install_netwatchdta.sh "[https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/Linux/install_netwatchdta_linux.sh](https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/Linux/install_netwatchdta_linux.sh)" && sudo bash /tmp/install_netwatchdta.sh

```

---

## 📂 Directory Structure

Depending on your OS, the files are installed in standard locations:

| File Type | OpenWrt Path | Linux Path | Description |
| --- | --- | --- | --- |
| **Base Folder** | `/root/netwatchdta/` | `/opt/netwatchdta/` | Main installation directory. |
| **Config** | `nwdta_settings.conf` | `nwdta_settings.conf` | User settings (Intervals, Toggles). |
| **IP List** | `nwdta_ips.conf` | `nwdta_ips.conf` | List of devices to monitor. |
| **Vault** | `.vault.enc` | `.vault.enc` | Encrypted tokens. |
| **Logs** | `/tmp/netwatchdta/` | `/tmp/netwatchdta/` | RAM-based activity logs. |

---

## 🛠️ Management & Commands

The management commands differ slightly between platforms due to init systems (Procd vs Systemd).

### 🟢 OpenWrt Commands

| Action | Command |
| --- | --- |
| **Start/Stop** | `/etc/init.d/netwatchdta start` (or `stop`) |
| **Check Status** | `/etc/init.d/netwatchdta status` |
| **View Logs** | `/etc/init.d/netwatchdta logs` |
| **Manage Creds** | `/etc/init.d/netwatchdta credentials` |
| **Test Alerts** | `/etc/init.d/netwatchdta discord` (or `telegram`) |
| **Uninstall** | `/etc/init.d/netwatchdta purge` |

### 🐧 Linux Commands

| Action | Command |
| --- | --- |
| **Start/Stop** | `sudo netwatchdta start` (or `stop`) |
| **Check Status** | `sudo netwatchdta status` |
| **View Logs** | `sudo netwatchdta logs` |
| **Manage Creds** | `sudo netwatchdta credentials` |
| **Test Alerts** | `sudo netwatchdta discord` (or `telegram`) |
| **Uninstall** | `sudo netwatchdta purge` |

---

## ⚙️ Configuration Guide

Configuration files are located in the **Base Folder** (see Directory Structure above).

### 1. `nwdta_settings.conf`

This file controls the behavior of the daemon. Key settings include:

* **`ROUTER_NAME`**: Name displayed in alerts (e.g., "Office Server").
* **`EXEC_METHOD`**: `1` (Parallel) or `2` (Sequential). Auto-detected during install.
* **`SILENT_ENABLE`**: Set to `YES` to buffer alerts overnight.
* **`HEARTBEAT`**: Set to `YES` for daily "I'm alive" messages.
* **`EXT_IP`**: The external IP used to check internet connectivity (Default: 1.1.1.1).

### 2. `nwdta_ips.conf`

List the local devices you want to monitor here.

```ini
# Format: IP_ADDRESS @ NAME
192.168.1.10   @ Home Server
192.168.1.50   @ CCTV Camera
10.0.0.5       @ IoT Gateway

```

*After editing files, always restart the service.*

---

## 🔔 Notification Setup

You will need a **Discord Webhook** or **Telegram Bot Token**.

<details>
<summary><strong>Click to view Discord Setup Instructions</strong></summary>

1. **Create Webhook:** Right-click a Discord channel -> Edit Channel -> Integrations -> Webhooks. Create one and copy the URL.
2. **Get User ID (Optional):** Enable Developer Mode in Discord settings. Right-click your username in chat -> Copy User ID.

</details>

<details>
<summary><strong>Click to view Telegram Setup Instructions</strong></summary>

1. **Get Token:** Chat with `@BotFather` on Telegram. Send `/newbot`. Copy the API Token.
2. **Get Chat ID:** Send a message to your new bot. Visit `https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates` and look for `"chat":{"id":123456789}`.

</details>

> **Tip:** You can update these securely at any time by running the `credentials` command shown in the Management section.

---

## 🗑️ Uninstallation

To completely remove **netwatchdta** (Service, Files, and Dependencies):

### OpenWrt

```sh
wget --no-check-certificate -qO /tmp/uninstall_netwatchdta_wrt.sh "[https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/OpenWRT/uninstall_netwatchdta_wrt.sh](https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/OpenWRT/uninstall_netwatchdta_wrt.sh)" && sh /tmp/uninstall_netwatchdta_wrt.sh

```

### Universal Linux

```sh
sudo wget --no-check-certificate -qO /tmp/uninstall_netwatchdta.sh "[https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/Linux/uninstall_netwatchdta_linux.sh](https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/Linux/uninstall_netwatchdta_linux.sh)" && sudo bash /tmp/uninstall_netwatchdta.sh

```

---

## ⚖️ License

Copyright (C) 2025 panoc.
This project is licensed under the **GNU General Public License v3.0**.

```

```