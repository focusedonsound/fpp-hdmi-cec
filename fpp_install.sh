#!/bin/bash
# fpp_install.sh — HDMI CEC Control plugin installer
# Called by FPP when the plugin is installed or updated.

PLUGIN_DIR="$(dirname "$0")"
LOGFILE="/tmp/HdmiCec_install.log"
MEDIA_LOG="/home/fpp/media/logs/HdmiCec_install.log"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" | tee -a "$LOGFILE"
    echo "$msg" >> "$MEDIA_LOG" 2>/dev/null || true
}

log "=== HDMI CEC Control install started (user=$(whoami), uid=$(id -u)) ==="

# ── Create media directories ─────────────────────────────────────
mkdir -p /home/fpp/media/logs
mkdir -p /home/fpp/media/config
cat "$LOGFILE" >> "$MEDIA_LOG" 2>/dev/null || true

# ── Install cec-utils ────────────────────────────────────────────
log "Installing cec-utils..."
if apt-get install -y --no-install-recommends cec-utils >> "$LOGFILE" 2>&1; then
    log "cec-utils installed OK"
else
    log "WARN: apt-get failed — cec-utils may not be installed"
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

log "=== HDMI CEC Control install complete ==="
exit 0
