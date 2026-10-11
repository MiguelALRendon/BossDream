BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:PublishScript = Join-Path $script:PluginRoot 'scripts/bossdream-learning-publish.ps1'

  function New-Sandbox {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    $dotDir = Join-Path $root 'bossdream_projects/testproj/.bossdream-project'
    New-Item -ItemType Directory -Force -Path (Join-Path $dotDir 'human-explanations') | Out-Null
    'contenido del tutorial de prueba' | Set-Content (Join-Path $dotDir 'human-explanations/caso-x.md') -Encoding utf8
    return $root
  }

  function Get-DestPath([string]$Root) {
    return Join-Path $Root 'docs/human-explanations/caso-x.md'
  }

  $script:LogSinAprobacion = @(
    '{"etapa": "evidence_gate", "veredicto": "pass", "detalle": "3 corridas con mismo script y resultado OK"}',
    '{"etapa": "pattern_consistency_gate", "veredicto": "pass", "detalle": "mismos parametros en las 3 corridas"}',
    '{"etapa": "validacion", "veredicto": "pass", "detalle": "patron revisado, no es solo repeticion casual"}'
  )

  $script:LogCompleto = $script:LogSinAprobacion + '{"etapa": "aprobacion", "veredicto": "pass", "detalle": "usuario confirmo"}'
}

Describe 'bossdream-learning-publish.ps1' {

  AfterEach {
    if ($script:Sandbox -and (Test-Path $script:Sandbox)) { Remove-Item $script:Sandbox -Recurse -Force -ErrorAction SilentlyContinue }
  }

  It 'log sin etapa aprobacion -- falla con exit 1 y no copia nada' {
    $script:Sandbox = New-Sandbox
    $logPath = Join-Path $script:Sandbox 'bossdream_projects/testproj/.bossdream-project/pattern-caso-x.log'
    Set-Content -Path $logPath -Value $script:LogSinAprobacion -Encoding utf8

    & $script:PublishScript -ProjectDir $script:Sandbox -ProjectSlug 'testproj' -Slug 'caso-x' | Out-Null
    $exitCode = $LASTEXITCODE

    $exitCode | Should -Be 1
    Test-Path (Get-DestPath $script:Sandbox) | Should -BeFalse
  }

  It 'log con las 4 etapas (aprobacion incluida) -- publica de verdad y el archivo destino existe' {
    $script:Sandbox = New-Sandbox
    $logPath = Join-Path $script:Sandbox 'bossdream_projects/testproj/.bossdream-project/pattern-caso-x.log'
    Set-Content -Path $logPath -Value $script:LogCompleto -Encoding utf8

    & $script:PublishScript -ProjectDir $script:Sandbox -ProjectSlug 'testproj' -Slug 'caso-x' | Out-Null
    $exitCode = $LASTEXITCODE

    $exitCode | Should -Be 0
    $destPath = Get-DestPath $script:Sandbox
    Test-Path $destPath | Should -BeTrue
    (Get-Content $destPath -Raw).Trim() | Should -Be 'contenido del tutorial de prueba'
  }

  It 'log inexistente -- bloquea con exit 1' {
    $script:Sandbox = New-Sandbox
    & $script:PublishScript -ProjectDir $script:Sandbox -ProjectSlug 'testproj' -Slug 'caso-x' | Out-Null
    $LASTEXITCODE | Should -Be 1
    Test-Path (Get-DestPath $script:Sandbox) | Should -BeFalse
  }
}
