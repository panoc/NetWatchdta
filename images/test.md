# 🚀 netwatchdta (v1.3.6)
**Universal Network Monitoring for OpenWrt & Linux**

**netwatchdta** is a lightweight, high-performance network monitor designed to track the uptime of local devices, remote servers, and internet connectivity.

It features a unique **"Hybrid Execution Engine"** that combines **Parallel Scanning** (for instant outage detection) with **Queued Notifications** (to prevent RAM saturation on low-end routers).

---

## 🌟 Key Features
* **Universal Compatibility:** Runs on OpenWrt (Ash) and Standard Linux (Bash/Systemd).
* **Hybrid Engine (v1.3.6+):**
    * **Scanning:** Always runs in **Parallel** for millisecond-precision detection.
    * **Notifications:** Uses a **Smart Lock Queue** on low-RAM devices to send alerts sequentially, capping RAM usage.
* **Dual-Stack Alerts:** Native support for **Discord** (Webhooks) and **Telegram** (Bot API).
* **Resource Efficient:** Uses as little as **400KB RAM** at idle on OpenWrt.
* **Hardware Locked Encryption:** Credentials are encrypted via OpenSSL AES-256 and locked to your specific CPU/MAC address.
* **Resilience:** Buffers alerts to disk during internet outages and flushes them when connectivity is restored.

---

## 📊 Performance & Resource Analysis
*Detailed analysis of RAM and Storage usage for v1.3.6.*

### 1. 💾 Disk / Flash Storage Requirements
*Space required for installation (Script + Dependencies).*

| Component | OpenWrt (uclient-fetch) | OpenWrt (curl) | Linux (Standard) | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Core Script** | ~50 KB | ~50 KB | ~50 KB | Includes config & service files. |
| **SSL Libs** | ~1.3 MB | ~1.3 MB | ~2.0 MB | `openssl-util` & `ca-bundle`. |
| **Fetch Tool** | ~20 KB | ~1.5 MB | ~2.0 MB | `uclient` is native/tiny. `curl` is heavy. |
| **TOTAL** | **~1.4 MB** | **~2.9 MB** | **~4.1 MB** | **Recommendation:** Use `uclient` on OpenWrt. |

### 2. 💤 RAM Usage at Idle
*Baseline memory usage when the service is sleeping between checks.*

| Platform | Shell | RAM Usage | Why the difference? |
| :--- | :--- | :--- | :--- |
| **OpenWrt** | `ash` | **~0.4 MB** | Optimized for embedded devices (BusyBox). |
| **Linux** | `bash` | **~3.5 MB** | Feature-rich shell with larger memory footprint. |

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

---

## 4. 🔔 Notification Phase (The Hybrid Engine)
*Resource usage depends on the **Execution Mode** (Parallel vs. Queue) and the number of destinations.*

### **A. Single Destination (Discord OR Telegram)**
*Scenario: Sending alerts to one platform.*

#### **Method 1: Parallel Mode (High Performance)**
*Auto-selected for RAM > 256MB. All alerts send instantly.*

| Scale | OpenWrt (uclient) | OpenWrt (curl) | Linux (curl) | Execution Time |
| :--- | :--- | :--- | :--- | :--- |
| **1 Event** | ~0.6 MB | ~2.5 MB | ~5.0 MB | ~1s |
| **5 Events** | ~3.0 MB | ~12.5 MB | ~25.0 MB | ~1s |
| **50 Events** | **~30.0 MB** | **~125.0 MB** ⚠️ | **~250.0 MB** | ~2s |

#### **Method 2: Queue Mode (Low RAM / Safe)**
*Auto-selected for RAM < 256MB. Alerts wait in line.*
*Formula: `(1 Active Transfer) + (N-1 Waiting Shells)`*

| Scale | OpenWrt (uclient) | OpenWrt (curl) | Linux (curl) | Execution Time |
| :--- | :--- | :--- | :--- | :--- |
| **1 Event** | ~0.6 MB | ~2.5 MB | ~5.0 MB | ~1s |
| **5 Events** | ~2.0 MB | ~4.0 MB | ~17.0 MB | ~5s |
| **50 Events** | **~15.0 MB** 🟢 | **~17.0 MB** 🟢 | **~152.0 MB** | **~50s** |

### **B. Dual Destination (Discord AND Telegram)**
*Scenario: Sending alerts to BOTH platforms for every event.*
*Logic: The script sends sequentially (Discord → Wait → Telegram), so RAM usage is based on the single peak of the active tool, but Execution Time doubles.*

#### **Method 1: Parallel Mode (High Performance)**

| Scale | OpenWrt (uclient) RAM | OpenWrt (curl) RAM | Linux (curl) RAM | Execution Time |
| :--- | :--- | :--- | :--- | :--- |
| **1 Event** | ~0.6 MB | ~2.5 MB | ~5.0 MB | ~2s |
| **5 Events** | ~3.0 MB | ~12.5 MB | ~25.0 MB | ~2s |
| **50 Events** | **~30.0 MB** | **~125.0 MB** ⚠️ | **~250.0 MB** | ~4s |

#### **Method 2: Queue Mode (Low RAM / Safe)**
*Critical for preventing crashes on weak devices.*

| Scale | OpenWrt (uclient) RAM | OpenWrt (curl) RAM | Linux (curl) RAM | Execution Time |
| :--- | :--- | :--- | :--- | :--- |
| **1 Event** | ~0.6 MB | ~2.5 MB | ~5.0 MB | ~2s |
| **5 Events** | ~2.0 MB | ~4.0 MB | ~17.0 MB | ~10s |
| **50 Events** | **~15.0 MB** 🟢 | **~17.0 MB** 🟢 | **~152.0 MB** | **~100s** 🕒 |

> **⚠️ The Trade-off:** In Queue Mode with 50 mass failures sending to both Discord & Telegram, the last notification will arrive **~100 seconds (1.5 mins)** after the event. This delay is intentional to save your router from crashing due to OOM (Out of Memory).

---

## 📈 Hardware Recommendations (v1.3.6)

<details>
<summary><strong>Click to expand: Safe Device Limits Table</strong></summary>

### **1. Method 1: Parallel Mode**
*Auto-selected for devices with **>256MB RAM**. Instant Alerts.*
*Limiting Factor: RAM Spike (Risk of Crash).*

| Chipset Tier | Example Devices | 50 Events (RAM Spike) | Est. Safe Max (Single Notif) | Est. Safe Max (Dual Notif) | Recommended? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Legacy (MIPS)** | Ubiquiti ER-X, Xiaomi 4A | **💀 CRITICAL (~125 MB)** | **~10 - 15 Devices** | **~5 - 10 Devices** | **❌ NO** |
| **Mid-Range (ARM)** | Pi Zero 2, Flint 2, Pi 3 | **High Spike (~150 MB)** | **~30 - 40 Devices** | **~20 - 30 Devices** | **⚠️ CAUTION** |
| **High-End (x86)** | N100, Pi 4/5, NanoPi R6S | **Low Load** | **200+ Devices** | **150+ Devices** | **✅ YES** |

### **2. Method 2: Queue Mode**
*Auto-selected for devices with **<256MB RAM**. Guaranteed Stability.*
*Limiting Factor: Time Delay (Alerts arrive late).*

| Chipset Tier | Example Devices | 50 Events (RAM Spike) | Est. Safe Max (Single Notif) | Est. Safe Max (Dual Notif) | Recommended? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Legacy (MIPS)** | Ubiquiti ER-X, R6220 | **~17 MB (Very Safe)** | **~50 - 70 Devices**<br>*(~50s delay)* | **~30 - 40 Devices**<br>*(~60s delay)* | **✅ YES** |
| **Mid-Range (ARM)** | Pi Zero 2, Pi 3 | **~20 MB (Negligible)** | **100+ Devices**<br>*(~100s delay)* | **~50 - 60 Devices**<br>*(~100s delay)* | **✅ YES** |
| **High-End (x86)** | N100, Pi 5 | **Negligible** | **Unlimited** | **Unlimited** | **❌ Unnecessary** |

> **ℹ️ Analytic Conclusion:**
> * **Why is "Dual Notif" lower?** In Queue Mode, sending to two platforms doubles the execution time per event. Monitoring 100 devices with Dual Notifications would result in a **~3.5 minute delay** for the last alert to arrive.
> * **Recommendation:** If monitoring >50 devices on a low-end router, stick to **Single Notification** (e.g., Discord only) to keep alerts timely.

</details>

<br>

<details>
<summary><strong>Click to expand: Quick Decision Matrix</strong></summary>

### 🎯 Quick Decision Matrix
*Choose the right hardware based on your intended usage.*

| If your goal is... | Recommended Hardware Tier | Execution Mode | Best Device Options |
| :--- | :--- | :--- | :--- |
| **Just Monitoring**<br>*(Dedicated "Watchdog")* | **Low-End / Legacy**<br>*(Zero Cost)* | **Method 2**<br>*(Auto-Selected)* | Old Routers (128MB RAM), Travel Routers, Pi Zero |
| **Monitoring + Network Services**<br>*(AdGuard, VPN Client)* | **Mid-Range SBC**<br>*(Balanced)* | **Method 1**<br>*(Standard)* | Raspberry Pi 3/4, NanoPi R4S, Flint 2 |
| **Heavy Multitasking**<br>*(Gigabit Routing, NAS)* | **High-End x86 / ARM**<br>*(Performance)* | **Method 1**<br>*(Standard)* | NanoPi R6S, Intel N100, Raspberry Pi 5 |

</details>

---

## 📂 File Structure
**netwatchdta** creates the following files during installation.

### 1. Installation Directory
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

### 2. Temporary & Log Files
**Location:** `/tmp/netwatchdta/`
*(Note: These are created in RAM to prevent flash storage wear on routers)*

| File Name | Description |
| :--- | :--- |
| `nwdta_uptime.log` | The main event log (Service started, alerts sent, etc). |
| `nwdta_ping.log` | Detailed ping log (Only if `PING_LOG_ENABLE=YES`). |
| `nwdta_net_status` | Stores current internet status (`UP` or `DOWN`). |
| `*_d`, `*_c`, `*_t` | Various tracking files for timeout/failure counts. |

---

## 🛠️ Commands

### **OpenWrt (Procd)**
```bash
/etc/init.d/netwatchdta start       # Start Service
/etc/init.d/netwatchdta stop        # Stop Service
/etc/init.d/netwatchdta check       # Check Status & PID
/etc/init.d/netwatchdta logs        # View Live Logs
/etc/init.d/netwatchdta edit        # Interactive Config Editor
/etc/init.d/netwatchdta credentials # Update Discord/Telegram Keys safely
/etc/init.d/netwatchdta purge       # Uninstall
