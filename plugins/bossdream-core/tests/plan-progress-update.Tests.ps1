BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/plan-progress-update.ps1'
}

Describe 'plan-progress-update.ps1' {

  BeforeEach {
    $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("plan-progress-test-" + [System.Guid]::NewGuid().ToString('N'))
    $script:DotDir = Join-Path $script:Sandbox 'bossdream_projects/demo/.bossdream-project'
    New-Item -ItemType Directory -Force -Path $script:DotDir | Out-Null
    @{ status = 'in-progress'; planned = @(); pending = @('FEAT-001', 'FEAT-002') } | ConvertTo-Json | Set-Content (Join-Path $script:DotDir 'plan-progress.json') -Encoding utf8
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
  }

  It 'pipeline del Increment 7 - rollup con 2 Features: mueve cada una de pending a planned, status queda complete al terminar ambas' {
    & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' -Completed 'FEAT-001' | Out-Null
    $progress = Get-Content (Join-Path $script:DotDir 'plan-progress.json') -Raw | ConvertFrom-Json
    $progress.planned | Should -Contain 'FEAT-001'
    $progress.pending | Should -Contain 'FEAT-002'
    $progress.pending | Should -Not -Contain 'FEAT-001'
    $progress.status | Should -Be 'in-progress'

    & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' -Completed 'FEAT-002' | Out-Null
    $progressFinal = Get-Content (Join-Path $script:DotDir 'plan-progress.json') -Raw | ConvertFrom-Json
    $progressFinal.planned | Should -Contain 'FEAT-001'
    $progressFinal.planned | Should -Contain 'FEAT-002'
    $progressFinal.pending.Count | Should -Be 0
    $progressFinal.status | Should -Be 'complete'
  }

  It 'no duplica una entrada ya movida a planned si se marca completa dos veces' {
    & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' -Completed 'FEAT-001' | Out-Null
    & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' -Completed 'FEAT-001' | Out-Null
    $progress = Get-Content (Join-Path $script:DotDir 'plan-progress.json') -Raw | ConvertFrom-Json
    @($progress.planned | Where-Object { $_ -eq 'FEAT-001' }).Count | Should -Be 1
  }

  It 'guarda una nota opcional' {
    & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' -Completed 'FEAT-001' -Note 'quedo pendiente validar con negocio' | Out-Null
    $progress = Get-Content (Join-Path $script:DotDir 'plan-progress.json') -Raw | ConvertFrom-Json
    $progress.notes | Should -Match 'validar con negocio'
  }

  It 'falla limpio si no existe plan-progress.json para el slug' {
    & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'no-existe' -Completed 'FEAT-001' | Out-Null
    $LASTEXITCODE | Should -Be 1
  }
}
