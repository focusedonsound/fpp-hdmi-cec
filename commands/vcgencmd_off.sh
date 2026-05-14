#!/bin/bash
# vcgencmd - Display Off  (always uses vcgencmd regardless of Display Mode)
LOG_FILE="/home/fpp/media/logs/HdmiCec.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [vcgencmd] $*" >> "$LOG_FILE"; }
log "display_power 0"
vcgencmd display_power 0 >> "$LOG_FILE" 2>&1
