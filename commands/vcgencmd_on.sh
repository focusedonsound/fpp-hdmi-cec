#!/bin/bash
# vcgencmd - Display On  (always uses vcgencmd/fallback chain, ignores Display Mode)
PLUGIN_DIR="$(dirname "$(dirname "$0")")"
exec "${PLUGIN_DIR}/scripts/display_power_direct.sh" "on"
