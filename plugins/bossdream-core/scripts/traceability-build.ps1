param(
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR,
  [Parameter(Mandatory=$true)][string]$ProjectSlug
)
$ErrorActionPreference = 'Stop'

if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }
$destDir = Join-Path $ProjectDir "bossdream_projects/$ProjectSlug"
$reqPath = Join-Path $destDir 'requirements.md'
$dotDir = Join-Path $destDir '.bossdream-project'
$casosDir = Join-Path $destDir 'tests/cases'
$cachePath = Join-Path $dotDir 'traceability-cache.json'

function Get-TraceabilityInputFiles {
  $files = @()
  if (Test-Path $reqPath) { $files += Get-Item $reqPath }
  if (Test-Path $casosDir) { $files += Get-ChildItem -Path $casosDir -Filter 'TC-*.md' -File }
  return $files
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

$preSignature = Get-AggregateSignature (Get-TraceabilityInputFiles)
if (Test-Path $cachePath) {
  $cache = Get-Content $cachePath -Raw | ConvertFrom-Json
  if ($cache.signature -eq $preSignature) {
    Write-Output "traceability-build: sin cambios detectados (cache hit) - no reconstruido."
    exit 0
  }
}

$idIndex = @{}

function Find-NodeById($node, [string]$Id) {
  if ($idIndex.ContainsKey($Id)) { return $idIndex[$Id] }
  if ($null -eq $node) { return $null }
  if ($node -is [PSCustomObject]) {
    foreach ($prop in $node.PSObject.Properties) {
      if ($prop.Name -eq $Id) { $idIndex[$Id] = $prop.Value; return $prop.Value }
      $found = Find-NodeById $prop.Value $Id
      if ($found) { $idIndex[$Id] = $found; return $found }
    }
  }
  return $null
}

$tree = [PSCustomObject]@{}
$curEpic = $null
$curFeature = $null
$curUs = $null

if (Test-Path $reqPath) {
  $lines = [System.IO.File]::ReadAllLines($reqPath, [System.Text.Encoding]::UTF8)
  foreach ($line in $lines) {

    if ($line -match '\*\*EPIC-(\d+[\w-]*)') {
      $epicId = "EPIC-$($Matches[1])"
      if (-not ($tree.PSObject.Properties.Name -contains 'epics')) { $tree | Add-Member -NotePropertyName 'epics' -NotePropertyValue ([PSCustomObject]@{}) }
      if (-not ($tree.epics.PSObject.Properties.Name -contains $epicId)) {
        $tree.epics | Add-Member -NotePropertyName $epicId -NotePropertyValue ([PSCustomObject]@{ features = [PSCustomObject]@{} })
      }
      $idIndex[$epicId] = $tree.epics.$epicId
      $curEpic = $epicId; $curFeature = $null; $curUs = $null
      continue
    }

    if ($line -match '\*\*FEAT-(\d+[\w-]*)') {
      $featId = "FEAT-$($Matches[1])"
      if ($curEpic) {
        if (-not ($tree.epics.$curEpic.features.PSObject.Properties.Name -contains $featId)) {
          $tree.epics.$curEpic.features | Add-Member -NotePropertyName $featId -NotePropertyValue ([PSCustomObject]@{ stories = [PSCustomObject]@{} })
        }
        $idIndex[$featId] = $tree.epics.$curEpic.features.$featId
      } else {
        if (-not ($tree.PSObject.Properties.Name -contains 'features')) { $tree | Add-Member -NotePropertyName 'features' -NotePropertyValue ([PSCustomObject]@{}) }
        if (-not ($tree.features.PSObject.Properties.Name -contains $featId)) {
          $tree.features | Add-Member -NotePropertyName $featId -NotePropertyValue ([PSCustomObject]@{ stories = [PSCustomObject]@{} })
        }
        $idIndex[$featId] = $tree.features.$featId
      }
      $curFeature = $featId; $curUs = $null
      continue
    }

    if ($line -match '^#+\s*US-(\d+[\w-]*)') {
      $usId = "US-$($Matches[1])"
      $storiesParent = $null
      if ($curFeature -and $curEpic) { $storiesParent = $tree.epics.$curEpic.features.$curFeature.stories }
      elseif ($curFeature) { $storiesParent = $tree.features.$curFeature.stories }
      else {
        if (-not ($tree.PSObject.Properties.Name -contains 'stories')) { $tree | Add-Member -NotePropertyName 'stories' -NotePropertyValue ([PSCustomObject]@{}) }
        $storiesParent = $tree.stories
      }
      if (-not ($storiesParent.PSObject.Properties.Name -contains $usId)) {
        $storiesParent | Add-Member -NotePropertyName $usId -NotePropertyValue ([PSCustomObject]@{ acceptanceCriteria = @(); tests = @() })
      }
      $idIndex[$usId] = $storiesParent.$usId
      $curUs = $usId
      continue
    }

    if ($curUs -and $line -match 'AC-(\d+\.\d+)') {
      $usNode = Find-NodeById $tree $curUs
      if ($usNode) {
        foreach ($m in [regex]::Matches($line, 'AC-(\d+\.\d+)')) {
          $acId = "AC-$($m.Groups[1].Value)"
          $existing = @($usNode.acceptanceCriteria)
          if ($existing -notcontains $acId) { $usNode.acceptanceCriteria = @($existing + $acId) }
        }
      }
    }
  }
}

$tcPassed = @{}
if (Test-Path $casosDir) {
  foreach ($f in Get-ChildItem -Path $casosDir -Filter 'TC-*.md' -File) {
    $tcId = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    $text = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    if ($text -match 'US-(\d+[\w-]*)') {
      $usId = "US-$($Matches[1])"
      $usNode = Find-NodeById $tree $usId
      if ($usNode) {
        if (-not ($usNode.PSObject.Properties.Name -contains 'tests')) {
          $usNode | Add-Member -NotePropertyName 'tests' -NotePropertyValue @()
        }
        $existing = @($usNode.tests)
        if ($existing -notcontains $tcId) { $usNode.tests = @($existing + $tcId) }
      }
    }
    # [char]0x00f3 en vez de la o con tilde literal: el .ps1 se lee sin BOM en Windows PowerShell 5.1 y corrompe literales no-ASCII
    if ($text -match '\*\*Estado\*\*\s*\|\s*([^|]+?)\s*\|') {
      $tcPassed[$tcId] = [bool]($Matches[1] -match ('^Pas(o|' + [char]0x00f3 + ')\b'))
    }
  }
}

function Update-TraceabilityTable([string]$Path, [hashtable]$Passed) {
  if (-not (Test-Path $Path)) { return }
  $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
  $headerIdx = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\|\s*Epic\s*\|\s*Feature\s*\|\s*User Story\s*\|\s*AC\s*\|\s*Test Case\s*\|\s*Prioridad\s*\|\s*Estado\s*\|$') { $headerIdx = $i; break }
  }
  if ($headerIdx -lt 0 -or $headerIdx + 2 -ge $lines.Count) { return }
  $changed = $false
  for ($i = $headerIdx + 2; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -notmatch '^\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|$') { break }
    $cols = @($Matches[1], $Matches[2], $Matches[3], $Matches[4], $Matches[5], $Matches[6], $Matches[7])
    $tcIds = @([regex]::Matches($cols[4], 'TC-\d+') | ForEach-Object { $_.Value })
    $isImplemented = $tcIds.Count -gt 0
    foreach ($tcId in $tcIds) {
      if (-not ($Passed.ContainsKey($tcId) -and $Passed[$tcId])) { $isImplemented = $false; break }
    }
    $newEstado = if ($isImplemented) { ' Implementado ' } else { ' Definido ' }
    if ($cols[6] -ne $newEstado) {
      $cols[6] = $newEstado
      $lines[$i] = '|' + ($cols -join '|') + '|'
      $changed = $true
    }
  }
  if ($changed) {
    [System.IO.File]::WriteAllLines($Path, $lines, [System.Text.UTF8Encoding]::new($false))
  }
}

Update-TraceabilityTable -Path $reqPath -Passed $tcPassed

New-Item -ItemType Directory -Force -Path $dotDir | Out-Null
$tree | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $dotDir 'traceability.json') -Encoding utf8

$postSignature = Get-AggregateSignature (Get-TraceabilityInputFiles)
(@{ signature = $postSignature } | ConvertTo-Json -Compress) | Set-Content $cachePath -Encoding utf8

Write-Output "traceability-build OK: reconstruido desde requirements.md + tests/cases/*.md (nunca a mano - el JSON es cache derivado)."
