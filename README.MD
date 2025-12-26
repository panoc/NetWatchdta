Here is the final, complete **README.md** with the **LuCI Web Interface Integration** section added.

---

# 🌐 NetWatchdta (Universal)

> **The Grand Unified Network Monitor for OpenWrt & Linux**

**NetWatchdta** is a lightweight, robust, and highly configurable network monitoring script. It continuously monitors your Internet connection (WAN), Local Devices (LAN), and Remote Servers, sending real-time alerts via **Discord** and **Telegram**.

Originally designed for OpenWrt routers, **v4.x** has been re-engineered as a **Universal Application**. It automatically detects your operating system, adjusts its dependencies, and installs as a native system service (`procd` for OpenWrt, `systemd` for Linux).

---

## ✨ Key Features (v4.3)

* **🦄 Universal Installer:** One script works on OpenWrt routers, Raspberry Pis, VPSs, and Desktop Linux.
* **🧠 Smart Engine:**
* **OpenWrt:** Uses `uclient-fetch` and minimal RAM logic (~7KB footprint).
* **Linux:** Uses `curl` and `systemd` for maximum stability.


* **🔔 Dual Notifications:** Send alerts to **Discord** (with rich embeds) and **Telegram** simultaneously or selectively.
* **🛡️ Encryption Vault:** Credentials (tokens/webhooks) are encrypted using OpenSSL AES-256 and locked to your specific hardware.
* **📂 Offline Buffer:** If the internet goes down, alerts are queued and delivered in bulk once connectivity is restored. No notifications are lost.
* **🌙 Silent Mode:** Mute alerts during specific hours (e.g., sleeping time), but keep logging them to the buffer.
* **💓 Heartbeat:** Periodic "I am alive" messages to confirm the system is running.
* **🌍 Multi-Tier Monitoring:**
1. **Internet (WAN):** Checks external IPs (Cloudflare/Google).
2. **Local (LAN):** Monitors devices on your network (e.g., NAS, Cameras).
3. **Remote:** Monitors external servers (only checks if WAN is UP).



---

## ✅ Supported Operating Systems

NetWatchdta v4.x automatically adapts to the underlying OS.

| Category | Status | Supported Distributions | Notes |
| --- | --- | --- | --- |
| **Embedded** | ✅ **Perfect** | **OpenWrt** (19.07 - 24.x) | Uses `procd`, optimized for low RAM. |
| **Debian** | ✅ **Perfect** | **Debian**, **Ubuntu**, **Linux Mint**, **Kali**, **Raspberry Pi OS**, **Pop!_OS** | Uses `systemd` & `apt`. |
| **Red Hat** | ✅ **Perfect** | **Fedora**, **RHEL**, **CentOS Stream**, **AlmaLinux**, **Rocky Linux** | Uses `systemd` & `dnf`. |
| **Arch** | ✅ **Perfect** | **Arch Linux**, **Manjaro**, **EndeavourOS**, **Garuda** | Uses `systemd` & `pacman`. |
| **SUSE** | ✅ **Perfect** | **OpenSUSE** (Leap/Tumbleweed) | Uses `systemd` & `zypper`. |

---

## 🚀 Installation

### Option 1: Linux (Desktop/Server)

*Requires `curl` and `sudo`.*

```bash
curl -sL https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/install_netwatchdta.sh | sudo bash

```

### Option 2: OpenWrt (Routers)

*No sudo required.*

```bash
wget -qO- https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/install_netwatchdta.sh | sh

```

---

## 🛠️ Management & Commands

Once installed, use the CLI commands to manage the service.

### 🎮 Service Commands

| Action | Linux Command | OpenWrt Command | Description |
| --- | --- | --- | --- |
| **Check Status** | `netwatchdta check` | `/etc/init.d/netwatchdta check` | Shows if the service is running or stopped. |
| **View Logs** | `netwatchdta logs` | `/etc/init.d/netwatchdta logs` | Displays the last 20 lines of the event log. |
| **Clear Logs** | `netwatchdta clear` | `/etc/init.d/netwatchdta clear` | Wipes the log file to save space/declutter. |
| **Restart** | `netwatchdta restart` | `/etc/init.d/netwatchdta restart` | Restarts the service (applies config changes). |
| **Stop** | `netwatchdta stop` | `/etc/init.d/netwatchdta stop` | Stops the monitoring service. |
| **Discord Test** | `netwatchdta discord` | `/etc/init.d/netwatchdta discord` | Sends a manual test alert to Discord. |
| **Telegram Test** | `netwatchdta telegram` | `/etc/init.d/netwatchdta telegram` | Sends a manual test alert to Telegram. |
| **Credentials** | `netwatchdta credentials` | `/etc/init.d/netwatchdta credentials` | Re-enter/Update API tokens & Webhooks. |
| **Uninstall** | `netwatchdta purge` | `/etc/init.d/netwatchdta purge` | Launch the interactive uninstaller. |

### ⚙️ Configuration Settings (`settings.conf`)

Location: `/opt/netwatchdta/settings.conf` (Linux) or `/root/netwatchdta/settings.conf` (OpenWrt).

| Category | Setting | Description |
| --- | --- | --- |
| **General** | `ROUTER_NAME` | The name displayed in all notifications (e.g., "Home Router"). |
|  | `FETCH_TOOL` | **AUTO** (Default), `CURL`, `UCLIENT`, or `WGET`. Controls which tool sends alerts. |
|  | `EXEC_METHOD` | `1` = Parallel (Fast), `2` = Sequential (Low RAM). Auto-detected on install. |
| **Notifications** | `DISCORD_ENABLE` | `YES`/`NO`. Master switch for Discord alerts. |
|  | `TELEGRAM_ENABLE` | `YES`/`NO`. Master switch for Telegram alerts. |
|  | `SILENT_ENABLE` | `YES`/`NO`. If YES, notifications are muted during silent hours. |
|  | `SILENT_START` / `END` | Start/End hour for silent mode (e.g., `23` to `07`). |
| **Discord Mentions** | `DISCORD_MENTION_...` | Toggles `@User` mentions for specific events (Local, Remote, Net, Heartbeat). |
| **Heartbeat** | `HEARTBEAT` | `YES`/`NO`. Sends a periodic "I am alive" message. |
|  | `HB_INTERVAL` | Seconds between heartbeats (Default `86400` = 24 Hours). |
|  | `HB_TARGET` | `DISCORD`, `TELEGRAM`, or `BOTH`. |
|  | `HB_START_HOUR` | The hour (0-23) the heartbeat should try to send (e.g., `12` for Noon). |
| **Monitoring** | `EXT_...` | Settings for WAN (Internet) monitoring (IPs, Interval, Thresholds). |
|  | `DEV_...` | Settings for Local Device monitoring (from `device_ips.conf`). |
|  | `REM_...` | Settings for Remote Server monitoring (from `remote_ips.conf`). |
| **Performance** | `CPU_GUARD_THRESHOLD` | Pauses checks if system load exceeds this value (Default `2.0`). |
|  | `RAM_GUARD_MIN_FREE` | Pauses checks if free RAM is below this (KB) (Default `4096`). |

---

## 🖥️ LuCI Web Interface Integration (Optional)

*For OpenWrt Users Only*

You can monitor NetWatchdta directly from the OpenWrt Web Interface (LuCI) by installing the **Custom Commands** package.

1. **Install the Package:**
```bash
opkg update && opkg install luci-app-commands

```


2. **Configure the Menu:**
* Go to **System** ➡️ **Custom Commands**.
* Click **Add**.
* **Description:** `NetWatchdta Logs`
* **Command:** `/etc/init.d/netwatchdta logs`
* Click **Save & Apply**.



Now you can view the live monitor logs directly from your browser by going to **System** ➡️ **Custom Commands**!

---

## 🗑️ Uninstallation

You have two ways to uninstall the tool. Both launch the interactive **Smart Uninstaller** which asks if you want to remove everything or keep your settings.

### Method 1: Built-in (Recommended)

* **Linux:** `sudo netwatchdta purge`
* **OpenWrt:** `/etc/init.d/netwatchdta purge`

### Method 2: Emergency Script

If the installation is broken, use the remote uninstaller:

* **Linux:** `curl -sL https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/uninstall_netwatchdta.sh | sudo bash`
* **OpenWrt:** `wget -qO- https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/uninstall_netwatchdta.sh | sh`

---

## 🔒 Security Note

This script uses **OpenSSL AES-256** to encrypt your Discord Webhook and Telegram Token. The encryption key is generated based on your device's unique CPU Serial and MAC address.

* **Benefit:** If someone copies your config files to another machine, they cannot decrypt your credentials.
* **Note:** If you change your hardware (e.g., swap Raspberry Pis), you must run the installer again to re-encrypt your credentials.

---

## 📜 License

This project is licensed under the **GNU General Public License v3.0**.
Copyright (C) 2025 panoc
