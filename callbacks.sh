#!/bin/bash
# callbacks.sh — HDMI CEC Control FPP lifecycle hooks
#
# FPP calls this script with $1 = hook name:
#   pluginStart — FPP has finished booting
#   pluginStop  — FPP is shutting down
#   getLinks    — FPP is building the Content Setup navigation menu

PLUGIN_DIR="$(dirname "$0")"
CONFIG_FILE="/home/fpp/media/config/hdmi_cec.json"
LOG_FILE="/home/fpp/media/logs/HdmiCec.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [callbacks] $*" >> "$LOG_FILE"; }

read_cfg() {
    # $1 = key, $2 = default
    python3 -c "
import json, sys
try:
    cfg = json.load(open('${CONFIG_FILE}'))
    v = cfg.get('${1}')
    print('true' if v is True else ('false' if v is False else (v if v is not None else '${2}')))
except: print('${2}')
" 2>/dev/null || echo "${2}"
}

case "${1:-}" in

    pluginStart)
        mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
        log "pluginStart"

        ENABLED=$(read_cfg "enabled" "true")
        [[ "$ENABLED" != "true" ]] && { log "Plugin disabled — skipping"; exit 0; }

        AUTO_ON=$(read_cfg "auto_on_start" "false")
        if [[ "$AUTO_ON" == "true" ]]; then
            log "auto_on_start: sending TV On in 15 s (waiting for HDMI to negotiate)"
            (sleep 15 && "${PLUGIN_DIR}/commands/cec_tv_on.sh") &
        fi
        ;;

    pluginStop)
        log "pluginStop"

        ENABLED=$(read_cfg "enabled" "true")
        [[ "$ENABLED" != "true" ]] && exit 0

        AUTO_OFF=$(read_cfg "auto_off_stop" "false")
        if [[ "$AUTO_OFF" == "true" ]]; then
            log "auto_off_stop: sending TV Standby"
            "${PLUGIN_DIR}/commands/cec_tv_standby.sh"
        fi
        ;;

    getLinks)
        cat <<'JSON'
[
  {
    "menu": "content",
    "text": "HDMI CEC Control",
    "url":  "/plugin.php?plugin=fpp-hdmi-cec&page=www/index.php",
    "icon": "fas fa-fw fa-tv"
  }
]
JSON
        ;;

    *)
        exit 0
        ;;
esac
