#!/bin/bash
# cec_command.sh — Core CEC command runner
# Usage: cec_command.sh <cec-client command string>
#
# All command scripts in commands/ delegate to this script.
# Reads adapter/log-level from /home/fpp/media/config/hdmi_cec.json.

CONFIG_FILE="/home/fpp/media/config/hdmi_cec.json"
LOG_FILE="/home/fpp/media/logs/HdmiCec.log"

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [cec] $*" >> "$LOG_FILE"; }

COMMAND="${1:-}"
if [[ -z "$COMMAND" ]]; then
    log "ERROR: no command specified"
    exit 1
fi

# ── Sanity checks ────────────────────────────────────────────────
if ! command -v cec-client >/dev/null 2>&1; then
    log "ERROR: cec-client not found — run: sudo apt install cec-utils"
    exit 1
fi

# Check plugin is enabled
ENABLED=$(python3 -c "
import json
try:
    cfg = json.load(open('${CONFIG_FILE}'))
    print('true' if cfg.get('enabled', True) else 'false')
except: print('true')
" 2>/dev/null || echo "true")

if [[ "$ENABLED" != "true" ]]; then
    log "Plugin disabled — skipping command: ${COMMAND}"
    exit 0
fi

# ── Read config ──────────────────────────────────────────────────
ADAPTER=$(python3 -c "
import json
try:
    cfg = json.load(open('${CONFIG_FILE}'))
    a = cfg.get('adapter', 'auto')
    print('' if a in ('auto', '') else a)
except: print('')
" 2>/dev/null || echo "")

LOG_LEVEL=$(python3 -c "
import json
try:
    cfg = json.load(open('${CONFIG_FILE}'))
    print(int(cfg.get('log_level', 1)))
except: print(1)
" 2>/dev/null || echo "1")

# ── Run command (10 s timeout to prevent hanging) ────────────────
log "Sending: ${COMMAND}"

if [[ -n "$ADAPTER" ]]; then
    OUTPUT=$(timeout 10 bash -c "echo '${COMMAND}' | cec-client -s -d ${LOG_LEVEL} '${ADAPTER}'" 2>&1)
else
    OUTPUT=$(timeout 10 bash -c "echo '${COMMAND}' | cec-client -s -d ${LOG_LEVEL}" 2>&1)
fi
STATUS=$?

if [[ $STATUS -eq 124 ]]; then
    log "ERROR: cec-client timed out (10 s) — is a CEC adapter connected?"
    exit 1
elif [[ $STATUS -ne 0 ]]; then
    log "ERROR: cec-client exited $STATUS for: ${COMMAND}"
    log "Output: ${OUTPUT}"
    exit 1
fi

log "OK: ${COMMAND}"
exit 0
