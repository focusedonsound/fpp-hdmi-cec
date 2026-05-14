<?php
ini_set('display_errors', '0');
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

$configFile = "/home/fpp/media/config/hdmi_cec.json";

function respond($ok, $msg) {
    echo json_encode(["status" => $ok ? "OK" : "ERROR", "message" => $msg]);
    exit;
}

$dir = dirname($configFile);
if (!is_dir($dir))      respond(false, "Config directory missing: $dir");
if (!is_writable($dir)) respond(false, "Config directory not writable");

// Load existing config
$cfg = [];
if (file_exists($configFile)) {
    $j = @json_decode(file_get_contents($configFile), true);
    if (is_array($j)) $cfg = $j;
}

$cfg["enabled"]        = isset($_POST["enabled"])        && $_POST["enabled"]        === "1";
$cfg["auto_on_start"]  = isset($_POST["auto_on_start"])  && $_POST["auto_on_start"]  === "1";
$cfg["auto_off_stop"]  = isset($_POST["auto_off_stop"])  && $_POST["auto_off_stop"]  === "1";

$adapter = trim($_POST["adapter"] ?? "auto");
$cfg["adapter"] = ($adapter !== "") ? $adapter : "auto";

$port = (int)(trim($_POST["hdmi_port"] ?? "1") ?: 1);
$cfg["hdmi_port"] = max(1, min(4, $port));

$addr = trim($_POST["device_address"] ?? "0");
$cfg["device_address"] = is_numeric($addr) ? (int)$addr : 0;

$ll = (int)(trim($_POST["log_level"] ?? "1") ?: 1);
$cfg["log_level"] = max(0, min(8, $ll));

// Atomic write
$tmp  = $configFile . ".tmp";
$data = json_encode($cfg, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";
if (@file_put_contents($tmp, $data) === false) respond(false, "Failed to write temp file");
if (!@rename($tmp, $configFile)) { @unlink($tmp); respond(false, "Failed to write config"); }

respond(true, "Settings saved.");
