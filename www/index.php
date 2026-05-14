<?php
$configFile = "/home/fpp/media/config/hdmi_cec.json";

function defaultCfg() {
    return [
        "enabled"        => true,
        "adapter"        => "auto",
        "hdmi_port"      => 1,
        "device_address" => 0,
        "auto_on_start"  => false,
        "auto_off_stop"  => false,
        "log_level"      => 1,
    ];
}

$cfg = defaultCfg();
if (file_exists($configFile)) {
    $j = @json_decode(file_get_contents($configFile), true);
    if (is_array($j)) $cfg = array_replace($cfg, $j);
}

// Detect CEC adapters available on this machine
$detectedAdapters = glob('/dev/cec*') ?: [];

// Is cec-utils installed?
$cecInstalled = !empty(shell_exec('which cec-client 2>/dev/null'));

function e($v) { return htmlspecialchars((string)$v, ENT_QUOTES, 'UTF-8'); }
?>
<style>
/* ── HDMI CEC plugin — explicit colours for FPP 9.x / 10.x compatibility ── */
.cec-btn {
  display: inline-flex;
  align-items: center;
  gap: .3rem;
  padding: .35rem .8rem;
  font-size: .875rem;
  font-weight: 500;
  line-height: 1.5;
  text-align: center;
  white-space: nowrap;
  cursor: pointer;
  border: 1px solid #3a7fc1;
  border-radius: .3rem;
  text-decoration: none !important;
  background-color: #1a6eb5;
  color: #fff !important;
  transition: background-color .15s, border-color .15s;
  vertical-align: middle;
}
.cec-btn:hover, .cec-btn:focus {
  background-color: #155a94;
  border-color: #0e4370;
  color: #fff !important;
  text-decoration: none !important;
}
.cec-btn:disabled, .cec-btn.disabled {
  opacity: .55;
  cursor: not-allowed;
  pointer-events: none;
}
.cec-btn-sm {
  padding: .2rem .5rem;
  font-size: .8rem;
  border-radius: .25rem;
}
.cec-btn-danger {
  background-color: #b02a37;
  border-color: #842029;
}
.cec-btn-danger:hover {
  background-color: #842029;
  border-color: #6a1a20;
}
#cecDepBanner {
  background-color: #fff3cd !important;
  border: 1px solid #e6a817 !important;
  color: #5a3e05 !important;
  border-radius: .35rem;
}
#cecDepBanner code {
  background-color: #ffe69c;
  padding: .1rem .35rem;
  border-radius: .2rem;
  color: #3d2600 !important;
  font-size: .85em;
}
</style>

<!-- ── Page header ─────────────────────────────────────────────────────── -->
<div class="d-flex justify-content-between align-items-center mb-2 flex-wrap gap-2">
  <h2 class="mb-0">
    <i class="fas fa-fw fa-tv"></i> HDMI CEC Control
  </h2>
  <span id="cecStatusPill" style="
      display:inline-flex; align-items:center; gap:.3rem;
      padding:.25rem .65rem; border-radius:999px; font-size:.8rem; font-weight:600;
      background-color:<?php echo $cecInstalled ? '#198754' : '#dc3545'; ?>;
      color:#fff; white-space:nowrap;">
    <i class="fas fa-fw fa-circle fa-xs"></i>
    <span id="cecStatusText"><?php echo $cecInstalled ? 'cec-utils Installed' : 'cec-utils Missing'; ?></span>
  </span>
</div>

<p class="text-muted mb-3">
  Control your TV or monitor via HDMI CEC — power on/off, input switching, and volume.
  Commands can be triggered from FPP <strong>playlists</strong>, <strong>schedules</strong>,
  and <strong>GPIO inputs</strong>.
</p>

<!-- ── Dependency banner ──────────────────────────────────────────────── -->
<?php if (!$cecInstalled): ?>
<div id="cecDepBanner" class="alert mb-3" role="alert">
  <strong><i class="fas fa-fw fa-triangle-exclamation"></i> cec-utils not installed</strong>
  <div class="mt-1 small">
    SSH into your FPP device and run:<br>
    <code class="user-select-all">sudo apt install cec-utils</code><br>
    Then reload this page. Alternatively, reinstall this plugin — the install script runs apt automatically.
  </div>
</div>
<?php endif; ?>

<form id="cecForm" onsubmit="return false;">

  <!-- ── Settings ───────────────────────────────────────────────────────── -->
  <div class="fppTableWrapper fppTableWrapperAsTable mb-3">
    <div class="fppTableContents">
      <table class="fppSelectableRowTable" style="width:100%;">
        <thead>
          <tr>
            <th colspan="4" style="padding:8px;">
              <i class="fas fa-fw fa-sliders"></i> Settings
            </th>
          </tr>
        </thead>
        <tbody>

          <!-- Enable -->
          <tr>
            <td style="width:220px; padding:8px;">
              <label class="mb-0"><strong>Enable Plugin</strong></label>
              <div class="text-muted small">Master on/off for all CEC commands</div>
            </td>
            <td colspan="3" style="padding:8px;">
              <div class="form-check form-switch">
                <input class="form-check-input" type="checkbox" name="enabled"
                       id="cecEnabled" value="1"
                       <?php echo !empty($cfg['enabled']) ? 'checked' : ''; ?> />
              </div>
            </td>
          </tr>

          <!-- Auto on/off -->
          <tr>
            <td style="padding:8px;">
              <label class="mb-0"><i class="fas fa-fw fa-power-off"></i> TV On at FPP Start</label>
              <div class="text-muted small">Send CEC On when FPP boots (15 s delay)</div>
            </td>
            <td style="width:80px; padding:8px;">
              <div class="form-check form-switch">
                <input class="form-check-input" type="checkbox" name="auto_on_start"
                       id="autoOnStart" value="1"
                       <?php echo !empty($cfg['auto_on_start']) ? 'checked' : ''; ?> />
              </div>
            </td>
            <td style="width:220px; padding:8px;">
              <label class="mb-0"><i class="fas fa-fw fa-moon"></i> TV Standby at FPP Stop</label>
              <div class="text-muted small">Send CEC Standby when FPP shuts down</div>
            </td>
            <td style="padding:8px;">
              <div class="form-check form-switch">
                <input class="form-check-input" type="checkbox" name="auto_off_stop"
                       id="autoOffStop" value="1"
                       <?php echo !empty($cfg['auto_off_stop']) ? 'checked' : ''; ?> />
              </div>
            </td>
          </tr>

          <!-- Adapter -->
          <tr>
            <td style="padding:8px;">
              <label class="mb-0"><i class="fas fa-fw fa-plug"></i> CEC Adapter</label>
              <div class="text-muted small">Usually auto-detected on Raspberry Pi</div>
            </td>
            <td style="padding:8px;">
              <select name="adapter" class="form-control form-control-sm" style="max-width:200px;"
                      title="Leave on Auto unless you have multiple HDMI ports. On Raspberry Pi the CEC adapter is built into the HDMI port.">
                <option value="auto" <?php echo ($cfg['adapter'] === 'auto' || $cfg['adapter'] === '') ? 'selected' : ''; ?>>
                  Auto (recommended)
                </option>
                <?php
                $devs = $detectedAdapters;
                if (!in_array($cfg['adapter'], ['auto', '']) && !in_array($cfg['adapter'], $devs)) {
                    $devs[] = $cfg['adapter'];
                }
                foreach ($devs as $d): ?>
                <option value="<?php echo e($d); ?>" <?php echo ($cfg['adapter'] === $d) ? 'selected' : ''; ?>>
                  <?php echo e($d); ?>
                </option>
                <?php endforeach; ?>
              </select>
            </td>
            <td style="padding:8px;">
              <label class="mb-0"><i class="fas fa-fw fa-hashtag"></i> HDMI Port</label>
              <div class="text-muted small">Physical port number on TV (1–4)</div>
            </td>
            <td style="padding:8px;">
              <div class="input-group input-group-sm" style="max-width:120px;">
                <span class="input-group-text">HDMI</span>
                <input type="number" class="form-control form-control-sm" name="hdmi_port"
                       min="1" max="4" step="1"
                       value="<?php echo (int)($cfg['hdmi_port'] ?? 1); ?>" />
              </div>
            </td>
          </tr>

          <!-- CEC address + log level -->
          <tr>
            <td style="padding:8px;">
              <label class="mb-0"><i class="fas fa-fw fa-address-card"></i> TV CEC Address</label>
              <div class="text-muted small">0 = TV &nbsp;|&nbsp; 5 = Audio system</div>
            </td>
            <td style="padding:8px;">
              <div class="input-group input-group-sm" style="max-width:130px;">
                <input type="number" class="form-control form-control-sm" name="device_address"
                       min="0" max="14" step="1"
                       title="CEC logical address of the device to control. 0 = TV (most common), 5 = Audio/Receiver."
                       value="<?php echo (int)($cfg['device_address'] ?? 0); ?>" />
              </div>
            </td>
            <td style="padding:8px;">
              <label class="mb-0"><i class="fas fa-fw fa-list-ol"></i> Log Level
                <span style="cursor:help; color:var(--bs-info);"
                      title="cec-client verbosity. 1 = errors only (default). 8 = full debug (very verbose). Increase only when diagnosing issues.">
                  <i class="fas fa-circle-question fa-xs"></i>
                </span>
              </label>
              <div class="text-muted small">cec-client -d value (1–8)</div>
            </td>
            <td style="padding:8px;">
              <div class="input-group input-group-sm" style="max-width:130px;">
                <input type="number" class="form-control form-control-sm" name="log_level"
                       min="1" max="8" step="1"
                       value="<?php echo (int)($cfg['log_level'] ?? 1); ?>" />
              </div>
            </td>
          </tr>

        </tbody>
      </table>
    </div>
  </div>

  <!-- ── Test Commands ──────────────────────────────────────────────────── -->
  <div class="fppTableWrapper fppTableWrapperAsTable mb-3">
    <div class="fppTableContents">
      <table class="fppSelectableRowTable" style="width:100%;">
        <thead>
          <tr>
            <th colspan="2" style="padding:8px;">
              <i class="fas fa-fw fa-gamepad"></i> Test Commands
              <span class="text-muted fw-normal small ms-2">
                Send a CEC command right now — same as calling it from an FPP playlist
              </span>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td style="padding:12px;">
              <div class="d-flex flex-wrap gap-2">
                <button type="button" class="cec-btn" onclick="cecCmd('on')"
                        title="Power on the TV via CEC">
                  <i class="fas fa-fw fa-power-off"></i> TV On
                </button>
                <button type="button" class="cec-btn cec-btn-danger" onclick="cecCmd('standby')"
                        title="Put the TV into standby via CEC">
                  <i class="fas fa-fw fa-moon"></i> TV Standby
                </button>
                <button type="button" class="cec-btn" onclick="cecCmd('active')"
                        title="Tell TV to switch input to the Pi">
                  <i class="fas fa-fw fa-arrow-right-to-bracket"></i> Set Active Source
                </button>
                <button type="button" class="cec-btn" onclick="cecCmd('inactive')"
                        title="Tell TV the Pi is no longer the active source">
                  <i class="fas fa-fw fa-arrow-right-from-bracket"></i> Set Inactive Source
                </button>
                <button type="button" class="cec-btn" onclick="cecCmd('volup')"
                        title="Volume Up">
                  <i class="fas fa-fw fa-volume-high"></i> Vol Up
                </button>
                <button type="button" class="cec-btn" onclick="cecCmd('voldown')"
                        title="Volume Down">
                  <i class="fas fa-fw fa-volume-low"></i> Vol Down
                </button>
                <button type="button" class="cec-btn" onclick="cecCmd('mute')"
                        title="Mute / Unmute Toggle">
                  <i class="fas fa-fw fa-volume-xmark"></i> Mute
                </button>
              </div>
            </td>
          </tr>

          <!-- Raw command -->
          <tr>
            <td style="padding:8px;">
              <div class="d-flex gap-2 align-items-center">
                <span class="text-muted small" style="white-space:nowrap;">Raw command:</span>
                <input type="text" id="rawCmdInput" class="form-control form-control-sm"
                       placeholder="e.g. on 0 &nbsp;/&nbsp; standby 5 &nbsp;/&nbsp; as"
                       style="max-width:300px;" />
                <button type="button" class="cec-btn cec-btn-sm" onclick="cecRaw()"
                        title="Send a raw cec-client command string">
                  <i class="fas fa-fw fa-paper-plane"></i> Send
                </button>
              </div>
            </td>
          </tr>

          <!-- Command output -->
          <tr>
            <td style="padding:0;">
              <pre id="cecCmdOutput" style="display:none; margin:0; padding:10px;
                   font-size:.78rem; line-height:1.4; white-space:pre-wrap;
                   background:#1a1a1a; color:#d0d0d0; max-height:120px; overflow-y:auto;
                   border-radius:0 0 4px 4px;"></pre>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>

  <!-- ── Save button ────────────────────────────────────────────────────── -->
  <div class="d-flex flex-wrap gap-2 mb-3">
    <button type="button" class="cec-btn" onclick="cecSave()">
      <i class="fas fa-fw fa-save"></i> Save Settings
    </button>
    <button type="button" class="cec-btn" onclick="cecScan()">
      <i class="fas fa-fw fa-magnifying-glass"></i> Scan CEC Devices
    </button>
    <button type="button" class="cec-btn cec-btn-sm" onclick="cecShowLog()">
      <i class="fas fa-fw fa-terminal"></i> Show Log
    </button>
  </div>

</form>

<!-- ── Device Scan panel ──────────────────────────────────────────────── -->
<div class="fppTableWrapper fppTableWrapperAsTable mb-3" id="cecScanPanel" style="display:none;">
  <div class="fppTableContents">
    <table class="fppSelectableRowTable" style="width:100%;">
      <thead>
        <tr>
          <th style="padding:8px;">
            <div class="d-flex justify-content-between align-items-center">
              <span><i class="fas fa-fw fa-magnifying-glass"></i> CEC Device Scan</span>
              <button type="button" class="cec-btn cec-btn-sm"
                      onclick="document.getElementById('cecScanPanel').style.display='none'">
                <i class="fas fa-fw fa-xmark"></i> Close
              </button>
            </div>
          </th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td style="padding:0;">
            <pre id="cecScanOutput"
                 style="margin:0; padding:10px; max-height:320px; overflow-y:auto;
                        font-size:.78rem; line-height:1.4; white-space:pre-wrap;
                        background:#1a1a1a; color:#d0d0d0; border-radius:0 0 4px 4px;">
Scanning… this takes up to 15 seconds.</pre>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</div>

<!-- ── Log panel ──────────────────────────────────────────────────────── -->
<div class="fppTableWrapper fppTableWrapperAsTable mb-3" id="cecLogPanel" style="display:none;">
  <div class="fppTableContents">
    <table class="fppSelectableRowTable" style="width:100%;">
      <thead>
        <tr>
          <th style="padding:8px;">
            <div class="d-flex justify-content-between align-items-center">
              <span><i class="fas fa-fw fa-terminal"></i> CEC Log (last 60 lines)</span>
              <div class="d-flex gap-2">
                <button type="button" class="cec-btn cec-btn-sm" onclick="cecLoadLog()">
                  <i class="fas fa-fw fa-rotate"></i> Refresh
                </button>
                <button type="button" class="cec-btn cec-btn-sm"
                        onclick="document.getElementById('cecLogPanel').style.display='none'">
                  <i class="fas fa-fw fa-xmark"></i> Close
                </button>
              </div>
            </div>
          </th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td style="padding:0;">
            <pre id="cecLogOutput"
                 style="margin:0; padding:10px; max-height:320px; overflow-y:auto;
                        font-size:.78rem; line-height:1.4; white-space:pre-wrap;
                        background:#1a1a1a; color:#d0d0d0; border-radius:0 0 4px 4px;">Loading…</pre>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</div>

<!-- ── FPP Command Reference ──────────────────────────────────────────── -->
<div class="fppTableWrapper fppTableWrapperAsTable mb-3">
  <div class="fppTableContents">
    <table class="fppSelectableRowTable" style="width:100%;">
      <thead>
        <tr>
          <th style="padding:8px;">
            <i class="fas fa-fw fa-circle-info"></i> Using CEC Commands in FPP
          </th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td style="padding:12px 16px;">
            <p class="mb-2">
              All CEC commands are registered as <strong>FPP Commands</strong> and can be used anywhere FPP accepts a command:
            </p>
            <ul class="mb-2">
              <li><strong>Playlists</strong> — add a <em>FPP Command</em> item, choose <em>CEC - TV On</em> etc.</li>
              <li><strong>Scheduler</strong> — trigger CEC On/Off at a specific time each day</li>
              <li><strong>GPIO Inputs</strong> — fire a CEC command when a button is pressed</li>
              <li><strong>Other plugins</strong> — any plugin that can run an FPP Command</li>
            </ul>
            <p class="mb-0 text-muted small">
              <strong>Available commands:</strong>
              CEC - TV On &nbsp;|&nbsp; CEC - TV Standby &nbsp;|&nbsp;
              CEC - Set Active Source &nbsp;|&nbsp; CEC - Set Inactive Source &nbsp;|&nbsp;
              CEC - Volume Up &nbsp;|&nbsp; CEC - Volume Down &nbsp;|&nbsp;
              CEC - Mute Toggle &nbsp;|&nbsp; CEC - Send Raw Command
            </p>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</div>

<script>
const CEC_BASE = (typeof pluginBase !== 'undefined' && pluginBase)
  ? pluginBase : 'plugin.php?plugin=fpp-hdmi-cec&';
const CEC_URL  = CEC_BASE + 'nopage=1&page=www/';

function cecUrl(p) { return CEC_URL + p; }

function cecNotify(msg, isError) {
  $.jGrowl(msg, { themeState: isError ? 'danger' : 'success' });
}

// ── Save ────────────────────────────────────────────────────────────────
async function cecSave() {
  const fd  = new FormData(document.getElementById('cecForm'));
  const res = await fetch(cecUrl('save.php'), { method:'POST', body:fd, cache:'no-store' });
  const j   = await res.json();
  cecNotify(j.message || (j.status==='OK' ? 'Saved.' : 'Save failed.'), j.status !== 'OK');
}

// ── Test command ─────────────────────────────────────────────────────────
async function cecCmd(cmd) {
  const out = document.getElementById('cecCmdOutput');
  if (out) { out.style.display = 'block'; out.textContent = 'Sending…'; }
  const fd = new FormData();
  fd.set('action', 'command');
  fd.set('cmd', cmd);
  try {
    const res = await fetch(cecUrl('action.php'), { method:'POST', body:fd, cache:'no-store' });
    const j   = await res.json();
    cecNotify(j.message || (j.status==='OK' ? 'Sent.' : 'Failed.'), j.status !== 'OK');
    if (out) out.textContent = j.log_tail || (j.status==='OK' ? 'Command sent.' : j.message);
  } catch(e) {
    if (out) out.textContent = 'Error: ' + e;
    cecNotify('Request failed: ' + e, true);
  }
}

// ── Raw command ───────────────────────────────────────────────────────────
async function cecRaw() {
  const raw = document.getElementById('rawCmdInput')?.value?.trim();
  if (!raw) { cecNotify('Enter a command first.', true); return; }
  const out = document.getElementById('cecCmdOutput');
  if (out) { out.style.display = 'block'; out.textContent = 'Sending…'; }
  const fd = new FormData();
  fd.set('action', 'raw');
  fd.set('raw_cmd', raw);
  try {
    const res = await fetch(cecUrl('action.php'), { method:'POST', body:fd, cache:'no-store' });
    const j   = await res.json();
    cecNotify(j.message || (j.status==='OK' ? 'Sent.' : 'Failed.'), j.status !== 'OK');
    if (out) out.textContent = j.log_tail || (j.status==='OK' ? 'Command sent.' : j.message);
  } catch(e) {
    cecNotify('Request failed: ' + e, true);
  }
}

// ── Device scan ───────────────────────────────────────────────────────────
async function cecScan() {
  const panel = document.getElementById('cecScanPanel');
  const out   = document.getElementById('cecScanOutput');
  if (!panel || !out) return;
  panel.style.display = '';
  out.textContent = 'Scanning… this takes up to 15 seconds.';
  panel.scrollIntoView({ behavior:'smooth', block:'start' });
  const fd = new FormData();
  fd.set('action', 'scan');
  try {
    const res = await fetch(cecUrl('action.php'), { method:'POST', body:fd, cache:'no-store' });
    const j   = await res.json();
    out.textContent = j.status === 'OK' ? (j.output || '(no output)') : ('Error: ' + j.message);
  } catch(e) {
    out.textContent = 'Request failed: ' + e;
  }
}

// ── Log viewer ────────────────────────────────────────────────────────────
async function cecLoadLog() {
  const pre = document.getElementById('cecLogOutput');
  if (pre) pre.textContent = 'Loading…';
  try {
    const res = await fetch(cecUrl('action.php') + '?action=logtail&lines=60', { cache:'no-store' });
    const j   = await res.json();
    if (pre) {
      pre.textContent = (j.lines && j.lines.length) ? j.lines.join('\n') : (j.note || '(log is empty)');
      pre.scrollTop = pre.scrollHeight;
    }
  } catch(e) {
    if (pre) pre.textContent = 'Failed: ' + e;
  }
}

function cecShowLog() {
  const panel = document.getElementById('cecLogPanel');
  if (!panel) return;
  panel.style.display = '';
  cecLoadLog();
  panel.scrollIntoView({ behavior:'smooth', block:'start' });
}
</script>
