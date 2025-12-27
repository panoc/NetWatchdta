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
* **Resource Efficient:** Uses as little as **300KB RAM** at idle on OpenWrt.
* **Hardware Locked Encryption:** Credentials are encrypted via OpenSSL AES-256 and locked to your specific CPU/MAC address.
* **Resilience:** Buffers alerts to disk during internet outages and flushes them when connectivity is restored.

---

## 📊 Performance & Resource Analysis
*Data based on v1.3.6 using `uclient-fetch` (OpenWrt) and `curl` (Linux).*

### 1. 💾 Storage Requirements
| Component | Size | Notes |
| :--- | :--- | :--- |
| **Core Script & Configs** | **~50 KB** | Ultra-lightweight footprint. |
| **Dependencies (OpenWrt)** | **~1.4 MB** | `openssl-util`, `ca-bundle`, `uclient-fetch` (often pre-installed). |
| **Dependencies (Linux)** | **~3.0 MB** | Standard `curl`, `openssl`, `ca-certificates`. |

### 2. 🧠 RAM Usage (Real-World Scenarios)

#### **A. Idle State**
*Background monitoring waiting for next cycle.*
* **OpenWrt:** ~0.4 MB
* **Linux:** ~3.5 MB

#### **B. Scanning Phase (Parallel Mode)**
*Usage scales with the number of monitored devices. Duration: ~1 second.*
*Formula: `(Shell Overhead + Ping Overhead) x Device Count`*

| Target Count | OpenWrt RAM Spike | Linux RAM Spike |
| :--- | :--- | :--- |
| **1 Device** | ~0.4 MB | ~3.0 MB |
| **10 Devices** | ~4.0 MB | ~30.0 MB |
| **50 Devices** | ~20.0 MB | ~150.0 MB |

#### **C. Notification Phase (Smart Queue)**
*Scenario: 50 devices go offline instantly. Alerts sent to Discord AND Telegram.*

| System Mode | Behavior | Total Peak RAM (OpenWrt) |
| :--- | :--- | :--- |
| **High RAM (>256MB)** | **Instant Parallel:** Sends 50 alerts at once. | **~125 MB** (Risk of Crash) |
| **Low RAM (<256MB)** | **Smart Queue:** Alerts wait in line. Sends 1 by 1. | **~23 MB** 🟢 **(Safe Limit)** |

> **Analytic Verdict:** By using the Smart Queue, **netwatchdta** ensures that even a 128MB router never exceeds ~23MB RAM usage during a catastrophic network failure, while still detecting the outage instantly.

---

## 📈 Hardware Selection Guide

<details>
<summary><strong>Click to expand: Safe Device Limits Table</strong></summary>

### **Method 2: Queued Notification Mode (Auto-Selected for <256MB RAM)**
*Parallel scanning (fast detection) + Serialized notifications (RAM safety).*

| Chipset Tier | Common CPU / Architecture | Example Devices | Behavior during 50 Events | Est. Safe Max Events | Recommended? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Legacy / Low Power** | **MediaTek MT7621**<br>*(MIPS)* | Ubiquiti ER-X, R6220 | **CPU:** 100% Spike (Scan)<br>**RAM:** ~20 MB (Safe) | **~50 - 70 Events** | **✅ YES**<br>*(Best Balance)* |
| **Mid-Range** | **All ARMv8 Chips** | Pi Zero 2, Pi 3/4 | **CPU:** Moderate Spike<br>**RAM:** ~40 MB (Very Safe) | **100+ Events** | **✅ YES** |
| **High-End** | **x86 / RK3588** | N100, Pi 5, NanoPi R6S | **CPU:** Negligible<br>**RAM:** Negligible | **Unlimited** | **✅ YES** |

</details>

---

## 📂 File Structure
| Path | File Name | Description |
| :--- | :--- | :--- |
| `/etc/netwatchdta/` | `netwatchdta.sh` | Core logic engine. |
| | `settings.conf` | User configuration (Timeouts, Webhooks, Toggles). |
| | `device_ips.conf` | List of local IPs to monitor. |
| | `.vault.enc` | Encrypted credential store. |
| `/tmp/netwatchdta/` | `nwdta_uptime.log` | Event log (Rotates at 50KB). |
| | `nwdta_net_status` | Current Internet State (UP/DOWN). |

---

## 🛠️ Commands
**OpenWrt:**
```bash
/etc/init.d/netwatchdta start       # Start Service
/etc/init.d/netwatchdta stop        # Stop Service
/etc/init.d/netwatchdta check       # Check Status
/etc/init.d/netwatchdta logs        # View Live Logs
/etc/init.d/netwatchdta edit        # Edit Configuration
/etc/init.d/netwatchdta credentials # Update Discord/Telegram Keys
/etc/init.d/netwatchdta purge       # Uninstall
