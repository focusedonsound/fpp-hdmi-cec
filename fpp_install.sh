#!/bin/bash
set -euo pipefail
# fpp_install.sh — HDMI CEC Control plugin installer
# Called by FPP when the plugin is installed or updated.

PLUGIN_DIR="$(dirname "$0")"

# Resolve FPP's logs directory the documented way (supports a relocated
# media directory) rather than hard-coding /home/fpp/media/logs, and use
# FPP's single conformant log file (plugin-<repoName>.log).
: "${FPPDIR:=/opt/fpp}"
# common isn't written to be `set -u`-safe (e.g. it references
# $LD_LIBRARY_PATH with no default, which is unset in some environments) --
# relax -u just for sourcing it, not for the rest of this script.
set +u
. "${FPPDIR}/scripts/common" 2>/dev/null || true
set -u
LOGDIR="$(getSetting logDirectory 2>/dev/null || true)"
LOGDIR="${LOGDIR:-/home/fpp/media/logs}"
LOGFILE="${LOGDIR}/plugin-fpp-hdmi-cec.log"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    mkdir -p "$LOGDIR" 2>/dev/null || true
    echo "$msg" >> "$LOGFILE" 2>/dev/null || echo "$msg"
}

log "=== HDMI CEC Control install started (user=$(whoami), uid=$(id -u)) ==="

# ── Require root ──────────────────────────────────────────────────
# FPP's Plugin Manager always runs this as root; install scripts don't
# need to re-exec themselves with elevated privileges (that hides the
# assumption rather than stating it). If running this by hand, become
# root first.
if [[ "$(id -u)" -ne 0 ]]; then
    log "ERROR: fpp_install.sh must be run as root."
    exit 1
fi

# ── Create media directories ─────────────────────────────────────
# (log() already mkdir -p's $LOGDIR on every call)
mkdir -p /home/fpp/media/config

# ── Install packages ─────────────────────────────────────────────
log "Updating package lists..."
apt-get update -qq >> "$LOGFILE" 2>&1 || true

# pluginInfo.json's dependencies.packages block declares cec-utils and
# ddcutil, but FPP 9 silently ignores that block entirely, so it's not
# enough on its own. Always install here by hand so both FPP 9 and FPP 10
# end up with the packages regardless of whether the JSON block was
# honored (re-installing an already-installed package via apt is a no-op).
log "Installing cec-utils..."
if apt-get install -y --no-install-recommends cec-utils >> "$LOGFILE" 2>&1; then
    log "cec-utils installed OK"
else
    log "WARN: cec-utils install failed (non-fatal — only needed for HDMI CEC TVs)"
fi

log "Installing ddcutil (DDC/CI monitor control for PC monitors)..."
if apt-get install -y --no-install-recommends ddcutil >> "$LOGFILE" 2>&1; then
    log "ddcutil installed OK"
else
    log "WARN: ddcutil install failed (non-fatal — only needed for DDC/CI PC monitors)"
fi

# kms++-utils (kmsblank -- KMS display blanking) is Raspberry Pi OS-specific
# and doesn't exist as a package on generic Debian/Ubuntu at all, so it's
# deliberately NOT in pluginInfo.json's dependencies -- declaring it there
# makes FPP treat it as a hard requirement and abort the whole plugin install
# on any non-Pi-OS platform where it's unavailable. Always attempt it here
# instead, best-effort, so its absence only disables KMS blanking specifically.
log "Installing kms++-utils (kmsblank — KMS display blanking for Pi OS Bookworm)..."
if apt-get install -y --no-install-recommends kms++-utils >> "$LOGFILE" 2>&1; then
    log "kms++-utils installed OK"
else
    log "WARN: kms++-utils not available on this platform (non-fatal — only needed for KMS display blanking on Pi OS Bookworm)"
fi

if command -v ddcutil >/dev/null 2>&1; then
    # ddcutil needs i2c-dev kernel module
    modprobe i2c-dev 2>/dev/null || true
    # Ensure fpp user is in i2c group for non-root access
    usermod -a -G i2c fpp 2>/dev/null || true
fi

# Verify installation
if command -v cec-client >/dev/null 2>&1; then
    VER=$(cec-client --version 2>/dev/null | head -1 || echo "unknown version")
    log "cec-client found: $VER"
else
    log "WARN: cec-client not found after install — check apt-get output above"
fi

# ── Make scripts executable ──────────────────────────────────────
log "Setting script permissions..."
chmod +x "${PLUGIN_DIR}/callbacks.sh"             2>/dev/null || true
chmod +x "${PLUGIN_DIR}/scripts/"*.sh             2>/dev/null || true
chmod +x "${PLUGIN_DIR}/commands/"*.sh            2>/dev/null || true

# ── Write default config if none exists ─────────────────────────
CONFIG="/home/fpp/media/config/hdmi_cec.json"
if [[ ! -f "$CONFIG" ]]; then
    log "Writing default config to $CONFIG"
    cat > "$CONFIG" <<'JSONEOF'
{
  "enabled": true,
  "adapter": "auto",
  "hdmi_port": 1,
  "device_address": 0,
  "auto_on_start": false,
  "auto_off_stop": false,
  "log_level": 1
}
JSONEOF
fi

setSetting restartFlag 1 2>/dev/null || true

log "=== HDMI CEC Control install complete ==="

# A little something for whoever's actually reading the install log. Only
# ever recommends a sibling plugin that isn't already sitting right next to
# this one, so it never suggests something you've clearly already got.
show_easter_egg() {
    local plugin_dir_abs
    plugin_dir_abs="$(cd "$PLUGIN_DIR" && pwd)"
    local plugins_root
    plugins_root="$(dirname "$plugin_dir_abs")"

    local siblings=(
        "fpp-tally|counts cars and crowd size passing your show"
        "fpp-EncoreRadio|keeps the radio-station vibe going after the show ends"
        "fpp-sled-mailbox|a smart Letters-to-Santa mailbox with visitor detection"
        "fpp-AnnouncementAssistant|one-tap announcements ducked over your show audio"
    )
    local jokes=(
        "I told my TV to turn itself off. It said, 'That's not my input.'"
        "Why don't TVs ever get invited to parties? Too much drama on every channel."
        "My remote and I are inseparable. We're always on the same channel."
        "Why did the HDMI cable break up with the VGA cable? It needed someone more high-definition."
    )

    local candidates=()
    local entry repo blurb
    for entry in "${siblings[@]}"; do
        repo="${entry%%|*}"
        [ -d "${plugins_root}/${repo}" ] || candidates+=("$entry")
    done

    echo
    echo "🏆 ACHIEVEMENT UNLOCKED"
    echo "════════════════════════════════════════"
    echo "📺  fpp-hdmi-cec installed / updated"
    echo
    echo "  \"${jokes[$((RANDOM % ${#jokes[@]}))]}\""
    echo
    if [ ${#candidates[@]} -gt 0 ]; then
        entry="${candidates[$((RANDOM % ${#candidates[@]}))]}"
        repo="${entry%%|*}"
        blurb="${entry#*|}"
        echo "🎁 Haven't tried ${repo} yet? ${blurb}"
        echo "   https://github.com/focusedonsound/${repo}"
    else
        echo "🎉 Looks like you've got the whole FocusedOnSound collection installed already!"
    fi
    echo
}
show_easter_egg

exit 0
