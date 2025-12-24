# ![](https://icongr.am/octicons/broadcast.svg?size=24&color=0366d6) netwatchdta
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

## 🔔 Discord and Telegram Configuration Guide

### Discord Configuration

To receive alerts, you need a Webhook URL. If you want mentions (pings), you also need your User ID.

#### Phase 1: Create the Discord Webhook
1. Open Discord and right-click your server's text channel (e.g., `#logs`).
2. Select **Edit Channel** -> **Integrations** -> **Webhooks**.
3. Click **New Webhook**, name it (e.g., "Router Watchdog"), and copy the **Webhook URL**.
4. *Keep this URL safe!*

#### Phase 2: Get your User ID (Optional)
1. Go to **User Settings** -> **Advanced** and enable **Developer Mode**.
2. Right-click your own username in any chat and select **Copy User ID**.
3. It will be a long number (e.g., `184000000000000000`).
4. *Keep this number safe!*

### Telegram Configuration

#### Phase 1: Create the Bot (Get the Token)
1. Open Telegram and search for `@BotFather`.
2. Start a chat and send the command: `/newbot`
3. Follow the instructions to give your bot a name (e.g., MyHomeMonitor) and a username (must end in "bot", e.g., nwdta_router_bot).
4. BotFather will send you a message containing your HTTP API Token. It looks like this: `123456789:ABCdefGhIJKlmNoPQRstUV`
5. Save this! This is your `TELE_BOT_TOKEN`.
6. *Keep this token safe!*

#### Phase 2: Get Your Chat ID
The bot needs to know who to send the messages to.
1. Search for your new bot by its username and press **Start**.
2. Send a random message to the bot (like "Hello").
3. Now, in your web browser, go to the following URL (replace `<YOUR_TOKEN>` with the token you got from BotFather):
   `https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates`
4. Look for the part of the text that says `"chat":{"id":XXXXXXXXX`.
5. The number (usually 9 or 10 digits) is your `TELE_CHAT_ID`.
6. *Keep this number safe!*

> **Note:** If you are using a Group, the Chat ID will usually start with a minus sign (e.g., -100123456789).

> [!TIP]
> The installer will ask for these during setup. If you change them later, use the secure command: `/etc/init.d/netwatchdta credentials`

---

## 🚀 Installation

**Requirement:** You need at least **3MB free storage**.
The script depends on `openssl-util` and `curl` to function securely. The installer will automatically handle dependencies for you.

**Run this command in your OpenWrt terminal:**

```sh
wget --no-check-certificate -qO /tmp/install_netwatchdta.sh "https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/OpenWRT/install_netwatchdta_wrt.sh" && sh /tmp/install_netwatchdta.sh

```

### The interactive installer will:

1. Check system requirements (Flash/RAM).
2. Ask for your **Notification Credentials** (Discord/Telegram).
3. Perform a live connectivity test.
4. Select some basic settings.
5. Set up the `procd` system service (autostart).

<details>
<summary><strong>Complete File Structure</strong></summary>

After installation, the following files will exist:
| File Path | Description |
| :--- | :--- |
| /root/netwatchdta/netwatchdta.sh	| The core logic engine (Daemon). |
| /root/netwatchdta/nwdta_settings.conf	| User configuration (Toggles & Intervals). |
| /root/netwatchdta/nwdta_ips.conf	| The list of devices to monitor. |
| /root/netwatchdta/.vault.enc	| Encrypted file containing Discord/Telegram tokens. |
| /etc/init.d/netwatchdta	| The OpenWrt service management script. |
| /tmp/netwatchdta/nwdta_uptime.log	| Human-readable event log (RAM-only). |
| /tmp/netwatchdta/nwdta_ping.log	 | Detailed ping history (Optional, RAM-only). |
| /tmp/netwatchdta/nwdta_silent_buffer	| Temporary storage for Silent Mode summaries. |
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

## 🛠️ 1 Management via Terminal

`netwatchdta` installs a comprehensive system service.

| Command | Action |
| --- | --- |
| `/etc/init.d/netwatchdta start` | Start the monitoring service. |
| `/etc/init.d/netwatchdta stop` | Stop the service. |
| `/etc/init.d/netwatchdta status` | Check if running and view PID. |
| `/etc/init.d/netwatchdta logs` | View the last 20 lines of the activity log. |
| `/etc/init.d/netwatchdta credentials` | **Interactive wizard** to update Discord/Telegram keys securely. |
| `/etc/init.d/netwatchdta discord` | Send a test notification to Discord. |
| `/etc/init.d/netwatchdta telegram` | Send a test notification to Telegram. |
| `/etc/init.d/netwatchdta purge` | **Uninstall:** Removes the service, files, and optionally dependencies. |

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

Use the 1-line uninstaller:

```sh
wget --no-check-certificate -qO /tmp/uninstall_netwatchdta_wrt.sh "https://raw.githubusercontent.com/panoc/NetWatchdta/refs/heads/main/OpenWRT/uninstall_netwatchdta_wrt.sh" && sh /tmp/uninstall_netwatchdta_wrt.sh

```

You will be prompted to either remove everything (including dependencies like `openssl-util`) or keep your configuration files for a future reinstall.

---

## ⚖️ License

Copyright (C) 2025 panoc.
This project is licensed under the **GNU General Public License v3.0**.
