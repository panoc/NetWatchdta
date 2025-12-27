# 🌐 NetWatchdta

> **Network Monitor with Real Time Alerts for OpenWrt & Linux**

<p align="left">
  <img src="https://img.shields.io/badge/OS-OpenWrt%20%7C%20Linux-1272ba?style=flat-squarelogo=openwrt&logoColor=white">
  <img src="https://img.shields.io/badge/Network-Monitoring%20and%20Logs-006400?style=flat-square&logo=activity&logoColor=white">  
   <img src="https://img.shields.io/badge/Alerts-Discord%20%26%20Telegram-7289da?style=flat-square&logo=alerts&logoColor=white">
 <img src="https://img.shields.io/badge/Shell-Script-orange?style=flat-square&logo=alerts&logoColor=orange">
  </p>

**NetWatchdta** is a POSIX-compliant, lightweight, robust, and highly configurable network monitoring script. It continuously monitors your Internet connection (WAN), Local Devices (LAN), and Remote Servers, sending real-time alerts via **Discord** and **Telegram**.

Originally designed for OpenWrt routers, **v1.x** has been re-engineered as a **Universal Application**. It automatically detects your operating system, adjusts its dependencies, adjusts default settings based on your hardware and installs as a native system service (`procd` for OpenWrt, `systemd` for Linux).
<br>

---

## ✨ Key Features

* **Universal Installer:** One script works on OpenWrt routers, Raspberry Pis, VPSs, and Desktop Linux.
* **Universal Compatibility:** Runs on OpenWrt (Ash) and Standard Linux (Bash/Systemd).
* **Smart Engine:**
     * **OpenWrt:** Uses `uclient-fetch` and minimal RAM logic.
     * **Linux:** Uses `curl` and `systemd` for maximum stability.
* **Dual Notifications:** Send alerts to **Discord** (with rich embeds) and **Telegram** simultaneously or selectively.
* **Encryption Vault:** Credentials (tokens/webhooks) are encrypted using OpenSSL AES-256 and locked to your specific hardware.
* **Offline Buffer:** If the internet goes down, alerts are queued and delivered in bulk once connectivity is restored. No notifications are lost.
* **Silent Mode:** Mute alerts during specific hours (e.g., sleeping time), but keep logging them to the buffer.
* **Heartbeat:** Periodic "I am alive" messages to confirm the system is running.
* **Multi-Tier Monitoring:**
     * **Internet (WAN):** Checks external IPs (Cloudflare/Google/Custom).
     * **Local (LAN):** Monitors devices on your network (e.g., NAS, Cameras).
     * **Remote:** Monitors external servers (only checks if WAN is UP).
<br>

---

## 🖥️ Supported Operating Systems

## NetWatchdta v1.x automatically adapts to the underlying OS

| Category | Status | Supported Distributions | Notes |
| --- | --- | --- | --- |
| **Embedded** | ✅ **Perfect** | **OpenWrt** (19.07 - 24.x) | Uses `procd`, optimized for low RAM. |
| **Debian** | ✅ **Perfect** | **Debian**, **Ubuntu**, **Linux Mint**, **Kali**, **Raspberry Pi OS**, **Pop!_OS** | Uses `systemd` & `apt`. |
| **Red Hat** | ✅ **Perfect** | **Fedora**, **RHEL**, **CentOS Stream**, **AlmaLinux**, **Rocky Linux** | Uses `systemd` & `dnf`. |
| **Arch** | ✅ **Perfect** | **Arch Linux**, **Manjaro**, **EndeavourOS**, **Garuda** | Uses `systemd` & `pacman`. |
| **SUSE** | ✅ **Perfect** | **OpenSUSE** (Leap/Tumbleweed) | Uses `systemd` & `zypper`. |

### ❌ Incompatible / Untested

* **Alpine Linux** (Uses OpenRC, not supported yet).
* **Slackware / Void / Gentoo** (Non-Systemd inits).
* **BSD / macOS** (Different userland tools).
<br>

---

## 🚀 Installation

The installer will automatically detect your OS, install necessary dependencies (`curl`, `openssl`, etc.), and set up the service.

### Option 1: Linux (Desktop/Server)

*Requires `curl` and `sudo`.*

```bash
sudo wget --no-check-certificate -qO /tmp/install_netwatchdta.sh "https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/install_netwatchdta.sh" && sudo bash /tmp/install_netwatchdta.sh

```

### Option 2: OpenWrt (Routers)

*No sudo required.*

*Requires `Curl` if you have problem with the default uclient-fetch and/or if you want to manually swtich to curl*

```bash
wget --no-check-certificate -qO /tmp/install_netwatchdta.sh "https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/install_netwatchdta.sh" && sh /tmp/install_netwatchdta.sh

```

### The interactive installer will:

1. Check system requirements (Storage/RAM) and will automatically set the appropriate settings.
2. Ask for your **Notification Credentials** (Discord/Telegram).
3. Perform a live connectivity test.
4. Select some basic settings.
5. Set up the system service (autostart).

### 📂 File Structure & Locations

<details>
<summary><strong>netwatchdta creates the following files during installation and operation.</strong></summary>

#### 1. Installation Directory
**Location:** `/opt/netwatchdta/` (Linux) or `/root/netwatchdta/` (OpenWrt).

| File Name | Description |
| :--- | :--- |
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
| :--- | :--- |
| `nwdta_uptime.log` | The main event log (Service started, alerts sent, etc). |
| `nwdta_ping.log` | Detailed ping log (Only if `PING_LOG_ENABLE=YES`). |
| `nwdta_net_status` | Stores current internet status (`UP` or `DOWN`). |
| `*_d`, `*_c`, `*_t` | Various tracking files for timeout/failure counts. |

#### 3. System Service Files
These files integrate the script with your operating system.

| OS | File Path | Description |
| :--- | :--- | :--- |
| **OpenWrt** | `/etc/init.d/netwatchdta` | Procd init script to manage the service. |
| **Linux** | `/etc/systemd/system/netwatchdta.service` | Systemd unit file to manage the service. |
| **Linux** | `/usr/local/bin/netwatchdta` | CLI wrapper command (allows typing `netwatchdta` directly). |  
</details>
<br>

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
<br>

### Configuration Settings (`settings.conf`)

Location: `/opt/netwatchdta/settings.conf` (Linux) or `/root/netwatchdta/settings.conf` (OpenWrt).

<details>
<summary><strong>List of all available settings</strong></summary>

| Setting | Description |
| :--- | :--- |
| `ROUTER_NAME` | The name displayed in the title of all notifications. |
| `FETCH_TOOL` | **AUTO**, `CURL`, `UCLIENT`, or `WGET`. Controls which tool sends alerts. |
| `EXEC_METHOD` | `1` = Parallel (Fast), `2` = Sequential (Low RAM). Auto-detected on install. |
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
| `DISCORD_MENTION_HEARTBEAT`| Mention inside the daily Heartbeat report. |
| `CPU_GUARD_THRESHOLD` | System load value (1 min avg) to trigger pause. |
| `RAM_GUARD_MIN_FREE` | Minimum free RAM (in KB) required to run checks. |
| `HEARTBEAT` | Enables the periodic "I am still running" report. |
| `HB_INTERVAL` | Seconds between heartbeats (86400s = 24 Hours). |
| `HB_TARGET` | `DISCORD`, `TELEGRAM`, or `BOTH`. |
| `HB_START_HOUR` | The hour (0-23) the heartbeat aligns to (e.g., `12` for Noon). |
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
| `REM_PING_COUNT | Number of packets per remote check. |
| `REM_PING_TIMEOUT | Seconds to wait for remote ping response. |
</details>
<br>

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
* **Command:** `/etc/init.d/netwatchdta logs` or `sudo netwatchdta logs'
* Click **Save & Apply**.

Now you can view the live monitor logs directly from your browser by going to **System** ➡️ **Custom Commands**!
</details>
<br>

---

## 🗑️ Uninstallation

You have two ways to uninstall the tool. Both launch the interactive **Smart Uninstaller** which asks if you want to remove everything or keep your settings.

### Method 1: Built-in (Recommended)

* **Linux:** 
```bash 
sudo netwatchdta purge
```

* **OpenWrt:** 
```bash 
/etc/init.d/netwatchdta purge
```

### Method 2: Emergency Script

If the installation is broken, use the remote uninstaller:

* **Linux:** 
```bash 
`wget --no-check-certificate -qO /tmp/uninstall_netwatchdta.sh "https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/uninstall_netwatchdta.sh" && sudo bash /tmp/uninstall_netwatchdta.sh`
```

* **OpenWrt:** 
```bash 
`wget --no-check-certificate -qO /tmp/uninstall_netwatchdta_wrt.sh "https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/uninstall_netwatchdta.sh" && sh /tmp/uninstall_netwatchdta_wrt.sh`
```
<br>

---

## 📊 Performance & Resource Analysis

This document provides a detailed technical breakdown of **netwatchdta v1.3.6** resource usage.
Calculations are provided for **OpenWrt** (using both `uclient-fetch` and `curl`) and **Standard Linux**.

---

### 1. 💾 Disk / Flash Storage Requirements
*Space required for installation (Script + Dependencies).*

| Component | OpenWrt (uclient-fetch) | OpenWrt (curl) | Linux (Standard) | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Core Script** | ~50 KB | ~50 KB | ~50 KB | Includes config & service files. |
| **SSL Libs** | ~1.3 MB | ~1.3 MB | ~2.0 MB | `openssl-util` & `ca-bundle`. |
| **Fetch Tool** | ~20 KB | ~1.5 MB | ~2.0 MB | `uclient` is native/tiny. `curl` is heavy. |
| **TOTAL** | **~1.4 MB** | **~2.9 MB** | **~4.1 MB** | **Recommendation:** Use `uclient` on OpenWrt. |

---

### 2. 💤 RAM Usage at Idle
*Baseline memory usage when the service is sleeping between checks.*

| Platform | Shell | RAM Usage | Why the difference? |
| :--- | :--- | :--- | :--- |
| **OpenWrt** | `ash` | **~0.4 MB** | Optimized for embedded devices (BusyBox). |
| **Linux** | `bash` | **~3.5 MB** | Feature-rich shell with larger memory footprint. |

---

### 3. 📡 Scanning Phase (Forced Parallel)
*In v1.3.6, scanning is **always parallel** to ensure millisecond-precision detection.*
*Metrics indicate the temporary spike during the ~1 second check window.*

**Formula:** `(Shell Overhead + Ping Overhead) × Device Count`

| Metric | 1 Device | 5 Devices | 50 Devices | Impact |
| :--- | :--- | :--- | :--- | :--- |
| **OpenWrt RAM** | ~0.4 MB | ~2.0 MB | **~20.0 MB** | Safe for >128MB routers. |
| **Linux RAM** | ~3.0 MB | ~15.0 MB | **~150.0 MB** | High, but negligible for PCs (8GB+ RAM). |
| **CPU Load** | Negligible | Low | **High Spike** | 100% CPU for ~1s on MIPS (MT7621) routers. |
| **Execution Time** | ~1.0s | ~1.0s | **~1.0s** | **Scale Invariant:** Checks happen simultaneously. |

> **ℹ️ Note on 50 Devices:** On low-end routers (MIPS), forking 50 background processes will spike the CPU to 100%, but because it finishes in 1 second, it does not impact long-term stability.

---

### 4. 🔔 Notification Phase (The Hybrid Engine)
*Resource usage depends on the **Execution Mode** (Parallel vs. Queue) and the number of destinations.*

**A. Single Destination (Discord OR Telegram)** *Scenario: Sending alerts to one platform.*

**B. Dual Destination (Discord AND Telegram)** *Scenario: Sending alerts to BOTH platforms for every event.*

*Logic: The script sends sequentially (Discord → Wait → Telegram), so RAM usage is based on the single peak of the active tool, but Execution Time doubles.*

#### **Method 1: Parallel Mode (High Performance)**
*Auto-selected for RAM > 256MB. All alerts send instantly.*

| Scale | OpenWrt (uclient) | OpenWrt (curl) | Linux (curl) | Execution Time  Single | Execution Time Dual |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1 Event** | ~0.6 MB | ~2.5 MB | ~5.0 MB | ~1 | ~2s |
| **5 Events** | ~3.0 MB | ~12.5 MB | ~25.0 MB | ~1s | ~2s |
| **50 Events** | **~30.0 MB** | **~125.0 MB** ⚠️ | **~250.0 MB** | **~2s** | **~4s** |

#### **Method 2: Queue Mode (Low RAM / Safe)**
*Auto-selected for RAM < 256MB. Alerts wait in line.*
*Formula: `(1 Active Transfer) + (N-1 Waiting Shells)`*

| Scale | OpenWrt (uclient) | OpenWrt (curl) | Linux (curl) | Execution Time  Single | Execution Time Dual |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1 Event** | ~0.6 MB | ~2.5 MB | ~5.0 MB | ~1s | ~10s |
| **5 Events** | ~2.0 MB | ~4.0 MB | ~17.0 MB | ~5s | ~10s |
| **50 Events** | **~15.0 MB** 🟢 | **~17.0 MB** 🟢 | **~152.0 MB** | **~50s** | **~100s** 🕒 |

---

> **⚠️ The Trade-off:** In Queue Mode with 50 mass failures sending to both Discord & Telegram, the last notification will arrive **~100 seconds (1.5 mins)** after the event. This delay is intentional to save your router from crashing due to OOM (Out of Memory).

> * **Why is "Dual Notif" lower?** In Queue Mode, sending to two platforms doubles the execution time per event. Monitoring 100 devices with Dual Notifications would result in a **~3.5 minute delay** for the last alert to arrive.
> * **Recommendation:** If monitoring >50 devices on a low-end router, stick to **Single Notification** (e.g., Discord only) to keep alerts timely.
---

### 📈 Hardware Recommendations

### Safe Device Limits Table

#### **1. Method 1: Parallel Mode**
*Auto-selected for devices with **>256MB RAM**. Instant Alerts.*
*Limiting Factor: RAM Spike (Risk of Crash).*

| Chipset Tier | Example Devices | 50 Events (RAM Spike) | Est. Safe Max (Single Notif) | Est. Safe Max (Dual Notif) | Recommended? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Legacy (MIPS)** | Ubiquiti ER-X, Xiaomi 4A | **💀 CRITICAL (~125 MB)** | **~10 - 15 Devices** | **~5 - 10 Devices** | **❌ NO** |
| **Mid-Range (ARM)** | Pi Zero 2, Flint 2, Pi 3 | **High Spike (~150 MB)** | **~30 - 40 Devices** | **~20 - 30 Devices** | **⚠️ CAUTION** |
| **High-End x86/ARM** | N100, Pi 4/5, NanoPi R6S | **Low Load** | **200+ Devices** | **150+ Devices** | **✅ YES** |

#### **2. Method 2: Queue Mode**
*Auto-selected for devices with **<256MB RAM**. Guaranteed Stability.*
*Limiting Factor: Time Delay (Alerts arrive late).*

| Chipset Tier | Example Devices | 50 Events (RAM Spike) | Est. Safe Max (Single Notif) | Est. Safe Max (Dual Notif) | Recommended? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Legacy (MIPS)** | Ubiquiti ER-X, R6220, Xiaomi 4A | **~17 MB (Very Safe)** | **~50 - 70 Devices**<br>*(~50s delay)* | **~30 - 40 Devices**<br>*(~60s delay)* | **✅ YES** |
| **Mid-Range (ARM)** | Pi Zero 2, Flint 2, Pi 3  | **~20 MB (Negligible)** | **100+ Devices**<br>*(~100s delay)* | **~50 - 60 Devices**<br>*(~100s delay)* | **✅ YES** |
| **High-End x86/ARM** | N100, Pi 4/5, NanoPi R6 | **Negligible** | **Unlimited** | **Unlimited** | **❌ Unnecessary** |

> **ℹ️ Analytic Conclusion:**
> * **OpenWrt Users:** Even on ancient hardware, you can monitor 50+ devices safely using **Queue Mode**.
> * **Linux Users:** Due to Bash memory overhead, monitoring 50+ devices requires at least **512MB RAM**, regardless of mode.


### 👤 **Profile 1: The "Pure Watchdog"**
* **Goal:** You want a cheap, dedicated device just to monitor your other servers/internet. You don't want to spend money on new hardware.
* **The Problem:** Low-end devices (like the **Pi Zero 1** or **MIPS routers**) lack hardware encryption.
* **The Fix:** You **must** use **Sequential Mode**.
* **Why:** Sequential mode creates ZERO resource spikes. Even a device from 2013 can monitor 1,000 IPs safely if it checks them one by one.
* **Recommended Devices:**
    * **Raspberry Pi Zero W:** Tiny, wireless, runs off a phone charger.
    * **Old Router (e.g., Archer C7, Xiaomi 4A):** Flash OpenWrt on it and give it a second life as a dedicated monitor.

### 👤 **Profile 2: The "Network Enhancer"**
* **Goal:** You want to run the monitoring script *alongside* moderate network tasks like **AdGuard Home** (ad blocking), **Tailscale** (VPN), or a **Unifi Controller**.
* **The Constraint:** You need a device with **ARMv8** architecture (modern 64-bit CPU). This gives you the "Crypto Extensions" needed to handle the script's SSL alerts without slowing down your DNS or VPN.
* **Mode:** **Parallel Mode** is safe here, but keep the "Concurrent Failures" setting reasonable (don't expect it to handle 100 simultaneous failures without a hiccup).
* **Recommended Devices:**
    * **Raspberry Pi 3B+ / 4:** The standard choice.
    * **NanoPi R4S:** Excellent networking performance for the price.
    * **GL.iNet Flint 2:** A powerful router that can run this script natively without affecting Wi-Fi speeds.

### 👤 **Profile 3: The "Power User / Lab"**
* **Goal:** This device is your **Main Router** (handling Gigabit fiber) OR a **Home Server** (running Docker, Home Assistant, Plex/Jellyfin).
* **The Reality:** The monitoring script is negligible for these devices. You can run **Parallel Mode** with 200+ devices and the CPU won't even blink.
* **Why:** These CPUs (Intel N100, RK3588) have massive power reserves. The script's 100-200MB RAM usage is a "drop in the bucket" for systems with 4GB+ RAM.
* **Recommended Devices:**
    * **NanoPi R6S:** The king of ARM routers (dual 2.5Gbps ports).
    * **Intel N100 Mini PC:** The ultimate low-power x86 server.
    * **Raspberry Pi 5:** Overkill for just monitoring, but perfect if running a full homelab.

> **⚠️ The "Golden Rule" of Stability**
> If you are ever in doubt, or if your device feels sluggish:
> **Switch to Sequential Mode.**
>
> It is better to receive your 50th alert **2 minutes late** than to have your monitoring device **crash** because it tried to send them all at the exact same second.
</details>






---

## 🔒 Security Note

This script uses **OpenSSL AES-256** to encrypt your Discord Webhook and Telegram Token. The encryption key is generated based on your device's unique CPU Serial and MAC address.

* **Benefit:** If someone copies your config files to another machine, they cannot decrypt your credentials.
* **Note:** If you change your hardware (e.g., swap Raspberry Pis), you must run the installer again to re-encrypt your credentials.
<br>

---

## 📜 License

This project is licensed under the **GNU General Public License v3.0**.
Copyright (C) 2025 panoc
