BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:CheckScript = Join-Path $script:PluginRoot 'scripts/validation-exemption-check.ps1'

  function New-Sandbox {
    $sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("validation-exemption-check-test-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
    return $sandbox
  }

  function New-ValidationFixture([string]$Sandbox, [string]$Slug, [hashtable]$Validation) {
    $dotDir = Join-Path $Sandbox "bossdream_projects/$Slug/.bossdream-project"
    New-Item -ItemType Directory -Force -Path $dotDir | Out-Null
    $validationPath = Join-Path $dotDir 'validation.json'
    $Validation | ConvertTo-Json -Depth 10 | Set-Content $validationPath -Encoding utf8
    return $validationPath
  }
}

Describe 'validation-exemption-check.ps1' {

  BeforeEach {
    $script:Sandbox = New-Sandbox
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
  }

  It 'documento sin bloqueos -> checksBloqueados vacio' {
    New-ValidationFixture $script:Sandbox 'demo' @{
      overallStatus = 'ready'
      exemptions = @()
      documents = @{
        'understanding.md' = @{
          status = 'verified'
          checks = @(
            @{ id = 'VALE'; status = 'pass'; findings = @() },
            @{ id = 'STRUCTURE'; status = 'pass'; findings = @() },
            @{ id = 'SEMANTIC'; status = 'pass'; findings = @('ok') }
          )
          intentosBloqueado = 0
          ultimoCheckBloqueado = $null
        }
      }
    } | Out-Null

    $out = & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -File 'understanding.md' | Select-Object -Last 1
    $parsed = $out | ConvertFrom-Json

    $parsed.status | Should -Be 'ok'
    @($parsed.checksBloqueados).Count | Should -Be 0
    $parsed.intentosBloqueado | Should -Be 0
  }

  It 'documento bloqueado con intentosBloqueado/ultimoCheckBloqueado reales -> los devuelve tal cual' {
    New-ValidationFixture $script:Sandbox 'demo' @{
      overallStatus = 'blocked'
      exemptions = @()
      documents = @{
        'tests/cases/TC-77.md' = @{
          status = 'blocked'
          checks = @(
            @{ id = 'VALE'; status = 'pass'; findings = @() },
            @{ id = 'STRUCTURE'; status = 'blocked'; findings = @('falta el campo Resultado obtenido') }
          )
          intentosBloqueado = 4
          ultimoCheckBloqueado = 'STRUCTURE'
        }
      }
    } | Out-Null

    $out = & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -File 'tests/cases/TC-77.md' | Select-Object -Last 1
    $parsed = $out | ConvertFrom-Json

    $parsed.status | Should -Be 'ok'
    @($parsed.checksBloqueados).Count | Should -Be 1
    $parsed.checksBloqueados[0].id | Should -Be 'STRUCTURE'
    $parsed.checksBloqueados[0].findings | Should -Contain 'falta el campo Resultado obtenido'
    $parsed.intentosBloqueado | Should -Be 4
    $parsed.ultimoCheckBloqueado | Should -Be 'STRUCTURE'
  }

  It 'documento con exemptions ya existentes -> las devuelve sin modificarlas' {
    $validationPath = New-ValidationFixture $script:Sandbox 'demo' @{
      overallStatus = 'ready'
      exemptions = @(
        @{ file = 'tests/cases/TC-77.md'; codes = @('SEMANTIC'); motivo = 'el AC probado no requiere validacion semantica adicional'; quien = 'tester'; cuando = '2026-01-01T00:00:00Z' }
      )
      documents = @{
        'tests/cases/TC-77.md' = @{
          status = 'verified'
          checks = @(
            @{ id = 'SEMANTIC'; status = 'EXEMPT'; findings = @('el AC probado no requiere validacion semantica adicional') }
          )
          intentosBloqueado = 0
          ultimoCheckBloqueado = $null
        }
      }
    }
    $before = Get-Content $validationPath -Raw

    $out = & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -File 'tests/cases/TC-77.md' | Select-Object -Last 1
    $parsed = $out | ConvertFrom-Json

    @($parsed.exemptions).Count | Should -Be 1
    $parsed.exemptions[0].file | Should -Be 'tests/cases/TC-77.md'
    $parsed.exemptions[0].codes | Should -Contain 'SEMANTIC'
    $parsed.exemptions[0].motivo | Should -Be 'el AC probado no requiere validacion semantica adicional'

    (Get-Content $validationPath -Raw) | Should -Be $before
  }

  It 'documento que no existe en validation.json.documents -> status not-found' {
    New-ValidationFixture $script:Sandbox 'demo' @{
      overallStatus = 'ready'
      exemptions = @()
      documents = @{
        'understanding.md' = @{ status = 'verified'; checks = @() }
      }
    } | Out-Null

    $out = & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -File 'tests/cases/TC-999.md' | Select-Object -Last 1
    $parsed = $out | ConvertFrom-Json

    $parsed.status | Should -Be 'not-found'
    @($parsed.findings).Count | Should -Be 0
  }

  It 'nunca escribe validation.json (contenido y mtime sin cambios tras correr)' {
    $validationPath = New-ValidationFixture $script:Sandbox 'demo' @{
      overallStatus = 'blocked'
      exemptions = @()
      documents = @{
        'tests/cases/TC-77.md' = @{
          status = 'blocked'
          checks = @(
            @{ id = 'STRUCTURE'; status = 'blocked'; findings = @('falta campo') }
          )
          intentosBloqueado = 2
          ultimoCheckBloqueado = 'STRUCTURE'
        }
      }
    }
    $beforeContent = Get-Content $validationPath -Raw
    $beforeMtime = (Get-Item $validationPath).LastWriteTimeUtc

    & $script:CheckScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -File 'tests/cases/TC-77.md' | Out-Null

    (Get-Content $validationPath -Raw) | Should -Be $beforeContent
    (Get-Item $validationPath).LastWriteTimeUtc | Should -Be $beforeMtime
  }
}
