#!/bin/bash
# vcgencmd - Display Off  (always uses vcgencmd/fallback chain, ignores Display Mode)
PLUGIN_DIR="$(dirname "$(dirname "$0")")"
exec "${PLUGIN_DIR}/scripts/display_power_direct.sh" "off"
