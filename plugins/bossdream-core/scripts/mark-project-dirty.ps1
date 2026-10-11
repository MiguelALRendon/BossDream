$ErrorActionPreference = 'Stop'

function Get-Fingerprint([string]$Path) {
  return (Get-FileHash -Path $Path -Algorithm SHA256).Hash
}

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $j = $raw | ConvertFrom-Json } catch { exit 0 }

$path = $j.tool_input.file_path
if (-not $path) { exit 0 }
if ([System.IO.Path]::GetExtension($path).ToLower() -ne '.md') { exit 0 }

$proj = [string]$j.cwd
if (-not $proj) { $proj = $env:CLAUDE_PROJECT_DIR }
if (-not $proj) { exit 0 }

$activeProjectFile = Join-Path $proj '.claude/.active-project'
if (-not (Test-Path $activeProjectFile)) { exit 0 }
$slug = (Get-Content $activeProjectFile -Raw).Trim()
if (-not $slug) { exit 0 }

$destDir = Join-Path $proj "bossdream_projects/$slug"
if (-not (Test-Path $destDir)) { exit 0 }
$destDirFull = (Resolve-Path -LiteralPath $destDir).Path

$editedFull = $null
try { $editedFull = (Resolve-Path -LiteralPath $path -ErrorAction Stop).Path } catch { exit 0 }
if (-not $editedFull.StartsWith($destDirFull, [System.StringComparison]::OrdinalIgnoreCase)) { exit 0 }

$docKey = $editedFull.Substring($destDirFull.Length).TrimStart('\', '/') -replace '\\', '/'

$validationPath = Join-Path $destDirFull '.bossdream-project/validation.json'
if (-not (Test-Path $validationPath)) { exit 0 }
$validation = Get-Content $validationPath -Raw | ConvertFrom-Json

# Solo actua sobre documentos ya registrados -- uno nuevo requiere interpretacion, no solo reabrir estado.
if (-not ($validation.documents.PSObject.Properties.Name -contains $docKey)) { exit 0 }

$currentEntry = $validation.documents.$docKey
if ($currentEntry.status -eq 'pending') { exit 0 }

if ($currentEntry.documentFingerprint -and (Get-Fingerprint $editedFull) -eq $currentEntry.documentFingerprint) { exit 0 }

$validation.documents.$docKey = [PSCustomObject]@{ status = 'pending'; documentFingerprint = ''; checks = @() }
$validation.overallStatus = 'blocked'
$validation | ConvertTo-Json -Depth 10 | Set-Content $validationPath -Encoding utf8
exit 0
