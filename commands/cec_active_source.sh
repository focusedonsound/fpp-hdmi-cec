#!/bin/bash
# CEC - Set Active Source
PLUGIN_DIR="$(dirname "$(dirname "$0")")"
exec "${PLUGIN_DIR}/scripts/cec_command.sh" "as"
