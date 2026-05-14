#!/bin/bash
# CEC - Mute Toggle
PLUGIN_DIR="$(dirname "$(dirname "$0")")"
exec "${PLUGIN_DIR}/scripts/cec_command.sh" "mute"
