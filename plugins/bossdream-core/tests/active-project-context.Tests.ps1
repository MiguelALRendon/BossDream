BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/active-project-context.ps1'

  function Invoke-ActiveProjectContext([string]$ProjectDir, [string]$Prompt = 'cualquier pregunta') {
    $payload = @{ cwd = $ProjectDir; prompt = $Prompt } | ConvertTo-Json -Compress
    $payload | & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:Script
  }

  function New-ActiveProjectFixture([string]$Sandbox, [string]$Slug) {
    $claudeDir = Join-Path $Sandbox '.claude'
    New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $claudeDir '.active-project'), $Slug)
  }
}

Describe 'active-project-context.ps1' {

  BeforeEach {
    $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("active-ctx-test-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $script:Sandbox | Out-Null
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
  }

  It 'sin .claude/.active-project, no imprime nada' {
    $output = Invoke-ActiveProjectContext -ProjectDir $script:Sandbox
    $output | Should -BeNullOrEmpty
  }

  It 'con .active-project pero sin validation.json, inyecta resumen minimo con solo el slug' {
    New-ActiveProjectFixture -Sandbox $script:Sandbox -Slug 'demo'
    $output = Invoke-ActiveProjectContext -ProjectDir $script:Sandbox
    $output | Should -Not -BeNullOrEmpty
    $json = $output | ConvertFrom-Json
    $json.hookSpecificOutput.hookEventName | Should -Be 'UserPromptSubmit'
    $json.hookSpecificOutput.additionalContext | Should -Match "'demo'"
    $json.hookSpecificOutput.additionalContext | Should -Not -Match 'overallStatus'
  }

  It 'con .active-project y validation.json, incluye overallStatus' {
    New-ActiveProjectFixture -Sandbox $script:Sandbox -Slug 'demo'
    $dotDir = Join-Path $script:Sandbox 'bossdream_projects/demo/.bossdream-project'
    New-Item -ItemType Directory -Force -Path $dotDir | Out-Null
    @{ overallStatus = 'ready'; documents = @{} } | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $dotDir 'validation.json') -Encoding utf8

    $output = Invoke-ActiveProjectContext -ProjectDir $script:Sandbox
    $json = $output | ConvertFrom-Json
    $json.hookSpecificOutput.additionalContext | Should -Match "'demo'"
    $json.hookSpecificOutput.additionalContext | Should -Match 'overallStatus: ready'
  }

  It 'sin filtro por contenido del prompt, se dispara con cualquier pregunta irrelevante' {
    New-ActiveProjectFixture -Sandbox $script:Sandbox -Slug 'demo'
    $output = Invoke-ActiveProjectContext -ProjectDir $script:Sandbox -Prompt 'que version de PowerShell tengo instalada?'
    $output | Should -Not -BeNullOrEmpty
  }

  It 'incluye el nombre de project.json cuando existe' {
    New-ActiveProjectFixture -Sandbox $script:Sandbox -Slug 'demo'
    $dotDir = Join-Path $script:Sandbox 'bossdream_projects/demo/.bossdream-project'
    New-Item -ItemType Directory -Force -Path $dotDir | Out-Null
    @{ name = 'Mi proyecto de prueba con acentos: rediseno' } | ConvertTo-Json | Set-Content -Path (Join-Path $dotDir 'project.json') -Encoding utf8

    $output = Invoke-ActiveProjectContext -ProjectDir $script:Sandbox
    $json = $output | ConvertFrom-Json
    $json.hookSpecificOutput.additionalContext | Should -Match 'Mi proyecto de prueba con acentos: rediseno'
  }

  It 'transliterates a ASCII un nombre con acentos, sin romper el JSON de salida' {
    New-ActiveProjectFixture -Sandbox $script:Sandbox -Slug 'demo'
    $dotDir = Join-Path $script:Sandbox 'bossdream_projects/demo/.bossdream-project'
    New-Item -ItemType Directory -Force -Path $dotDir | Out-Null
    $nombreConAcentos = 'Redise' + [char]0x00F1 + 'o hacia BossDream'
    @{ name = $nombreConAcentos } | ConvertTo-Json | Set-Content -Path (Join-Path $dotDir 'project.json') -Encoding utf8

    $output = Invoke-ActiveProjectContext -ProjectDir $script:Sandbox
    { $output | ConvertFrom-Json } | Should -Not -Throw
    $json = $output | ConvertFrom-Json
    $json.hookSpecificOutput.additionalContext | Should -Match 'Rediseno hacia BossDream'
    $json.hookSpecificOutput.additionalContext | Should -Match '^[\x00-\x7F]+$'
  }

  It 'no revienta con stdin vacio o JSON invalido' {
    '' | & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:Script
    $LASTEXITCODE | Should -Be 0
    'no es json' | & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:Script
    $LASTEXITCODE | Should -Be 0
  }
}
