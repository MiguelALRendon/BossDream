param(
  [Parameter(Mandatory=$true)][string]$ProjectDir,
  [Parameter(Mandatory=$true)][string]$ProjectSlug
)
$ErrorActionPreference = 'Stop'

$idPattern = '\b(REQ|EPIC|FEAT|US|AC|TC)-(XXX(\.\d+)?|\d+(\.\d+)?)\b'
function Test-RealId([string]$Id) { return ($Id -notmatch '-XXX') }

function Add-IdsFromNode($node, $bag) {
  if ($null -eq $node) { return }
  if ($node -is [string]) {
    foreach ($m in [regex]::Matches($node, $idPattern)) {
      if (Test-RealId $m.Value) { [void]$bag.Add($m.Value) }
    }
    return
  }
  if ($node -is [System.Collections.IEnumerable]) {
    foreach ($item in $node) { Add-IdsFromNode $item $bag }
    return
  }
  if ($node -is [PSCustomObject]) {
    foreach ($prop in $node.PSObject.Properties) {
      if ($prop.Name -match $idPattern -and (Test-RealId $prop.Name)) { [void]$bag.Add($prop.Name) }
      Add-IdsFromNode $prop.Value $bag
    }
  }
}

function Get-AggregateSignature($files) {
  $sb = [System.Text.StringBuilder]::new()
  foreach ($f in ($files | Sort-Object FullName)) {
    [void]$sb.Append($f.FullName).Append('|').Append($f.LastWriteTimeUtc.Ticks).Append('|').Append($f.Length).Append("`n")
  }
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($sb.ToString())
  $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
  return [System.BitConverter]::ToString($hash) -replace '-', ''
}

$destDir = Join-Path $ProjectDir "bossdream_projects/$ProjectSlug"
$dotDir = Join-Path $destDir '.bossdream-project'
$cachePath = Join-Path $dotDir 'trace-cache.json'

$mdFiles = Get-ChildItem -Path $destDir -Recurse -Filter '*.md' -File -ErrorAction SilentlyContinue
$signature = Get-AggregateSignature $mdFiles

if (Test-Path $cachePath) {
  $cache = Get-Content $cachePath -Raw | ConvertFrom-Json
  if ($cache.signature -eq $signature) {
    (@{ status = $cache.status; findings = @($cache.findings) } | ConvertTo-Json -Compress -Depth 4)
    exit 0
  }
}

$tracePath = Join-Path $dotDir 'traceability.json'
$trace = if (Test-Path $tracePath) { Get-Content $tracePath -Raw | ConvertFrom-Json } else { [PSCustomObject]@{} }

$projectId = $null
$projectJsonPath = Join-Path $dotDir 'project.json'
if (Test-Path $projectJsonPath) {
  $projectJson = Get-Content $projectJsonPath -Raw | ConvertFrom-Json
  if ($projectJson.id) { $projectId = $projectJson.id }
}

$inGraph = New-Object System.Collections.Generic.HashSet[string]
Add-IdsFromNode $trace $inGraph

$mentioned = New-Object System.Collections.Generic.HashSet[string]
foreach ($f in $mdFiles) {
  $text = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
  foreach ($m in [regex]::Matches($text, $idPattern)) {
    if (Test-RealId $m.Value) { [void]$mentioned.Add($m.Value) }
  }
}

$findings = @()
foreach ($id in $mentioned) {
  if ($projectId -and $id -eq $projectId) { continue }
  if (-not $inGraph.Contains($id)) { $findings += "ID huerfano (mencionado en un documento, sin nodo en traceability.json): $id" }
}
foreach ($id in $inGraph) {
  if (-not $mentioned.Contains($id)) { $findings += "ID fantasma (existe en traceability.json, sin mencion en ningun documento): $id" }
}

$status = if ($findings.Count -gt 0) { 'blocked' } else { 'pass' }

New-Item -ItemType Directory -Force -Path $dotDir | Out-Null
(@{ signature = $signature; status = $status; findings = $findings } | ConvertTo-Json -Compress -Depth 4) | Set-Content $cachePath -Encoding utf8

(@{ status = $status; findings = $findings } | ConvertTo-Json -Compress -Depth 4)
exit 0
