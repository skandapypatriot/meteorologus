# How To Build Meteorologus

Single-page, end-to-end build guide: what to buy, how to wire it, how to flash it, how to pair it, and the battery math behind the one-month runtime claim.

> **Fixed hardware recommendations:** MCU = **ESP32-C3**, display = **0.96" 128×64 I²C OLED** only. **Sensors are your choice** — the firmware auto-detects whichever supported sensor you fit (see the sensor table below), so the node works with a bare DHT11 or a full BME680 without touching the firmware.
>
> This guide documents the **TP4056 + 18650** build. All current figures below are **datasheet-derived estimates, not lab measurements** — see [Battery Life: The Numbers](#battery-life-the-numbers) for the math and how to validate on your own hardware.

---

## Table of Contents

1. [Parts List (BOM)](#1-parts-list-bom)
2. [Wiring & Pinout](#2-wiring--pinout)
3. [Peripheral Power Switch (BC547)](#3-peripheral-power-switch-bc547)
4. [Power Section (18650 + TP4056 + ME211)](#4-power-section)
5. [Firmware: Install, Configure, Flash](#5-firmware)
6. [First Boot Checklist](#6-first-boot-checklist)
7. [Pairing & Cloud Setup](#7-pairing--cloud-setup)
8. [Battery Life: The Numbers](#8-battery-life-the-numbers)
9. [Final Assembly](#9-final-assembly)
10. [Known Discrepancies in the Repo](#10-known-discrepancies)
11. [Component References](#11-component-references)

---

## 1. Parts List (BOM)

### Required

| Part | Role | Notes |
| :--- | :--- | :--- |
| **ESP32-C3** (module board) | MCU — Wi-Fi, BLE disabled at runtime | Build target: `esp32-c3-devkitm-1` |
| **0.96" 128×64 I²C OLED** | Display | SSD1306/SSD1315 or SH1106 controller — firmware auto-detects both, address 0x3C/0x3D. **This is the only display the UI supports.** |
| **BC547** (NPN, TO-92) | Peripheral power switch | Cuts OLED + sensors completely during sleep |
| 1 kΩ resistor | BC547 base resistor | GPIO 10 → base |
| 10 kΩ resistor | BC547 base pull-down | Keeps the switch OFF during boot/reset |
| I²C pull-ups, 2 × 10 kΩ | SDA/SCL → 3V3 | Many OLED breakouts include 4.7 kΩ already; 10 kΩ keeps back-feed leakage negligible when the switched rail is off |
| 18650 Li-ion cell + holder | Power | A **3000 mAh** cell is used in the battery budget below (typical branded cell; 2600–3400 mAh all work) |
| **TP4056** module (Type-C, **with protection** — DW01 + 8205) | Charge & battery protection | Must include the protection ICs; a bare TP4056 has no over-discharge cutoff |
| **ME211** 3.3 V LDO | Step 4.2 V → 3.3 V | Low quiescent current — this is the regulator assumed throughout this guide |
| Momentary push button | Wake from deep sleep / force awake | GPIO 1, active-low to GND |
| Perfboard, headers, wire | Assembly | Breadboard first (Stage 1) |

### Sensors (your choice — auto-detected at boot)

| Fits | Gives you | Firmware treats it as |
| :--- | :--- | :--- |
| **DHT11** (GPIO 7, needs 4.7 kΩ data pull-up) | Temp + humidity | Baseline, always probed |
| AHT20 (I²C 0x38) | Temp + humidity | Overrides DHT11 |
| BMP180 (I²C 0x77) | Temp + pressure | Pressure source |
| BMP280 / BME280 (I²C 0x76 or 0x77) | Temp + humidity + pressure | Overrides all above humidity |
| BME680 (I²C 0x76 or 0x77, chip ID 0x61) | All of the above **+ gas resistance / air-quality screen** | Highest priority — top of the chain |

Detection priority: **BME680 > BME280 > AHT20 > DHT11** (humidity) and **BME680 > BME280 > BMP280 > BMP180** (pressure). Sensors attach via I²C except the DHT11's one-wire data pin on GPIO 7; no further configuration is needed — the boot log prints what it found.

The DS3231 RTC (I²C 0x68) is **optional** and compiled out by default (`-DRTC_SUPPORT=0` in `platformio.ini`); without it the node times itself from NTP on every wake.

---

## 2. Wiring & Pinout

| Signal | GPIO | Connected to |
| :--- | :--- | :--- |
| DHT11 data *(only if fitted)* | **7** | DHT11 out, 4.7 kΩ pull-up to 3V3 |
| I²C SDA | **4** | OLED, all I²C sensors |
| I²C SCL | **5** | OLED, all I²C sensors |
| Wake button | **1** | Button to GND (GPIO-low wakeup) |
| BC547 base | **10** | Via 1 kΩ resistor (next section) |

Notes:

- GPIO 8/9 are deliberately avoided — they are strapping pins and GPIO 9 doubles as the BOOT button.
- GPIO 1 is inside the ESP32-C3's GPIO-wakeup-capable range (GPIO 0–5), which `esp_deep_sleep_enable_gpio_wakeup()` requires.
- The ESP32-C3's onboard BOOT button can also wake the node in a pinch, but only if wired in the same GPIO-1 circuit on a custom build; on a stock DevKitC the boot button drives GPIO 9, which is **not** wake-capable on the C3 — hence the external button on GPIO 1.

```
                          3V3 rail (from ME211)
                             │      │      │
                        ┌────┴───┐ ┌┴──────┴─── ...
                        │ I²C    │ │ switched peripheral rail:
                        │ pull-  │ │   OLED (VCC)
                        │ ups    │ │   sensors (VCC)
                        └────┬───┘ └───────────┬───
                             │                 │
  ESP32-C3                   │            (their GND pins join)
  GPIO4 ── SDA ──────────────┤                 │
  GPIO5 ── SCL ──────────────┤            BC547 COLLECTOR
  GPIO7 ── DHT11 data ───────┤                 │
  GPIO10 ──[1k]── BC547 BASE │            BC547 EMITTER ── GND
  GPIO1 ── button ── GND     │
  GND  ──────────────────────┴──────── battery GND
```

I²C addresses probed at boot: `0x68` (RTC, optional), `0x76`/`0x77` (pressure), `0x38` (AHT20), `0x3C`/`0x3D` (OLED).

---

## 3. Peripheral Power Switch (BC547)

Deep sleep alone (~5 µA for the C3) is wasted if the OLED and sensors keep drawing milliamps. The BC547 is a **low-side switch**: GPIO 10 drives it ON while awake and OFF right before sleeping, so the peripherals are disconnected from GND entirely — effectively 0 mA, not just "sleeping".

```
   GPIO 10 ──[ 1 kΩ ]──┬──► Base       BC547 (flat side facing you:
                       │                       C  B  E)
                    [10 kΩ]
                       │
                      GND

   ┌──────────────────────────────┐
   │  OLED · all sensors          │   VCC ──► 3V3 (always on — DO NOT
   │  GND ──────► BC547 Collector │             switch VCC, switch GND)
   └──────────────────────────────┘
                                  BC547 Emitter ──► GND
```

**Wiring steps**

1. Emitter → GND (battery negative).
2. Collector → GND pins of the OLED and **all switched sensors**; their VCC pins stay on 3V3.
3. Base → GPIO 10 through the 1 kΩ resistor.
4. 10 kΩ pull-down from base to GND — ESP32-C3 GPIOs float during boot/reset; this holds the switch OFF so peripherals never get phantom power.
5. Use 10 kΩ I²C pull-ups where possible: when the switched group is off, pull-ups to 3V3 can back-feed a few µA through unpowered chips' protection diodes; higher resistance keeps that negligible.

**Logic (matches firmware exactly)**

| GPIO 10 | BC547 | Peripherals |
| :--- | :--- | :--- |
| HIGH | ON | Powered — normal operation |
| LOW (set just before deep sleep) | OFF | Fully disconnected ≈ 0 mA |

Load check: OLED (~15 mA) + sensors (< 5 mA) ≪ BC547's ~100 mA limit; the ~0.2 V collector–emitter saturation drop is negligible at 3.3 V.

---

## 4. Power Section

```
  18650 ── holder ── TP4056 (Type-C, DW01+8205 protection) ── battery V+ ── ME211 (3.3 V)
                                                       │                        │
                                                       └── battery GND ──────────┘── 3V3 rail + ESP32 power
```

- **Charge** through the TP4056's Type-C port; its protection section enforces over-charge/over-discharge cutoffs.
- **ME211** regulates to 3.3 V for the MCU and peripheral rail; its low quiescent current is one of the assumptions baked into the battery budget in [section 8](#8-battery-life-the-numbers).
- Keep cell wiring short and ≥ 22 AWG; add a small capacitor across the ME211 output if your build sits far from it.

---

## 5. Firmware

### 5.1 Install

Install the [PlatformIO extension](https://platformio.org/) for VS Code (or `pip install platformio`). Then open `firmware/` as the PlatformIO project — dependencies auto-install on first build.

### 5.2 Configuration

Defaults live in `firmware/platformio.ini` and `firmware/src/main.cpp`. What actually matters:

| Setting | Where | Default / effect |
| :--- | :--- | :--- |
| `WIFI_SSID` / `WIFI_PASS` | `main.cpp` | Compile-time **fallbacks** only — credentials saved via the on-device Wi-Fi Setup Portal override them |
| `FIREBASE_BASE_URL` / `CLAIM_WEB_BASE` | `main.cpp` | Point these at **your** Firebase RTDB and deployed dashboard if you're not using the shipped project |
| `-DRTC_SUPPORT=0` | `platformio.ini` | DS3231 compiled out (recommended unless you fit one) |
| `-DHA_MQTT_ENABLED=0/1` | `platformio.ini` | `1` enables MQTT + Home Assistant auto-discovery (`MQTT_BROKER_*` in `main.cpp`) |
| `-DLOGGING_ENABLED=1/0` | `platformio.ini` | `0` compiles all serial logging out (frees a little time/energy) |
| `-DHEADLESS_MODE=1` | `platformio.ini` | No OLED at all: claim URL prints to serial instead of showing a QR |
| `-DARDUINO_LOOP_STACK_SIZE=65536` | `platformio.ini` | Keep this — the on-device KNN needs the larger loop stack |

Timing constants (in `main.cpp`) that drive the duty cycle:

| Constant | Value | Meaning |
| :--- | :--- | :--- |
| `DEEP_SLEEP_DURATION_US` | `5400000000` = **1.5 h** | Timer sleep between cycles (the inline comment says "1hour" but the value is 5,400 s — see [section 10](#10-known-discrepancies)) |
| `AWAKE_DURATION` | 20 s | Awake window before sleeping (claimed nodes) |
| `WIFI_CONNECT_TIMEOUT` | 5 s | Per-cycle Wi-Fi join attempt |
| `FIREBASE_SYNC_INTERVAL` | 12 s | Cloud sync cadence while awake |
| `PROVISION_RECHECK_INTERVAL` | 30 s | Claim/wi-fi poll rate while unpaired |

### 5.3 Build & Flash

```powershell
cd firmware
pio run                 # compile
pio run -t upload       # flash over USB
pio device monitor      # serial console @ 115200
pio run -t erase        # wipe NVS (forces re-pairing, clears portal credentials)
```

Debug tip: set `ENABLE_SLEEP = false` in `main.cpp` to keep the node awake while iterating.

---

## 6. First Boot Checklist

Power via the main supply, watch `pio device monitor`, and confirm in order:

1. `[boot] Cold Boot` → logo splash renders on the OLED.
2. `[i2c] Scan:` lines — every device you wired should answer `OK`; the OLED auto-detect prints `[oled] 0x3C: ... SSD1306` (or SH1106).
3. `[sensor] Detected ...` names the sensors you chose.
4. `[wifi] Connected to <SSID>` and `[time] Synced: ... IST` — Wi-Fi and NTP work.
5. If unclaimed: `[provision] No stored key ...` and the OLED alternates **NOT PAIRED YET** ↔ QR code every 5 s.
6. After claiming (next section): sensor values on screen 1, `[firebase] Data POST result: 200`, and a forecast appears on screen 3.
7. After 20 s awake: `[sleep] Entering Deep Sleep. Goodnight!` — the OLED blanks and the peripheral rail dies at that instant (that's the BC547 working).

Behaviour recap: claimed nodes run a 20 s window (3 or 4 rotating screens at 5 s each), post `{t, h, p, ts}` (+ `gas`/`aqi` on a BME680) to Firebase, fetch the newest forecast, then deep-sleep for 1.5 h. Unclaimed nodes **never sleep** — they stay awake showing the QR pattern and polling every 30 s, so pair them promptly (or keep them on the TP4056 charger) to avoid running the battery down.

---

## 7. Pairing & Cloud Setup

Full walkthroughs live in [`website/README.md`](website/README.md) (dashboard + Firebase setup + user guide) and [`inferenceserver/README.md`](inferenceserver/README.md) (forecast worker). Short version:

**One-time cloud setup**
1. Create a Firebase project; enable Email/Password auth; create a Realtime Database; deploy `website/` (`firebase deploy`) with `website/public/config.js` filled in; deploy `database.rules.json`.
2. Run the inference server (`cd inferenceserver && pip install -r requirements.txt && python main.py`) — it patches cloud ML forecasts into your device records.

**Pairing the node**
1. Power the node; it shows **NOT PAIRED YET** with a QR.
2. Scan the QR (or type the shown `https://<host>/<MAC>` URL), sign in, click **Claim device**.
3. Within ~30 s the node polls the cloud, stores its key, and starts syncing — the screen flips to normal operation.

---

## 8. Battery Life: The Numbers

> **Everything in this section is a datasheet-derived budget, not a measurement.** Typical figures at 25 °C from the ESP32-C3, SSD1306, ME211, and BC547/protection datasheets, plus the firmware's actual timings. The PCB's test points let you replace these estimates with real numbers — calibration procedure at the end.

### 8.1 Duty cycle (from firmware constants)

| | Value |
| :--- | :--- |
| Awake window | 20 s (claimed node) |
| Sleep duration | 5,400 s (1.5 h) |
| Cycle length | 5,420 s |
| **Awake duty** | **0.37 %** |

### 8.2 Sleep state (~5,400 s per cycle)

| Source | Current | Basis |
| :--- | :--- | :--- |
| ESP32-C3, deep sleep w/ timer wake | ~5 µA | ESP32-C3 datasheet (typical) |
| ME211 quiescent | ~2–4 µA | ME211 datasheet (typical) |
| TP4056 DW01 + 8205 protection quiescent | ~3–6 µA | typical for this protection pair |
| BC547 (OFF, base pulled to GND) | ≈ 0 µA | leakage only |
| OLED + sensors (rail cut) | 0 | physically disconnected |
| **Total sleep draw** | **~10–15 µA** | |

Sleep charge per cycle: 15 µA × 5,400 s ≈ **0.023 mAh**.

### 8.3 Awake state (20 s per cycle) — normal connected cycle

| Phase | Duration | Avg current | Basis |
| :--- | :--- | :--- | :--- |
| Boot, I²C scan, sensor read, OLED on | ~5 s | ~35 mA | C3 core + SSD1306 (~12–15 mA) + sensor |
| Wi-Fi join (≤5 s), NTP, HTTPS POST + GET (TLS) | ~10 s | ~90 mA | C3 Wi-Fi RX ≈ 85 mA typical; TX capped low by `esp_wifi_set_max_tx_power` |
| Screens cycle, prediction, idle | ~5 s | ~40 mA | C3 core + OLED + radio maintenance |
| **Awake charge** | 20 s | ≈ **0.35 mAh** | |

### 8.4 Per-cycle and daily totals (claimed, connected)

| | |
| :--- | :--- |
| Per cycle (awake + sleep) | ~0.37 mAh per 1.5 h |
| Per day (16 cycles) | **~6 mAh/day** |
| Per month (30 days) | **~180 mAh/month** |
| % of a 3000 mAh cell consumed per day | **~0.2 %/day** |

### 8.5 Worst case — Wi-Fi unreachable every cycle

A failed join adds retries and an 8 s full network scan (`log_wifi_scan()`) with no successful exchange to show for it:

| | |
| :--- | :--- |
| Per cycle (offline retry pattern) | ~0.64 mAh |
| Per day | **~10 mAh/day** |
| Per month | **~305 mAh/month** |

### 8.6 real battery life

| | |
| :--- | :--- |
| Cell | 18650, 3000 mAh nominal |
| Usable capacity (90 % utilization, protection cutoff + aging) | ~2,700 mAh |
| Self-discharge (quality cell, ~2 %/month) | ~60 mAh over the month |
| Worst-case month of use (section 8.5) | ~305 mAh |
| **Remaining margin after one month** | **~2,300 mAh → ≥ 7× headroom** |
| Theoretical full runtime ((datasheet budget)) | 2,700 / 5.9 ≈ 15 months |
| **Conservative claim** | **≈ 1 month is met with huge margin — even offline-heavy usage stays under ~11 % of capacity per month.** |

### 8.7 Caveats that would erode the budget

- **Unclaimed node:** never sleeps (~35–90 mA continuous + 30 s polls) — expect days, not weeks. Pair promptly.
- **Dev board vs bare module:** a stock ESP32-C3-DevKitC-1 carries extra silicon (USB bridge, LEDs, regulator) that raises deep-sleep draw well above the ~5 µA module figure — on the order of 0.1–0.5 mA on some boards, which alone can consume 3–12 mAh/day. The budget above assumes a module/bare-chip build; measure your exact board (see below).
- **Button wakes, log-ins via USB, weak RSSI retransmits** all add awake time. that is why it is recommeneded to use a esp32 c3 mini

### 8.8 Validating on your hardware (PCB test points)

1. Sleep current: put a µA-range meter (or a power profiler) in series with the battery, wait for `[sleep] Entering Deep Sleep`, record the current after 30 s of settling. Expect **10–15 µA** on a bare-module build; whatever you measure becomes your `I_sleep`.
2. Awake current: same series meter during the 20 s window; note the spike profile (radio bursts, ~90–300 mA peaks). Average it for `I_awake`.
3. Recompute: `mAh/day = I_awake × (duty × 24 h) + I_sleep × (1 − duty) × 24 h`, where `duty = 20/5420 ≈ 0.0037`.
4. Crosscheck against 8.4; if your measured sleep draw exceeds ~30 µA, hunt leakage (I²C pull-up back-feed, missing base pull-down, protection circuit) before trusting the runtime math.

---

## 9. Final Assembly

1. **Breadboard first** — full Section 2 wiring *without* the BC547; verify every item in the Section 6 checklist.
2. Add the battery section (18650 + TP4056 + ME211) and confirm it runs on battery.
3. Add the BC547 stage and confirm the OLED blanks the instant `[sleep] Entering Deep Sleep` prints.
4. Move to perfboard/PCB: sockets first, then the switched-GND star to the transistor, then battery wiring.
5. Enclose with an OLED window and sensor ventilation; the pairing flow needs no computer — just the QR.
6. Released PCB design files: [`pcb fab file and schematic/`](<pcb fab file and schematic/>) (Gerbers + schematic PDF, 2026-11-07 revision).
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
---


## 10. Component References

| Component | Details |
| :--- | :--- |
| [`firmware/`](firmware/) | Firmware detail: OLED screens, Wi-Fi portal, MQTT/HA, troubleshooting → [`firmware/README.md`](firmware/README.md) |
| [`inferenceserver/`](inferenceserver/) | Forecast worker guide → [`inferenceserver/README.md`](inferenceserver/README.md) |
| [`website/`](website/) | Dashboard, Firebase setup, claim walkthrough → [`website/README.md`](website/README.md) |
| [`firmware/models/`](firmware/models/) + [`inferenceserver/modeltoc.py`](inferenceserver/modeltoc.py) | On/offline model pairing, retraining workflow |
