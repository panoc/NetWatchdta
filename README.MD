# 🌐 NetWatchdta (Universal)

> **Network Monitor for OpenWrt & Linux**

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

## 🖥️ Supported Operating Systems

<details>
<summary><strong>🐧NetWatchdta v4.x automatically adapts to the underlying OS.</strong></summary>

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
</details>

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

*Requires `curl` only if you have problem with default uclient-fetch implementation and/or you want to manually switch to `curl`.*

```bash
wget -qO- https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/install_netwatchdta.sh | sh

```

---

## 🛠️ Management & Commands

Once installed, use the CLI commands to manage the service.

### 🎮 Service Commands

<details>
<summary><strong>⌨️ List of all available commands</strong></summary>

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
</details>

### ⚙️ Configuration Settings (`settings.conf`)

Location: `/opt/netwatchdta/settings.conf` (Linux) or `/root/netwatchdta/settings.conf` (OpenWrt).

<details>
<summary><strong>📝 List of all available settings</strong></summary>

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


### 🖥️ LuCI Web Interface Integration
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

### 📊 RAM & CPU Usage Scaling

<details>
<summary><strong>📊 Click to expand: Combined Resource Scaling & Safe Limits</strong></summary>

### **1. Parallel Mode (Performance Focused)**
*Simultaneous execution. Fastest alerts. Use this ONLY if your device is within the "Safe Max" limit.*

| Chipset Tier | Common CPU / Architecture | Example Devices | 5 Events (CPU / RAM) | 50 Events (CPU / RAM) | **Est. Safe Max**<br>*(w/ Headroom)* | Recommended? |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Legacy / Low Power** | **MediaTek MT7621**<br>*(MIPS 1004Kc Dual)* | Ubiquiti ER-X, Xiaomi 4A Gig | Moderate / **~3 MB** | **💀 CRITICAL** / **~12 MB** | **~3 - 5 Events** | **❌ NO**<br>*(Use Sequential)* |
| | **Broadcom BCM2835**<br>*(ARMv6 Single-Core)* | **Raspberry Pi Zero / Zero W** | Moderate / **~8 MB** | **💀 CRITICAL** / **~30 MB** | **~3 - 5 Events** | **❌ NO**<br>*(Use Sequential)* |
| **Mid-Range** | **Broadcom BCM2710**<br>*(ARM Cortex-A53)* | **Raspberry Pi Zero 2 W**, Pi 3B+ | Negligible / **~8 MB** | **High Spike** / **~25 MB**<br>*(~75% CPU)* | **~30 - 40 Events** | **✅ YES**<br>*(For Home Labs)* |
| | **MediaTek Filogic 820**<br>*(ARM Cortex-A53)* | **Flint 2 (MT6000)**, AX3000 | Negligible / **~4 MB** | **High Spike** / **~18 MB**<br>*(~80% CPU)* | **~30 - 40 Events** | **✅ YES**<br>*(Safe)* |
| **Performance SBC** | **Rockchip RK3399**<br>*(ARMv8 Hexa-Core)* | **NanoPi R4S**, R2S, Orange Pi | Negligible / **~8 MB** | **Moderate** / **~25 MB**<br>*(~60% CPU)* | **~50 - 60 Events** | **✅ YES**<br>*(Excellent)* |
| | **Broadcom BCM2711**<br>*(ARM Cortex-A72)* | **Raspberry Pi 4**, Pi 400 | Negligible / **~8 MB** | **Moderate** / **~25 MB**<br>*(~50% CPU)* | **~60 - 70 Events** | **✅ YES**<br>*(Excellent)* |
| **High-End** | **Broadcom BCM2712**<br>*(ARM Cortex-A76)* | **Raspberry Pi 5** | Negligible / **~10 MB** | **Low Load** / **~40 MB**<br>*(~20% CPU)* | **150+ Events** | **✅ YES**<br>*(Best Perf)* |
| | **Rockchip RK3588**<br>*(ARMv8 Octa-Core)* | **NanoPi R6S**, Orange Pi 5 | Negligible / **~10 MB** | **Low Load** / **~40 MB**<br>*(~20% CPU)* | **150+ Events** | **✅ YES**<br>*(Best Perf)* |
| | **Intel N100 / x86**<br>*(x86_64)* | Mini PC Routers, PfSense | Negligible / **~20 MB** | **Low Load** / **~150 MB***<br>*(~15% CPU)* | **200+ Events** | **✅ YES**<br>*(Best Perf)* |

> **⚠️ What happens if I exceed the "Safe Max"?**
> The device will likely hit **100% CPU usage** for several seconds.
> * **On Routers:** This may cause temporary Wi-Fi lag or packet loss.
> * **On Raspberry Pis:** The system may become sluggish or unresponsive via SSH.
> * **Note on x86 RAM:** Linux `bash` and `curl` use significantly more private memory per process than OpenWrt's optimized `ash` and `uclient-fetch`.

### **2. Sequential Mode (Stability Focused)**
*One-by-one execution. Zero resource spikes. Unlimited capacity.*

| Chipset Tier | Common CPU / Architecture | Example Devices | Est. Safe Max Events | Recommended? |
| :--- | :--- | :--- | :--- | :--- |
| **Legacy / Low Power** | **MediaTek MT7621** | Ubiquiti ER-X, R6220 | **Unlimited*** | **✅ YES**<br>*(Mandatory)* |
| | **Broadcom BCM2835** | **Raspberry Pi Zero / Zero W** | **Unlimited*** | **✅ YES**<br>*(Mandatory)* |
| **Mid-Range** | **All ARMv8 Chips** | Pi Zero 2, Pi 3/4, Flint 2 | **Unlimited*** | **⚠️ Optional**<br>*(Max Stability)* |
| **High-End** | **x86 / RK3588** | N100, Pi 5, NanoPi R6S | **Unlimited*** | **❌ Unnecessary** |

> **\*ℹ️ Mode Comparison:**
> * **Parallel Mode:** Processes all failures simultaneously. Recommended for devices with **>256MB RAM**.
>     * *Pros:* Instant notification for mass outages.
>     * *Cons:* High temporary CPU/RAM spike during mass failure events.
> * **Sequential Mode:** Processes failures one by one. Recommended for devices with **<256MB RAM**.
>     * *Pros:* Zero resource spikes; RAM usage remains flat even if 100 devices fail.
>     * *Cons:* Alerts are sent one after another, so the 50th alert may arrive ~20-30 seconds later than the 1st.

> **ℹ️ Note on OpenWrt CPU:** 
>* The **100% CPU spike** during 50 simultaneous events is due to the heavy math required for 50 concurrent TLS (HTTPS) handshakes. While RAM usage remains safe/low due to shared libraries, the processor may be momentarily saturated, potentially causing brief web interface lag.
</details>

<details>
<summary><strong>💡 Click to expand: Hardware Recommendations & Selection Guide</strong></summary>

### 🎯 Quick Decision Matrix
*Choose the right hardware based on your intended usage.*

| If your goal is... | Recommended Hardware Tier | Execution Mode | Best Device Options |
| :--- | :--- | :--- | :--- |
| **Just Monitoring**<br>*(Dedicated "Watchdog")* | **Low-End / Legacy**<br>*(Zero Cost)* | **Sequential**<br>*(Mandatory)* | Raspberry Pi Zero W, Old Router (Archer C7), Travel Router |
| **Monitoring + Network Services**<br>*(AdGuard, VPN Client, DNS)* | **Mid-Range SBC**<br>*(Balanced)* | **Parallel**<br>*(Safe up to ~50 devs)* | Raspberry Pi 3/4, NanoPi R4S, Flint 2 |
| **Heavy Multitasking**<br>*(Gigabit Routing, NAS, Docker)* | **High-End x86 / ARM**<br>*(Performance)* | **Parallel**<br>*(Unrestricted)* | NanoPi R6S, Intel N100, Raspberry Pi 5 |

---

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
