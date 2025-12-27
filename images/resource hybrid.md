# 📊 Performance & Resource Analysis (v1.3.6)

This document provides a detailed technical breakdown of **netwatchdta v1.3.6** resource usage.
Calculations are provided for **OpenWrt** (using both `uclient-fetch` and `curl`) and **Standard Linux**.

---

## 1. 💾 Disk / Flash Storage Requirements
*Space required for installation (Script + Dependencies).*

| Component | OpenWrt (uclient-fetch) | OpenWrt (curl) | Linux (Standard) | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Core Script** | ~50 KB | ~50 KB | ~50 KB | Includes config & service files. |
| **SSL Libs** | ~1.3 MB | ~1.3 MB | ~2.0 MB | `openssl-util` & `ca-bundle`. |
| **Fetch Tool** | ~20 KB | ~1.5 MB | ~2.0 MB | `uclient` is native/tiny. `curl` is heavy. |
| **TOTAL** | **~1.4 MB** | **~2.9 MB** | **~4.1 MB** | **Recommendation:** Use `uclient` on OpenWrt. |

---

## 2. 💤 RAM Usage at Idle
*Baseline memory usage when the service is sleeping between checks.*

| Platform | Shell | RAM Usage | Why the difference? |
| :--- | :--- | :--- | :--- |
| **OpenWrt** | `ash` | **~0.4 MB** | Optimized for embedded devices (BusyBox). |
| **Linux** | `bash` | **~3.5 MB** | Feature-rich shell with larger memory footprint. |

---

## 3. 📡 Scanning Phase (Forced Parallel)
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

---

### **B. Dual Destination (Discord AND Telegram)**
*Scenario: Sending alerts to BOTH platforms for every event.*
*Logic: The script sends sequentially (Discord → Wait → Telegram), so RAM usage is based on the single peak of the active tool, but Execution Time doubles.*

#### **Method 1: Parallel Mode (High Performance)**
*Auto-selected for RAM > 256MB. All alerts start immediately.*

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

### Safe Device Limits Table

### **1. Method 1: Parallel Mode**
*Best for: Devices with >256MB RAM. Instant Alerts.*

| Chipset Tier | Common CPU | Example Devices | 50 Events (RAM Spike) | Recommended? |
| :--- | :--- | :--- | :--- | :--- |
| **Legacy / Low Power** | **MIPS (MT7621)** | Ubiquiti ER-X, Xiaomi 4A | **💀 CRITICAL (~125 MB)** | **❌ NO** |
| **Mid-Range** | **ARM Cortex-A53** | Pi Zero 2, Flint 2, Pi 3 | **High Spike (~150 MB)** | **⚠️ CAUTION** |
| **High-End** | **x86 / ARMv8** | N100, Pi 4/5, NanoPi R6S | **Low Load** | **✅ YES** |

### **2. Method 2: Queue Mode**
*Best for: Devices with <256MB RAM. Guaranteed Stability.*

| Chipset Tier | Common CPU | Example Devices | 50 Events (RAM Spike) | Recommended? |
| :--- | :--- | :--- | :--- | :--- |
| **Legacy / Low Power** | **MIPS (MT7621)** | Ubiquiti ER-X, R6220 | **~17 MB (Very Safe)** | **✅ YES** |
| **Mid-Range** | **ARM Cortex-A53** | Pi Zero 2, Pi 3 | **~20 MB (Negligible)** | **✅ YES** |
| **High-End** | **x86 / ARMv8** | N100, Pi 5 | **Negligible** | **❌ Unnecessary** |

> **ℹ️ Analytic Conclusion:**
> * **OpenWrt Users:** Even on ancient hardware, you can monitor 50+ devices safely using **Queue Mode**.
> * **Linux Users:** Due to Bash memory overhead, monitoring 50+ devices requires at least **512MB RAM**, regardless of mode.

## 📈 Hardware Recommendations (v1.3.6)

Safe Device Limits Table<

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
| **Legacy (MIPS)** | Ubiquiti ER-X, R6220, Xiaomi 4A | **~17 MB (Very Safe)** | **~50 - 70 Devices**<br>*(~50s delay)* | **~30 - 40 Devices**<br>*(~60s delay)* | **✅ YES** |
| **Mid-Range (ARM)** | Pi Zero 2, Flint 2, Pi 3  | **~20 MB (Negligible)** | **100+ Devices**<br>*(~100s delay)* | **~50 - 60 Devices**<br>*(~100s delay)* | **✅ YES** |
| **High-End x86 / ARM** | N100, Pi 4/5, NanoPi R6 | **Negligible** | **Unlimited** | **Unlimited** | **❌ Unnecessary** |

> **ℹ️ Analytic Conclusion:**
> * **Why is "Dual Notif" lower?** In Queue Mode, sending to two platforms doubles the execution time per event. Monitoring 100 devices with Dual Notifications would result in a **~3.5 minute delay** for the last alert to arrive.
> * **Recommendation:** If monitoring >50 devices on a low-end router, stick to **Single Notification** (e.g., Discord only) to keep alerts timely.



