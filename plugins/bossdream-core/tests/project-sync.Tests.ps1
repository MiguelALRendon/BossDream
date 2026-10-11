BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:ScaffoldScript = Join-Path $script:PluginRoot 'scripts/project-scaffold.ps1'
  $script:SyncScript = Join-Path $script:PluginRoot 'scripts/project-sync.ps1'

  function Invoke-Sync([string]$ProjectDir) {
    $payload = @{ cwd = $ProjectDir } | ConvertTo-Json -Compress
    $env:CLAUDE_PLUGIN_ROOT = $script:PluginRoot
    $payload | & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:SyncScript
  }
}

Describe 'project-sync.ps1' {

  BeforeEach {
    $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("project-sync-test-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $script:Sandbox | Out-Null
    $env:CLAUDE_PLUGIN_ROOT = $script:PluginRoot
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-800' -ProjectName 'Demo' -Classification 'Medio' | Out-Null
    $script:DestDir = Join-Path $script:Sandbox 'bossdream_projects/demo'
    $script:DotDir = Join-Path $script:DestDir '.bossdream-project'
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
    Remove-Item Env:\CLAUDE_PLUGIN_ROOT -ErrorAction SilentlyContinue
  }

  It 'sin proyecto activo no toca traceability.json ni validation.json' {
    Remove-Item (Join-Path $script:Sandbox '.claude/.active-project') -Force
    $traceBefore = Get-Content (Join-Path $script:DotDir 'traceability.json') -Raw
    $validationBefore = Get-Content (Join-Path $script:DotDir 'validation.json') -Raw

    Invoke-Sync -ProjectDir $script:Sandbox | Out-Null
    $LASTEXITCODE | Should -Be 0

    (Get-Content (Join-Path $script:DotDir 'traceability.json') -Raw) | Should -Be $traceBefore
    (Get-Content (Join-Path $script:DotDir 'validation.json') -Raw) | Should -Be $validationBefore
  }

  It 'con proyecto activo, tras editar requirements.md actualiza traceability.json (hash cambia) y validation.json (status recalculado) sin correr /bossdream-update-docs' {
    $req = @"
User Stories

### US-001 - ver saldo

- AC-001.1: criterio uno
"@
    [System.IO.File]::WriteAllText((Join-Path $script:DestDir 'requirements.md'), $req, (New-Object System.Text.UTF8Encoding($false)))

    $validation = Get-Content (Join-Path $script:DotDir 'validation.json') -Raw | ConvertFrom-Json
    $validation.documents.'requirements.md' = [PSCustomObject]@{ status = 'verified'; documentFingerprint = 'fp-congelado'; checks = @() }
    $validation | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $script:DotDir 'validation.json') -Encoding utf8

    $traceHashBefore = (Get-FileHash (Join-Path $script:DotDir 'traceability.json') -Algorithm SHA256).Hash
    $statusBefore = (Get-Content (Join-Path $script:DotDir 'validation.json') -Raw | ConvertFrom-Json).documents.'requirements.md'.status

    Invoke-Sync -ProjectDir $script:Sandbox | Out-Null
    $LASTEXITCODE | Should -Be 0

    $traceHashAfter = (Get-FileHash (Join-Path $script:DotDir 'traceability.json') -Algorithm SHA256).Hash
    $statusAfter = (Get-Content (Join-Path $script:DotDir 'validation.json') -Raw | ConvertFrom-Json).documents.'requirements.md'.status

    $traceHashAfter | Should -Not -Be $traceHashBefore
    $statusAfter | Should -Not -Be $statusBefore
  }

  It 'no revienta con stdin vacio o sin proyecto activo' {
    '' | & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:SyncScript
    $LASTEXITCODE | Should -Be 0
  }

  It 'no revienta si el proyecto activo no existe en disco' {
    [System.IO.File]::WriteAllText((Join-Path $script:Sandbox '.claude/.active-project'), 'fantasma')
    Invoke-Sync -ProjectDir $script:Sandbox | Out-Null
    $LASTEXITCODE | Should -Be 0
  }

  It 'resuelve traceability-build.ps1 y validation-check.ps1 via Get-CanonicalPluginScriptsDir, no via CLAUDE_PLUGIN_ROOT (D1.1)' {
    Remove-Item Env:\CLAUDE_PLUGIN_ROOT -ErrorAction SilentlyContinue
    $env:CLAUDE_PLUGIN_ROOT = 'C:\ruta-inexistente-que-no-deberia-usarse'

    $req = @"
User Stories

### US-001 - ver saldo

- AC-001.1: criterio uno
"@
    [System.IO.File]::WriteAllText((Join-Path $script:DestDir 'requirements.md'), $req, (New-Object System.Text.UTF8Encoding($false)))

    $traceHashBefore = (Get-FileHash (Join-Path $script:DotDir 'traceability.json') -Algorithm SHA256).Hash

    Invoke-Sync -ProjectDir $script:Sandbox | Out-Null
    $LASTEXITCODE | Should -Be 0

    $traceHashAfter = (Get-FileHash (Join-Path $script:DotDir 'traceability.json') -Algorithm SHA256).Hash
    $validationAfter = Get-Content (Join-Path $script:DotDir 'validation.json') -Raw | ConvertFrom-Json

    $traceHashAfter | Should -Not -Be $traceHashBefore
    $validationAfter.documents.'requirements.md'.status | Should -Not -BeNullOrEmpty
  }

  It 'ambas invocaciones (traceability-build.ps1 y validation-check.ps1) usan Get-CanonicalPluginScriptsDir de forma consistente' {
    $content = Get-Content $script:SyncScript -Raw
    $canonicalScriptsLine = ($content -split "`n" | Where-Object { $_ -match 'canonicalScripts\s*=' })
    $canonicalScriptsLine | Should -Match 'Get-CanonicalPluginScriptsDir'
    ($content -split "`n" | Where-Object { $_ -match "Join-Path\s+\`$canonicalScripts\s+'traceability-build.ps1'" }) | Should -Not -BeNullOrEmpty
    ($content -split "`n" | Where-Object { $_ -match "Join-Path\s+\`$canonicalScripts\s+'validation-check.ps1'" }) | Should -Not -BeNullOrEmpty
  }
}
