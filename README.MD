# 🌐 NetWatchdta

> **Network Monitor with Real Time Alerts for OpenWrt & Linux**

<p align="left">
  <img src="https://img.shields.io/badge/OS-OpenWrt%20%7C%20Linux-1272ba?style=flat-square&logo=openwrt&logoColor=white">
  <img src="https://img.shields.io/badge/Network-Monitoring%20and%20Logs-006400?style=flat-square&logo=activity&logoColor=white">  
   <img src="https://img.shields.io/badge/Alerts-Discord%20%26%20Telegram-7289da?style=flat-square&logo=alerts&logoColor=white">
 <img src="https://img.shields.io/badge/Shell-Script-orange?style=flat-square&logo=alerts&logoColor=orange">
  </p>

**NetWatchdta** is a POSIX-compliant, lightweight, robust, and highly configurable network monitoring script. It continuously monitors your Internet connection (WAN), Local Devices (LAN), and Remote Servers, sending real-time alerts via **Discord** and **Telegram**.

Originally designed for OpenWrt routers, **v1.x** has been re-engineered as a **Universal Application**. It automatically detects your operating system, adjusts its dependencies, adjusts default settings based on your hardware, and installs as a native system service (`procd` for OpenWrt, `systemd` for Linux).
<br>

---

## ✨ Key Features

* **Universal Installer:** One script works on OpenWrt routers, Raspberry Pis, VPSs, and Desktop Linux.
* **Smart Hardware Detection:** Automatically configures itself for **High Performance** (Parallel) or **Safe Mode** (Batching) based on your RAM (512MB Threshold).
* **Self-Healing Config:** The installer automatically detects missing settings in your configuration file during upgrades and patches them with safe defaults.
* **Smart Batch Scanning:** Dynamically calculates how many devices to ping simultaneously based on **Free RAM**, reserving a 10% safety margin to prevent crashes on low-end hardware.
* **Dual Notifications:** Send alerts to **Discord** (with rich embeds) and **Telegram** simultaneously or selectively.
* **Encryption Vault:** Credentials (tokens/webhooks) are encrypted using OpenSSL AES-256 and locked to your specific hardware.
* **Offline Buffer:** If the internet goes down, alerts are queued and delivered in bulk once connectivity is restored.
* **Silent Mode:** Mute alerts during specific hours (e.g., sleeping time), but keep logging them to the buffer.
* **Precision Heartbeat:** Periodic "I am alive" messages aligned to the exact Hour:Minute you define, with anti-drift logic.
<br>

---

## 🖥️ Supported Operating Systems

## NetWatchdta v1.x automatically adapts to the underlying OS

| Category | Status | Supported Distributions | Notes |
| --- | --- | --- | --- |
| **Embedded** | ✅ **Perfect** | **OpenWrt** (19.07 - 24.x) | Uses `procd` & `uclient-fetch`, optimized for low RAM. |
| **Debian** | ✅ **Perfect** | **Debian**, **Ubuntu**, **Linux Mint**, **Kali**, **Raspberry Pi OS**, **Pop!_OS** | Uses `systemd`, `curl` & `apt`. |
| **Red Hat** | ✅ **Perfect** | **Fedora**, **RHEL**, **CentOS Stream**, **AlmaLinux**, **Rocky Linux** | Uses `systemd`, `curl` & `dnf`. |
| **Arch** | ✅ **Perfect** | **Arch Linux**, **Manjaro**, **EndeavourOS**, **Garuda** | Uses `systemd`, `curl` & `pacman`. |
| **SUSE** | ✅ **Perfect** | **OpenSUSE** (Leap/Tumbleweed) | Uses `systemd`, `curl` & `zypper`. |

### ❌ Incompatible / Untested

* **Alpine Linux** (Uses OpenRC, not supported yet).
* **Slackware / Void / Gentoo** (Non-Systemd inits).
* **BSD / macOS** (Different userland tools).
<br>

---

## 🚀 Installation

The installer will automatically detect your OS, install necessary dependencies (`curl`, `openssl`, etc.), and set up the service.

### OpenWrt (Routers)

*No sudo required.*

*Requires `Curl` if you have problem with the default uclient-fetch and/or if you want to manually swtich to curl*

```bash
wget --no-check-certificate -qO /tmp/install_netwatchdta.sh "https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/install_netwatchdta.sh" && sh /tmp/install_netwatchdta.sh

```

### Linux (Desktop/Server)

*Requires `curl` and `sudo`.*

```bash
sudo wget --no-check-certificate -qO /tmp/install_netwatchdta.sh "https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/install_netwatchdta.sh" && sudo bash /tmp/install_netwatchdta.sh

```

### The interactive installer will:

1. Check system requirements (Storage/RAM) and automatically set `EXEC_METHOD` and `SCAN_BATCH_SIZE`.
2. Ask for your **Notification Credentials** (Discord/Telegram).
3. Perform a live connectivity test.
4. Select basic settings (Silent Hours, Heartbeat).
5. Set up the system service (autostart).

### 📂 File Structure & Locations

<details>
<summary><strong>netwatchdta creates the following files during installation and operation.</strong></summary>

#### 1. Installation Directory

**Location:** `/opt/netwatchdta/` (Linux) or `/root/netwatchdta/` (OpenWrt).

| File Name | Description |
| --- | --- |
| `netwatchdta.sh` | The core logic script (the engine). |
| `settings.conf` | Main configuration file for user settings. |
| `device_ips.conf` | List of local IPs to monitor. |
| `remote_ips.conf` | List of remote IPs to monitor. |
| `.vault.enc` | Encrypted credential store (Discord/Telegram tokens). |
| `nwdta_silent_buffer` | Temporary buffer for alerts held during silent hours. |
| `nwdta_offline_buffer` | Temporary buffer for alerts held during Internet outages. |

#### 2. Temporary & Log Files

**Location:** `/tmp/netwatchdta/`
*(Note: These are created in RAM to prevent flash storage wear on routers)*

| File Name | Description |
| --- | --- |
| `nwdta_uptime.log` | The main event log (Service started, alerts sent, etc). |
| `nwdta_ping.log` | Detailed ping log (Only if `PING_LOG_ENABLE=YES`). |
| `nwdta_net_status` | Stores current internet status (`UP` or `DOWN`). |
| `*_d`, `*_c`, `*_t` | Various tracking files for timeout/failure counts. |

#### 3. System Service Files

These files integrate the script with your operating system.

| OS | File Path | Description |
| --- | --- | --- |
| **OpenWrt** | `/etc/init.d/netwatchdta` | Procd init script to manage the service. |
| **Linux** | `/etc/systemd/system/netwatchdta.service` | Systemd unit file to manage the service. |
| **Linux** | `/usr/local/bin/netwatchdta` | CLI wrapper command (allows typing `netwatchdta` directly). |

</details>




---

## 🛠️ Management & Commands

Once installed, use the CLI commands to manage the service.

### Service Commands

<details>
<summary><strong>List of all available commands</strong></summary>

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
| **Edit Settings** | `netwatchdta edit` | `/etc/init.d/netwatchdta edit` | Edit settings menu. |
| **Uninstall** | `netwatchdta purge` | `/etc/init.d/netwatchdta purge` | Launch the interactive uninstaller. |

</details>




### Configuration Settings (`settings.conf`)

Location: `/opt/netwatchdta/settings.conf` (Linux) or `/root/netwatchdta/settings.conf` (OpenWrt).

<details>
<summary><strong>List of all available settings</strong></summary>

| Setting | Description |
| :--- | :--- |
| `ROUTER_NAME` | The name displayed in the title of all notifications. |
| `FETCH_TOOL` | **AUTO**, `CURL`, `UCLIENT`. Controls which tool sends alerts. |
| `EXEC_METHOD` | **Notification Concurrency.**<br>`1` = Parallel (Fast, >=512MB RAM).<br>`2` = Queue (Safe, <512MB RAM). |
| `SCAN_BATCH_SIZE` | **Scanning Concurrency.**<br>`0` = Unlimited Parallel (High Performance).<br>`AUTO` = Smart Batching based on Free RAM.<br>`10` = Fixed number of parallel pings. |
| `LOG_ENABLE` | Enables writing events to `netwatchdta.log`. |
| `LOG_MAX_SIZE` | Max size of the log file in KB before rotation. |
| `DISCORD_ENABLE` | Master switch for Discord alerts. |
| `TELEGRAM_ENABLE` | Master switch for Telegram alerts. |
| `SILENT_ENABLE` | If `YES`, notifications are paused during specific hours. |
| `SILENT_START` | Hour to **start** silence (0-23). |
| `SILENT_END` | Hour to **end** silence (0-23). |
| `DISCORD_MENTION_LOCAL` | Mention on Local Device events. |
| `DISCORD_MENTION_REMOTE`| Mention on Remote Server events. |
| `DISCORD_MENTION_NET` | Mention on Internet (WAN) events. |
| `DISCORD_MENTION_HB`| Mention inside the daily Heartbeat report. |
| `CPU_GUARD_THRESHOLD` | System load value (1 min avg) to trigger pause. |
| `RAM_GUARD_MIN_FREE` | Minimum free RAM (in KB) required to run checks. |
| `HEARTBEAT` | Enables the periodic "I am still running" report. |
| `HB_INTERVAL` | Seconds between heartbeats (86400s = 24 Hours). |
| `HB_TARGET` | `DISCORD`, `TELEGRAM`, or `BOTH`. |
| `HB_START_HOUR` | The hour (0-23) the heartbeat aligns to (e.g., `12` for Noon). |
| `HB_START_MIN` | The minute (0-59) the heartbeat aligns to (e.g., `30`). |
| `EXT_CHECK_ENABLE` |  Enables monitoring of the external internet connection. |
| `EXT_IP1` | Primary public IP to ping (Google DNS). |
| `EXT_IP2` | Secondary public IP to ping (Cloudflare DNS). |
| `EXT_SCAN_INTERVAL` | Seconds between internet checks. |
| `EXT_FAIL_THRESHOLD` | Consecutive failed pings before marking Internet as DOWN. |
| `EXT_PING_COUNT` | Number of packets per internet check. |
| `EXT_PING_TIMEOUT` | Seconds to wait for ping response. |
| `DEV_CHECK_ENABLE` | Enables monitoring of devices in `device_ips.conf`. |
| `DEV_CHECK_INTERVAL` | Seconds between checks for local devices. |
| `DEV_FAIL_THRESHOLD` | Consecutive failed pings before marking a Device as DOWN. |
| `DEV_PING_COUNT` | Number of packets per device check. |
| `DEV_PING_TIMEOUT` | Seconds to wait for device ping response. |
| `REM_CHECK_ENABLE` | Enables monitoring of servers in `remote_ips.conf`. |
| `REM_CHECK_INTERVAL` | Seconds between checks for remote servers. |
| `REM_FAIL_THRESHOLD` | Consecutive failed pings before marking a Server as DOWN. |
| `REM_PING_COUNT` | Number of packets per remote check. |
| `REM_PING_TIMEOUT` | Seconds to wait for remote ping response. |
</details>




### LuCI Web Interface Integration

<details>
<summary><strong>Installation guide</strong></summary>

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

</details>




---

## 🗑️ Uninstallation

You have two ways to uninstall the tool. Both launch the interactive **Smart Uninstaller** which asks if you want to remove everything or keep your settings.

### Method 1: Built-in (Recommended)

* **OpenWrt:** 
```bash 
/etc/init.d/netwatchdta purge
```

* **Linux:** 
```bash 
sudo netwatchdta purge
```

### Method 2: Emergency Script

If the installation is broken, use the remote uninstaller:

* **OpenWrt:** 
```bash 
`wget --no-check-certificate -qO /tmp/uninstall_netwatchdta_wrt.sh "https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/uninstall_netwatchdta.sh" && sh /tmp/uninstall_netwatchdta_wrt.sh`
```

* **Linux:** 
```bash 
`wget --no-check-certificate -qO /tmp/uninstall_netwatchdta.sh "https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/uninstall_netwatchdta.sh" && sudo bash /tmp/uninstall_netwatchdta.sh`
```


---

## 📊 Performance & Resource Analysis

This document provides a detailed technical breakdown of **netwatchdta** resource usage.
Calculations are provided for **OpenWrt** (using both `uclient-fetch` and `curl`) and **Standard Linux**.

<details>
<summary><strong>Click here to expand full document</strong></summary>

### 1. 💾 Disk / Flash Storage Requirements

*Space required for installation (Script + Dependencies).*

| Component | OpenWrt (uclient-fetch) | OpenWrt (curl) | Linux (Standard) | Notes |
| --- | --- | --- | --- | --- |
| **Core Script** | ~60 KB | ~60 KB | ~60 KB | Includes config & service files. |
| **SSL Libs** | ~1.3 MB | ~1.3 MB | ~2.0 MB | `openssl-util` & `ca-bundle`. |
| **Fetch Tool** | ~20 KB | ~1.5 MB | ~2.0 MB | `uclient` is native/tiny. `curl` is heavy. |
| **TOTAL** | **~1.4 MB** | **~2.9 MB** | **~4.1 MB** | **Recommendation:** Use `uclient` on OpenWrt. |

---

### 2. 💤 RAM Usage at Idle

*Baseline memory usage when the service is sleeping between checks.*

| Platform | Shell | RAM Usage | Why the difference? |
| --- | --- | --- | --- |
| **OpenWrt** | `ash` | **~0.4 MB** | Optimized for embedded devices (BusyBox). |
| **Linux** | `bash` | **~3.5 MB** | Feature-rich shell with larger memory footprint. |

---

### 3. 📡 Scanning Phase (Concurrent Pings)

*Resource usage depends on `SCAN_BATCH_SIZE` setting.*

#### **Mode A: Full Parallel (`SCAN_BATCH_SIZE=0`)**

*Default for RAM >= 512MB. Launches all pings at once.*

| Scale | OpenWrt RAM Spike | CPU Load (MIPS) | Execution Time |
| --- | --- | --- | --- |
| **10 Devices** | ~4.0 MB | Low | ~1s |
| **50 Devices** | **~20.0 MB** | 100% (1s) | **~1s** |
| **100 Devices** | **~40.0 MB** | 100% (2s) | **~2s** |

#### **Mode B: Smart Batching (`SCAN_BATCH_SIZE=AUTO`)**

*Default for RAM < 512MB. Dynamically calculates safe limit based on **Free RAM & CPU Cores**.*
*Example: Single-Core MIPS Router -> Caps at 10 pings/batch.*

| Scale | OpenWrt RAM Spike | CPU Load (MIPS) | Execution Time | Stability |
| --- | --- | --- | --- | --- |
| **10 Devices** | ~4.0 MB | Low | ~1s | ✅ High |
| **50 Devices** | **~6.0 MB** | Moderate | **~5s** | ✅ High |
| **100 Devices** | **~6.0 MB** | Moderate | **~10s** | ✅ High |

> **ℹ️ Conclusion:** **Smart Batching** ensures that even ancient single-core routers can monitor 100+ devices without freezing, by splitting the work into safe, tiny chunks.


---

### 4. 🔔 Notification Phase (The Hybrid Engine)

*Resource usage depends on `EXEC_METHOD` (Notification Concurrency).*

#### **Method 1: Parallel Notifications (`EXEC_METHOD=1`)**

*Fastest. Default for >= 512MB RAM.*

| Scale | OpenWrt (uclient) | OpenWrt (curl) | Linux (curl) | Execution Time Single | Execution Time Dual |
| --- | --- | --- | --- | --- | --- |
| **1 Event** | ~0.6 MB | ~2.5 MB | ~5.0 MB | ~1s | ~2s |
| **5 Events** | ~3.0 MB | ~12.5 MB | ~25.0 MB | ~1s | ~2s |
| **50 Events** | **~30.0 MB** | **~125.0 MB** ⚠️ | **~250.0 MB** | **~2s** | **~4s** |

#### **Method 2: Queue Notifications (`EXEC_METHOD=2`)**

*Safest. Default for < 512MB RAM.*

| Scale | OpenWrt (uclient) | OpenWrt (curl) | Linux (curl) | Execution Time Single | Execution Time Dual |
| --- | --- | --- | --- | --- | --- |
| **1 Event** | ~0.6 MB | ~2.5 MB | ~5.0 MB | ~1s | ~2s |
| **5 Events** | ~2.0 MB | ~4.0 MB | ~17.0 MB | ~5s | ~10s |
| **50 Events** | **~15.0 MB** 🟢 | **~17.0 MB** 🟢 | **~152.0 MB** | **~50s** | **~100s** 🕒 |

---

### 📈 Hardware Recommendations / Safe Device Limits Table

To ensure stability, choose the configuration that matches your hardware capabilities.

#### **1. Method 1: Parallel Mode**

* **Setting:** `EXEC_METHOD=1`
* **Best for:** Devices with **>512MB RAM**.
* **Behavior:** Instant alerts. High RAM usage during mass outages.

| Chipset Tier | Example Devices | RAM Spike (50 Events) | Safe Limit (Single Notif) | Safe Limit (Dual Notif) | Recommended? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Legacy (MIPS)** | Ubiquiti ER-X, Xiaomi 4A | **CRITICAL (~125 MB)** | **~10 Devices** | **~5 Devices** | ❌ **NO** |
| **Mid-Range (ARM)** | Pi Zero 2, Pi 3, Flint 2 | **High (~150 MB)** | **~40 Devices** | **~25 Devices** | ⚠️ **CAUTION** |
| **High-End (x86/ARM)** | N100, Pi 4/5, NanoPi R6 | **Low Load** | **200+ Devices** | **150+ Devices** | ✅ **YES** |

#### **2. Method 2: Queue Mode**

* **Setting:** `EXEC_METHOD=2`
* **Best for:** Devices with **<512MB RAM**.
* **Behavior:** Alerts queue up one by one. Zero RAM spikes.

| Chipset Tier | Example Devices | RAM Spike (50 Events) | Safe Limit (Single Notif) | Safe Limit (Dual Notif) | Recommended? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Legacy (MIPS)** | Ubiquiti ER-X, Xiaomi 4A | **~17 MB (Safe)** | **~60 Devices** | **~35 Devices** | ✅ **YES** |
| **Mid-Range (ARM)** | Pi Zero 2, Pi 3, Flint 2 | **~20 MB (Safe)** | **100+ Devices** | **~60 Devices** | ✅ **YES** |
| **High-End (x86/ARM)** | N100, Pi 4/5, NanoPi R6 | **Negligible** | **Unlimited** | **Unlimited** | ❌ **Unnecessary** |

---

### Recommended Configuration by Device

| Device Class | RAM | Scan Mode (`SCAN_BATCH_SIZE`) | Notif Mode (`EXEC_METHOD`) | Safe Device Limit |
| :--- | :--- | :--- | :--- | :--- |
| **Legacy / Tiny**<br>*(WR841N, ER-X, Pi Zero 1)* | 128MB - 256MB | **AUTO** (Batch ~10 Max) | **Queue** (2) | **50+** |
| **Mid-Range**<br>*(Pi 3, Xiaomi 4A, Gl.iNet)* | 256MB - 512MB | **AUTO** (Batch ~25 Max) | **Queue** (2) | **100+** |
| **High-End / x86**<br>*(Pi 4/5, N100, NanoPi R6)* | 512MB+ | **0** (Parallel) | **Parallel** (1) | **Unlimited** |

> **⚠️ The "Golden Rule" of Stability**
> If you are ever in doubt, or if your device feels sluggish:
> **Set `SCAN_BATCH_SIZE=AUTO`.**
>
> It is better to check your 100 devices in **5 seconds** (Batch) than to check them in **1 second** (Parallel) and crash the router.

<details>
<summary><strong>💡 Final Thoughts & Advice</strong></summary>

### 👤 Profile 1: The "Pure Watchdog"
* **Goal:** A cheap, dedicated monitoring device (e.g., Pi Zero 1, Old Router).
* **The Fix:** You **must** use **Queue Mode** (`EXEC_METHOD=2`) and **Batch Scanning** (`SCAN_BATCH_SIZE=AUTO`).
* **Why:** This ensures the device never runs out of RAM, even if it monitors 100 IPs.

### 👤 Profile 2: The "Network Enhancer"
* **Goal:** Running this alongside AdGuard Home or VPN on a mid-range device (Pi 3, Flint 2).
* **The Fix:** **Parallel Mode** (`EXEC_METHOD=1`) is usually safe, but don't go crazy with 100+ devices if you also have heavy VPN traffic.

### 👤 Profile 3: The "Power User"
* **Goal:** Running on an Intel N100, Raspberry Pi 5, or NanoPi R6S.
* **The Fix:** Use **Parallel Mode** (`EXEC_METHOD=1`) and **Unlimited Scanning** (`SCAN_BATCH_SIZE=0`). Your hardware is powerful enough to handle anything.

> **⚠️ The "Golden Rule" of Stability**
> If you are ever in doubt, or if your device feels sluggish:
> **Switch to Queue Mode.**
>
> It is better to receive your 50th alert **2 minutes late** than to have your monitoring device **crash** because it tried to send them all at the exact same second.
</details>
</details>

---

## 🔒 Security Note

This script uses **OpenSSL AES-256** to encrypt your Discord Webhook and Telegram Token. The encryption key is generated based on your device's unique CPU Serial and MAC address.

* **Benefit:** If someone copies your config files to another machine, they cannot decrypt your credentials.
* **Note:** If you change your hardware (e.g., swap Raspberry Pis), you must run the installer again to re-encrypt your credentials.

---

## 📜 License

This project is licensed under the **GNU General Public License v3.0**.
Copyright (C) 2025 panoc

```
