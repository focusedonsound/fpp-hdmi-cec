#!/bin/bash
# CEC - TV On
PLUGIN_DIR="$(dirname "$(dirname "$0")")"
exec "${PLUGIN_DIR}/scripts/cec_command.sh" "on 0"
