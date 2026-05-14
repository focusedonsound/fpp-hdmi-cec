<?php
// action.php — AJAX endpoint for CEC test commands, device scan, log tail, status check
ini_set('display_errors', '0');
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

$PLUGIN_DIR = dirname(__DIR__);
$LOG_FILE   = "/home/fpp/media/logs/HdmiCec.log";

function respond($ok, $msg, $extra = []) {
    echo json_encode(array_merge(["status" => $ok ? "OK" : "ERROR", "message" => $msg], $extra));
    exit;
}

$action = trim($_POST["action"] ?? $_GET["action"] ?? "");

// ── Install cec-utils via apt ─────────────────────────────────────────────
if ($action === "install_pkg") {
    // FPP's web server runs as root on most builds, so apt works directly.
    // Fall back to sudo if needed.
    $cmd    = "apt-get install -y --no-install-recommends cec-utils 2>&1";
    $output = shell_exec("sudo $cmd") ?: shell_exec($cmd) ?: "(no output)";
    $ok     = !empty(shell_exec("which cec-client 2>/dev/null"));
    if ($ok) {
        respond(true,  "cec-utils installed successfully. Reload the page to confirm.", ["output" => $output]);
    } else {
        respond(false, "apt-get ran but cec-client was not found — check output below.", ["output" => $output]);
    }
}

// ── Status / dependency check ──────────────────────────────────────────────
if ($action === "check") {
    $cecInstalled = !empty(shell_exec("which cec-client 2>/dev/null"));

    // Look for CEC adapters
    $adapters = [];
    $devs = glob("/dev/cec*") ?: [];
    foreach ($devs as $d) $adapters[] = $d;

    // Also try cec-client -l (only if installed)
    $adapterList = "";
    if ($cecInstalled) {
        $adapterList = shell_exec("timeout 5 cec-client -l 2>/dev/null") ?: "";
    }

    respond(true, "ok", [
        "cec_installed" => $cecInstalled,
        "adapters"      => $adapters,
        "adapter_info"  => trim($adapterList),
    ]);
}

// ── Run a named test command ───────────────────────────────────────────────
if ($action === "command") {
    $cmd = trim($_POST["cmd"] ?? "");
    $map = [
        "on"       => "cec_tv_on.sh",
        "standby"  => "cec_tv_standby.sh",
        "active"   => "cec_active_source.sh",
        "inactive" => "cec_inactive_source.sh",
        "volup"    => "cec_volume_up.sh",
        "voldown"  => "cec_volume_down.sh",
        "mute"     => "cec_mute.sh",
    ];
    if (!isset($map[$cmd])) respond(false, "Unknown command: $cmd");

    $script = $PLUGIN_DIR . "/commands/" . $map[$cmd];
    if (!file_exists($script)) respond(false, "Script not found: " . $map[$cmd]);

    $output = shell_exec("bash " . escapeshellarg($script) . " 2>&1");
    $lines  = array_slice(file($LOG_FILE) ?: [], -5);
    respond(true, "Command sent.", ["log_tail" => implode("", $lines)]);
}

// ── Run raw command ────────────────────────────────────────────────────────
if ($action === "raw") {
    $raw = trim($_POST["raw_cmd"] ?? "");
    if ($raw === "") respond(false, "No command specified.");

    $script = $PLUGIN_DIR . "/scripts/cec_command.sh";
    if (!file_exists($script)) respond(false, "Core script not found.");

    shell_exec("bash " . escapeshellarg($script) . " " . escapeshellarg($raw) . " 2>&1");
    $lines = array_slice(file($LOG_FILE) ?: [], -5);
    respond(true, "Raw command sent.", ["log_tail" => implode("", $lines)]);
}

// ── Test vcgencmd / display power ─────────────────────────────────────────
if ($action === "vcgencmd_test") {
    $cmd = trim($_POST["vcmd"] ?? "");
    if (!in_array($cmd, ["on", "off", "status"])) respond(false, "Unknown action: $cmd");

    if ($cmd === "status") {
        $lines = [];

        // vcgencmd
        $vcg = shell_exec("vcgencmd display_power 2>&1") ?: "(not available)";
        $lines[] = "vcgencmd display_power: " . trim($vcg);

        // tvservice
        $tvs = shell_exec("tvservice -s 2>&1") ?: "(not available)";
        $lines[] = "tvservice -s: " . trim($tvs);

        // ALL DRM connectors (not just HDMI-A) so we can see what's there
        $lines[] = "";
        $lines[] = "=== DRM connectors in /sys/class/drm/ ===";
        $allDrm = glob("/sys/class/drm/card*-*/status") ?: [];
        if (empty($allDrm)) {
            $lines[] = "(none found)";
        } else {
            foreach ($allDrm as $f) {
                $name    = basename(dirname($f));
                $status  = trim(@file_get_contents($f) ?: "?");
                $dpmsF   = dirname($f) . "/dpms";
                $dpms    = file_exists($dpmsF) ? trim(@file_get_contents($dpmsF) ?: "?") : "N/A";
                $writable = is_writable($dpmsF) ? "writable" : "read-only";
                $lines[] = "  $name: status=$status  dpms=$dpms ($writable)";
            }
        }

        // X11 / xrandr
        $lines[] = "";
        $lines[] = "=== X11 / xrandr ===";
        foreach ([":0", ":0.0"] as $d) {
            $xr = shell_exec("DISPLAY=$d xrandr --query 2>&1 | head -5") ?: "";
            if ($xr) { $lines[] = "DISPLAY=$d: " . trim($xr); break; }
        }

        // Kernel / driver info
        $lines[] = "";
        $lines[] = "=== Driver info ===";
        $lines[] = trim(shell_exec("cat /proc/device-tree/model 2>/dev/null || echo 'unknown Pi model'") ?: "");
        $lines[] = trim(shell_exec("grep -E 'dtoverlay|vc4' /boot/firmware/config.txt /boot/config.txt 2>/dev/null | head -5") ?: "(no vc4 overlay found)");

        respond(true, "Status checked.", ["output" => implode("\n", $lines)]);
    }

    // on / off — run display_power.sh and tail the log for results
    $script = $PLUGIN_DIR . "/scripts/display_power.sh";
    if (!file_exists($script)) respond(false, "display_power.sh not found.");

    shell_exec("bash " . escapeshellarg($script) . " " . escapeshellarg($cmd) . " 2>&1");

    // Read last few log lines to show which method was used
    $lines = array_slice(file($LOG_FILE) ?: [], -8);
    $logStr = implode("", $lines);

    // Determine success from log
    $ok = strpos($logStr, "succeeded") !== false || strpos($logStr, "complete") !== false;
    respond($ok,
        $ok ? "Display $cmd sent." : "Display $cmd ran but all methods may have failed — check log.",
        ["log_tail" => $logStr]
    );
}

// ── Device scan ────────────────────────────────────────────────────────────
if ($action === "scan") {
    if (empty(shell_exec("which cec-client 2>/dev/null"))) {
        respond(false, "cec-client is not installed. Run: sudo apt install cec-utils");
    }
    $output = shell_exec("timeout 15 bash -c \"echo 'scan' | cec-client -s -d 1\" 2>&1") ?: "(no output)";
    respond(true, "Scan complete.", ["output" => trim($output)]);
}

// ── Log tail ───────────────────────────────────────────────────────────────
if ($action === "logtail") {
    $n = max(20, min(200, (int)($_GET["lines"] ?? 60)));
    if (!file_exists($LOG_FILE)) {
        respond(true, "ok", ["ok" => true, "lines" => [], "note" => "Log file not yet created."]);
    }
    $lines = array_slice(file($LOG_FILE, FILE_IGNORE_NEW_LINES) ?: [], -$n);
    respond(true, "ok", ["ok" => true, "lines" => $lines]);
}

// ── Register / remove FPP Command Presets ─────────────────────────────────
if ($action === "add_presets" || $action === "remove_presets") {
    $presetsFile = "/home/fpp/media/config/command_presets.json";

    // The full set of CEC presets this plugin manages
    $cecPresets = [
        ["name" => "CEC - TV On",              "command" => "CEC - TV On",              "args" => [], "multisyncCommand" => false, "multisyncHosts" => ""],
        ["name" => "CEC - TV Standby",          "command" => "CEC - TV Standby",          "args" => [], "multisyncCommand" => false, "multisyncHosts" => ""],
        ["name" => "CEC - Set Active Source",   "command" => "CEC - Set Active Source",   "args" => [], "multisyncCommand" => false, "multisyncHosts" => ""],
        ["name" => "CEC - Set Inactive Source", "command" => "CEC - Set Inactive Source", "args" => [], "multisyncCommand" => false, "multisyncHosts" => ""],
        ["name" => "CEC - Volume Up",           "command" => "CEC - Volume Up",           "args" => [], "multisyncCommand" => false, "multisyncHosts" => ""],
        ["name" => "CEC - Volume Down",         "command" => "CEC - Volume Down",         "args" => [], "multisyncCommand" => false, "multisyncHosts" => ""],
        ["name" => "CEC - Mute Toggle",         "command" => "CEC - Mute Toggle",         "args" => [], "multisyncCommand" => false, "multisyncHosts" => ""],
        ["name" => "vcgencmd - Display On",     "command" => "vcgencmd - Display On",     "args" => [], "multisyncCommand" => false, "multisyncHosts" => ""],
        ["name" => "vcgencmd - Display Off",    "command" => "vcgencmd - Display Off",    "args" => [], "multisyncCommand" => false, "multisyncHosts" => ""],
    ];
    $cecNames = array_column($cecPresets, "name");

    // Load existing presets
    $existing = [];
    if (file_exists($presetsFile)) {
        $j = @json_decode(file_get_contents($presetsFile), true);
        if (is_array($j)) $existing = $j;
    }

    if ($action === "add_presets") {
        // Remove any stale CEC entries, then append fresh ones
        $existing = array_values(array_filter($existing, fn($p) => !in_array($p["name"] ?? "", $cecNames)));
        $existing = array_merge($existing, $cecPresets);
        $msg = count($cecPresets) . " CEC command presets added. They are now available in FPP\'s Command Presets picker.";
    } else {
        // remove_presets — strip all CEC entries
        $existing = array_values(array_filter($existing, fn($p) => !in_array($p["name"] ?? "", $cecNames)));
        $msg = "CEC command presets removed from FPP.";
    }

    $dir = dirname($presetsFile);
    if (!is_dir($dir)) @mkdir($dir, 0755, true);

    $tmp  = $presetsFile . ".tmp";
    $data = json_encode(array_values($existing), JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";
    if (@file_put_contents($tmp, $data) === false) respond(false, "Failed to write presets file.");
    if (!@rename($tmp, $presetsFile)) { @unlink($tmp); respond(false, "Failed to save presets file."); }

    respond(true, $msg, ["preset_count" => count($existing)]);
}

// ── Check preset registration status ──────────────────────────────────────
if ($action === "preset_status") {
    $presetsFile = "/home/fpp/media/config/command_presets.json";
    $existing = [];
    if (file_exists($presetsFile)) {
        $j = @json_decode(file_get_contents($presetsFile), true);
        if (is_array($j)) $existing = $j;
    }
    $names    = array_column($existing, "name");
    $registered = in_array("CEC - TV On", $names);
    respond(true, "ok", ["registered" => $registered, "total_presets" => count($existing)]);
}

respond(false, "Unknown action: $action");
