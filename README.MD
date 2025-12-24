# ![](https://icongr.am/octicons/broadcast.svg?size=24&color=0366d6) NetWatchdta
![License](https://img.shields.io/badge/license-GPLv3-blue.svg) ![Platform](https://img.shields.io/badge/platform-OpenWrt-red.svg) ![Network](https://img.shields.io/badge/Network-Monitoring-orange.svg) ![Version](https://img.shields.io/badge/version-1.1-green.svg)

### Advanced Network Monitoring & Alerting for OpenWrt

**netwatchdta** is a lightweight, POSIX-compliant shell daemon designed specifically for OpenWRT routers. It bridges the gap between your network hardware and your mobile device by sending real-time status **notifications** via **Discord** and/or **Telegram**.

Designed for easy installation, reliability, minimal resource usage, and zero bloat. It features **smart resource management** that automatically adjusts its execution strategy based on your router's available RAM and CPU load, making it reliable on everything from tiny travel routers to enterprise gateways.


---

## ✨ Key Features

* **🔔 Rich Notifications**
    * Real-time alerts via **Discord** (Embeds) and **Telegram**.
    * **Silent Hours:** Pauses alerts during the night and sends a single summary in the morning.
    * **Heartbeat:** Optional "I'm alive" periodic check-ins.
* **📡 Dual-Stack Monitoring**
    * **Internet Watchdog:** Monitors external IPs (default 1.1.1.1/8.8.8.8) to detect ISP outages.
    * **Device Watchdog:** Monitors specific local IPs (servers, cameras, IoT) and alerts when they go offline.
* **🧠 Smart RAM Detection**
    * **Parallel Mode:** Automatically enables on routers with **≥ 256MB RAM** for ultra-fast, simultaneous pinging.
    * **Sequential Mode:** Automatically enables on routers with **< 256MB RAM** to prevent system instability and OOM crashes.
* **🔐 OpenSSL Security**
    * Credentials are **never** stored in plain text.
    * Uses **AES-256 Encryption (OpenSSL)** locked to your specific hardware signature.
* **🛡️ Resilience**
    * **Offline Buffering:** If the internet cuts out, alerts are saved (up to 5KB) and sent immediately when connectivity is restored.
    * **Resource Guards:** Pauses monitoring if system CPU load is too high or RAM is critically low.

---

## 🔔 Discord and Telegram Setup

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

> [!TIP]
> The installer will ask for these during setup. If you change them later, use the secure command: `/etc/init.d/netwatchdta credentials`

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

**Requirement:** You need at least **3MB free storage**.
The script depends on `openssl-util` and `curl` to function securely. The installer will automatically handle dependencies for you.

### The interactive installer will:

1. Check system requirements (Flash/RAM).
2. Ask for your **Notification Credentials** (Discord/Telegram).
3. Perform a live connectivity test.
4. Select some basic settings.
5. Set up the `procd` system service (autostart).

<details>
<summary><strong>Complete File Structure</strong></summary>

Depending on your OS, the files are installed in standard locations:

| File Type | OpenWrt Path | Linux Path | Description |
| --- | --- | --- | --- |
| **Base Folder** | `/root/netwatchdta/` | `/opt/netwatchdta/` | Main installation directory. |
| **Config** | `nwdta_settings.conf` | `nwdta_settings.conf` | User settings (Intervals, Toggles). |
| **IP List** | `nwdta_ips.conf` | `nwdta_ips.conf` | List of devices to monitor. |
| **Vault** | `.vault.enc` | `.vault.enc` | Encrypted tokens. |
| **Logs** | `/tmp/netwatchdta/` | `/tmp/netwatchdta/` | Activity logs. |
</details>

---

## ⚙️ Configuration

Configuration files are located in `/root/netwatchdta/`.

### 1. `nwdta_settings.conf`

<details>
<summary><strong>Controls the behavior of the daemon.</summary></strong>

| Setting | Description |
| --- | --- |
| `ROUTER_NAME` | Name displayed in all notifications (e.g., "Home Router"). |
| `EXEC_METHOD` | `1` for **Parallel** (Fast/High RAM), `2` for **Sequential** (Safe/Low RAM). |
| `UPTIME_LOG_MAX_SIZE` | Max log file size in bytes for uptime tracking |
| `PING_LOG_ENABLE` | Enable or disable detailed ping logging. |
| `DISCORD_ENABLE` | `YES`/`NO`. Toggle Discord notifications. |
| `TELEGRAM_ENABLE` | `YES`/`NO`. Toggle Telegram notifications. |
| `SILENT_ENABLE` | `YES`/`NO`. Enables Silent Mode (buffers alerts). |
| `SILENT_START` | Hour to **start** silence (0-23) (e.g., `23` for 11 PM). |
| `SILENT_END` | Hour to **end** silence (0-23) (e.g., `07` for 7 AM). |
| `CPU_GUARD_THRESHOLD` | Pauses monitoring if system load exceeds this value. |
| `RAM_GUARD_MIN_FREE` | Min free RAM (KB) required to process alerts. |
| `HEARTBEAT` | `YES`/`NO`. Sends a periodic "I am alive" message. |
| `HB_INTERVAL` | Seconds between heartbeats (Default: `86400` = 24h). |
| `HB_START_HOUR` | The hour (0-23) the 1st heartbeat should arrive. |
| `HB_TARGET` | Where to send: `DISCORD`, `TELEGRAM`, or `BOTH`. |
| `HB_START_HOUR` | Time of Heartbeat will start, also if 24H interval is selected time of day Heartbeat will notify. |
| `EXT_ENABLE` | `YES`/`NO`. Monitor ISP/Internet connectivity. |
| `EXT_IP` | Primary external IP to ping (Default: `1.1.1.1`). |
| `EXT_IP2` | Seondary external IP to ping (Default: `8.8.8.8`). |
| `EXT_SCAN_INTERVAL` | How often (in seconds) to check internet status. |
| `EXT_FAIL_THRESHOLD` | Failed checks before marking internet as DOWN. |
| `EXT_PING_COUNT1` | Number of packets per internet check.|
| `EXT_PING_TIMEOUT` | Seconds to wait for ping response. |
| `DEVICE_MONITOR` | `YES`/`NO`. Monitor local LAN devices. |
| `DEV_SCAN_INTERVAL` | How often (in seconds) to check local devices. |
| `DEV_FAIL_THRESHOLD` | Failed checks before marking a device as DOWN. |
| 1DEV_PING_COUNT` | Number of packets per device check. |

> ### Understanding "Silent Hours"
> 
> If you enable Silent Hours (e.g., 23:00 to 07:00):
> 1. Individual alerts are **paused**.
> 2. Events are saved to a temporary RAM buffer (`nwdta_silent_buffer`).
> 3. At 07:00, a single **Summary Message** is sent containing all overnight events.
</details>

### 2. `nwdta_ips.conf`

<details>
<summary><strong>List the local devices you want to monitor.</strong></summary>

```ini
Format: IP_ADDRESS @ NAME
192.168.1.10   @ Home Server
192.168.1.50   @ CCTV Camera
10.0.0.5       @ IoT Gateway
```
</details>

**Note:** After editing files, restart the service:

```sh
/etc/init.d/netwatchdta restart

```

---

## 🛠️ Management via Terminal

`netwatchdta` installs a comprehensive system service.

| OpenWrt | Linux | Action |
| --- | --- | --- |
| `/etc/init.d/netwatchdta start` (or `stop`) | `sudo netwatchdta start` (or `stop`) | **Start/Stop Service** |
| `/etc/init.d/netwatchdta status` | `sudo netwatchdta status` | **Check Status** |
| `/etc/init.d/netwatchdta logs` | `sudo netwatchdta logs` | **View Logs** |
| `/etc/init.d/netwatchdta credentials` | `sudo netwatchdta credentials` | **Manage Credentials** |
| `/etc/init.d/netwatchdta discord` | `sudo netwatchdta discord` | **Test Discord Alert** |
| `/etc/init.d/netwatchdta telegram` | `sudo netwatchdta telegram` | **Test Telegram Alert** |
| `/etc/init.d/netwatchdta purge` | `sudo netwatchdta purge` | **Uninstall** |

---

## 🖥️ LuCI Web Interface Integration (Optional)

If you prefer the web interface, you can add control buttons to your router's dashboard.

1. **Install:** Go to **System** -> **Software** and install `luci-app-commands`.
2. **Configure:** Go to **System** -> **Custom Commands** and add:

| Button Name | Command |
| --- | --- |
| **Check Status** | `/etc/init.d/netwatchdta status` |
| **View Activity Logs** | `/etc/init.d/netwatchdta logs` |
| **Restart Service** | `/etc/init.d/netwatchdta restart` |

<details>
<summary><strong>🔍 Click to zoom image</strong></summary>

![Custom Commands](images/custom-commands.png)
</details>

<img src="images/custom-commands.png" width="300">

---

## 📊 Resource Usage

To see how much RAM `netwatchdta` is using:

```sh
top -b -n 1 | grep netwatchdta

```

### 📊 RAM Usage Scaling (Stress Test: 50 Simultaneous Events)

The following table illustrates how `netwatchdta` manages memory during a "mass event" (e.g., a network switch failure causing 50 devices to go offline instantly).

| Scenario | Sequential Mode (< 256MB RAM) | Parallel Mode (≥ 256MB RAM) |
| --- | --- | --- |
| **50 Devices Idle (Pinging)** | ~2 MB (Total) | ~4 MB (Total) |
| **50 Devices Down (Buffering)** | ~2 MB (Total) | ~5 MB (Total) |
| **50 Devices Down (Sending Alerts)** | **~3.5 MB** (Queue: 1 at a time) | **~75-100 MB Spike** (Concurrency: 50 at once) |
| **Flushing 50 Buffered Alerts** | **~3.5 MB** (Queue: 1 at a time) | **~3.5 MB** (Queue: 1 at a time) |

> **Note:** Parallel Mode trades spare RAM for speed. The installer automatically restricts Parallel Mode to routers with sufficient memory to absorb these spikes safely.
> If you don't have many devices to monitor you can safely use Parallel Mode on less powerful routers by adjusting **EXEC_METHOD** in **nwdta_settings.conf**.

## 🗑️ Uninstallation

To completely remove `netwatchdta`, use the built-in purge command:

```sh
/etc/init.d/netwatchdta purge

```

OR

Use the one-line uninstaller:

```sh
wget --no-check-certificate -qO /tmp/uninstall_netwatchdta_wrt.sh "https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/OpenWRT/uninstall_netwatchdta_wrt.sh" && sh /tmp/uninstall_netwatchdta_wrt.sh

```

You will be prompted to either remove everything (including dependencies like `openssl-util`) or keep your configuration files for a future reinstall.

---

## ⚖️ License

Copyright (C) 2025 panoc.
This project is licensed under the **GNU General Public License v3.0**.
