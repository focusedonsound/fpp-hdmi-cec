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

respond(false, "Unknown action: $action");
