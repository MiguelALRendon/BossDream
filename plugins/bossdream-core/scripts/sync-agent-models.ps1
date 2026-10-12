param([string]$ProjectDir = $env:CLAUDE_PROJECT_DIR)
$ErrorActionPreference = 'Stop'

$projectDirExplicit = $PSBoundParameters.ContainsKey('ProjectDir') -and $ProjectDir
if (-not $projectDirExplicit) {
  $raw = [Console]::In.ReadToEnd()
  if ($raw) {
    try { $j = $raw | ConvertFrom-Json } catch { $j = $null }
    if ($j) {
      $hookFile = $j.tool_input.file_path
      if (-not $hookFile -or [System.IO.Path]::GetFileName($hookFile) -ne 'bossdream.json') { exit 0 }
      $ProjectDir = [string]$j.cwd
    }
  }
}

if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }

$configPath = Join-Path $ProjectDir 'bossdream.json'
if (-not (Test-Path $configPath)) {
  Write-Output "sync-agent-models: no se encontro bossdream.json en '$ProjectDir', nada que sincronizar."
  exit 0
}

try { $config = Get-Content -Encoding utf8 $configPath -Raw | ConvertFrom-Json } catch {
  Write-Output "sync-agent-models: bossdream.json invalido, nada que sincronizar."
  exit 0
}

if (-not $config.models) {
  Write-Output "sync-agent-models: bossdream.json no tiene seccion 'models', nada que sincronizar."
  exit 0
}

$models = $config.models
$defaultModel = $models.default
$agentsMap = $models.agents

$agentsDir = Join-Path $ProjectDir 'plugins/bossdream-core/agents'
if (-not (Test-Path $agentsDir)) {
  Write-Output "sync-agent-models: no se encontro carpeta de agentes en '$agentsDir', nada que sincronizar."
  exit 0
}

function Resolve-ExpectedModel([string]$AgentName) {
  if ($agentsMap -and ($agentsMap.PSObject.Properties.Name -contains $AgentName)) {
    return $agentsMap.$AgentName
  }
  return $defaultModel
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$changes = @()

Get-ChildItem -Path $agentsDir -Filter '*.md' | ForEach-Object {
  $file = $_
  $content = [System.IO.File]::ReadAllText($file.FullName)

  $frontmatterMatch = [regex]::Match($content, '(?s)^---\r?\n(.*?)\r?\n---')
  if (-not $frontmatterMatch.Success) { return }
  $frontmatter = $frontmatterMatch.Groups[1].Value

  $nameMatch = [regex]::Match($frontmatter, '(?m)^name:\s*(.+?)\s*$')
  $agentName = if ($nameMatch.Success) { $nameMatch.Groups[1].Value } else { [System.IO.Path]::GetFileNameWithoutExtension($file.Name) }

  $expectedModel = Resolve-ExpectedModel $agentName
  if (-not $expectedModel) { return }

  $modelMatch = [regex]::Match($frontmatter, '(?m)^model:\s*(.+?)\s*$')
  if (-not $modelMatch.Success) { return }
  $currentModel = $modelMatch.Groups[1].Value
  if ($currentModel -eq $expectedModel) { return }

  $lineStart = $modelMatch.Groups[1].Index
  $newFrontmatter = $frontmatter.Substring(0, $lineStart) + $expectedModel + $frontmatter.Substring($lineStart + $modelMatch.Groups[1].Length)

  $groupStart = $frontmatterMatch.Groups[1].Index
  $groupLength = $frontmatterMatch.Groups[1].Length
  $newContent = $content.Substring(0, $groupStart) + $newFrontmatter + $content.Substring($groupStart + $groupLength)

  [System.IO.File]::WriteAllText($file.FullName, $newContent, $utf8NoBom)
  $changes += "${agentName}: $currentModel -> $expectedModel"
}

if ($changes.Count -eq 0) {
  Write-Output "sync-agent-models: sin cambios, todo ya coincide con bossdream.json > models"
} else {
  $changes | ForEach-Object { Write-Output $_ }
}

exit 0
