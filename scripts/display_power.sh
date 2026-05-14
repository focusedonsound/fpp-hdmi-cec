#!/bin/bash
# display_power.sh — mode-aware display power control
# Usage: display_power.sh on|off
#
# Tries multiple methods in order until one works:
#   1. vcgencmd display_power   (Pi legacy/firmware driver)
#   2. tvservice                (older Pi OS)
#   3. kmsblank                 (Pi OS Bookworm KMS — any monitor, cuts HDMI signal)
#   4. ddcutil DDC/CI           (PC monitors via HDMI — HP, Dell, etc.)
#   5. DRM sysfs connector      (Pi KMS driver — Bookworm default)
#   6. xrandr via DISPLAY=:0   (if X11 is running under FPP)

PLUGIN_DIR="$(dirname "$(dirname "$0")")"
CONFIG_FILE="/home/fpp/media/config/hdmi_cec.json"
LOG_FILE="/home/fpp/media/logs/HdmiCec.log"

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [display] $*" >> "$LOG_FILE"; }

ACTION="${1:-on}"   # on | off

# ── Read mode + enabled ──────────────────────────────────────────
MODE=$(python3 -c "
import json
try:
    cfg = json.load(open('${CONFIG_FILE}'))
    print(cfg.get('display_mode', 'cec'))
except: print('cec')
" 2>/dev/null || echo "cec")

ENABLED=$(python3 -c "
import json
try:
    cfg = json.load(open('${CONFIG_FILE}'))
    print('true' if cfg.get('enabled', True) else 'false')
except: print('true')
" 2>/dev/null || echo "true")

if [[ "$ENABLED" != "true" ]]; then
    log "Plugin disabled — skipping display $ACTION"
    exit 0
fi

# ── CEC mode — delegate entirely ────────────────────────────────
if [[ "$MODE" != "vcgencmd" ]]; then
    CEC_CMD=$([ "$ACTION" = "on" ] && echo "on 0" || echo "standby 0")
    exec "${PLUGIN_DIR}/scripts/cec_command.sh" "$CEC_CMD"
fi

# ── vcgencmd mode — try multiple Pi display-off methods ─────────
log "Display $ACTION via vcgencmd/fallback methods"

POWER_VAL=$([ "$ACTION" = "on" ] && echo "1" || echo "0")
SUCCESS=false
KMSBLANK_PID_FILE="/tmp/HdmiCec_kmsblank.pid"
KMSBLANK_FIFO="/tmp/HdmiCec_kmsblank_ctrl"

# ── Pre-step for "on": stop kmsblank if it was used to blank ─────
# Send a newline into the control FIFO so kmsblank reads its "press Enter"
# and exits cleanly, restoring the display. Kill as backup if it lingers.
if [[ "$ACTION" == "on" ]] && command -v kmsblank >/dev/null 2>&1; then
    SAVED_PID=$(cat "$KMSBLANK_PID_FILE" 2>/dev/null || echo "")
    if [[ -n "$SAVED_PID" ]] && kill -0 "$SAVED_PID" 2>/dev/null; then
        echo "" > "$KMSBLANK_FIFO" 2>/dev/null || true   # graceful: send Enter
        sleep 0.2
        kill "$SAVED_PID" 2>/dev/null || true             # forceful backup
        rm -f "$KMSBLANK_PID_FILE" "$KMSBLANK_FIFO"
        log "Stopped kmsblank (PID $SAVED_PID) — HDMI signal restored"
        SUCCESS=true
    elif pkill -x kmsblank 2>/dev/null; then
        rm -f "$KMSBLANK_PID_FILE" "$KMSBLANK_FIFO"
        log "Stopped kmsblank (by name) — HDMI signal restored"
        SUCCESS=true
    fi
fi

# ── Method 1: vcgencmd display_power ────────────────────────────
if command -v vcgencmd >/dev/null 2>&1; then
    BEFORE=$(vcgencmd display_power 2>/dev/null | grep -o '[0-9]' || echo "-1")
    RESULT=$(sudo vcgencmd display_power "$POWER_VAL" 2>&1 || vcgencmd display_power "$POWER_VAL" 2>&1)
    log "vcgencmd result: $RESULT"
    CURRENT=$(vcgencmd display_power 2>/dev/null | grep -o '[0-9]' || echo "-1")
    if [[ "$CURRENT" == "$POWER_VAL" && "$BEFORE" != "$POWER_VAL" ]]; then
        # State changed to the desired value — vcgencmd actually worked
        log "Method 1 (vcgencmd) succeeded"
        SUCCESS=true
    elif [[ "$CURRENT" == "$POWER_VAL" && "$BEFORE" == "$POWER_VAL" ]]; then
        # State was already what we want — on KMS 'on' reads 1 always; skip to next method
        log "Method 1 (vcgencmd) state was already $POWER_VAL before command (KMS false positive?) — trying fallbacks"
    else
        log "Method 1 (vcgencmd) ran but state did not change (KMS driver?) — trying fallbacks"
    fi
fi

# ── Method 2: tvservice (older Pi OS / legacy driver) ────────────
if [[ "$SUCCESS" == "false" ]] && command -v tvservice >/dev/null 2>&1; then
    if [[ "$ACTION" == "off" ]]; then
        OUTPUT=$(sudo tvservice -o 2>&1 || tvservice -o 2>&1)
    else
        OUTPUT=$(sudo tvservice -p 2>&1 || tvservice -p 2>&1)
    fi
    log "Method 2 (tvservice): $OUTPUT"
    if [[ "$OUTPUT" != *"error"* && "$OUTPUT" != *"not"* ]]; then
        SUCCESS=true
        log "Method 2 (tvservice) succeeded"
    fi
fi

# ── Method 3: kmsblank (Pi OS Bookworm KMS — works on any monitor) ──
# Runs as a persistent background process; blanks the HDMI output at KMS level.
# Kills any stale instance first, then starts fresh and saves the PID.
if [[ "$SUCCESS" == "false" ]] && [[ "$ACTION" == "off" ]] && command -v kmsblank >/dev/null 2>&1; then
    pkill -x kmsblank 2>/dev/null || true
    rm -f "$KMSBLANK_FIFO"
    mkfifo "$KMSBLANK_FIFO"
    # Open FIFO read-write (<>) so kmsblank doesn't block or get SIGTTIN from the TTY.
    # kmsblank will wait for a newline on this FIFO instead of the terminal.
    sudo kmsblank <>"$KMSBLANK_FIFO" 2>/tmp/HdmiCec_kmsblank.err &
    KMSBLANK_PID=$!
    echo "$KMSBLANK_PID" > "$KMSBLANK_PID_FILE"
    sleep 0.5
    if kill -0 "$KMSBLANK_PID" 2>/dev/null; then
        SUCCESS=true
        log "Method 3 (kmsblank) started PID $KMSBLANK_PID"
    else
        KMSBLANK_ERR=$(head -1 /tmp/HdmiCec_kmsblank.err 2>/dev/null || echo "")
        rm -f "$KMSBLANK_PID_FILE" "$KMSBLANK_FIFO"
        log "Method 3 (kmsblank) failed to start${KMSBLANK_ERR:+ — $KMSBLANK_ERR}"
    fi
fi

# ── Method 4: ddcutil DDC/CI (PC monitors — HP, Dell, etc.) ─────
# VCP code D6: 1=On  2=Standby (keeps DDC bus alive)  Works with KMS; requires i2c-dev module.
if [[ "$SUCCESS" == "false" ]] && command -v ddcutil >/dev/null 2>&1; then
    modprobe i2c-dev 2>/dev/null || true
    if [[ "$ACTION" == "off" ]]; then
        OUTPUT=$(sudo ddcutil setvcp D6 2 2>&1 || ddcutil setvcp D6 2 2>&1)  # Standby (keeps DDC/CI bus alive)
    else
        OUTPUT=$(sudo ddcutil setvcp D6 1 2>&1 || ddcutil setvcp D6 1 2>&1)  # On
    fi
    log "Method 4 (ddcutil): $OUTPUT"
    if [[ $? -eq 0 && "$OUTPUT" != *"Unable"* && "$OUTPUT" != *"error"* && "$OUTPUT" != *"Error"* && "$OUTPUT" != *"not found"* && "$OUTPUT" != *"No display"* ]]; then
        SUCCESS=true
        log "Method 4 (ddcutil) succeeded"
    else
        log "Method 4 (ddcutil) failed or no DDC/CI monitor found — trying next method"
    fi
fi

# ── Method 5: DRM/KMS sysfs (Bookworm default driver) ────────────
if [[ "$SUCCESS" == "false" ]]; then
    DRM_STATUS=$([ "$ACTION" = "on" ] && echo "on" || echo "off")
    # Find HDMI connectors under /sys/class/drm
    for CONN in /sys/class/drm/card*-HDMI-A-*/status; do
        if [[ -w "$CONN" ]]; then
            echo "$DRM_STATUS" | sudo tee "$CONN" >/dev/null 2>&1 || \
            echo "$DRM_STATUS" > "$CONN" 2>/dev/null
            log "Method 5 (DRM sysfs) wrote '$DRM_STATUS' to $CONN"
            SUCCESS=true
        fi
    done
    # Also try dpms sysfs path on some systems
    for DPMS in /sys/class/drm/card*-HDMI-A-*/dpms; do
        if [[ -w "$DPMS" ]]; then
            DPMS_VAL=$([ "$ACTION" = "on" ] && echo "On" || echo "Off")
            echo "$DPMS_VAL" | sudo tee "$DPMS" >/dev/null 2>&1 || \
            echo "$DPMS_VAL" > "$DPMS" 2>/dev/null
            log "Method 5 (DRM dpms) wrote '$DPMS_VAL' to $DPMS"
            SUCCESS=true
        fi
    done
fi

# ── Method 6: xrandr (if X11 is running) ────────────────────────
if [[ "$SUCCESS" == "false" ]]; then
    for DISP in ":0" ":0.0"; do
        if DISPLAY="$DISP" xrandr --query >/dev/null 2>&1; then
            # Find connected HDMI output
            HDMI_OUT=$(DISPLAY="$DISP" xrandr --query 2>/dev/null \
                | grep " connected" | grep -i hdmi | awk '{print $1}' | head -1)
            if [[ -n "$HDMI_OUT" ]]; then
                if [[ "$ACTION" == "off" ]]; then
                    DISPLAY="$DISP" xrandr --output "$HDMI_OUT" --off 2>/dev/null
                else
                    DISPLAY="$DISP" xrandr --output "$HDMI_OUT" --auto 2>/dev/null
                fi
                log "Method 6 (xrandr) ran on $HDMI_OUT via DISPLAY=$DISP"
                SUCCESS=true
                break
            fi
        fi
    done
fi

if [[ "$SUCCESS" == "true" ]]; then
    log "Display $ACTION complete"
    exit 0
else
    log "ERROR: All display power methods failed — display may not support software power control"
    exit 1
fi
