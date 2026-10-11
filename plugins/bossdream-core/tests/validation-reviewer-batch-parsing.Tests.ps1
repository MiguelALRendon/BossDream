BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:ScaffoldScript = Join-Path $script:PluginRoot 'scripts/project-scaffold.ps1'
  $script:CheckScript = Join-Path $script:PluginRoot 'scripts/validation-check.ps1'

  function New-Sandbox {
    $sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("validation-batch-test-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
    return $sandbox
  }

  function Write-Utf8([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
  }

  function New-TcFixture([string]$Path, [string]$Id, [string]$Escenario) {
    $tc = @"
# $Id — $Escenario
**Relacionado con:** US-001 / AC-001.1
| Campo | Detalle |
|---|---|
| **Escenario** | $Escenario |
| **Precondiciones** | Usuario autenticado con cuenta activa |
| **Datos de prueba** | Cuenta con movimientos recientes |
| **Pasos** | 1. Iniciar sesion 2. Ir a saldo 3. Refrescar |
| **Resultado esperado** | El saldo mostrado coincide con el ultimo movimiento |
| **Resultado obtenido** | El saldo mostrado coincide con el ultimo movimiento |
| **Evidencia** | captura.png |
| **Estado** | Paso |
"@
    Write-Utf8 $Path $tc
  }

  function Initialize-ReadyDocs([string]$DestDir) {
    $requerimientos = "## Reglas de negocio relevantes`n- Los clientes no ven su saldo actualizado.`n## Feature — FEAT-001`n## User Stories — siempre presente`n### US-001 — saldo en tiempo real`nAC-001.1`n## Tabla resumen de trazabilidad`n| FEAT-001 | US-001 | AC-001.1 | TC-001 |"
    Write-Utf8 (Join-Path $DestDir 'requirements.md') $requerimientos

    New-Item -ItemType Directory -Force -Path (Join-Path $DestDir 'tests/cases') | Out-Null
    New-TcFixture (Join-Path $DestDir 'tests/cases/TC-001.md') 'TC-001' 'Consulta de saldo en tiempo real'
    New-TcFixture (Join-Path $DestDir 'tests/cases/TC-002.md') 'TC-002' 'Refresco automatico del saldo'
  }
}

Describe 'bossdream-document-auditor batching — parseo de N veredictos de una tanda (plan.md Increment 4.4)' {

  BeforeEach {
    $script:Sandbox = New-Sandbox
    $env:CLAUDE_PLUGIN_ROOT = $script:PluginRoot
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
    Remove-Item Env:\CLAUDE_PLUGIN_ROOT -ErrorAction SilentlyContinue
  }

  It 'aplica N veredictos de una misma tanda cada uno a su documento exacto, sin cruzarse entre si' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-950' -ProjectName 'Demo Batch' -Classification 'Medio' | Out-Null
    $destDir = Join-Path $script:Sandbox 'bossdream_projects/demo'
    $dotDir = Join-Path $destDir '.bossdream-project'
    Initialize-ReadyDocs $destDir

    & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null

    $verdicts = @{
      'requirements.md' = @{ verdict = 'blocked'; reason = 'razon exclusiva de requerimientos' }
      'tests/test-approach.md' = @{ verdict = 'pass'; reason = 'estrategia ok' }
      'tests/cases/TC-001.md' = @{ verdict = 'blocked'; reason = 'razon exclusiva de TC-001' }
      'tests/cases/TC-002.md' = @{ verdict = 'pass'; reason = 'TC-002 ok' }
    }
    $verdictsPath = Join-Path $dotDir '.validation-semantic-verdicts.json'
    $verdicts | ConvertTo-Json -Depth 6 | Set-Content $verdictsPath -Encoding utf8

    & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -SemanticVerdictsPath $verdictsPath | Out-Null

    $validation = Get-Content (Join-Path $dotDir 'validation.json') -Raw | ConvertFrom-Json

    $validation.documents.'tests/test-approach.md'.status | Should -Be 'verified'
    $validation.documents.'tests/cases/TC-002.md'.status | Should -Be 'verified'

    $validation.documents.'requirements.md'.status | Should -Be 'blocked'
    $validation.documents.'requirements.md'.reason | Should -Be 'razon exclusiva de requerimientos'
    $validation.documents.'tests/cases/TC-001.md'.status | Should -Be 'blocked'
    $validation.documents.'tests/cases/TC-001.md'.reason | Should -Be 'razon exclusiva de TC-001'

    ($validation.documents.'requirements.md'.checks | Where-Object { $_.id -eq 'SEMANTIC' }).findings | Should -Be @('razon exclusiva de requerimientos')
    ($validation.documents.'tests/cases/TC-001.md'.checks | Where-Object { $_.id -eq 'SEMANTIC' }).findings | Should -Be @('razon exclusiva de TC-001')
  }

  It 'un veredicto con nombre de documento inexistente se ignora sin romper la corrida' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-951' -ProjectName 'Demo Batch' -Classification 'Medio' | Out-Null
    $destDir = Join-Path $script:Sandbox 'bossdream_projects/demo'
    $dotDir = Join-Path $destDir '.bossdream-project'
    Initialize-ReadyDocs $destDir

    & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' | Out-Null

    $verdicts = @{
      'requirements.md' = @{ verdict = 'pass'; reason = 'requerimientos ok' }
      'tests/test-approach.md' = @{ verdict = 'pass'; reason = 'estrategia ok' }
      'tests/cases/TC-001.md' = @{ verdict = 'pass'; reason = 'TC-001 ok' }
      'tests/cases/TC-002.md' = @{ verdict = 'pass'; reason = 'TC-002 ok' }
      'tests/cases/TC-999-fantasma.md' = @{ verdict = 'blocked'; reason = 'documento que bossdream-document-auditor inventó, no existe en el proyecto' }
    }
    $verdictsPath = Join-Path $dotDir '.validation-semantic-verdicts.json'
    $verdicts | ConvertTo-Json -Depth 6 | Set-Content $verdictsPath -Encoding utf8

    { & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -SemanticVerdictsPath $verdictsPath | Out-Null } | Should -Not -Throw

    $validation = Get-Content (Join-Path $dotDir 'validation.json') -Raw | ConvertFrom-Json
    $validation.documents.PSObject.Properties.Name | Should -Not -Contain 'tests/cases/TC-999-fantasma.md'
    $validation.documents.'requirements.md'.status | Should -Be 'verified'
    $validation.documents.'tests/test-approach.md'.status | Should -Be 'verified'
    $validation.documents.'tests/cases/TC-001.md'.status | Should -Be 'verified'
    $validation.documents.'tests/cases/TC-002.md'.status | Should -Be 'verified'
  }
}
