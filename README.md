# fpp-hdmi-cec

HDMI CEC control plugin for [Falcon Player (FPP)](https://github.com/FalconChristmas/fpp) — power your TV on/off, switch inputs, and control volume directly from FPP playlists, schedules, and GPIO triggers.

## Features

- **TV Power** — On and Standby (off) via CEC
- **Input switching** — Set Active Source / Set Inactive Source
- **Volume control** — Volume Up, Volume Down, Mute Toggle
- **Raw command** — Send any `cec-client` command string for advanced use
- **Auto power** — Optionally turn the TV on when FPP starts and off when FPP stops
- **Device scan** — Discover all CEC devices on the HDMI bus from the settings page
- **FPP Commands** — All 8 CEC commands are registered as FPP Commands usable in playlists, the scheduler, GPIO inputs, and any other plugin
- **Log viewer** — Built-in log viewer on the settings page

## Requirements

- Raspberry Pi (or other device with a CEC-capable HDMI port)
- `cec-utils` package (`sudo apt install cec-utils`) — installed automatically by the plugin
- FPP 6.0 or later

## Installation

### From the FPP Plugin Manager

1. In FPP go to **Content Setup → Plugin Manager**
2. Find **HDMI CEC Control** and click **Install**
3. `cec-utils` is installed automatically

### Manual

```bash
cd /opt/fpp/SD/FPP/plugins   # or wherever FPP stores plugins
git clone https://github.com/focusedonsound/fpp-hdmi-cec.git
bash fpp-hdmi-cec/fpp_install.sh
```

## Configuration

Navigate to **Content Setup → HDMI CEC Control**.

| Setting | Description |
|---------|-------------|
| **Enable Plugin** | Master on/off for all CEC commands |
| **TV On at FPP Start** | Sends CEC On 15 seconds after FPP boots |
| **TV Standby at FPP Stop** | Sends CEC Standby when FPP shuts down |
| **CEC Adapter** | Auto-detected on Raspberry Pi; override if needed |
| **HDMI Port** | Physical HDMI port number on the TV (1–4) |
| **TV CEC Address** | 0 = TV (default), 5 = Audio/Receiver |
| **Log Level** | cec-client verbosity (1 = errors only, 8 = full debug) |

## Using CEC Commands in FPP

All commands appear in FPP's command picker as **CEC - …**:

| FPP Command | Action |
|-------------|--------|
| `CEC - TV On` | Power on the TV |
| `CEC - TV Standby` | Put TV into standby |
| `CEC - Set Active Source` | Switch TV input to the Pi |
| `CEC - Set Inactive Source` | Release active source |
| `CEC - Volume Up` | Volume up |
| `CEC - Volume Down` | Volume down |
| `CEC - Mute Toggle` | Mute / unmute |
| `CEC - Send Raw Command` | Any `cec-client` command string |

### Examples

**Playlist**: Add a *FPP Command* item at the start of your show playlist → `CEC - TV On`

**Scheduler**: Create a schedule entry at 22:00 → `CEC - TV Standby` to turn off the TV at the end of the night

**GPIO**: Wire a button to a GPIO pin → falling edge → `CEC - TV On` to wake the display with a button press

## Troubleshooting

**CEC commands do nothing / timeout**
- Verify the TV supports CEC (called *Anynet+* on Samsung, *Bravia Sync* on Sony, *SimpLink* on LG, *EasyLink* on Philips)
- Ensure CEC is enabled in the TV's settings menu
- Run **Scan CEC Devices** on the settings page — you should see your TV listed
- Try a different HDMI cable; some cheaper cables omit the CEC pin

**`cec-client not found`**
- Run `sudo apt install cec-utils` on the Pi, or reinstall the plugin

**Works on Pi but not another device**
- CEC support depends on the hardware. Raspberry Pi 3/4/5 have CEC built into all HDMI ports. Other SBCs may not.

## License

MIT — free for personal and commercial use.

## Author

Nick Scilingo — [FocusedOnSound](https://github.com/focusedonsound)
