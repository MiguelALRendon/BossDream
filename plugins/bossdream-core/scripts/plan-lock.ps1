$ErrorActionPreference = 'Stop'
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $j = $raw | ConvertFrom-Json } catch { exit 0 }

$file = [string]$j.tool_input.file_path
if (-not $file) { exit 0 }

$proj = [string]$j.cwd
if (-not $proj) { $proj = $env:CLAUDE_PROJECT_DIR }
if (-not $proj) { exit 0 }
Import-Module (Join-Path $PSScriptRoot 'plugin-paths.psm1')
$proj = Get-ProjectRoot $proj

# mode-lock: un modo NO-editable bloquea edicion de codigo y de archivos de control
$nonEditing = @('plan', 'document', 'review')
try { $c0 = Get-Content -Encoding utf8 (Join-Path $proj 'bossdream.json') -Raw | ConvertFrom-Json; if ($c0.planLock.nonEditingModes) { $nonEditing = $c0.planLock.nonEditingModes } } catch {}
$mf = Join-Path $proj '.claude/.work-mode'
$mode = ''
if (Test-Path $mf) { $mode = ((Get-Content -Encoding utf8 $mf -Raw) -replace '[^a-zA-Z]', '').ToLower() }
if ($nonEditing -contains $mode) {
  $leaf = [System.IO.Path]::GetFileName($file).ToLower()
  $control = @('.work-mode', '.active-plan', 'bossdream.json')
  if ($control -contains $leaf) {
    $r = "mode-lock: en modo '$mode' NO puedes cambiar el modo ni la config por tu cuenta ($leaf). No edites .work-mode: para implementar un plan, INDICA al usuario que ejecute /bossdream-implement; al correrlo, el hook cambia el modo automaticamente. El modo nunca lo cambias tu."
    (@{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'; permissionDecisionReason = $r } } | ConvertTo-Json -Compress -Depth 5)
    exit 0
  }
  $ext = [System.IO.Path]::GetExtension($file).ToLower()
  $codeExt = @('.css', '.scss', '.sql', '.ps1')
  try { if ($c0.codeExtensions) { $codeExt = @($c0.codeExtensions) } } catch {}
  if ($codeExt -contains $ext) {
    $r = "mode-lock: estas en modo '$mode' (NO-editable). No implementes por tu cuenta. Al terminar el plan, INDICA al usuario que ejecute /bossdream-implement; al correrlo, el hook cambia el modo a implement y arranca la ejecucion increment por increment. Los .md/.feature del plan si se permiten."
    (@{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'; permissionDecisionReason = $r } } | ConvertTo-Json -Compress -Depth 5)
    exit 0
  }
}

$cfgPath = Join-Path $proj 'bossdream.json'
if (-not (Test-Path $cfgPath)) { exit 0 }
try { $cfg = Get-Content -Encoding utf8 $cfgPath -Raw | ConvertFrom-Json } catch { exit 0 }
$sg = $cfg.planLock
if (-not $sg -or $sg.enabled -ne $true) { exit 0 }
if (-not $sg.requirePaths -or $sg.requirePaths.Count -eq 0) { exit 0 }

$rel = $file
if ($file.StartsWith($proj, [StringComparison]::OrdinalIgnoreCase)) {
  $rel = $file.Substring($proj.Length)
}
$rel = ($rel -replace '\\', '/').TrimStart('/')

function Test-Glob([string]$path, [string]$glob) {
  $rx = [Regex]::Escape($glob)
  $rx = $rx -replace '\\\*\\\*/', '(.*/)?'
  $rx = $rx -replace '\\\*\\\*', '.*'
  $rx = $rx -replace '\\\*', '[^/]*'
  return $path -match ('^' + $rx + '$')
}

foreach ($g in $sg.exemptPaths) { if (Test-Glob $rel $g) { exit 0 } }

$isDomain = $false
foreach ($g in $sg.requirePaths) { if (Test-Glob $rel $g) { $isDomain = $true; break } }
if (-not $isDomain) { exit 0 }

$modeFile = Join-Path $proj '.claude/.work-mode'
if (Test-Path $modeFile) {
  $mode = (Get-Content -Encoding utf8 $modeFile -Raw).Trim().ToLower()
  if ($sg.exemptModes -contains $mode) { exit 0 }
}

$active = Join-Path $proj '.claude/.active-plan'
if (Test-Path $active) {
  $f = (Get-Content -Encoding utf8 $active -Raw).Trim()
  if ($f) { exit 0 }
}

$reason = "plan-lock: editas '$rel' (ruta de dominio) sin spec activa. Crea una con /plan-new <feature>, o si no la amerita declara /bossdream-mode spike|explore|bugfix|chore."
(@{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'; permissionDecisionReason = $reason } } | ConvertTo-Json -Compress -Depth 5)
exit 0
