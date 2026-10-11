BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:ScaffoldScript = Join-Path $script:PluginRoot 'scripts/project-scaffold.ps1'
  $script:RegisterScript = Join-Path $script:PluginRoot 'scripts/testcase-register.ps1'

  function Write-Utf8([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
  }
}

Describe 'testcase-register.ps1' {

  BeforeEach {
    $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("testcase-register-test-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $script:Sandbox | Out-Null
    $env:CLAUDE_PLUGIN_ROOT = $script:PluginRoot

    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-700' -ProjectName 'Demo' -Classification 'Medio' | Out-Null
    $script:DestDir = Join-Path $script:Sandbox 'bossdream_projects/demo'
    $script:DotDir = Join-Path $script:DestDir '.bossdream-project'

    $trace = @{ stories = @{ 'US-001' = @{ acceptanceCriteria = @('AC-001.1') } } }
    $trace | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $script:DotDir 'traceability.json') -Encoding utf8

    New-Item -ItemType Directory -Force -Path (Join-Path $script:DestDir 'tests/cases') | Out-Null
    Write-Utf8 (Join-Path $script:DestDir 'tests/cases/TC-001.md') "# TC-001`n**Relacionado con:** US-001 / AC-001.1`n| **Estado** | Paso |"
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
    Remove-Item Env:\CLAUDE_PLUGIN_ROOT -ErrorAction SilentlyContinue
  }

  It 'registra el TC bajo su US en traceability.json' {
    & $script:RegisterScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -TcId 'TC-001' -UsId 'US-001' | Out-Null

    $trace = Get-Content (Join-Path $script:DotDir 'traceability.json') -Raw | ConvertFrom-Json
    $trace.stories.'US-001'.tests | Should -Contain 'TC-001'
  }

  It 'no duplica el TC si se registra dos veces' {
    & $script:RegisterScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -TcId 'TC-001' -UsId 'US-001' | Out-Null
    & $script:RegisterScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -TcId 'TC-001' -UsId 'US-001' | Out-Null

    $trace = Get-Content (Join-Path $script:DotDir 'traceability.json') -Raw | ConvertFrom-Json
    @($trace.stories.'US-001'.tests | Where-Object { $_ -eq 'TC-001' }).Count | Should -Be 1
  }

  It 'agrega el TC a validation.json y fuerza overallStatus a blocked, incluso si estaba ready' {
    $validation = Get-Content (Join-Path $script:DotDir 'validation.json') -Raw | ConvertFrom-Json
    $validation.overallStatus = 'ready'
    $validation | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $script:DotDir 'validation.json') -Encoding utf8

    & $script:RegisterScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -TcId 'TC-001' -UsId 'US-001' | Out-Null

    $validationAfter = Get-Content (Join-Path $script:DotDir 'validation.json') -Raw | ConvertFrom-Json
    $validationAfter.overallStatus | Should -Be 'blocked'
    $validationAfter.documents.'tests/cases/TC-001.md'.status | Should -Be 'pending'
  }

  It 'actualiza la tabla resumen de test-approach.md seccion 7 contando los TC existentes' {
    Write-Utf8 (Join-Path $script:DestDir 'tests/cases/TC-002.md') "# TC-002`n**Relacionado con:** US-001 / AC-001.1`n| **Estado** | Fallo |"

    & $script:RegisterScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -TcId 'TC-001' -UsId 'US-001' | Out-Null

    $approach = [System.IO.File]::ReadAllText((Join-Path $script:DestDir 'tests/test-approach.md'), [System.Text.Encoding]::UTF8)
    $approach | Should -Match '\| 2 \| 1 \| 1 \| 0 \| No \|'
  }

  It 'bootstrap sin cache previo: el conteo persistido coincide con el rescan manual completo' {
    Write-Utf8 (Join-Path $script:DestDir 'tests/cases/TC-002.md') "# TC-002`n**Relacionado con:** US-001 / AC-001.1`n| **Estado** | Fallo |"
    Write-Utf8 (Join-Path $script:DestDir 'tests/cases/TC-003.md') "# TC-003`n**Relacionado con:** US-001 / AC-001.1`n| **Estado** | Bloqueado |"

    & $script:RegisterScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -TcId 'TC-001' -UsId 'US-001' | Out-Null

    $casosDir = Join-Path $script:DestDir 'tests/cases'
    $expectedFiles = @(Get-ChildItem -Path $casosDir -Filter 'TC-*.md' -File)
    $expectedTotal = $expectedFiles.Count
    $expectedPasaron = 0; $expectedFallaron = 0; $expectedBloqueados = 0
    foreach ($f in $expectedFiles) {
      $text = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
      if ($text -match '\|\s*\*\*Estado\*\*\s*\|\s*Pas[oó]\s*\|') { $expectedPasaron++ }
      elseif ($text -match '\|\s*\*\*Estado\*\*\s*\|\s*Fall[oó]\s*\|') { $expectedFallaron++ }
      elseif ($text -match '\|\s*\*\*Estado\*\*\s*\|\s*Bloqueado\s*\|') { $expectedBloqueados++ }
    }

    $cache = Get-Content (Join-Path $script:DotDir 'tc-summary-cache.json') -Raw | ConvertFrom-Json
    $cache.total | Should -Be $expectedTotal
    $cache.pasaron | Should -Be $expectedPasaron
    $cache.fallaron | Should -Be $expectedFallaron
    $cache.bloqueados | Should -Be $expectedBloqueados
  }

  It 'con cache previo, registrar un TC nuevo incrementa el contador sin releer los TC viejos' {
    & $script:RegisterScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -TcId 'TC-001' -UsId 'US-001' | Out-Null
    $cacheBefore = Get-Content (Join-Path $script:DotDir 'tc-summary-cache.json') -Raw | ConvertFrom-Json
    $cacheBefore.total | Should -Be 1
    $cacheBefore.pasaron | Should -Be 1

    Write-Utf8 (Join-Path $script:DestDir 'tests/cases/TC-001.md') "contenido corrupto sin tabla parseable {{{ | **Estado** | Bloqueado |"
    Write-Utf8 (Join-Path $script:DestDir 'tests/cases/TC-002.md') "# TC-002`n**Relacionado con:** US-001 / AC-001.1`n| **Estado** | Paso |"

    & $script:RegisterScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -TcId 'TC-002' -UsId 'US-001' | Out-Null

    $cacheAfter = Get-Content (Join-Path $script:DotDir 'tc-summary-cache.json') -Raw | ConvertFrom-Json
    $cacheAfter.total | Should -Be 2
    $cacheAfter.pasaron | Should -Be 2
    $cacheAfter.bloqueados | Should -Be 0
  }

  It 'avisa (no revienta) si el US referenciado no existe todavia en traceability.json' {
    $output = & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:RegisterScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -TcId 'TC-001' -UsId 'US-999'
    ($output -join ' ') | Should -Match 'AVISO'
    $LASTEXITCODE | Should -Be 0
  }

  It 'falla limpio si el archivo TC-XXX.md todavia no existe' {
    & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:RegisterScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -TcId 'TC-999' -UsId 'US-001' | Out-Null
    $LASTEXITCODE | Should -Be 1
  }

  It 'agrega una linea JSONL valida a operations-log.jsonl con script/resultado fijos' {
    & $script:RegisterScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -TcId 'TC-001' -UsId 'US-001' -AcIds @('AC-001.1') | Out-Null

    $logPath = Join-Path $script:DotDir 'operations-log.jsonl'
    Test-Path $logPath | Should -Be $true
    $entry = Get-Content $logPath -Raw | ConvertFrom-Json
    $entry.script | Should -Be 'testcase-register.ps1'
    $entry.resultado | Should -Be 'OK'
    $entry.TcId | Should -Be 'TC-001'
    $entry.AcIds | Should -Be @('AC-001.1')
  }

  It 'tres registros consistentes producen un log que pattern-detect.ps1 reconoce como candidato' {
    Write-Utf8 (Join-Path $script:DestDir 'tests/cases/TC-002.md') "# TC-002`n**Relacionado con:** US-001 / AC-001.1`n| **Estado** | Paso |"
    Write-Utf8 (Join-Path $script:DestDir 'tests/cases/TC-003.md') "# TC-003`n**Relacionado con:** US-001 / AC-001.1`n| **Estado** | Paso |"
    & $script:RegisterScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -TcId 'TC-001' -UsId 'US-001' -AcIds @('AC-001.1') | Out-Null
    & $script:RegisterScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -TcId 'TC-002' -UsId 'US-001' -AcIds @('AC-001.1') | Out-Null
    & $script:RegisterScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -TcId 'TC-003' -UsId 'US-001' -AcIds @('AC-001.1') | Out-Null

    $patternDetectScript = Join-Path $script:PluginRoot 'scripts/pattern-detect.ps1'
    $logPath = Join-Path $script:DotDir 'operations-log.jsonl'
    $result = & $patternDetectScript -LogPath $logPath | ConvertFrom-Json
    $result.status | Should -Be 'pass'
    $result.candidatos[0].repeticiones | Should -Be 3
  }

  It 'registra el TC igual aunque .bossdream-project no sea escribible para el log (best-effort)' {
    $dotDirAcl = Join-Path $script:DotDir 'operations-log.jsonl'
    New-Item -ItemType Directory -Force -Path $dotDirAcl | Out-Null

    $output = & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:RegisterScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -TcId 'TC-001' -UsId 'US-001'
    ($output -join ' ') | Should -Match 'AVISO'
    $LASTEXITCODE | Should -Be 0
    $trace = Get-Content (Join-Path $script:DotDir 'traceability.json') -Raw | ConvertFrom-Json
    $trace.stories.'US-001'.tests | Should -Contain 'TC-001'
  }
}
