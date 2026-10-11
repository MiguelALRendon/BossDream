param(
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR,
  [Parameter(Mandatory=$true)][string]$ProjectSlug,
  [Parameter(Mandatory=$true)][string]$Completed,
  [string]$Note = ''
)
$ErrorActionPreference = 'Stop'

if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }
$progressPath = Join-Path $ProjectDir "bossdream_projects/$ProjectSlug/.bossdream-project/plan-progress.json"
if (-not (Test-Path $progressPath)) {
  Write-Output "plan-progress-update: no existe plan-progress.json para '$ProjectSlug' - corre /bossdream-project primero."
  exit 1
}

$progress = Get-Content $progressPath -Raw | ConvertFrom-Json
$planned = @($progress.planned)
$pending = @($progress.pending)

if ($planned -notcontains $Completed) { $planned = @($planned + $Completed) }
$pending = @($pending | Where-Object { $_ -ne $Completed })

$progress.planned = $planned
$progress.pending = $pending
$progress.status = if ($pending.Count -eq 0) { 'complete' } else { 'in-progress' }

if (-not ($progress.PSObject.Properties.Name -contains 'lastSession')) {
  $progress | Add-Member -NotePropertyName 'lastSession' -NotePropertyValue ''
}
$progress.lastSession = (Get-Date -Format 'yyyy-MM-dd')

if ($Note) {
  if (-not ($progress.PSObject.Properties.Name -contains 'notes')) {
    $progress | Add-Member -NotePropertyName 'notes' -NotePropertyValue ''
  }
  $progress.notes = $Note
}

$progress | ConvertTo-Json -Depth 8 | Set-Content $progressPath -Encoding utf8
Write-Output "plan-progress-update OK: '$Completed' movido a planned. pending restante: $($pending.Count)."
