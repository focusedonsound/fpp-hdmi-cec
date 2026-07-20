#!/bin/bash
# fpp_uninstall.sh — HDMI CEC Control plugin uninstaller
# Called by FPP when the plugin is removed.
#
# fpp_install.sh creates nothing outside the plugin directory except the
# declared apt packages (cec-utils, kms++-utils, ddcutil) and adding the fpp
# user to the i2c group. FPP ref-counts and removes the declared packages
# itself, and removing fpp from the i2c group isn't safe here -- another
# plugin or the user's own tooling may still depend on it. Nothing to undo.

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "=== HDMI CEC Control uninstall: nothing outside the plugin directory to remove ==="
exit 0
