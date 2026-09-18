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

# cowsay-style speech bubble that word-wraps to fit whatever text it's
# given, rather than a fixed-width box hand-tuned per joke. Never mix a
# literal backslash into a printf FORMAT string here -- pass it as %s data
# instead (see the bs='\' variable below); a backslash sitting next to \n
# in a format string is ambiguous across shells and silently prints "\n"
# literally instead of a newline on at least one of them.
render_speech_bubble() {
    local text="$1" maxwidth=44 bs='\'
    local -a lines=()
    local line=""
    for word in $text; do
        if [ -z "$line" ]; then
            line="$word"
        elif [ $((${#line} + 1 + ${#word})) -le "$maxwidth" ]; then
            line="$line $word"
        else
            lines+=("$line")
            line="$word"
        fi
    done
    [ -n "$line" ] && lines+=("$line")

    local width=0 l
    for l in "${lines[@]}"; do
        [ ${#l} -gt "$width" ] && width=${#l}
    done

    local top bot padded n=${#lines[@]}
    top=$(printf '%*s' "$((width + 2))" '' | tr ' ' '_')
    bot=$(printf '%*s' "$((width + 2))" '' | tr ' ' '-')
    printf '%s\n' " ${top}"
    if [ "$n" -eq 1 ]; then
        padded=$(printf '%-*s' "$width" "${lines[0]}")
        printf '%s\n' "< ${padded} >"
    else
        local i
        for i in "${!lines[@]}"; do
            padded=$(printf '%-*s' "$width" "${lines[$i]}")
            if [ "$i" -eq 0 ]; then
                printf '%s\n' "/ ${padded} ${bs}"
            elif [ "$i" -eq $((n - 1)) ]; then
                printf '%s\n' "${bs} ${padded} /"
            else
                printf '%s\n' "| ${padded} |"
            fi
        done
    fi
    printf '%s\n' " ${bot}"
}

# A little something for whoever's actually reading the install log. Only
# ever recommends a sibling plugin that isn't already sitting right next to
# this one, so it never suggests something you've clearly already got. A
# 1-in-7 roll swaps the everyday joke pool for a separate "rare drop" pool
# with its own art framing, instead of just re-skinning the same box.
_show_easter_egg_render() {
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
        "Why did the TV break up with the remote? It said their relationship had too many buttons to push."
        "I told my television a joke about lag. It's still buffering."
        "My remote ran away from home. Police say it's a clear case of button abandonment."
        "Why is the TV always so calm? It's got great remote control."
    )
    local rare_jokes=(
        "Legend says one CEC install in seven secretly dreams of controlling the neighbor's TV too."
        "Rare stat unlocked: this remote's batteries will outlive us all."
        "You've found the one HDMI cable that's never once come loose. Cherish it."
    )

    local candidates=()
    local entry repo blurb
    for entry in "${siblings[@]}"; do
        repo="${entry%%|*}"
        [ -d "${plugins_root}/${repo}" ] || candidates+=("$entry")
    done

    local wordmark mascot
    wordmark=$(cat <<'WORDMARK'
.####..#####...####..
#......#......#......
#......####...#......
#......#......#......
.####..#####...####..
WORDMARK
)
    mascot=$(cat <<'MASCOT'
        \   /
         \ /
      .-'''''-.
     /  ~~~~~~~\
    |  ~~~~~~~~ |
     \_________/
        |   |
       _|___|_
MASCOT
)

    local is_rare=0
    [ $((RANDOM % 7)) -eq 0 ] && is_rare=1

    echo
    echo "$wordmark"
    echo
    if [ "$is_rare" -eq 1 ]; then
        echo "  *** RARE DROP (1-in-7) — fpp-hdmi-cec ***"
        echo
        render_speech_bubble "${rare_jokes[$((RANDOM % ${#rare_jokes[@]}))]}"
    else
        echo "  🏆 ACHIEVEMENT UNLOCKED — fpp-hdmi-cec installed & ready to roll"
        echo
        render_speech_bubble "${jokes[$((RANDOM % ${#jokes[@]}))]}"
    fi
    echo "$mascot"
    echo

    if [ "$is_rare" -eq 0 ]; then
        local stars=$((3 + RANDOM % 3)) s rating=""
        for ((s = 0; s < 5; s++)); do
            if [ "$s" -lt "$stars" ]; then rating="${rating}★"; else rating="${rating}☆"; fi
        done
        echo "  dad-joke rating: ${rating}  (${stars}/5 groans)"
        echo
    fi

    echo "  ----------------------------------------"
    if [ ${#candidates[@]} -gt 0 ]; then
        entry="${candidates[$((RANDOM % ${#candidates[@]}))]}"
        repo="${entry%%|*}"
        blurb="${entry#*|}"
        echo "  🎁 NEXT UP: ${repo}"
        echo "     ${blurb}"
        echo "     https://github.com/focusedonsound/${repo}"
    else
        echo "  🎉 FULL COLLECTION UNLOCKED — every FocusedOnSound plugin, right here."
    fi
    echo "  ----------------------------------------"
    echo
}

# pluginsProgressPopupText (the "Upgrade Plugin" dialog) is a <div>, not a
# real <textarea>/<pre> -- FPP core's StreamURL() inserts our output via
# innerHTML with only \n -> <br> conversion (see www/js/fpp.js), so normal
# HTML whitespace collapsing squashes every run of spaces down to one,
# wrecking any column-aligned ASCII art. A non-breaking space (U+00A0) is
# never collapsed, so render everything normally and swap plain spaces for
# nbsp right before printing, rather than trying to build every line out of
# nbsp by hand.
show_easter_egg() {
    _show_easter_egg_render | sed 's/ /\xc2\xa0/g'
}
show_easter_egg

exit 0
