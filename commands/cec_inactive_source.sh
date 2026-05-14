#!/bin/bash
# CEC - Set Inactive Source
PLUGIN_DIR="$(dirname "$(dirname "$0")")"
exec "${PLUGIN_DIR}/scripts/cec_command.sh" "is"
