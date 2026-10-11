BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:GateScript = Join-Path $script:PluginRoot 'scripts/validation-lock.ps1'

  function Invoke-ValidationGate([string]$Prompt, [string]$ProjectDir) {
    $payload = @{ cwd = $ProjectDir; prompt = $Prompt } | ConvertTo-Json -Compress
    $payload | & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:GateScript
  }

  function New-ActiveProject([string]$Sandbox, [string]$Slug, [string]$OverallStatus) {
    $dotDir = Join-Path $Sandbox "bossdream_projects/$Slug/.bossdream-project"
    New-Item -ItemType Directory -Force -Path $dotDir | Out-Null
    $validation = @{ overallStatus = $OverallStatus; documents = @{ 'understanding.md' = @{ status = 'pending'; checks = @() } } }
    $validation | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $dotDir 'validation.json') -Encoding utf8
    $claudeDir = Join-Path $Sandbox '.claude'
    New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $claudeDir '.active-project'), $Slug)
  }
}

Describe 'validation-lock.ps1' {

  BeforeEach {
    $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("validation-lock-test-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $script:Sandbox | Out-Null
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
  }

  It 'caso 1 - overallStatus blocked + prompt matchea /bossdream-plan -> bloquea con decision=block' {
    New-ActiveProject -Sandbox $script:Sandbox -Slug 'demo' -OverallStatus 'blocked'
    $output = Invoke-ValidationGate -Prompt '/bossdream-plan agrega un campo nuevo' -ProjectDir $script:Sandbox

    $output | Should -Not -BeNullOrEmpty
    $json = $output | ConvertFrom-Json
    $json.decision | Should -Be 'block'
    $json.reason | Should -Match 'understanding\.md'
  }

  It 'caso 1b - overallStatus blocked + prompt matchea /bossdream-implement -> tambien bloquea' {
    New-ActiveProject -Sandbox $script:Sandbox -Slug 'demo' -OverallStatus 'blocked'
    $output = Invoke-ValidationGate -Prompt '/bossdream-implement' -ProjectDir $script:Sandbox

    $json = $output | ConvertFrom-Json
    $json.decision | Should -Be 'block'
  }

  It 'caso 2 - overallStatus ready + prompt matchea -> sale limpio, sin output' {
    New-ActiveProject -Sandbox $script:Sandbox -Slug 'demo' -OverallStatus 'ready'
    $output = Invoke-ValidationGate -Prompt '/bossdream-plan agrega un campo nuevo' -ProjectDir $script:Sandbox

    $output | Should -BeNullOrEmpty
  }

  It 'caso 3 - prompt sin match de ningun comando gobernado -> no hace nada' {
    New-ActiveProject -Sandbox $script:Sandbox -Slug 'demo' -OverallStatus 'blocked'
    $output = Invoke-ValidationGate -Prompt 'que hora es' -ProjectDir $script:Sandbox

    $output | Should -BeNullOrEmpty
  }

  It 'caso 4 - sin .claude/.active-project -> no bloquea aunque el prompt matchee' {
    $output = Invoke-ValidationGate -Prompt '/bossdream-plan agrega un campo nuevo' -ProjectDir $script:Sandbox

    $output | Should -BeNullOrEmpty
  }

  It 'caso 5 - blocked + override con consumido=false -> deja pasar y lo marca consumido=true' {
    New-ActiveProject -Sandbox $script:Sandbox -Slug 'demo' -OverallStatus 'blocked'
    $overridesPath = Join-Path $script:Sandbox 'bossdream_projects/demo/.bossdream-project/emergency-overrides.json'
    $entry = @{ quien = 'tester'; cuando = '2026-09-20T10:30:00Z'; motivo = 'fix urgente'; alcance = 'solo-esta-tarea'; consumido = $false }
    ConvertTo-Json -InputObject @($entry) -Depth 6 | Set-Content $overridesPath -Encoding utf8

    $output = Invoke-ValidationGate -Prompt '/bossdream-plan agrega un campo nuevo' -ProjectDir $script:Sandbox

    $output | Should -BeNullOrEmpty
    $overridesRaw = Get-Content $overridesPath -Raw | ConvertFrom-Json
    $overrides = @($overridesRaw)
    $overrides[0].consumido | Should -Be $true
  }

  It 'caso 6 - override ya consumido=true -> vuelve a bloquear (no se reusa)' {
    New-ActiveProject -Sandbox $script:Sandbox -Slug 'demo' -OverallStatus 'blocked'
    $overridesPath = Join-Path $script:Sandbox 'bossdream_projects/demo/.bossdream-project/emergency-overrides.json'
    $entry = @{ quien = 'tester'; cuando = '2026-09-20T10:30:00Z'; motivo = 'fix urgente'; alcance = 'solo-esta-tarea'; consumido = $true }
    ConvertTo-Json -InputObject @($entry) -Depth 6 | Set-Content $overridesPath -Encoding utf8

    $output = Invoke-ValidationGate -Prompt '/bossdream-plan agrega un campo nuevo' -ProjectDir $script:Sandbox

    $json = $output | ConvertFrom-Json
    $json.decision | Should -Be 'block'
  }

  It 'no revienta con stdin vacio o JSON invalido' {
    '' | & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:GateScript
    $LASTEXITCODE | Should -Be 0

    'esto no es json' | & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:GateScript
    $LASTEXITCODE | Should -Be 0
  }
}
