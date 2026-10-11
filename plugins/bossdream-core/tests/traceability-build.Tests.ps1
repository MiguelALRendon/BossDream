BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/traceability-build.ps1'

  function Write-Utf8([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
  }
}

Describe 'traceability-build.ps1' {

  BeforeEach {
    $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("trace-build-test-" + [System.Guid]::NewGuid().ToString('N'))
    $script:DestDir = Join-Path $script:Sandbox 'bossdream_projects/demo'
    $script:DotDir = Join-Path $script:DestDir '.bossdream-project'
    New-Item -ItemType Directory -Force -Path $script:DotDir | Out-Null
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
  }

  It 'reconstruye Feature/US/AC (Medio, sin Epic) desde requirements.md' {
    $req = @"
## Feature — algo
**FEAT-001 — Consulta de saldo**

## User Stories
### US-001 — ver saldo
- **AC-001.1:** criterio uno
- **AC-001.2:** criterio dos
"@
    Write-Utf8 (Join-Path $script:DestDir 'requirements.md') $req

    & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null

    $trace = Get-Content (Join-Path $script:DotDir 'traceability.json') -Raw | ConvertFrom-Json
    $trace.features.'FEAT-001'.stories.'US-001'.acceptanceCriteria | Should -Contain 'AC-001.1'
    $trace.features.'FEAT-001'.stories.'US-001'.acceptanceCriteria | Should -Contain 'AC-001.2'
  }

  It 'reconstruye Epic -> Feature -> US (Complejo)' {
    $req = @"
## Epic
**EPIC-001 — Facturacion**

## Feature
**FEAT-001 — Timbrado**

### US-001 — timbrar factura
- **AC-001.1:** criterio
"@
    Write-Utf8 (Join-Path $script:DestDir 'requirements.md') $req

    & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null

    $trace = Get-Content (Join-Path $script:DotDir 'traceability.json') -Raw | ConvertFrom-Json
    $trace.epics.'EPIC-001'.features.'FEAT-001'.stories.'US-001'.acceptanceCriteria | Should -Contain 'AC-001.1'
  }

  It 'enlaza un TC-XXX.md a su US via "Relacionado con"' {
    $req = @"
## User Stories
### US-001 — ver saldo
- **AC-001.1:** criterio
"@
    Write-Utf8 (Join-Path $script:DestDir 'requirements.md') $req

    New-Item -ItemType Directory -Force -Path (Join-Path $script:DestDir 'tests/cases') | Out-Null
    Write-Utf8 (Join-Path $script:DestDir 'tests/cases/TC-001.md') "# TC-001`n**Relacionado con:** US-001 / AC-001.1"

    & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null

    $trace = Get-Content (Join-Path $script:DotDir 'traceability.json') -Raw | ConvertFrom-Json
    $trace.stories.'US-001'.tests | Should -Contain 'TC-001'
  }

  It 'el idIndex resuelve el mismo nodo que la busqueda DFS original, en varias ramas Epic/Feature/US/AC' {
    $req = @"
## Epic
**EPIC-001 — Facturacion**

## Feature
**FEAT-001 — Timbrado**

### US-001 — timbrar factura
- **AC-001.1:** criterio uno

## Epic
**EPIC-002 — Pagos**

## Feature
**FEAT-002 — Conciliacion**

### US-002 — conciliar pago
- **AC-002.1:** criterio dos
"@
    Write-Utf8 (Join-Path $script:DestDir 'requirements.md') $req

    New-Item -ItemType Directory -Force -Path (Join-Path $script:DestDir 'tests/cases') | Out-Null
    Write-Utf8 (Join-Path $script:DestDir 'tests/cases/TC-001.md') "# TC-001`n**Relacionado con:** US-001 / AC-001.1"
    Write-Utf8 (Join-Path $script:DestDir 'tests/cases/TC-002.md') "# TC-002`n**Relacionado con:** US-002 / AC-002.1"

    & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null

    $trace = Get-Content (Join-Path $script:DotDir 'traceability.json') -Raw | ConvertFrom-Json
    $usUno = $trace.epics.'EPIC-001'.features.'FEAT-001'.stories.'US-001'
    $usDos = $trace.epics.'EPIC-002'.features.'FEAT-002'.stories.'US-002'

    $usUno.acceptanceCriteria | Should -Be @('AC-001.1')
    $usUno.tests | Should -Be @('TC-001')
    $usDos.acceptanceCriteria | Should -Be @('AC-002.1')
    $usDos.tests | Should -Be @('TC-002')
  }

  It 'es idempotente: correrlo dos veces no duplica IDs' {
    $req = "## User Stories`n### US-001 — ver saldo`n- **AC-001.1:** criterio"
    Write-Utf8 (Join-Path $script:DestDir 'requirements.md') $req

    & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null
    & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null

    $trace = Get-Content (Join-Path $script:DotDir 'traceability.json') -Raw | ConvertFrom-Json
    @($trace.stories.'US-001'.acceptanceCriteria | Where-Object { $_ -eq 'AC-001.1' }).Count | Should -Be 1
  }

  It 'la 2da corrida sin cambios no toca el mtime de requirements.md ni de traceability.json (cache hit)' {
    $req = "## User Stories`n### US-001 — ver saldo`n- **AC-001.1:** criterio"
    Write-Utf8 (Join-Path $script:DestDir 'requirements.md') $req

    & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null
    $reqTimeAfterFirst = (Get-Item (Join-Path $script:DestDir 'requirements.md')).LastWriteTimeUtc
    $traceTimeAfterFirst = (Get-Item (Join-Path $script:DotDir 'traceability.json')).LastWriteTimeUtc

    Start-Sleep -Milliseconds 50
    $secondOutput = & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo'
    $reqTimeAfterSecond = (Get-Item (Join-Path $script:DestDir 'requirements.md')).LastWriteTimeUtc
    $traceTimeAfterSecond = (Get-Item (Join-Path $script:DotDir 'traceability.json')).LastWriteTimeUtc

    $reqTimeAfterSecond | Should -Be $reqTimeAfterFirst
    $traceTimeAfterSecond | Should -Be $traceTimeAfterFirst
    $secondOutput | Should -Match 'cache hit'
  }

  It 'detecta un cambio real (nuevo AC agregado) y reconstruye traceability.json en consecuencia' {
    $req1 = "## User Stories`n### US-001 — ver saldo`n- **AC-001.1:** criterio"
    Write-Utf8 (Join-Path $script:DestDir 'requirements.md') $req1
    & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null

    $req2 = "## User Stories`n### US-001 — ver saldo`n- **AC-001.1:** criterio`n- **AC-001.2:** criterio nuevo"
    Write-Utf8 (Join-Path $script:DestDir 'requirements.md') $req2
    & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null

    $trace = Get-Content (Join-Path $script:DotDir 'traceability.json') -Raw | ConvertFrom-Json
    $trace.stories.'US-001'.acceptanceCriteria | Should -Contain 'AC-001.2'
  }

  It 'no revienta si requirements.md no existe todavia' {
    & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null
    $LASTEXITCODE | Should -Be 0
  }

  Context 'sincronizacion de columna Estado en la tabla de trazabilidad' {

    BeforeEach {
      New-Item -ItemType Directory -Force -Path (Join-Path $script:DestDir 'tests/cases') | Out-Null
    }

    It 'una fila con su TC en Paso pasa a Implementado' {
      $req = @"
## Tabla resumen de trazabilidad

| Epic | Feature | User Story | AC | Test Case | Prioridad | Estado |
|---|---|---|---|---|---|---|
| EPIC-001 | FEAT-001 | US-001 | AC-001.1 | TC-001 | Alta | Definido |
"@
      Write-Utf8 (Join-Path $script:DestDir 'requirements.md') $req
      Write-Utf8 (Join-Path $script:DestDir 'tests/cases/TC-001.md') "# TC-001`n| **Estado** | Paso |"

      & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null

      $updated = Get-Content (Join-Path $script:DestDir 'requirements.md') -Raw
      $updated | Should -Match '\| EPIC-001 \| FEAT-001 \| US-001 \| AC-001\.1 \| TC-001 \| Alta \| Implementado \|'
    }

    It 'una fila con su TC en Bloqueado se queda en Definido' {
      $req = @"
## Tabla resumen de trazabilidad

| Epic | Feature | User Story | AC | Test Case | Prioridad | Estado |
|---|---|---|---|---|---|---|
| EPIC-001 | FEAT-001 | US-001 | AC-001.1 | TC-001 | Alta | Definido |
"@
      Write-Utf8 (Join-Path $script:DestDir 'requirements.md') $req
      Write-Utf8 (Join-Path $script:DestDir 'tests/cases/TC-001.md') "# TC-001`n| **Estado** | Bloqueado |"

      & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null

      $updated = Get-Content (Join-Path $script:DestDir 'requirements.md') -Raw
      $updated | Should -Match '\| EPIC-001 \| FEAT-001 \| US-001 \| AC-001\.1 \| TC-001 \| Alta \| Definido \|'
    }

    It 'una fila con 2 TC, uno Paso y otro Bloqueado, se queda en Definido (todos deben pasar)' {
      $req = @"
## Tabla resumen de trazabilidad

| Epic | Feature | User Story | AC | Test Case | Prioridad | Estado |
|---|---|---|---|---|---|---|
| EPIC-001 | FEAT-001 | US-001 | AC-001.1 | TC-001, TC-002 | Alta | Definido |
"@
      Write-Utf8 (Join-Path $script:DestDir 'requirements.md') $req
      Write-Utf8 (Join-Path $script:DestDir 'tests/cases/TC-001.md') "# TC-001`n| **Estado** | Paso |"
      Write-Utf8 (Join-Path $script:DestDir 'tests/cases/TC-002.md') "# TC-002`n| **Estado** | Bloqueado |"

      & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null

      $updated = Get-Content (Join-Path $script:DestDir 'requirements.md') -Raw
      $updated | Should -Match '\| EPIC-001 \| FEAT-001 \| US-001 \| AC-001\.1 \| TC-001, TC-002 \| Alta \| Definido \|'
    }

    It 'es idempotente: correrlo dos veces sobre la misma tabla no cambia nada en la 2da corrida' {
      $req = @"
## Tabla resumen de trazabilidad

| Epic | Feature | User Story | AC | Test Case | Prioridad | Estado |
|---|---|---|---|---|---|---|
| EPIC-001 | FEAT-001 | US-001 | AC-001.1 | TC-001 | Alta | Definido |
"@
      Write-Utf8 (Join-Path $script:DestDir 'requirements.md') $req
      Write-Utf8 (Join-Path $script:DestDir 'tests/cases/TC-001.md') "# TC-001`n| **Estado** | Paso |"

      & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null
      $afterFirst = Get-Content (Join-Path $script:DestDir 'requirements.md') -Raw
      & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null
      $afterSecond = Get-Content (Join-Path $script:DestDir 'requirements.md') -Raw

      $afterSecond | Should -Be $afterFirst
    }
  }
}
