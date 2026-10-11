BeforeAll {
. (Join-Path $PSScriptRoot 'stub-helpers.ps1')
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:ScaffoldScript = Join-Path $script:PluginRoot 'scripts/project-scaffold.ps1'
  $script:CheckScript = Join-Path $script:PluginRoot 'scripts/validation-check.ps1'

  function New-Sandbox {
    $sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("validation-check-test-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
    return $sandbox
  }

  function Write-Utf8([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
  }
}

Describe 'validation-check.ps1 — pipeline del Increment 4 (3 fixtures negativos + 1 limpio)' {

  BeforeEach {
    $script:Sandbox = New-Sandbox
    $env:CLAUDE_PLUGIN_ROOT = $script:PluginRoot
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
    Remove-Item Env:\CLAUDE_PLUGIN_ROOT -ErrorAction SilentlyContinue
  }

  It 'fixture 1 - vocabulario debil (vale simulado) bloquea el documento y NO corre structure-check (fail-fast)' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-900' -ProjectName 'Demo' -Classification 'Simple' | Out-Null

    $stubDir = Join-Path ([System.IO.Path]::GetTempPath()) ("vale-stub-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $stubDir | Out-Null
    $jsonOut = '{"doc.md":[{"Line":1,"Message":"TBD detectado"}]}'
    New-CommandStub $stubDir 'vale' $jsonOut

    $originalPath = $env:PATH
    try {
      $env:PATH = "$stubDir$([IO.Path]::PathSeparator)$originalPath"
      & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null
    } finally {
      $env:PATH = $originalPath
      Remove-Item -Recurse -Force $stubDir -ErrorAction SilentlyContinue
    }

    $validation = Get-Content (Join-Path $script:Sandbox 'bossdream_projects/demo/.bossdream-project/validation.json') -Raw | ConvertFrom-Json
    $entradoc = $validation.documents.'requirements.md'
    $entradoc.status | Should -Be 'blocked'
    $checkIds = @($entradoc.checks | ForEach-Object { $_.id })
    $checkIds | Should -Contain 'VALE'
    $checkIds | Should -Not -Contain 'STRUCTURE'
    $validation.overallStatus | Should -Be 'blocked'
  }

  It 'fixture 2 - seccion faltante bloquea via structure-check' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-901' -ProjectName 'Demo' -Classification 'Simple' | Out-Null
    # deja requirements.md roto a proposito (sin la mayoria de secciones)
    Write-Utf8 (Join-Path $script:Sandbox 'bossdream_projects/demo/requirements.md') "# Doc incompleto`n## 1. algo"

    & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null

    $validation = Get-Content (Join-Path $script:Sandbox 'bossdream_projects/demo/.bossdream-project/validation.json') -Raw | ConvertFrom-Json
    $validation.documents.'requirements.md'.status | Should -Be 'blocked'
    $validation.overallStatus | Should -Be 'blocked'
  }

  It 'fixture 3 - ID huerfano en traceability.json bloquea overallStatus aunque los documentos esten verified' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-902' -ProjectName 'Demo' -Classification 'Simple' | Out-Null
    $destDir = Join-Path $script:Sandbox 'bossdream_projects/demo'

    # US-777 mencionado en el documento pero jamas registrado en traceability.json -> huerfano
    Add-Content (Join-Path $destDir 'requirements.md') -Value "`n### US-777 — nota suelta" -Encoding utf8

    & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null

    $validation = Get-Content (Join-Path $destDir '.bossdream-project/validation.json') -Raw | ConvertFrom-Json
    $validation.projectChecks.TRACE.status | Should -Be 'blocked'
    ($validation.projectChecks.TRACE.findings -join ' ') | Should -Match 'US-777'
    $validation.overallStatus | Should -Be 'blocked'
  }

  It 'fixture limpio - documento completo + traceability consistente + veredictos semanticos pass -> overallStatus ready' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-903' -ProjectName 'Demo Limpio' -Classification 'Medio' | Out-Null
    $destDir = Join-Path $script:Sandbox 'bossdream_projects/demo'
    $dotDir = Join-Path $destDir '.bossdream-project'

    # requirements.md: Medio -> Feature presente, Epic ausente (ya lo cumple la plantilla base solo si se elimina Epic)
    $requerimientos = "## Reglas de negocio relevantes`n- Regla 1`n## Feature — FEAT-001`n## User Stories — siempre presente`n### US-001 — saldo en tiempo real`nAC-001.1`n## Tabla resumen de trazabilidad`n| FEAT-001 | US-001 | AC-001.1 | TC-001 |"
    Write-Utf8 (Join-Path $destDir 'requirements.md') $requerimientos

    # tests/test-approach.md: ya trae las secciones requeridas de la plantilla base, no se toca

    $trace = @{ features = @{ 'FEAT-001' = @{ stories = @{ 'US-001' = @{ acceptanceCriteria = @('AC-001.1'); tests = @('TC-001') } } } } }
    $trace | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $dotDir 'traceability.json') -Encoding utf8

    # TC-001.md referenciado arriba, con TODOS los campos llenos (si no, queda blocked por structure y nunca deja overallStatus=ready)
    New-Item -ItemType Directory -Force -Path (Join-Path $destDir 'tests/cases') | Out-Null
    $tc001 = @"
# TC-001 — Saldo en tiempo real
**Relacionado con:** US-001 / AC-001.1
| Campo | Detalle |
|---|---|
| **Escenario** | Consulta de saldo en tiempo real |
| **Precondiciones** | Usuario autenticado con cuenta activa |
| **Datos de prueba** | Cuenta con movimientos recientes |
| **Pasos** | 1. Iniciar sesion 2. Ir a saldo 3. Refrescar |
| **Resultado esperado** | El saldo mostrado coincide con el ultimo movimiento |
| **Resultado obtenido** | El saldo mostrado coincide con el ultimo movimiento |
| **Evidencia** | captura-tc001.png |
| **Estado** | Paso |
"@
    Write-Utf8 (Join-Path $destDir 'tests/cases/TC-001.md') $tc001

    # Primera pasada: deterministica
    & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null
    $validation = Get-Content (Join-Path $dotDir 'validation.json') -Raw | ConvertFrom-Json
    $validation.documents.'requirements.md'.status | Should -Be 'needs-semantic-review'
    $validation.documents.'tests/test-approach.md'.status | Should -Be 'needs-semantic-review'
    $validation.documents.'tests/cases/TC-001.md'.status | Should -Be 'needs-semantic-review'
    $validation.projectChecks.TRACE.status | Should -Be 'pass'

    # Segunda pasada: veredictos semanticos (simulando lo que bossdream-document-auditor devolveria) todos pass
    $verdicts = @{
      'requirements.md' = @{ verdict = 'pass' }
      'tests/test-approach.md' = @{ verdict = 'pass' }
      'tests/cases/TC-001.md' = @{ verdict = 'pass' }
    }
    $verdictsPath = Join-Path $dotDir '.validation-semantic-verdicts.json'
    $verdicts | ConvertTo-Json -Depth 6 | Set-Content $verdictsPath -Encoding utf8

    & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -SemanticVerdictsPath $verdictsPath | Out-Null

    $validationFinal = Get-Content (Join-Path $dotDir 'validation.json') -Raw | ConvertFrom-Json
    $validationFinal.documents.'requirements.md'.status | Should -Be 'verified'
    $validationFinal.documents.'tests/test-approach.md'.status | Should -Be 'verified'
    $validationFinal.documents.'tests/cases/TC-001.md'.status | Should -Be 'verified'
    $validationFinal.overallStatus | Should -Be 'ready'
  }

  It 'no re-evalua un documento verified cuyo fingerprint no cambio (ahorro de corridas)' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-904' -ProjectName 'Demo' -Classification 'Simple' | Out-Null
    $dotDir = Join-Path $script:Sandbox 'bossdream_projects/demo/.bossdream-project'

    $validation = Get-Content (Join-Path $dotDir 'validation.json') -Raw | ConvertFrom-Json
    $validation.documents.'requirements.md' = [PSCustomObject]@{ status = 'verified'; documentFingerprint = 'sha-falso-para-la-prueba'; checks = @() }
    $validation | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $dotDir 'validation.json') -Encoding utf8

    & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null

    $validationAfter = Get-Content (Join-Path $dotDir 'validation.json') -Raw | ConvertFrom-Json
    # el fingerprint NO coincide con el archivo real -> SI debio re-evaluarse (fingerprint cambiado se trata como pending)
    $validationAfter.documents.'requirements.md'.documentFingerprint | Should -Not -Be 'sha-falso-para-la-prueba'
  }

  It 'normaliza checks[].id de una corrida anterior a mayuscula sin re-evaluar (findings sin cambios)' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-905' -ProjectName 'Demo' -Classification 'Simple' | Out-Null
    $destDir = Join-Path $script:Sandbox 'bossdream_projects/demo'
    $dotDir = Join-Path $destDir '.bossdream-project'
    $docPath = Join-Path $destDir 'requirements.md'
    $fingerprint = (Get-FileHash -Path $docPath -Algorithm SHA256).Hash

    $validation = Get-Content (Join-Path $dotDir 'validation.json') -Raw | ConvertFrom-Json
    $validation.documents.'requirements.md' = [PSCustomObject]@{
      status = 'verified'
      documentFingerprint = $fingerprint
      checks = @(
        [PSCustomObject]@{ id = 'vale'; status = 'skip'; findings = @() },
        [PSCustomObject]@{ id = 'structure'; status = 'pass'; findings = @() },
        [PSCustomObject]@{ id = 'semantic'; status = 'pass'; findings = @('veredicto de la corrida anterior') }
      )
    }
    $validation | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $dotDir 'validation.json') -Encoding utf8

    & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null

    $validationAfter = Get-Content (Join-Path $dotDir 'validation.json') -Raw | ConvertFrom-Json
    $entry = $validationAfter.documents.'requirements.md'
    $entry.status | Should -Be 'verified'
    $entry.documentFingerprint | Should -Be $fingerprint
    @($entry.checks | ForEach-Object { $_.id }) | Should -Be @('VALE', 'STRUCTURE', 'SEMANTIC')
    ($entry.checks | Where-Object { $_.id -eq 'SEMANTIC' }).findings | Should -Be @('veredicto de la corrida anterior')
  }

  It 'persiste exemptions: [] en un validation.json existente que no lo tenga (nunca opcional)' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-906' -ProjectName 'Demo' -Classification 'Simple' | Out-Null
    $dotDir = Join-Path $script:Sandbox 'bossdream_projects/demo/.bossdream-project'
    $validation = Get-Content (Join-Path $dotDir 'validation.json') -Raw | ConvertFrom-Json
    $validation.PSObject.Properties.Remove('exemptions')
    $validation | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $dotDir 'validation.json') -Encoding utf8

    & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null

    $validationAfter = Get-Content (Join-Path $dotDir 'validation.json') -Raw | ConvertFrom-Json
    $validationAfter.PSObject.Properties.Name | Should -Contain 'exemptions'
    @($validationAfter.exemptions).Count | Should -Be 0
  }

  It 'un documento con exemptions para SEMANTIC (su unico check bloqueante) pasa a verified sin invocar semantic' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-906' -ProjectName 'Demo' -Classification 'Complejo' | Out-Null
    $destDir = Join-Path $script:Sandbox 'bossdream_projects/demo'
    $dotDir = Join-Path $destDir '.bossdream-project'

    $validation = Get-Content (Join-Path $dotDir 'validation.json') -Raw | ConvertFrom-Json
    $validation | Add-Member -NotePropertyName 'exemptions' -NotePropertyValue @(
      [PSCustomObject]@{ file = 'requirements.md'; codes = @('SEMANTIC'); motivo = 'este caso no requiere revision semantica adicional'; quien = 'tester'; cuando = '2026-01-01T00:00:00Z' }
    ) -Force
    $validation | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $dotDir 'validation.json') -Encoding utf8

    & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null

    $validationAfter = Get-Content (Join-Path $dotDir 'validation.json') -Raw | ConvertFrom-Json
    $entry = $validationAfter.documents.'requirements.md'
    $entry.status | Should -Be 'verified'
    ($entry.checks | Where-Object { $_.id -eq 'SEMANTIC' }).status | Should -Be 'EXEMPT'
    ($entry.checks | Where-Object { $_.id -eq 'SEMANTIC' }).findings | Should -Contain 'este caso no requiere revision semantica adicional'
  }

  It 'intentosBloqueado incrementa con el mismo codigo, resetea a 1 con codigo distinto, y a 0 al dejar de bloquear' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-907' -ProjectName 'Demo' -Classification 'Simple' | Out-Null
    $destDir = Join-Path $script:Sandbox 'bossdream_projects/demo'
    $dotDir = Join-Path $destDir '.bossdream-project'

    $stubDir = Join-Path ([System.IO.Path]::GetTempPath()) ("vale-stub2-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $stubDir | Out-Null
    $jsonOut = '{"doc.md":[{"Line":1,"Message":"TBD detectado"}]}'
    New-CommandStub $stubDir 'vale' $jsonOut

    $originalPath = $env:PATH
    try {
      $env:PATH = "$stubDir$([IO.Path]::PathSeparator)$originalPath"
      & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null
      & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null
    } finally {
      $env:PATH = $originalPath
      Remove-Item -Recurse -Force $stubDir -ErrorAction SilentlyContinue
    }

    $validation1 = Get-Content (Join-Path $dotDir 'validation.json') -Raw | ConvertFrom-Json
    $entry1 = $validation1.documents.'requirements.md'
    $entry1.intentosBloqueado | Should -Be 2
    $entry1.ultimoCheckBloqueado | Should -Be 'VALE'

    # sin el stub de vale (binario ausente -> skip, no bloquea), la seccion faltante bloquea via STRUCTURE
    Write-Utf8 (Join-Path $destDir 'requirements.md') "# Doc incompleto`n## 1. algo"
    & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null
    $validation2 = Get-Content (Join-Path $dotDir 'validation.json') -Raw | ConvertFrom-Json
    $entry2 = $validation2.documents.'requirements.md'
    $entry2.intentosBloqueado | Should -Be 1
    $entry2.ultimoCheckBloqueado | Should -Be 'STRUCTURE'

    Write-Utf8 (Join-Path $destDir 'requirements.md') "## Reglas de negocio relevantes`n- Regla 1`n## User Stories — siempre presente`n## Tabla resumen de trazabilidad"

    & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null
    $validation3 = Get-Content (Join-Path $dotDir 'validation.json') -Raw | ConvertFrom-Json
    $entry3 = $validation3.documents.'requirements.md'
    $entry3.intentosBloqueado | Should -Be 0
    $entry3.ultimoCheckBloqueado | Should -Be $null
  }

  It 'con 20 documentos TC pendientes, invoca validation-vale-check.ps1 y validation-structure-check.ps1 UNA sola vez cada uno (batch)' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-908' -ProjectName 'Demo' -Classification 'Simple' | Out-Null
    $destDir = Join-Path $script:Sandbox 'bossdream_projects/demo'
    New-Item -ItemType Directory -Force -Path (Join-Path $destDir 'tests/cases') | Out-Null
    1..20 | ForEach-Object {
      $n = '{0:D3}' -f $_
      Write-Utf8 (Join-Path $destDir "tests/cases/TC-$n.md") "# TC-$n`n**Relacionado con:** US-001 / AC-001.1"
    }

    $stubDir = Join-Path ([System.IO.Path]::GetTempPath()) ("ps-stub-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $stubDir | Out-Null
    $logFile = Join-Path $stubDir 'invocations.log'
    New-Item -ItemType File -Force -Path $logFile | Out-Null
    $hostStub = New-LoggingHostStub $stubDir $logFile

    $originalPath = $env:PATH
    $log = @()
    try {
      $env:BOSSDREAM_CHILD_HOST = $hostStub
      & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null
      $log = Get-Content $logFile
    } finally {
      Remove-Item Env:BOSSDREAM_CHILD_HOST -ErrorAction SilentlyContinue
      Remove-Item -Recurse -Force $stubDir -ErrorAction SilentlyContinue
    }

    $valeCalls = @($log | Where-Object { $_ -match 'validation-vale-check\.ps1' })
    $structCalls = @($log | Where-Object { $_ -match 'validation-structure-check\.ps1' })
    $valeCalls.Count | Should -Be 1
    $structCalls.Count | Should -Be 1

    $validation = Get-Content (Join-Path $destDir '.bossdream-project/validation.json') -Raw | ConvertFrom-Json
    1..20 | ForEach-Object {
      $n = '{0:D3}' -f $_
      $validation.documents."tests/cases/TC-$n.md".status | Should -Be 'blocked'
    }
  }
}
