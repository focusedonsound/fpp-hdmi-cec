#!/bin/bash
# display_power_direct.sh — always uses vcgencmd/fallback chain regardless of Display Mode setting
# Usage: display_power_direct.sh on|off
# Used by vcgencmd_on.sh / vcgencmd_off.sh FPP commands.

PLUGIN_DIR="$(dirname "$(dirname "$0")")"
CONFIG_FILE="/home/fpp/media/config/hdmi_cec.json"
LOG_FILE="/home/fpp/media/logs/HdmiCec.log"

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [display] $*" >> "$LOG_FILE"; }

ACTION="${1:-on}"
POWER_VAL=$([ "$ACTION" = "on" ] && echo "1" || echo "0")
SUCCESS=false

log "Display $ACTION (direct vcgencmd/fallback)"

# Method 1: vcgencmd
if command -v vcgencmd >/dev/null 2>&1; then
    RESULT=$(sudo vcgencmd display_power "$POWER_VAL" 2>&1 || vcgencmd display_power "$POWER_VAL" 2>&1)
    log "vcgencmd: $RESULT"
    CURRENT=$(vcgencmd display_power 2>/dev/null | grep -o '[0-9]' || echo "-1")
    if [[ "$CURRENT" == "$POWER_VAL" ]]; then
        SUCCESS=true; log "Method 1 (vcgencmd) succeeded"
    fi
fi

# Method 2: tvservice
if [[ "$SUCCESS" == "false" ]] && command -v tvservice >/dev/null 2>&1; then
    OUTPUT=$([ "$ACTION" = "off" ] && { sudo tvservice -o 2>&1 || tvservice -o 2>&1; } \
                                  || { sudo tvservice -p 2>&1 || tvservice -p 2>&1; })
    log "tvservice: $OUTPUT"
    [[ "$OUTPUT" != *"error"* ]] && { SUCCESS=true; log "Method 2 (tvservice) succeeded"; }
fi

# Method 3: DRM sysfs
if [[ "$SUCCESS" == "false" ]]; then
    DRM_STATUS=$([ "$ACTION" = "on" ] && echo "on" || echo "off")
    for CONN in /sys/class/drm/card*-HDMI-A-*/status; do
        [[ -e "$CONN" ]] && { echo "$DRM_STATUS" | sudo tee "$CONN" >/dev/null 2>&1; SUCCESS=true; log "Method 3 (DRM) $CONN"; }
    done
    DPMS_VAL=$([ "$ACTION" = "on" ] && echo "On" || echo "Off")
    for DPMS in /sys/class/drm/card*-HDMI-A-*/dpms; do
        [[ -e "$DPMS" ]] && { echo "$DPMS_VAL" | sudo tee "$DPMS" >/dev/null 2>&1; SUCCESS=true; log "Method 3 (DRM dpms) $DPMS"; }
    done
fi

# Method 4: xrandr
if [[ "$SUCCESS" == "false" ]]; then
    for DISP in ":0" ":0.0"; do
        HDMI_OUT=$(DISPLAY="$DISP" xrandr --query 2>/dev/null | grep " connected" | grep -i hdmi | awk '{print $1}' | head -1)
        if [[ -n "$HDMI_OUT" ]]; then
            [ "$ACTION" = "off" ] && DISPLAY="$DISP" xrandr --output "$HDMI_OUT" --off 2>/dev/null \
                                  || DISPLAY="$DISP" xrandr --output "$HDMI_OUT" --auto 2>/dev/null
            SUCCESS=true; log "Method 4 (xrandr) $HDMI_OUT"
        fi
    done
fi

[[ "$SUCCESS" == "true" ]] && { log "Display $ACTION complete"; exit 0; }
log "ERROR: All display power methods failed"
exit 1
