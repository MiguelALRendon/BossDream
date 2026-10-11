param(
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'pipeline-helpers.psm1') -Force -WarningAction SilentlyContinue
if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }

# politica de estilos desde bossdream.json: fuente del tema + estilos de vendor exentos
$themeSource = ''
$vendorExempt = @()
$bossdreamPath = Join-Path $ProjectDir 'bossdream.json'
if (Test-Path $bossdreamPath) {
  try { $st = (Get-Content $bossdreamPath -Raw | ConvertFrom-Json).style; if ($st) { $themeSource = ([string]$st.themeSource) -replace '\\', '/'; if ($st.vendorExempt) { $vendorExempt = @($st.vendorExempt) } } } catch {}
}

$files = Get-ProjectFiles $ProjectDir @('*.css', '*.scss')
if (-not $files) { Write-Output 'style-check: sin archivos CSS/SCSS, nada que revisar'; exit 0 }

# la fuente del tema es donde se DEFINEN los tokens: ahi los literales son validos
function Test-Skip([string]$rel) {
  if ($themeSource -and $rel -like ('*' + $themeSource + '*')) { return $true }
  foreach ($v in $vendorExempt) { if ($v -and $rel -like $v) { return $true } }
  return $false
}

$colorRx = [regex]'#[0-9a-fA-F]{3,8}\b|\b(rgb|rgba|hsl|hsla)\s*\('
$lenRx = [regex]'(?<![\w.])([1-9]\d*|0?\.\d+|\d+\.\d+)(px|rem|em|pt)\b'
$problems = @()
foreach ($f in $files) {
  $rel = ($f.FullName.Substring($ProjectDir.Length) -replace '\\', '/').TrimStart('/')
  if (Test-Skip $rel) { continue }
  $n = 0
  foreach ($line in [System.IO.File]::ReadAllLines($f.FullName)) {
    $n++
    $t = $line.TrimStart()
    if ($t.StartsWith('//') -or $t.StartsWith('/*') -or $t.StartsWith('*')) { continue }
    if ($colorRx.IsMatch($line)) { $problems += "$rel : $n : color quemado (usa un token del tema)" }
    elseif ($lenRx.IsMatch($line)) { $problems += "$rel : $n : tamano quemado (usa un token del tema)" }
  }
}

if ($problems.Count -gt 0) {
  Write-Output ("STYLE-CHECK FAIL (theme-first):`n" + (($problems | Select-Object -First 40) -join "`n"))
  exit 1
}
Write-Output "style-check OK ($($files.Count) archivos de estilo)"
exit 0
