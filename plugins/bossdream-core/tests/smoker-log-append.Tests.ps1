BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/smoker-log-append.ps1'

  function New-TempProjectDir {
    $projectDir = Join-Path ([System.IO.Path]::GetTempPath()) ('sla-proj-' + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
    return $projectDir
  }

  function New-VeredictoFile([string]$Veredicto, [array]$Casos) {
    $veredictoPath = Join-Path ([System.IO.Path]::GetTempPath()) ('sla-veredicto-' + [System.Guid]::NewGuid().ToString('N') + '.json')
    $data = [ordered]@{ veredicto = $Veredicto; casos = $Casos }
    ConvertTo-Json -InputObject $data -Depth 10 | Set-Content $veredictoPath -Encoding utf8
    return $veredictoPath
  }

  function Read-JsonArray([string]$Path) {
    $parsed = Get-Content $Path -Raw | ConvertFrom-Json
    return ,@($parsed)
  }
}

Describe 'smoker-log-append.ps1' {

  AfterEach {
    if ($script:TmpProjectDir -and (Test-Path $script:TmpProjectDir)) {
      Remove-Item -Recurse -Force $script:TmpProjectDir -ErrorAction SilentlyContinue
    }
    if ($script:TmpVeredictoPath -and (Test-Path $script:TmpVeredictoPath)) {
      Remove-Item -Force $script:TmpVeredictoPath -ErrorAction SilentlyContinue
    }
  }

  It 'crea smoker-log.json con 1 entrada si no existe' {
    $script:TmpProjectDir = New-TempProjectDir
    $script:TmpVeredictoPath = New-VeredictoFile 'PASS' @(@{ caso = 'input-vacio'; resultado = 'ok' })

    & $script:Script -ProjectDir $script:TmpProjectDir -IncrementId 'increment-2-1' -VeredictoPath $script:TmpVeredictoPath | Out-Null

    $logPath = Join-Path $script:TmpProjectDir '.bossdream-project/smoker-log.json'
    Test-Path $logPath | Should -BeTrue
    $log = Read-JsonArray $logPath
    $log.Count | Should -Be 1
    $log[0].incrementId | Should -Be 'increment-2-1'
    $log[0].veredicto | Should -Be 'PASS'
  }

  It 'agrega una 2a entrada sin pisar la 1a' {
    $script:TmpProjectDir = New-TempProjectDir
    $primerVeredicto = New-VeredictoFile 'PASS' @(@{ caso = 'a' })
    & $script:Script -ProjectDir $script:TmpProjectDir -IncrementId 'increment-1' -VeredictoPath $primerVeredicto | Out-Null
    Remove-Item $primerVeredicto -Force

    $script:TmpVeredictoPath = New-VeredictoFile 'HALLAZGOS' @(@{ caso = 'b' })
    & $script:Script -ProjectDir $script:TmpProjectDir -IncrementId 'increment-2' -VeredictoPath $script:TmpVeredictoPath | Out-Null

    $logPath = Join-Path $script:TmpProjectDir '.bossdream-project/smoker-log.json'
    $log = Read-JsonArray $logPath
    $log.Count | Should -Be 2
    $log[0].incrementId | Should -Be 'increment-1'
    $log[0].veredicto | Should -Be 'PASS'
    $log[1].incrementId | Should -Be 'increment-2'
    $log[1].veredicto | Should -Be 'HALLAZGOS'
  }

  It 'lee el veredicto (incluyendo casos anidados) desde el archivo temporal sin perder datos' {
    $script:TmpProjectDir = New-TempProjectDir
    $casos = @(
      @{ caso = 'sql-injection'; input = "'; DROP TABLE users; --"; esperado = 'rechazado'; obtenido = 'rechazado' },
      @{ caso = 'unicode'; input = 'ñáéíóú漢字'; esperado = 'aceptado'; obtenido = 'aceptado' }
    )
    $script:TmpVeredictoPath = New-VeredictoFile 'HALLAZGOS' $casos

    & $script:Script -ProjectDir $script:TmpProjectDir -IncrementId 'increment-2-4' -VeredictoPath $script:TmpVeredictoPath | Out-Null

    $logPath = Join-Path $script:TmpProjectDir '.bossdream-project/smoker-log.json'
    $log = Read-JsonArray $logPath
    $log[0].casos.Count | Should -Be 2
    $log[0].casos[0].input | Should -Be "'; DROP TABLE users; --"
    $log[0].casos[1].input | Should -Be 'ñáéíóú漢字'
  }
}
