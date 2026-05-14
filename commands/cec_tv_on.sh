#!/bin/bash
# CEC - TV On  (mode-aware: CEC or vcgencmd depending on Display Mode setting)
PLUGIN_DIR="$(dirname "$(dirname "$0")")"
exec "${PLUGIN_DIR}/scripts/display_power.sh" "on"
