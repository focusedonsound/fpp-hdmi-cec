#!/bin/bash
# CEC - Send Raw Command  ($1 = command string from FPP)
PLUGIN_DIR="$(dirname "$(dirname "$0")")"
exec "${PLUGIN_DIR}/scripts/cec_command.sh" "${1:-}"
