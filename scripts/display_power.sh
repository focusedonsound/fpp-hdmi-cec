#!/bin/bash
# display_power.sh — mode-aware display power control
# Usage: display_power.sh on|off
#
# Reads display_mode from hdmi_cec.json:
#   "cec"      — sends CEC on/standby to TV (default)
#   "vcgencmd" — uses Raspberry Pi vcgencmd display_power (PC monitors)

PLUGIN_DIR="$(dirname "$(dirname "$0")")"
CONFIG_FILE="/home/fpp/media/config/hdmi_cec.json"
LOG_FILE="/home/fpp/media/logs/HdmiCec.log"

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [display] $*" >> "$LOG_FILE"; }

ACTION="${1:-on}"   # on | off

# ── Read display mode ────────────────────────────────────────────
MODE=$(python3 -c "
import json
try:
    cfg = json.load(open('${CONFIG_FILE}'))
    print(cfg.get('display_mode', 'cec'))
except: print('cec')
" 2>/dev/null || echo "cec")

# Check enabled
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

log "Display $ACTION (mode=$MODE)"

# ── vcgencmd mode ────────────────────────────────────────────────
if [[ "$MODE" == "vcgencmd" ]]; then
    POWER=$([ "$ACTION" = "on" ] && echo "1" || echo "0")
    if ! command -v vcgencmd >/dev/null 2>&1; then
        log "ERROR: vcgencmd not found — is this a Raspberry Pi?"
        exit 1
    fi
    OUTPUT=$(vcgencmd display_power "$POWER" 2>&1)
    STATUS=$?
    log "vcgencmd display_power $POWER → $OUTPUT"
    exit $STATUS
fi

# ── CEC mode (default) ───────────────────────────────────────────
CEC_CMD=$([ "$ACTION" = "on" ] && echo "on 0" || echo "standby 0")
exec "${PLUGIN_DIR}/scripts/cec_command.sh" "$CEC_CMD"
