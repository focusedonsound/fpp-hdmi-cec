#!/bin/bash
# display_power_direct.sh — always uses vcgencmd/kmsblank/DDC/fallback chain regardless of Display Mode setting
# Usage: display_power_direct.sh on|off
# Used by vcgencmd_on.sh / vcgencmd_off.sh FPP commands.
# Method order: 1. vcgencmd  2. tvservice  3. kmsblank  4. ddcutil DDC/CI  5. DRM sysfs  6. xrandr

PLUGIN_DIR="$(dirname "$(dirname "$0")")"
CONFIG_FILE="/home/fpp/media/config/hdmi_cec.json"
LOG_FILE="/home/fpp/media/logs/HdmiCec.log"

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [display] $*" >> "$LOG_FILE"; }

ACTION="${1:-on}"
POWER_VAL=$([ "$ACTION" = "on" ] && echo "1" || echo "0")
SUCCESS=false
KMSBLANK_PID_FILE="/tmp/HdmiCec_kmsblank.pid"
KMSBLANK_FIFO="/tmp/HdmiCec_kmsblank_ctrl"

log "Display $ACTION (direct vcgencmd/fallback)"

# Pre-step for "on": stop kmsblank if running
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

# Method 1: vcgencmd
if command -v vcgencmd >/dev/null 2>&1; then
    BEFORE=$(vcgencmd display_power 2>/dev/null | grep -o '[0-9]' || echo "-1")
    RESULT=$(sudo vcgencmd display_power "$POWER_VAL" 2>&1 || vcgencmd display_power "$POWER_VAL" 2>&1)
    log "vcgencmd: $RESULT"
    CURRENT=$(vcgencmd display_power 2>/dev/null | grep -o '[0-9]' || echo "-1")
    if [[ "$CURRENT" == "$POWER_VAL" && "$BEFORE" != "$POWER_VAL" ]]; then
        SUCCESS=true; log "Method 1 (vcgencmd) succeeded"
    elif [[ "$CURRENT" == "$POWER_VAL" && "$BEFORE" == "$POWER_VAL" ]]; then
        log "Method 1 (vcgencmd) state already $POWER_VAL (KMS false positive?) — trying fallbacks"
    fi
fi

# Method 2: tvservice
if [[ "$SUCCESS" == "false" ]] && command -v tvservice >/dev/null 2>&1; then
    OUTPUT=$([ "$ACTION" = "off" ] && { sudo tvservice -o 2>&1 || tvservice -o 2>&1; } \
                                  || { sudo tvservice -p 2>&1 || tvservice -p 2>&1; })
    log "tvservice: $OUTPUT"
    [[ "$OUTPUT" != *"error"* ]] && { SUCCESS=true; log "Method 2 (tvservice) succeeded"; }
fi

# Method 3: kmsblank (Pi OS Bookworm KMS — works on any monitor)
if [[ "$SUCCESS" == "false" ]] && [[ "$ACTION" == "off" ]] && command -v kmsblank >/dev/null 2>&1; then
    pkill -x kmsblank 2>/dev/null || true
    rm -f "$KMSBLANK_FIFO"
    mkfifo "$KMSBLANK_FIFO"
    sudo kmsblank <>"$KMSBLANK_FIFO" 2>/tmp/HdmiCec_kmsblank.err &
    KMSBLANK_PID=$!
    echo "$KMSBLANK_PID" > "$KMSBLANK_PID_FILE"
    sleep 0.5
    if kill -0 "$KMSBLANK_PID" 2>/dev/null; then
        SUCCESS=true; log "Method 3 (kmsblank) started PID $KMSBLANK_PID"
    else
        KMSBLANK_ERR=$(head -1 /tmp/HdmiCec_kmsblank.err 2>/dev/null || echo "")
        rm -f "$KMSBLANK_PID_FILE" "$KMSBLANK_FIFO"
        if [[ "$KMSBLANK_ERR" == *"-13"* || "$KMSBLANK_ERR" == *"EACCES"* || "$KMSBLANK_ERR" == *"DPMS"* ]]; then
            log "Method 3 (kmsblank) failed — DRM master conflict: another process (e.g. video player) already holds DRM master. kmsblank needs exclusive KMS access. Use a DDC/CI monitor (ddcutil) instead."
        else
            log "Method 3 (kmsblank) failed to start${KMSBLANK_ERR:+ — $KMSBLANK_ERR}"
        fi
    fi
fi

# Method 4: ddcutil DDC/CI (PC monitors — HP, Dell, etc.)
if [[ "$SUCCESS" == "false" ]] && command -v ddcutil >/dev/null 2>&1; then
    modprobe i2c-dev 2>/dev/null || true
    if [[ "$ACTION" == "off" ]]; then
        OUTPUT=$(sudo ddcutil setvcp D6 2 2>&1 || ddcutil setvcp D6 2 2>&1)  # Standby (keeps DDC/CI bus alive)
    else
        OUTPUT=$(sudo ddcutil setvcp D6 1 2>&1 || ddcutil setvcp D6 1 2>&1)  # On
    fi
    log "ddcutil: $OUTPUT"
    if [[ $? -eq 0 && "$OUTPUT" != *"Unable"* && "$OUTPUT" != *"error"* && "$OUTPUT" != *"Error"* && "$OUTPUT" != *"not found"* && "$OUTPUT" != *"No display"* ]]; then
        SUCCESS=true; log "Method 4 (ddcutil) succeeded"
    fi
fi

# Method 5: DRM sysfs
if [[ "$SUCCESS" == "false" ]]; then
    DRM_STATUS=$([ "$ACTION" = "on" ] && echo "on" || echo "off")
    for CONN in /sys/class/drm/card*-HDMI-A-*/status; do
        [[ -e "$CONN" ]] && { echo "$DRM_STATUS" | sudo tee "$CONN" >/dev/null 2>&1; SUCCESS=true; log "Method 5 (DRM) $CONN"; }
    done
    DPMS_VAL=$([ "$ACTION" = "on" ] && echo "On" || echo "Off")
    for DPMS in /sys/class/drm/card*-HDMI-A-*/dpms; do
        [[ -e "$DPMS" ]] && { echo "$DPMS_VAL" | sudo tee "$DPMS" >/dev/null 2>&1; SUCCESS=true; log "Method 5 (DRM dpms) $DPMS"; }
    done
fi

# Method 6: xrandr
if [[ "$SUCCESS" == "false" ]]; then
    for DISP in ":0" ":0.0"; do
        HDMI_OUT=$(DISPLAY="$DISP" xrandr --query 2>/dev/null | grep " connected" | grep -i hdmi | awk '{print $1}' | head -1)
        if [[ -n "$HDMI_OUT" ]]; then
            [ "$ACTION" = "off" ] && DISPLAY="$DISP" xrandr --output "$HDMI_OUT" --off 2>/dev/null \
                                  || DISPLAY="$DISP" xrandr --output "$HDMI_OUT" --auto 2>/dev/null
            SUCCESS=true; log "Method 6 (xrandr) $HDMI_OUT"
        fi
    done
fi

[[ "$SUCCESS" == "true" ]] && { log "Display $ACTION complete"; exit 0; }
log "ERROR: All display power methods failed"
exit 1
