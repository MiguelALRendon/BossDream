BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/plan-context-inject.ps1'

  function Invoke-ContextInject([string]$Prompt, [string]$ProjectDir) {
    $payload = @{ cwd = $ProjectDir; prompt = $Prompt } | ConvertTo-Json -Compress
    $payload | & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:Script
  }

  function New-ActiveProject([string]$Sandbox, [string]$Slug, [string]$OverallStatus, [hashtable]$Trace = @{}) {
    $dotDir = Join-Path $Sandbox "bossdream_projects/$Slug/.bossdream-project"
    New-Item -ItemType Directory -Force -Path $dotDir | Out-Null
    @{ overallStatus = $OverallStatus; documents = @{} } | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $dotDir 'validation.json') -Encoding utf8
    $Trace | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $dotDir 'traceability.json') -Encoding utf8
    @{ status = 'not-started'; planned = @(); pending = @() } | ConvertTo-Json | Set-Content (Join-Path $dotDir 'plan-progress.json') -Encoding utf8
    $claudeDir = Join-Path $Sandbox '.claude'
    New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $claudeDir '.active-project'), $Slug)
  }
}

Describe 'plan-context-inject.ps1' {

  BeforeEach {
    $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("plan-inject-test-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $script:Sandbox | Out-Null
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
  }

  It 'regresion (a) - sin .claude/.active-project, no imprime nada aunque el prompt matchee' {
    $output = Invoke-ContextInject -Prompt '/bossdream-plan agrega algo' -ProjectDir $script:Sandbox
    $output | Should -BeNullOrEmpty
  }

  It 'regresion (b) - con validation.json blocked, no imprime nada (validation-lock.ps1 ya bloquea el turno)' {
    New-ActiveProject -Sandbox $script:Sandbox -Slug 'demo' -OverallStatus 'blocked'
    $output = Invoke-ContextInject -Prompt '/bossdream-plan agrega algo' -ProjectDir $script:Sandbox
    $output | Should -BeNullOrEmpty
  }

  It 'sin match de /bossdream-plan, no imprime nada' {
    New-ActiveProject -Sandbox $script:Sandbox -Slug 'demo' -OverallStatus 'ready'
    $output = Invoke-ContextInject -Prompt '/otra-cosa' -ProjectDir $script:Sandbox
    $output | Should -BeNullOrEmpty
  }

  It 'con proyecto activo y validation.json ready, inyecta additionalContext via hookSpecificOutput (mismo shape real que readiness.ps1)' {
    New-ActiveProject -Sandbox $script:Sandbox -Slug 'demo' -OverallStatus 'ready'
    $output = Invoke-ContextInject -Prompt '/bossdream-plan agrega algo' -ProjectDir $script:Sandbox

    $output | Should -Not -BeNullOrEmpty
    $json = $output | ConvertFrom-Json
    $json.hookSpecificOutput.hookEventName | Should -Be 'UserPromptSubmit'
    $json.hookSpecificOutput.additionalContext | Should -Match 'demo'
    $json.hookSpecificOutput.additionalContext | Should -Match 'research-log'
    $json.hookSpecificOutput.additionalContext | Should -Match 'plan-progress-update\.ps1'
    $json.hookSpecificOutput.additionalContext | Should -Match 'roadmap\.md'
  }

  It 'calcula el tamano sugerido segun conteo de Epics/Features en traceability.json' {
    $trace = @{ features = @{ 'FEAT-001' = @{}; 'FEAT-002' = @{} } }
    New-ActiveProject -Sandbox $script:Sandbox -Slug 'demo' -OverallStatus 'ready' -Trace $trace
    $output = Invoke-ContextInject -Prompt '/bossdream-plan agrega algo' -ProjectDir $script:Sandbox
    $json = $output | ConvertFrom-Json
    $json.hookSpecificOutput.additionalContext | Should -Match 'grande'
  }

  It 'no revienta con stdin vacio o JSON invalido' {
    '' | & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:Script
    $LASTEXITCODE | Should -Be 0
    'no es json' | & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:Script
    $LASTEXITCODE | Should -Be 0
  }
}
