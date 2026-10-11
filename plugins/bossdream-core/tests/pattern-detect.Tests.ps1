BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/pattern-detect.ps1'

  function New-LogFile([string[]]$Lines) {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + '.jsonl')
    Set-Content -Path $path -Value $Lines -Encoding utf8
    return $path
  }

  $script:TresConsistentes = @(
    '{"script": "testcase-register.ps1", "ProjectSlug": "rediseno-bossdream-framework", "TcId": "TC-050", "UsId": "US-015", "AcIds": ["AC-015.1"], "resultado": "OK"}',
    '{"script": "testcase-register.ps1", "ProjectSlug": "rediseno-bossdream-framework", "TcId": "TC-051", "UsId": "US-015", "AcIds": ["AC-015.2"], "resultado": "OK"}',
    '{"script": "testcase-register.ps1", "ProjectSlug": "rediseno-bossdream-framework", "TcId": "TC-052", "UsId": "US-016", "AcIds": ["AC-016.1"], "resultado": "OK"}'
  )
}

Describe 'pattern-detect.ps1' {

  AfterEach {
    if ($script:TmpFile -and (Test-Path $script:TmpFile)) { Remove-Item $script:TmpFile -Force -ErrorAction SilentlyContinue }
  }

  It '3 corridas consistentes (mismo script, mismos nombres de parametro, mismo resultado) -- detecta el candidato' {
    $script:TmpFile = New-LogFile $script:TresConsistentes
    $result = & $script:Script -LogPath $script:TmpFile | ConvertFrom-Json
    $result.status | Should -Be 'pass'
    $result.candidatos.Count | Should -Be 1
    $result.candidatos[0].script | Should -Be 'testcase-register.ps1'
    $result.candidatos[0].repeticiones | Should -Be 3
    @($result.candidatos[0].parametros) | Should -Be @('AcIds', 'ProjectSlug', 'TcId', 'UsId')
  }

  It 'solo 2 corridas consistentes -- no detecta candidato' {
    $script:TmpFile = New-LogFile ($script:TresConsistentes[0..1])
    $result = & $script:Script -LogPath $script:TmpFile | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $result.candidatos | Should -BeNullOrEmpty
    ($result.razon -join ' ') | Should -Match '3'
  }

  It 'log inexistente -- bloquea con razon' {
    $result = & $script:Script -LogPath 'C:\no-existe\registro-log.jsonl' | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    ($result.razon -join ' ') | Should -Match 'no encontrado'
  }

  It 'mismo script pero distinto set de parametros -- no se agrupan juntas' {
    $lines = @(
      '{"script": "testcase-register.ps1", "TcId": "TC-050", "resultado": "OK"}',
      '{"script": "testcase-register.ps1", "TcId": "TC-051", "UsId": "US-015", "resultado": "OK"}',
      '{"script": "testcase-register.ps1", "TcId": "TC-052", "resultado": "OK"}'
    )
    $script:TmpFile = New-LogFile $lines
    $result = & $script:Script -LogPath $script:TmpFile | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
  }
}
