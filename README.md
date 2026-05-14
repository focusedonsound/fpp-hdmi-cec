# 📺 HDMI CEC Control+ for Falcon Player

### *FPP Plugin: HDMI CEC Control +*

[![FPP Compatible](https://img.shields.io/badge/FPP-8.x%20%7C%209.x%20%7C%2010.x%2B-red?style=for-the-badge&logo=raspberry-pi)](https://github.com/FalconChristmasLighting/fpp)
[![Platform](https://img.shields.io/badge/Platform-Raspberry%20Pi-c51a4a?style=for-the-badge&logo=raspberry-pi)](https://www.raspberrypi.com/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![HDMI CEC](https://img.shields.io/badge/HDMI-CEC%20%2B%20DDC%2FCI-blue?style=for-the-badge)](https://www.hdmi.org/)
[![GitHub](https://img.shields.io/badge/GitHub-focusedonsound-181717?style=for-the-badge&logo=github)](https://github.com/focusedonsound/fpp-hdmi-cec)

---

> **Turn your display on when the show starts. Turn it off when the show ends. Switch inputs, control volume, and automate it all from FPP playlists, schedules, and GPIO triggers — works with CEC TVs AND PC monitors. No remote required. 📺✨**

---

## 🎄 Table of Contents

- [What Is HDMI CEC Control+?](#-what-is-hdmi-cec-control)
- [Feature Overview](#-feature-overview)
- [How It Works (Architecture)](#️-how-it-works-architecture)
- [TV vs PC Monitor — Which Mode Do I Use?](#-tv-vs-pc-monitor--which-mode-do-i-use)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Configuration](#️-configuration)
- [The 10 FPP Commands](#-the-10-fpp-commands)
- [Auto Power (On at Start / Off at Stop)](#-auto-power-on-at-start--off-at-stop)
- [Display Power Fallback Chain](#-display-power-fallback-chain-vcgencmd-mode)
- [Using Commands in FPP](#-using-commands-in-fpp)
- [Command Presets](#-command-presets)
- [Device Scan](#-device-scan)
- [Test Panel](#-test-panel)
- [CEC Raw Commands](#-cec-raw-commands)
- [Troubleshooting](#-troubleshooting)
- [File Reference](#-file-reference)
- [FAQ](#-faq)
- [Credits](#-credits)

---

## 📺 What Is HDMI CEC Control+?

**HDMI CEC Control+** is a Falcon Player plugin that gives FPP full control over the display connected to your Raspberry Pi's HDMI port — powering it on, putting it to sleep, switching inputs, and adjusting volume, all from inside FPP's playlist and scheduling system.

For **CEC-capable TVs**, it uses the HDMI CEC bus — the same protocol your TV remote uses behind the scenes — to send commands directly over the HDMI cable without any extra wiring.

For **PC monitors** (HP, Dell, Samsung, LG, and most monitors without CEC), it uses a smart **6-method fallback chain** that tries `vcgencmd`, `kmsblank`, `ddcutil` (DDC/CI), DRM sysfs, and more until something works on your specific hardware.

The result: your display turns on when the show starts, turns off when the show ends, and you never have to touch it again all season. 🎄

---

## ✨ Feature Overview

| Feature | Description |
|---|---|
| 📺 TV Power On/Standby | CEC `on 0` / `standby 0` — works on any CEC TV |
| 🔌 Input Switching | Set Active Source (Pi takes input) / Set Inactive Source |
| 🔊 Volume Control | Volume Up, Volume Down, Mute Toggle via CEC |
| ⌨️ Raw CEC Command | Send any `cec-client` string for advanced/custom use |
| 🖥️ PC Monitor Support | 6-method fallback chain for monitors without CEC |
| ⚡ Auto Power | Turn display on 15s after FPP boot; off on FPP shutdown |
| 🔧 Display Mode | Switch between CEC mode (TVs) and vcgencmd mode (PC monitors) |
| 🎮 10 FPP Commands | All commands usable in playlists, sequences, GPIO triggers, and schedules |
| 📋 Command Presets | One-click registration in FPP's command_presets.json |
| 🔍 Device Scan | Discover all CEC devices on the HDMI bus from the settings page |
| 🧪 Test Panel | Test every command interactively from the UI |
| 📜 Log Viewer | Built-in log tail right on the settings page |

---

## 🏗️ How It Works (Architecture)

```
┌────────────────────────────────────────────────────────────────────┐
│                         Raspberry Pi                               │
│                                                                    │
│  ┌──────────────┐   FPP Command    ┌────────────────────────────┐  │
│  │  FPP Web UI  │ ───────────────▶ │  commands/cec_tv_on.sh     │  │
│  │  (Test Panel)│                  │  commands/cec_tv_standby.sh│  │
│  └──────────────┘                  │  commands/cec_active_src.sh│  │
│                                    │  commands/cec_volume_up.sh │  │
│  ┌──────────────┐   FPP Command    │  commands/cec_mute.sh      │  │
│  │  FPP Playlist│ ───────────────▶ │  commands/cec_raw.sh       │  │
│  │  / Sequence  │                  │  commands/vcgencmd_on.sh   │  │
│  └──────────────┘                  │  commands/vcgencmd_off.sh  │  │
│                                    └────────────┬───────────────┘  │
│  ┌──────────────┐   FPP Command                │                  │
│  │  GPIO Trigger│ ───────────────▶              │                  │
│  │  / Schedule  │                               ▼                  │
│  └──────────────┘              ┌────────────────────────────────┐  │
│                                │    scripts/cec_command.sh      │  │
│  ┌──────────────┐              │    (CEC mode)                  │  │
│  │  callbacks.sh│              │                                │  │
│  │  pluginStart ├────────────▶ │  echo '<cmd>' | cec-client -s  │  │
│  │  pluginStop  │              │  10s timeout, adapter config   │  │
│  └──────────────┘              └────────────────────────────────┘  │
│                                             │                      │
│  OR for vcgencmd mode:                      ▼                      │
│                                ┌────────────────────────────────┐  │
│                                │   scripts/display_power.sh     │  │
│                                │   (vcgencmd mode — 6 methods)  │  │
│                                │                                │  │
│                                │  1. vcgencmd display_power     │  │
│                                │  2. tvservice                  │  │
│                                │  3. kmsblank (KMS/Bookworm)    │  │
│                                │  4. ddcutil DDC/CI             │  │
│                                │  5. DRM sysfs                  │  │
│                                │  6. xrandr                     │  │
│                                └────────────────────────────────┘  │
│                                             │                      │
│                                             ▼                      │
│                              ┌──────────────────────────────────┐  │
│                              │         HDMI Cable               │  │
│                              └──────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
                                              │
                          ┌───────────────────┴──────────────────┐
                          ▼                                       ▼
               ┌────────────────────┐               ┌────────────────────┐
               │   CEC-capable TV   │               │   PC Monitor       │
               │   (Samsung, LG,    │               │   (HP, Dell,       │
               │   Sony, etc.)      │               │   Samsung, etc.)   │
               └────────────────────┘               └────────────────────┘
```

---

## 🖥️ TV vs PC Monitor — Which Mode Do I Use?

This is the most important decision in the plugin setup:

| | **CEC Mode** | **vcgencmd Mode** |
|---|---|---|
| **Best for** | TVs (Samsung, LG, Sony, Vizio, etc.) | PC monitors (HP, Dell, BenQ, etc.) |
| **How it works** | Sends commands over HDMI CEC bus | Tries 6 Pi/OS methods in sequence |
| **Requires** | `cec-utils` package | Nothing extra (some methods need `kmsblank`, `ddcutil`) |
| **Commands available** | Power, input, volume, mute, raw | Power on/off only |
| **Reliability** | Depends on TV's CEC support | Depends on Pi OS + hardware |

### Set Display Mode in the UI

In the HDMI CEC Control+ settings page, set **Display Mode** to:
- **CEC** — for TVs. The TV on/off buttons and `CEC - TV On/Standby` FPP commands use `cec-client`.
- **vcgencmd** — for PC monitors. The TV on/off buttons and `vcgencmd - Display On/Off` commands use the 6-method fallback chain.

You can also use **both** — set Display Mode to CEC for the main TV commands, and use the dedicated `vcgencmd - Display On/Off` FPP commands to target a PC monitor directly regardless of mode.

---

## 📋 Requirements

### For CEC TVs
- Raspberry Pi with HDMI output
- CEC-capable TV (most modern TVs — Samsung AnyNet+, LG SimpLink, Sony Bravia Sync, etc.)
- `cec-utils` package (installed automatically)
- HDMI cable connected at boot time

### For PC Monitors
- Raspberry Pi with HDMI output
- PC monitor connected via HDMI
- One or more of: `kms++-utils` (kmsblank), `ddcutil` (installed automatically)
- For DDC/CI: monitor must support DDC/CI (most do — check OSD settings)

### FPP
- Falcon Player 8.0, 9.x, or 10.x+

---

## 🚀 Installation

### Via FPP Plugin Manager (Recommended)

1. In FPP, go to **Content Setup → Plugin Manager**
2. Click **Available Plugins**
3. Find **"HDMI CEC Control +"** in the list
4. Click **Install**
5. The installer automatically installs `cec-utils`, `kms++-utils`, and `ddcutil`
6. Navigate to **HDMI CEC Control** in the left menu
7. Set your Display Mode and configure Auto Power if desired
8. Click **Test** to verify commands reach your display

### What the Installer Does

- Installs `cec-utils` via apt (provides `cec-client` for CEC TVs)
- Installs `kms++-utils` via apt (provides `kmsblank` for Pi OS Bookworm KMS display blanking)
- Installs `ddcutil` via apt (provides DDC/CI control for PC monitors)
- Loads `i2c-dev` kernel module and adds `fpp` user to `i2c` group (needed for ddcutil)
- Creates a default config at `/home/fpp/media/config/hdmi_cec.json`

---

## ⚙️ Configuration

All settings live in:
```
/home/fpp/media/config/hdmi_cec.json
```

### Settings Reference

| Setting | Default | Description |
|---|---|---|
| `enabled` | `true` | Master enable/disable. When false, all commands are silently skipped. |
| `display_mode` | `"cec"` | `"cec"` for TVs using HDMI CEC; `"vcgencmd"` for PC monitors |
| `adapter` | `"auto"` | CEC adapter device path (e.g., `/dev/cec0`). `"auto"` lets cec-client find it. |
| `hdmi_port` | `1` | HDMI port number on the TV (1–4). Used by Set Active Source. |
| `device_address` | `0` | CEC device address. `0` = TV (broadcast). Rarely needs changing. |
| `log_level` | `1` | cec-client log verbosity (0–8). 1 = normal. 8 = maximum debug. |
| `auto_on_start` | `false` | Turn display ON automatically 15 seconds after FPP boots |
| `auto_off_stop` | `false` | Turn display OFF automatically when FPP shuts down |

### Example Config

```json
{
  "enabled": true,
  "display_mode": "cec",
  "adapter": "auto",
  "hdmi_port": 1,
  "device_address": 0,
  "log_level": 1,
  "auto_on_start": true,
  "auto_off_stop": true
}
```

---

## 🎮 The 10 FPP Commands

HDMI CEC Control+ registers **10 FPP Commands** — usable everywhere FPP accepts commands: playlists, sequences, the scheduler, GPIO inputs, scripts, and via the REST API.

### CEC Commands (for TVs)

| Command | What It Does | CEC String Sent |
|---|---|---|
| **CEC - TV On** | Wakes the TV from standby | `on 0` |
| **CEC - TV Standby** | Puts the TV into standby/off | `standby 0` |
| **CEC - Set Active Source** | Tells TV to switch HDMI input to the Pi | `as` (Active Source) |
| **CEC - Set Inactive Source** | Tells TV the Pi is no longer the active source | `is` (Inactive Source) |
| **CEC - Volume Up** | Sends volume up to the TV/AV receiver | `volup` |
| **CEC - Volume Down** | Sends volume down to the TV/AV receiver | `voldown` |
| **CEC - Mute Toggle** | Sends mute/unmute toggle | `mute` |
| **CEC - Send Raw Command** | Sends any custom `cec-client` command string | *(your input)* |

### Display Power Commands (for PC Monitors)

| Command | What It Does | Method Used |
|---|---|---|
| **vcgencmd - Display On** | Powers on the connected HDMI display | 6-method fallback chain |
| **vcgencmd - Display Off** | Powers off / blanks the HDMI display | 6-method fallback chain |

> **Note:** The `vcgencmd` commands always use the fallback chain regardless of Display Mode setting. Use these specifically when you have a PC monitor and want an explicit power-control command in your playlist.

### CEC Device Addresses

| Address | Device |
|---|---|
| `0` | TV (most common — broadcast to all) |
| `1`–`4` | Other CEC devices (AV receivers, set-top boxes) |
| `5` | Specific address — use Device Scan to find your devices |

---

## ⚡ Auto Power (On at Start / Off at Stop)

Enable **Auto Power** to have your display turn on and off automatically with FPP — no manual intervention, no separate scheduler rules.

### Auto On at Start
When enabled, FPP's `pluginStart` hook triggers a **15-second delayed TV On** command after FPP boots. The 15-second delay is intentional — it gives HDMI time to negotiate and the CEC bus to initialize before sending commands.

### Auto Off at Stop
When enabled, FPP's `pluginStop` hook sends a TV Standby command immediately when FPP shuts down.

### Typical Show Setup

```
FPP Boot
  └─ 15s delay ──▶ CEC - TV On          (display wakes up)
       ↓
  Show runs all evening
       ↓
FPP Shutdown
  └─ CEC - TV Standby                   (display sleeps)
```

Or schedule the on/off via FPP's built-in scheduler for more precise timing:
- **17:00** → FPP Command: `CEC - TV On`
- **22:00** → FPP Command: `CEC - TV Standby`

---

## 🔗 Display Power Fallback Chain (vcgencmd Mode)

PC monitors don't support HDMI CEC. For them, HDMI CEC Control+ implements a **6-method fallback chain** — it tries each method in order until one succeeds, logging each attempt.

```
Display Off/On requested
        │
        ▼
┌───────────────────────────────────────────────────────────┐
│ Method 1: vcgencmd display_power 0/1                      │
│   Pi firmware command — works on legacy driver (pre-KMS)  │
│   Fails silently on KMS/Bookworm if state doesn't change  │
└───────────────────────┬───────────────────────────────────┘
                        │ failed?
                        ▼
┌───────────────────────────────────────────────────────────┐
│ Method 2: tvservice -o / tvservice -p                     │
│   Older Pi OS (pre-Bookworm) display control              │
│   Not available on Pi OS Bookworm                         │
└───────────────────────┬───────────────────────────────────┘
                        │ failed?
                        ▼
┌───────────────────────────────────────────────────────────┐
│ Method 3: kmsblank                                        │
│   KMS-level HDMI blanking — Pi OS Bookworm default        │
│   Cuts HDMI signal entirely (monitor goes to sleep)       │
│   Requires exclusive DRM master — fails if video is       │
│   playing (SLED, FPP video player holds DRM master)       │
└───────────────────────┬───────────────────────────────────┘
                        │ failed?
                        ▼
┌───────────────────────────────────────────────────────────┐
│ Method 4: ddcutil DDC/CI                                  │
│   Monitor control over HDMI/I2C bus                       │
│   VCP D6=2 (standby), D6=1 (on)                          │
│   Works with most PC monitors (HP, Dell, etc.)            │
│   Works even when video player holds DRM master           │
└───────────────────────┬───────────────────────────────────┘
                        │ failed?
                        ▼
┌───────────────────────────────────────────────────────────┐
│ Method 5: DRM sysfs                                       │
│   Write "off"/"on" to /sys/class/drm/card*-HDMI-A-*/dpms  │
│   Works on some KMS configurations                        │
└───────────────────────┬───────────────────────────────────┘
                        │ failed?
                        ▼
┌───────────────────────────────────────────────────────────┐
│ Method 6: xrandr                                          │
│   X11 display control — only if X11 is running under FPP  │
│   Rare on most FPP setups                                 │
└───────────────────────┬───────────────────────────────────┘
                        │ all failed?
                        ▼
               Log error — display may not
               support software power control
```

### Which Method Will Work for Me?

| Your Setup | Expected Method |
|---|---|
| Pi OS Bullseye (legacy driver) | Method 1: vcgencmd |
| Pi OS Bookworm, no video player | Method 3: kmsblank |
| Pi OS Bookworm, SLED/video running | Method 4: ddcutil |
| HP, Dell, or most PC monitors | Method 4: ddcutil (verify DDC/CI enabled in monitor OSD) |
| Older Pi OS | Method 2: tvservice |

Check the log at `/home/fpp/media/logs/HdmiCec.log` to see exactly which method succeeded.

---

## 🔧 Using Commands in FPP

### In a Playlist

Add a command step to any FPP playlist:
1. Edit or create a playlist
2. Add a new item → type **"Command"** or **"Effect"**
3. Select the command (e.g., `CEC - TV On`)
4. Place it at the start of the playlist to wake the display, or end to sleep it

### In the Scheduler

FPP's built-in scheduler can trigger commands at specific times without a playlist:
1. Content Setup → FPP Scheduler
2. Add a new entry → Action: **Run Command** → pick `CEC - TV On`
3. Set time: 17:00 daily

### Via GPIO Trigger

Wire a physical button or sensor → FPP GPIO Inputs → on trigger: run `CEC - TV On` or `CEC - TV Standby`. Great for a "show start" button at the display.

### Via REST API

Any device on your network can trigger CEC commands:
```bash
# Turn TV on
curl "http://<fpp-ip>/api/command/CEC%20-%20TV%20On"

# TV standby
curl "http://<fpp-ip>/api/command/CEC%20-%20TV%20Standby"

# Set active source
curl "http://<fpp-ip>/api/command/CEC%20-%20Set%20Active%20Source"

# Raw command
curl "http://<fpp-ip>/api/command/CEC%20-%20Send%20Raw%20Command/on%200"
```

### From Home Assistant

```yaml
# Turn TV on when show starts
action: rest_command.fpp_cec
data:
  cmd: "CEC%20-%20TV%20On"
```
```yaml
rest_command:
  fpp_cec:
    url: "http://192.168.1.xxx/api/command/{{ cmd }}"
    method: get
```

---

## 📋 Command Presets

FPP's **Command Presets** system lets you save frequently used commands for quick access in the scheduler and other places.

HDMI CEC Control+ can automatically register all 9 CEC/vcgencmd commands as presets — one click in the settings page:

1. Go to HDMI CEC Control settings
2. Click **"Add CEC Presets to FPP"**
3. All commands appear immediately in FPP's preset picker

To clean up, click **"Remove CEC Presets"** — only the CEC presets are removed; your other presets are untouched.

Presets are stored in `/home/fpp/media/config/command_presets.json`.

---

## 🔍 Device Scan

Not sure what CEC devices are on your HDMI bus? Use the **Device Scan** button on the settings page:

1. Make sure your TV is powered on and the HDMI cable is connected
2. Click **Scan CEC Devices** on the settings page
3. The plugin runs `echo 'scan' | cec-client -s -d 1` (15-second scan)
4. Results show every CEC device: TV, AV receiver, set-top boxes, and more

### Example Scan Output
```
requesting CEC bus information ...
CEC bus information
===================
device #0: TV
address:       0.0.0.0
active source: no
vendor:        Samsung
osd string:    TV
CEC version:   1.4
power status:  standby
language:      eng

device #1: Recording 1
address:       1.0.0.0
active source: yes
vendor:        Pulse-Eight
osd string:    fpp-hdmi-cec
CEC version:   1.4
power status:  on
language:      eng
```

The device scan helps you identify:
- Whether CEC is working at all
- Your TV's vendor name and CEC version
- The Pi's CEC address on the bus (`device #1` above)
- Any other CEC devices (AV receivers, soundbars)

---

## 🧪 Test Panel

The settings page includes a full **Test Panel** so you can verify every command works before putting it in a playlist:

| Button | Tests |
|---|---|
| **TV On** | Sends `on 0` via CEC |
| **TV Standby** | Sends `standby 0` via CEC |
| **Set Active Source** | Switches TV input to Pi |
| **Set Inactive Source** | Releases Pi as active source |
| **Volume Up** | CEC volume up |
| **Volume Down** | CEC volume down |
| **Mute Toggle** | CEC mute |
| **Display On** | Runs the vcgencmd/fallback chain (on) |
| **Display Off** | Runs the vcgencmd/fallback chain (off) |
| **Display Status** | Shows all display power methods and their state |

After each test, the last few log lines are shown directly in the UI — so you can see immediately whether the command succeeded and which method was used.

The **Display Status** button runs a full diagnostic:
- vcgencmd current state
- tvservice status
- All DRM connectors and their DPMS state
- kmsblank: installed / running
- ddcutil: installed / detected displays
- Pi model and video overlay config

---

## ⌨️ CEC Raw Commands

The **CEC - Send Raw Command** FPP command accepts any string that `cec-client` understands. This gives you access to the full CEC command set.

### Common Raw Commands

| Command String | Effect |
|---|---|
| `on 0` | Power on the TV (same as CEC - TV On) |
| `standby 0` | Standby the TV (same as CEC - TV Standby) |
| `standby 5` | Standby a specific CEC device at address 5 |
| `as` | Set active source (Pi takes input) |
| `is` | Set inactive source |
| `volup` | Volume up |
| `voldown` | Volume down |
| `mute` | Mute toggle |
| `scan` | Scan bus (use the UI Scan button instead) |
| `tx 1F:82:10:00` | Send raw CEC hex frame (advanced) |

### Using Raw Commands in FPP

In the FPP Command picker, select **"CEC - Send Raw Command"** and enter the command string as the argument. For example:
- Send `standby 5` to put your soundbar to sleep
- Send `tx 1F:82:10:00` to send a custom HDMI CEC frame

### CEC Addressing Cheat Sheet

```
0.0.0.0  = TV (address 0)
1.0.0.0  = Recording Device 1 (often the Pi)
2.0.0.0  = Recording Device 2
3.0.0.0  = Tuner 1
5.0.0.0  = Audio System (AV receiver / soundbar)
F = broadcast (all devices)
```

---

## 🔍 Troubleshooting

### TV doesn't respond to CEC commands

```bash
# Verify cec-utils is installed
which cec-client

# Check if a CEC adapter is detected
ls /dev/cec*

# Manual test — run a scan
echo 'scan' | timeout 15 cec-client -s -d 1

# Check the log
tail -30 /home/fpp/media/logs/HdmiCec.log
```

**Common causes:**
| Symptom | Cause | Fix |
|---|---|---|
| `cec-client not found` | cec-utils not installed | `sudo apt install cec-utils` |
| `no CEC adapters found` | HDMI not connected, or TV doesn't support CEC | Check cable; check TV CEC setting in its menu |
| `timed out (10s)` | CEC bus not responding | Ensure TV is connected and CEC is enabled in its settings |
| TV has CEC but won't respond | CEC feature disabled in TV menu | Enable "AnyNet+", "SimpLink", "Bravia Sync", or equivalent in TV settings |

---

### TV CEC setting names by brand

| Brand | CEC Setting Name |
|---|---|
| Samsung | AnyNet+ |
| LG | SimpLink |
| Sony | Bravia Sync |
| Panasonic | VIERA Link |
| Philips | EasyLink |
| Sharp | Aquos Link |
| Vizio | CEC (in Settings menu) |
| Generic | HDMI CEC, HDMI Control |

Make sure this feature is **enabled** in your TV's settings menu. It is often disabled by default.

---

### Display Off doesn't work (PC monitor)

1. Run the **Display Status** test from the settings page — it shows all methods and their state
2. Check the log: `tail -30 /home/fpp/media/logs/HdmiCec.log`
3. Look for which method was tried and why each failed

**kmsblank fails with "DRM master conflict":**
Another process (FPP video player, SLED) holds DRM master. kmsblank requires exclusive KMS access. Use ddcutil instead:
```bash
sudo apt install ddcutil
modprobe i2c-dev
sudo ddcutil detect   # verify your monitor is found
sudo ddcutil setvcp D6 2   # standby
```
Enable DDC/CI in your monitor's OSD settings if ddcutil doesn't find it.

**vcgencmd always returns "display_power=1" (KMS false positive):**
On Pi OS Bookworm with KMS driver, vcgencmd's `display_power` reads as 1 even when the display is off — it doesn't actually control the display in KMS mode. The plugin detects this and falls through to the next method automatically.

---

### "Plugin disabled — skipping command" in the log

The **Enabled** toggle in settings is off. Go to HDMI CEC Control settings and enable the plugin.

---

### Auto On doesn't fire on boot

- Verify **Auto On at Start** is checked in settings
- Check the log: `grep "auto_on_start" /home/fpp/media/logs/HdmiCec.log`
- The command fires 15 seconds after `pluginStart` — check if FPP boot logs show `pluginStart` for this plugin
- If the TV CEC scan shows the TV at address 0 but on a non-standard port, try setting `hdmi_port` in settings

---

### ddcutil doesn't find my monitor

```bash
# Load i2c-dev module
sudo modprobe i2c-dev

# Add fpp user to i2c group
sudo usermod -a -G i2c fpp

# Try detection
sudo ddcutil detect

# If "No displays found", verify DDC/CI is enabled in your monitor's OSD
# Look for "DDC/CI" or "Input Control" in the monitor menu
```

---

## 📁 File Reference

| File | Description |
|---|---|
| `fpp_install.sh` | Installer — installs cec-utils, kms++-utils, ddcutil; creates default config |
| `callbacks.sh` | FPP lifecycle hooks — pluginStart (auto on), pluginStop (auto off) |
| `scripts/cec_command.sh` | Core CEC runner — reads config, calls cec-client with 10s timeout |
| `scripts/display_power.sh` | Mode-aware display power — delegates to CEC or vcgencmd chain |
| `scripts/display_power_direct.sh` | Always runs the 6-method vcgencmd/fallback chain, ignores Display Mode |
| `commands/cec_tv_on.sh` | FPP Command: TV On |
| `commands/cec_tv_standby.sh` | FPP Command: TV Standby |
| `commands/cec_active_source.sh` | FPP Command: Set Active Source |
| `commands/cec_inactive_source.sh` | FPP Command: Set Inactive Source |
| `commands/cec_volume_up.sh` | FPP Command: Volume Up |
| `commands/cec_volume_down.sh` | FPP Command: Volume Down |
| `commands/cec_mute.sh` | FPP Command: Mute Toggle |
| `commands/cec_raw.sh` | FPP Command: Send Raw Command (takes arg) |
| `commands/vcgencmd_on.sh` | FPP Command: Display On (vcgencmd/fallback chain) |
| `commands/vcgencmd_off.sh` | FPP Command: Display Off (vcgencmd/fallback chain) |
| `commands/descriptions.json` | FPP Command definitions |
| `www/index.php` | Settings UI — config form, test panel, device scan, log viewer |
| `www/save.php` | Config save endpoint |
| `www/action.php` | AJAX endpoint — test commands, scan, log tail, preset management, status |
| `/home/fpp/media/config/hdmi_cec.json` | Runtime config |
| `/home/fpp/media/logs/HdmiCec.log` | Full command / method / error log |
| `/home/fpp/media/config/command_presets.json` | FPP command presets (shared with FPP) |

---

## ❓ FAQ

**Q: My TV supports CEC but the commands are slow / delayed. Is that normal?**  
A: Yes — CEC is inherently slow. Most TVs take 1–3 seconds to respond to a power command. The plugin uses a 10-second timeout to accommodate slow responders. This is a CEC protocol limitation, not a plugin issue.

**Q: Can I control my soundbar or AV receiver separately from the TV?**  
A: Yes — use "CEC - Send Raw Command" with the device's CEC address. Run a Device Scan first to find your soundbar's address, then send `standby 5` (or whatever its address is) to control it independently.

**Q: Does this work with HDMI switches?**  
A: It depends on the switch. Passive switches usually pass CEC through fine. Active switches (with their own remote) sometimes intercept or block CEC. If CEC commands work when the Pi is the only device but not through the switch, the switch is the culprit.

**Q: kmsblank works great but my SLED video prop broke Display Off. What do I do?**  
A: This is expected — SLED's video player holds DRM master, which kmsblank requires. Install ddcutil (`sudo apt install ddcutil`) and enable DDC/CI in your monitor's OSD settings. ddcutil controls the monitor via I2C and doesn't need DRM master — it works even when video is playing.

**Q: Can I turn the TV off mid-show and back on again?**  
A: Yes — use `CEC - TV Standby` and `CEC - TV On` as FPP Commands in your sequence or via the scheduler. The plugin handles each call independently.

**Q: Will this work on a Raspberry Pi Zero 2W?**  
A: Yes — CEC is handled by the Pi's HDMI hardware, not the CPU. It works on any Pi with an HDMI port.

**Q: Can I use Display Mode = CEC for the TV but also control a separate PC monitor?**  
A: Yes — set Display Mode to CEC, and use the dedicated `vcgencmd - Display On/Off` commands in your playlist for the PC monitor. Those commands always use the fallback chain regardless of Display Mode.

---

## 💛 Support the Project

If HDMI CEC Control+ has simplified your show setup, consider supporting development!

<a href="https://buymeacoffee.com/jm9pwtesct" target="_blank">
  <img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-☕-yellow?style=for-the-badge" alt="Buy Me a Coffee" />
</a>
&nbsp;
<a href="https://paypal.me/NScilingo" target="_blank">
  <img src="https://img.shields.io/badge/Donate-PayPal-blue?style=for-the-badge&logo=paypal" alt="Donate via PayPal" />
</a>

---

## 🤝 Contributing

Found a bug? TV brand that needs special handling? New fallback method idea? PRs and issues welcome!

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes
4. Open a pull request against `main`

Bug reports: [github.com/focusedonsound/fpp-hdmi-cec/issues](https://github.com/focusedonsound/fpp-hdmi-cec/issues)

---

## 📜 License

MIT License — see [LICENSE](LICENSE) for details.

Free for personal use. If you're building something commercial with this, please reach out.

---

## 🎉 Credits

**Author:** Nick Scilingo ([FocusedOnSound](https://github.com/focusedonsound))

Built with ❤️ for every Christmas lighting enthusiast who's ever wanted their display to just *turn itself on* at show time.

---

*Part of the [FocusedOnSound FPP Plugin Collection](https://github.com/focusedonsound):*
- 🎅 **[SLED Smart Letters to Santa](https://github.com/focusedonsound/fpp-sled-mailbox)** — sensor-driven Santa Mailbox with video playback, car counting, and Home Assistant integration
- 📣 **[Announcement Assistant](https://github.com/focusedonsound/fpp-AnnouncementAssistant)** — play pre-recorded announcements over show audio with automatic PulseAudio ducking
