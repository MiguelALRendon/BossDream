param(
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR,
  [Parameter(Mandatory=$true)][string]$ProjectSlug,
  [Parameter(Mandatory=$true)][string]$ProjectId,
  [Parameter(Mandatory=$true)][string]$ProjectName,
  [Parameter(Mandatory=$true)][ValidateSet('Simple','Medio','Complejo')][string]$Classification
)

$ErrorActionPreference = 'Stop'

$pluginRoot = Split-Path -Parent $PSScriptRoot
$templatesRoot = Join-Path $pluginRoot 'templates'
$projectTemplate = Join-Path $templatesRoot '_PROJECT_TEMPLATE'

if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }
$claudeDir = Join-Path $ProjectDir '.claude'
New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null

# Copia los scripts de hook a .claude/bossdream-hooks/ (mismo mecanismo de entrega que bossdream-init:
# hooks.json del plugin no es fiable en todos los Claude Code; via settings.json + script local del proyecto si).
# Corre siempre, independiente del proyecto de negocio que se este creando/actualizando.
$hooksDir = Join-Path $claudeDir 'bossdream-hooks'
New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null
Copy-Item (Join-Path $pluginRoot 'scripts/validation-lock.ps1') (Join-Path $hooksDir 'validation-lock.ps1') -Force
Copy-Item (Join-Path $pluginRoot 'scripts/mark-project-dirty.ps1') (Join-Path $hooksDir 'mark-project-dirty.ps1') -Force
Copy-Item (Join-Path $pluginRoot 'scripts/plan-context-inject.ps1') (Join-Path $hooksDir 'plan-context-inject.ps1') -Force
Copy-Item (Join-Path $pluginRoot 'scripts/project-sync.ps1') (Join-Path $hooksDir 'project-sync.ps1') -Force
Copy-Item (Join-Path $pluginRoot 'scripts/traceability-build.ps1') (Join-Path $hooksDir 'traceability-build.ps1') -Force

# Fusiona (merge, nunca overwrite) el fragmento de hooks en .claude/settings.json del proyecto consumidor.
$hooksSnippetPath = Join-Path $templatesRoot 'settings.hooks-snippet.json'
if (Test-Path $hooksSnippetPath) {
  $snippet = Get-Content $hooksSnippetPath -Raw | ConvertFrom-Json
  $settingsPath = Join-Path $claudeDir 'settings.json'
  if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
  } else {
    $settings = [PSCustomObject]@{}
  }
  if (-not ($settings.PSObject.Properties.Name -contains 'hooks')) {
    $settings | Add-Member -NotePropertyName 'hooks' -NotePropertyValue ([PSCustomObject]@{})
  }
  foreach ($eventName in $snippet.hooks.PSObject.Properties.Name) {
    if (-not ($settings.hooks.PSObject.Properties.Name -contains $eventName)) {
      $settings.hooks | Add-Member -NotePropertyName $eventName -NotePropertyValue @()
    }
    $existingEntries = @($settings.hooks.$eventName)
    $newEntries = @($snippet.hooks.$eventName)
    foreach ($newEntry in $newEntries) {
      $newCommands = @($newEntry.hooks | ForEach-Object { $_.command })
      $alreadyPresent = $false
      foreach ($existingEntry in $existingEntries) {
        foreach ($existingHook in @($existingEntry.hooks)) {
          if ($newCommands -contains $existingHook.command) { $alreadyPresent = $true }
        }
      }
      if (-not $alreadyPresent) { $existingEntries = $existingEntries + $newEntry }
    }
    $settings.hooks.$eventName = $existingEntries
  }
  $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding utf8
}

# Fusiona (append, nunca overwrite) la linea de .active-project en .gitignore del proyecto consumidor.
# .active-project es un puntero LOCAL por desarrollador - nunca se comparte via git (mismo principio
# que .active-plan/.work-mode del motor core, ya listados en su propio .gitignore).
$gitignoreSnippetPath = Join-Path $templatesRoot 'gitignore-snippet.txt'
if (Test-Path $gitignoreSnippetPath) {
  $gitignorePath = Join-Path $ProjectDir '.gitignore'
  $snippetLines = @(Get-Content $gitignoreSnippetPath)
  $existingLines = if (Test-Path $gitignorePath) { @(Get-Content $gitignorePath) } else { @() }
  $linesToAdd = @($snippetLines | Where-Object { $existingLines -notcontains $_ })
  if ($linesToAdd.Count -gt 0) {
    Add-Content -Path $gitignorePath -Value $linesToAdd -Encoding utf8
  }
}

$destDir = Join-Path $ProjectDir "bossdream_projects/$ProjectSlug"
$dotDir = Join-Path $destDir '.bossdream-project'

# Idempotencia: si el proyecto ya existe, no se pisa sin confirmacion explicita del usuario.
if (Test-Path (Join-Path $dotDir 'project.json')) {
  Write-Output "scaffold SKIP: bossdream_projects/$ProjectSlug ya existe (usa /bossdream-update-docs para modificarlo, no /bossdream-project de nuevo)."
  exit 0
}

New-Item -ItemType Directory -Force -Path $destDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $destDir 'tests/_templates') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $destDir 'tests/cases') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $destDir 'tests/evidence') | Out-Null
New-Item -ItemType Directory -Force -Path $dotDir | Out-Null

Copy-Item (Join-Path $projectTemplate 'requirements.md') (Join-Path $destDir 'requirements.md') -Force
Copy-Item (Join-Path $projectTemplate 'tests/test-approach.md') (Join-Path $destDir 'tests/test-approach.md') -Force
Copy-Item (Join-Path $projectTemplate 'tests/_templates/test-case.md') (Join-Path $destDir 'tests/_templates/test-case.md') -Force

$project = Get-Content (Join-Path $templatesRoot 'project.json') -Raw | ConvertFrom-Json
$project.id = $ProjectId
$project.name = $ProjectName
$project.classification = $Classification
$project.status = 'draft'
$project.createdAt = (Get-Date -Format 'yyyy-MM-dd')
$project.documentsPath = "bossdream_projects/$ProjectSlug/"
$project | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $dotDir 'project.json') -Encoding utf8

Copy-Item (Join-Path $templatesRoot 'validation.json') (Join-Path $dotDir 'validation.json') -Force
Copy-Item (Join-Path $templatesRoot 'traceability.json') (Join-Path $dotDir 'traceability.json') -Force
Copy-Item (Join-Path $templatesRoot 'plan-progress.json') (Join-Path $dotDir 'plan-progress.json') -Force

[System.IO.File]::WriteAllText((Join-Path $claudeDir '.active-project'), $ProjectSlug)

Write-Output "scaffold OK: bossdream_projects/$ProjectSlug creado (validation.json blocked, active-project fijo)."
