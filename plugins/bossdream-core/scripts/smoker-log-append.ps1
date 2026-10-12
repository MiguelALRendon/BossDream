param(
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR,
  [Parameter(Mandatory=$true)][string]$IncrementId,
  [Parameter(Mandatory=$true)][string]$VeredictoPath
)
$ErrorActionPreference = 'Stop'

if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }
if (-not (Test-Path $VeredictoPath)) {
  throw "VeredictoPath no encontrado: $VeredictoPath"
}

$veredictoData = Get-Content -Encoding utf8 $VeredictoPath -Raw | ConvertFrom-Json

$dotDir = Join-Path $ProjectDir '.bossdream-project'
$logPath = Join-Path $dotDir 'smoker-log.json'

$entries = @()
if (Test-Path $logPath) {
  $existing = Get-Content -Encoding utf8 $logPath -Raw | ConvertFrom-Json
  $entries = @($existing)
}

$newEntry = [ordered]@{
  incrementId    = $IncrementId
  timestamp = [DateTime]::UtcNow.ToString('o')
  veredicto = $veredictoData.veredicto
  casos     = $veredictoData.casos
}
$entries += [PSCustomObject]$newEntry

if (-not (Test-Path $dotDir)) { New-Item -ItemType Directory -Path $dotDir -Force | Out-Null }
ConvertTo-Json -InputObject $entries -Depth 10 | Set-Content $logPath -Encoding utf8

Write-Output "smoker-log-append OK: entrada de increment '$IncrementId' agregada a .bossdream-project/smoker-log.json"
exit 0
