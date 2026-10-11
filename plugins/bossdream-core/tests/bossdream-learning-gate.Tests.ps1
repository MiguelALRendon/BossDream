BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:GateScript = Join-Path $script:PluginRoot 'scripts/bossdream-learning-gate.ps1'

  $script:TresConsistentes = @(
    '{"script": "testcase-register.ps1", "ProjectSlug": "rediseno-bossdream-framework", "TcId": "TC-050", "UsId": "US-015", "AcIds": ["AC-015.1"], "resultado": "OK"}',
    '{"script": "testcase-register.ps1", "ProjectSlug": "rediseno-bossdream-framework", "TcId": "TC-051", "UsId": "US-015", "AcIds": ["AC-015.2"], "resultado": "OK"}',
    '{"script": "testcase-register.ps1", "ProjectSlug": "rediseno-bossdream-framework", "TcId": "TC-052", "UsId": "US-016", "AcIds": ["AC-016.1"], "resultado": "OK"}'
  )

  function New-Sandbox {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'bossdream_projects/testproj/.bossdream-project') | Out-Null
    return $root
  }
}

Describe 'bossdream-learning-gate.ps1' {

  AfterEach {
    if ($script:Sandbox -and (Test-Path $script:Sandbox)) { Remove-Item $script:Sandbox -Recurse -Force -ErrorAction SilentlyContinue }
  }

  It 'evidencia insuficiente (log inexistente) -- se detiene en evidence_gate, no corre las demas etapas' {
    $script:Sandbox = New-Sandbox
    $opsLog = Join-Path $script:Sandbox 'no-existe.jsonl'
    $result = & $script:GateScript -ProjectDir $script:Sandbox -ProjectSlug 'testproj' -Slug 'caso-a' -OperationsLog $opsLog -ValidacionVeredicto pass -AprobacionVeredicto pass | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    @($result.etapas) | Should -Be @('evidence_gate')
  }

  It 'evidencia ok pero solo 2 corridas consistentes -- se detiene en pattern_consistency_gate' {
    $script:Sandbox = New-Sandbox
    $opsLog = Join-Path $script:Sandbox 'ops.jsonl'
    Set-Content -Path $opsLog -Value $script:TresConsistentes[0..1] -Encoding utf8
    $result = & $script:GateScript -ProjectDir $script:Sandbox -ProjectSlug 'testproj' -Slug 'caso-b' -OperationsLog $opsLog -ValidacionVeredicto pass -AprobacionVeredicto pass | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    @($result.etapas) | Should -Be @('evidence_gate', 'pattern_consistency_gate')
  }

  It 'pasa evidence y pattern pero sin ValidacionVeredicto -- se detiene antes de validacion' {
    $script:Sandbox = New-Sandbox
    $opsLog = Join-Path $script:Sandbox 'ops.jsonl'
    Set-Content -Path $opsLog -Value $script:TresConsistentes -Encoding utf8
    $result = & $script:GateScript -ProjectDir $script:Sandbox -ProjectSlug 'testproj' -Slug 'caso-c' -OperationsLog $opsLog | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    @($result.etapas) | Should -Be @('evidence_gate', 'pattern_consistency_gate')
  }

  It 'las 4 etapas pasan -- log final tiene evidence_gate, pattern_consistency_gate, validacion, aprobacion en ese orden' {
    $script:Sandbox = New-Sandbox
    $opsLog = Join-Path $script:Sandbox 'ops.jsonl'
    Set-Content -Path $opsLog -Value $script:TresConsistentes -Encoding utf8
    $result = & $script:GateScript -ProjectDir $script:Sandbox -ProjectSlug 'testproj' -Slug 'caso-d' -OperationsLog $opsLog -ValidacionVeredicto pass -ValidacionDetalle 'no es casual' -AprobacionVeredicto pass -AprobacionDetalle 'usuario confirmo' | ConvertFrom-Json
    $result.status | Should -Be 'pass'
    @($result.etapas) | Should -Be @('evidence_gate', 'pattern_consistency_gate', 'validacion', 'aprobacion')

    $logPath = Join-Path $script:Sandbox 'bossdream_projects/testproj/.bossdream-project/pattern-caso-d.log'
    $lineas = @(Get-Content $logPath | ForEach-Object { $_ | ConvertFrom-Json })
    @($lineas.etapa) | Should -Be @('evidence_gate', 'pattern_consistency_gate', 'validacion', 'aprobacion')
    $lineas[3].veredicto | Should -Be 'pass'
  }

  It 'ValidacionVeredicto blocked -- aprobacion nunca corre ni se escribe' {
    $script:Sandbox = New-Sandbox
    $opsLog = Join-Path $script:Sandbox 'ops.jsonl'
    Set-Content -Path $opsLog -Value $script:TresConsistentes -Encoding utf8
    $result = & $script:GateScript -ProjectDir $script:Sandbox -ProjectSlug 'testproj' -Slug 'caso-e' -OperationsLog $opsLog -ValidacionVeredicto blocked -ValidacionDetalle 'parece casualidad' -AprobacionVeredicto pass | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    @($result.etapas) | Should -Be @('evidence_gate', 'pattern_consistency_gate', 'validacion')
  }
}
