---

# 🌐 NetWatchdta (Universal)

> **The Grand Unified Network Monitor for OpenWrt & Linux**

**NetWatchdta** is a lightweight, robust, and highly configurable network monitoring script. It continuously monitors your Internet connection (WAN), Local Devices (LAN), and Remote Servers, sending real-time alerts via **Discord** and **Telegram**.

Originally designed for OpenWrt routers, **v4.x** has been re-engineered as a **Universal Application**. It automatically detects your operating system, adjusts its dependencies, and installs as a native system service (`procd` for OpenWrt, `systemd` for Linux).

---

<details>
<summary><strong>📊 Click to expand: Resource Scaling by Chipset & Architecture</strong></summary>

### **1. Parallel Mode (Performance Focused)**
*Simultaneous execution. Fastest alerts, but creates a CPU spike due to concurrent TLS handshakes.*

| Chipset Tier | Common CPU / Architecture | Example Devices | 5 Events (CPU) | **5 Events (RAM)** | 50 Events (CPU) | **50 Events (RAM)** | Recommended? |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Legacy MIPS** | **MediaTek MT7621**<br>*(MIPS 1004Kc Dual)* | Ubiquiti ER-X, Xiaomi 4A Gig | Moderate | **~3 MB** | **💀 CRITICAL**<br>*(100% CPU Lag)* | **~12 MB** | **❌ NO**<br>*(Use Sequential)* |
| | **Qualcomm QCA95xx**<br>*(MIPS 74Kc Single)* | Archer C7, TP-Link WDR4300 | Moderate | **~3 MB** | **💀 CRITICAL**<br>*(100% CPU Freeze)* | **~12 MB** | **❌ NO**<br>*(Use Sequential)* |
| **Mid-Range** | **Rockchip RK3399**<br>*(ARMv8 Hexa-Core)* | **NanoPi R4S**, R2S, Orange Pi | Negligible | **~8 MB** | **Moderate**<br>*(~60% CPU)* | **~25 MB** | **✅ YES**<br>*(Excellent)* |
| | **Broadcom BCM2711**<br>*(ARMv8 Quad-Core)* | **Raspberry Pi 4**, Pi 5 | Negligible | **~8 MB** | **Moderate**<br>*(~60% CPU)* | **~25 MB** | **✅ YES**<br>*(Excellent)* |
| | **MediaTek Filogic 820**<br>*(ARMv8 Cortex-A53)* | **Flint 2 (MT6000)**, AX3000 | Negligible | **~4 MB** | **High Spike**<br>*(~80% CPU)* | **~18 MB** | **✅ YES**<br>*(Safe)* |
| **High-End** | **Rockchip RK3588**<br>*(ARMv8 Octa-Core)* | **NanoPi R6S**, Orange Pi 5 | Negligible | **~10 MB** | **Low Load**<br>*(~20% CPU)* | **~40 MB** | **✅ YES**<br>*(Best Perf)* |
| | **Intel N100 / x86**<br>*(x86_64)* | Mini PC Routers, PfSense | Negligible | **~20 MB** | **Low Load**<br>*(~15% CPU)* | **~150 MB*** | **✅ YES**<br>*(Best Perf)* |

> ***Note on x86 RAM:** Linux `bash` and `curl` use significantly more private memory per process than OpenWrt's optimized `ash` and `uclient-fetch`.*

### **2. Sequential Mode (Stability Focused)**
*One-by-one execution. Zero spikes. **Mandatory for MIPS**.*

| Chipset Tier | Common CPU / Architecture | Example Devices | 5 Events (CPU) | **5 Events (RAM)** | 50 Events (CPU) | **50 Events (RAM)** | Recommended? |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Legacy MIPS** | **MediaTek MT7621** | Ubiquiti ER-X, R6220 | Low (<10%) | **~2 MB** | **Safe (<25%)** | **~2 MB** | **✅ YES**<br>*(Mandatory)* |
| | **Qualcomm QCA95xx** | Archer C7, WDR4300 | Low (<10%) | **~2 MB** | **Safe (<25%)** | **~2 MB** | **✅ YES**<br>*(Mandatory)* |
| **Mid-Range** | **All ARMv8 Chips** | NanoPi R4S, RPi 4, Flint 2 | Negligible | **~4 MB** | **Negligible** | **~4 MB** | **⚠️ Optional**<br>*(Max Stability)* |
| **High-End** | **x86 / RK3588** | N100, NanoPi R6S | Negligible | **~15 MB** | **Negligible** | **~15 MB** | **❌ Unnecessary** |

</details>

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

### ❌ Incompatible / Untested

* **Alpine Linux** (Uses OpenRC, not supported yet).
* **Slackware / Void / Gentoo** (Non-Systemd inits).
* **BSD / macOS** (Different userland tools).

---

## 🚀 Installation

The installer will automatically detect your OS, install necessary dependencies (`curl`, `openssl`, etc.), and set up the service.

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

### 📊 RAM & CPU Usage Scaling (Stress Test)
*Estimates based on simultaneous failure events triggering alerts.*

| Simultaneous Failures | OS Environment | Network Tool | Shell | Est. CPU Usage (Peak) | Est. RAM Usage (Total) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **5 Events** | **OpenWrt** | `uclient-fetch` | `ash` | Low (< 5%) | **~1.5 - 2.5 MB** |
| | **Linux** | `curl` | `bash` | Low (< 10%) | **~15 - 20 MB** |
| | | | | | |
| **20 Events** | **OpenWrt** | `uclient-fetch` | `ash` | Moderate (~25-40%) | **~5 - 8 MB** |
| | **Linux** | `curl` | `bash` | Moderate (~20-30%) | **~60 - 80 MB** |
| | | | | | |
| **50 Events** | **OpenWrt** | `uclient-fetch` | `ash` | **Critical Spike (100%)*** | **~15 - 25 MB** |
| | **Linux** | `curl` | `bash` | High Spike (~70-80%) | **~150 - 200 MB** |

> **\*Note on OpenWrt CPU:** The 100% CPU spike during 50 simultaneous events is due to the heavy math required for 50 concurrent TLS (HTTPS) handshakes. While RAM usage remains safe/low due to shared libraries, the processor may be momentarily saturated, potentially causing brief web interface lag.

> **Note on Linux RAM:** Linux memory usage is significantly higher because `bash` and `curl` do not share memory resources as efficiently as `ash` and `uclient-fetch` do on embedded systems.

---

### 📊 RAM & CPU Usage Scaling (Stress Test)
*Estimates comparing Parallel (High Performance) vs. Sequential (Low RAM) modes.*

| Execution Mode | Simultaneous Failures | OS | Tool | Est. CPU Usage (Peak) | Est. RAM Usage (Peak) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Parallel**<br>*(Fastest Alerts)* | **5 Events** | OpenWrt | `uclient` | Low (< 5%) | **~2.5 MB** |
| | | Linux | `curl` | Low (< 10%) | **~20 MB** |
| | **20 Events** | OpenWrt | `uclient` | Moderate (~30%) | **~8 MB** |
| | | Linux | `curl` | Moderate (~30%) | **~80 MB** |
| | **50 Events** | OpenWrt | `uclient` | **High Spike (100%)*** | **~25 MB** |
| | | Linux | `curl` | High Spike (~80%) | **~200 MB** |
| | | | | | |
| **Sequential**<br>*(Safe / Low RAM)* | **5 Events** | OpenWrt | `uclient` | Very Low (< 5%) | **~2 MB (Constant)** |
| | | Linux | `curl` | Very Low (< 5%) | **~15 MB (Constant)** |
| | **20 Events** | OpenWrt | `uclient` | Very Low (< 5%) | **~2 MB (Constant)** |
| | | Linux | `curl` | Very Low (< 5%) | **~15 MB (Constant)** |
| | **50 Events** | OpenWrt | `uclient` | Very Low (< 5%) | **~2 MB (Constant)** |
| | | Linux | `curl` | Very Low (< 5%) | **~15 MB (Constant)** |

> **ℹ️ Mode Comparison:**
> * **Parallel Mode:** Processes all failures simultaneously. Recommended for devices with **>256MB RAM**.
>     * *Pros:* Instant notification for mass outages.
>     * *Cons:* High temporary CPU/RAM spike during mass failure events.
> * **Sequential Mode:** Processes failures one by one. Recommended for devices with **<256MB RAM**.
>     * *Pros:* Zero resource spikes; RAM usage remains flat even if 100 devices fail.
>     * *Cons:* Alerts are sent one after another, so the 50th alert may arrive ~20-30 seconds later than the 1st.

> **ℹ️ Note on OpenWrt CPU:** 
>* The **100% CPU spike** during 50 simultaneous events is due to the heavy math required for 50 concurrent TLS (HTTPS) handshakes. While RAM usage remains safe/low due to shared libraries, the processor may be momentarily saturated, potentially causing brief web interface lag.

<details>
<summary><strong>📊 Click to expand: Resource Scaling by Chipset & Architecture</strong></summary>

### **1. Parallel Mode (Performance Focused)**
*Simultaneous execution. Fastest alerts, but requires Hardware Crypto Support.*

| Chipset Tier | Common CPU / Architecture | Example Devices | 5 Events (CPU) | 50 Events (CPU) | Recommended? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Legacy & Budget**<br>*(MIPS / Older ARM)* | **MediaTek MT7621**<br>*(MIPS 1004Kc Dual)* | Ubiquiti ER-X, Netgear R6220, Xiaomi 4A Gig | Low | **💀 CRITICAL**<br>*(100% Freeze)* | **❌ NO**<br>*(Use Sequential)* |
| | **Qualcomm QCA95xx**<br>*(MIPS 74Kc Single)* | Archer C7, TP-Link WDR4300, WR841N | Low | **💀 CRITICAL**<br>*(100% Freeze)* | **❌ NO**<br>*(Use Sequential)* |
| | **Qualcomm IPQ40xx**<br>*(ARM Cortex-A7 Quad)* | Google Wifi (1st Gen), Deco M5 | Moderate | **High Risk**<br>*(~90-100% Load)* | **⚠️ Caution** |
| **Mid-Range**<br>*(ARMv8 + Crypto Ext)* | **Rockchip RK3399**<br>*(Cortex-A72/A53)* | **NanoPi R4S**, NanoPi R2S, Orange Pi R1 Plus | Negligible | **Moderate Spike**<br>*(~60% CPU)* | **✅ YES**<br>*(Excellent)* |
| | **Broadcom BCM2711**<br>*(Cortex-A72 Quad)* | **Raspberry Pi 4**, CM4, Banana Pi M5 | Negligible | **Moderate Spike**<br>*(~60% CPU)* | **✅ YES**<br>*(Excellent)* |
| | **MediaTek Filogic 820**<br>*(Cortex-A53 Dual)* | **Flint 2 (MT6000)**, Xiaomi AX3000 | Negligible | **High Spike**<br>*(~80% CPU)* | **✅ YES**<br>*(Safe)* |
| | **Qualcomm IPQ807x**<br>*(Cortex-A53 Quad)* | Xiaomi AX3600, Dynalink DL-WRX36 | Negligible | **High Spike**<br>*(~80% CPU)* | **✅ YES**<br>*(Safe)* |
| **High-End**<br>*(x86 / Flagship ARM)* | **Rockchip RK3588**<br>*(Cortex-A76 Octa)* | **NanoPi R6S**, Orange Pi 5, Banana Pi BPI-M7 | Negligible | **Low Load**<br>*(~20% CPU)* | **✅ YES**<br>*(Best Perf)* |
| | **Intel N100 / J4125**<br>*(x86_64)* | Mini PC Softrouters, PfSense/OpenWrt boxes | Negligible | **Low Load**<br>*(~20% CPU)* | **✅ YES**<br>*(Best Perf)* |
| | **MediaTek Filogic 880**<br>*(Cortex-A73 Quad)* | **Banana Pi BPI-R4**, Wi-Fi 7 Routers | Negligible | **Low Load**<br>*(~25% CPU)* | **✅ YES**<br>*(Best Perf)* |

### **2. Sequential Mode (Stability Focused)**
*One-by-one execution. Zero spikes, flat memory usage. Mandatory for MIPS.*

| Chipset Tier | Common CPU / Architecture | Example Devices | 5 Events (CPU) | 50 Events (CPU) | Recommended? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Legacy & Budget** | **MediaTek MT7621**<br>*(MIPS 1004Kc)* | Ubiquiti ER-X, Netgear R6220 | Low (<10%) | **Safe (<25%)** | **✅ YES**<br>*(Mandatory)* |
| | **Qualcomm QCA95xx**<br>*(MIPS 74Kc)* | Archer C7, WDR4300 | Low (<10%) | **Safe (<25%)** | **✅ YES**<br>*(Mandatory)* |
| | **Qualcomm IPQ40xx**<br>*(ARM Cortex-A7)* | Google Wifi, Deco M5 | Negligible | **Safe (<15%)** | **✅ YES**<br>*(Recommended)* |
| **Mid-Range** | **All ARMv8 Chips**<br>*(RK3399, BCM2711)* | NanoPi R4S, RPi 4, Flint 2 | Negligible | **Negligible**<br>*(<5%)* | **⚠️ Optional**<br>*(Max Stability)* |
| **High-End** | **x86 / RK3588** | N100, NanoPi R6S | Negligible | **Negligible**<br>*(<1%)* | **❌ Unnecessary** |

</details>

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
