BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/sobriety-audit.ps1'
  $script:Fixture = Join-Path $script:PluginRoot 'tests/fixtures/components-registry.json'
}

Describe 'sobriety-audit.ps1' {

  It 'TC-123: reporta 3 componentes con nombre/tipo/justificado/razon' {
    $result = & $script:Script -Scope framework -Components $script:Fixture | ConvertFrom-Json
    $result.componentes.Count | Should -Be 3
    foreach ($c in $result.componentes) {
      $c.nombre | Should -Not -BeNullOrEmpty
      $c.tipo | Should -Not -BeNullOrEmpty
      $c.razon | Should -Not -BeNullOrEmpty
    }
  }

  It 'TC-123: assertion-breaker es justificado false y su razon cita bossdream-qa-auditor' {
    $result = & $script:Script -Scope framework -Components $script:Fixture | ConvertFrom-Json
    $entry = $result.componentes | Where-Object { $_.nombre -eq 'assertion-breaker' }
    $entry.justificado | Should -Be $false
    $entry.razon | Should -Match 'bossdream-qa-auditor'
  }

  It 'TC-123: bossdream-qa-auditor y bossdream-traceability-watcher son justificado true' {
    $result = & $script:Script -Scope framework -Components $script:Fixture | ConvertFrom-Json
    ($result.componentes | Where-Object { $_.nombre -eq 'bossdream-qa-auditor' }).justificado | Should -Be $true
    ($result.componentes | Where-Object { $_.nombre -eq 'bossdream-traceability-watcher' }).justificado | Should -Be $true
  }

  It 'exit code 0 cuando el registro se pudo leer' {
    & $script:Script -Scope framework -Components $script:Fixture | Out-Null
    $LASTEXITCODE | Should -Be 0
  }

  It 'reporta blocked y exit code 1 cuando components-registry.json no existe' {
    $missing = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + '.json')
    $result = & $script:Script -Scope framework -Components $missing | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $LASTEXITCODE | Should -Be 1
  }

  It 'no infiere redundancia por descripcion similar sin reemplaza_a explicito' {
    $sinCampo = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + '.json')
    @{ componentes = @(
        @{ nombre = 'a'; tipo = 'agente'; descripcion = 'hace X'; reemplaza_a = $null }
        @{ nombre = 'b'; tipo = 'agente'; descripcion = 'hace X'; reemplaza_a = $null }
      )
    } | ConvertTo-Json -Depth 10 | Set-Content $sinCampo -Encoding utf8
    $result = & $script:Script -Scope framework -Components $sinCampo | ConvertFrom-Json
    ($result.componentes | Where-Object { $_.nombre -eq 'a' }).justificado | Should -Be $true
    ($result.componentes | Where-Object { $_.nombre -eq 'b' }).justificado | Should -Be $true
    Remove-Item $sinCampo -Force -ErrorAction SilentlyContinue
  }

  It 'sin -Components introspecciona el repo real y todos los componentes son justificado true' {
    $result = & $script:Script -Scope framework | ConvertFrom-Json
    $result.componentes.Count | Should -BeGreaterThan 0
    ($result.componentes | Where-Object { $_.justificado -eq $false }).Count | Should -Be 0
  }

  It 'rechaza un -Scope distinto de framework' {
    { & $script:Script -Scope global -Components $script:Fixture } | Should -Throw
  }
}
