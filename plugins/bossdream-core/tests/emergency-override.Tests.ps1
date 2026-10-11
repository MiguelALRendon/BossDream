BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:OverrideScript = Join-Path $script:PluginRoot 'scripts/emergency-override.ps1'

  function New-ActiveProject([string]$Sandbox, [string]$Slug) {
    $dotDir = Join-Path $Sandbox "bossdream_projects/$Slug/.bossdream-project"
    New-Item -ItemType Directory -Force -Path $dotDir | Out-Null
    $claudeDir = Join-Path $Sandbox '.claude'
    New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $claudeDir '.active-project'), $Slug)
    return $dotDir
  }

  function Invoke-EmergencyOverride([string]$ProjectDir, [string]$Motivo, [string]$Quien = 'tester') {
    & $script:OverrideScript -ProjectDir $ProjectDir -Motivo $Motivo -Quien $Quien
  }
}

Describe 'emergency-override.ps1' {

  BeforeEach {
    $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("emergency-override-test-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $script:Sandbox | Out-Null
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
  }

  It 'agrega la primera entrada con quien/cuando/motivo/alcance/consumido=false' {
    $dotDir = New-ActiveProject -Sandbox $script:Sandbox -Slug 'demo'

    Invoke-EmergencyOverride -ProjectDir $script:Sandbox -Motivo 'fix de produccion urgente' -Quien 'colosjipis' | Out-Null

    $overridesPath = Join-Path $dotDir 'emergency-overrides.json'
    Test-Path $overridesPath | Should -BeTrue
    $overridesRaw = Get-Content $overridesPath -Raw | ConvertFrom-Json
    $overrides = @($overridesRaw)
    $overrides.Count | Should -Be 1
    $overrides[0].quien | Should -Be 'colosjipis'
    $overrides[0].motivo | Should -Be 'fix de produccion urgente'
    $overrides[0].alcance | Should -Be 'solo-esta-tarea'
    $overrides[0].consumido | Should -Be $false
    (Get-Content $overridesPath -Raw) | Should -Match '"cuando":\s*"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z"'
  }

  It 'agrega una segunda entrada sin pisar la primera (array crece, no se reemplaza)' {
    $dotDir = New-ActiveProject -Sandbox $script:Sandbox -Slug 'demo'
    Invoke-EmergencyOverride -ProjectDir $script:Sandbox -Motivo 'primer motivo' | Out-Null
    Invoke-EmergencyOverride -ProjectDir $script:Sandbox -Motivo 'segundo motivo' | Out-Null

    $overridesRaw = Get-Content (Join-Path $dotDir 'emergency-overrides.json') -Raw | ConvertFrom-Json
    $overrides = @($overridesRaw)
    $overrides.Count | Should -Be 2
    $overrides[0].motivo | Should -Be 'primer motivo'
    $overrides[1].motivo | Should -Be 'segundo motivo'
  }

  It 'falla (exit 1) sin proyecto activo, sin escribir nada' {
    & $script:OverrideScript -ProjectDir $script:Sandbox -Motivo 'sin proyecto activo' | Out-Null
    $LASTEXITCODE | Should -Be 1
    Test-Path (Join-Path $script:Sandbox 'bossdream_projects') | Should -BeFalse
  }

  It 'exige -Motivo (parametro obligatorio)' {
    { & $script:OverrideScript -ProjectDir $script:Sandbox -ErrorAction Stop } | Should -Throw
  }
}
