BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/tasks-complete.ps1'

  function New-Sandbox {
    $sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("tasks-complete-test-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
    return $sandbox
  }

  function Write-TasksFile([string]$Path, [string[]]$Lines) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    Set-Content -Path $Path -Value $Lines -Encoding utf8
  }
}

Describe 'tasks-complete.ps1' {

  AfterEach {
    if ($script:Sandbox -and (Test-Path $script:Sandbox)) { Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue }
  }

  It 'sin plans/, reporta OK' {
    $script:Sandbox = New-Sandbox
    $result = & $script:Script -ProjectDir $script:Sandbox
    $result | Should -Match 'tasks OK \(sin tasks.md\)'
    $LASTEXITCODE | Should -Be 0
  }

  It 'ignora plans/_TEMPLATE/tasks.md aunque tenga checkboxes sin marcar' {
    $script:Sandbox = New-Sandbox
    Write-TasksFile (Join-Path $script:Sandbox 'plans/_TEMPLATE/tasks.md') @('- [ ] 1. <tarea>', '- [ ] 2. <tarea>')
    $result = & $script:Script -ProjectDir $script:Sandbox
    $result | Should -Match 'tasks OK'
    $LASTEXITCODE | Should -Be 0
  }

  It 'sin .active-plan, detecta tasks pendientes en cualquier feature real bajo plans/' {
    $script:Sandbox = New-Sandbox
    Write-TasksFile (Join-Path $script:Sandbox 'plans/mi-feature/tasks.md') @('- [x] 1. hecha', '- [ ] 2. pendiente')
    $result = & $script:Script -ProjectDir $script:Sandbox
    $result | Should -Match 'TASKS PENDIENTES'
    $result | Should -Match '2\. pendiente'
    $LASTEXITCODE | Should -Be 1
  }

  It 'sin .active-plan, con _TEMPLATE pendiente y una feature real completa, reporta OK (no cuenta _TEMPLATE)' {
    $script:Sandbox = New-Sandbox
    Write-TasksFile (Join-Path $script:Sandbox 'plans/_TEMPLATE/tasks.md') @('- [ ] 1. <tarea>')
    Write-TasksFile (Join-Path $script:Sandbox 'plans/mi-feature/tasks.md') @('- [x] 1. hecha')
    $result = & $script:Script -ProjectDir $script:Sandbox
    $result | Should -Be 'tasks OK'
    $LASTEXITCODE | Should -Be 0
  }

  It 'con .active-plan, solo evalua esa feature, ignorando pendientes de otras' {
    $script:Sandbox = New-Sandbox
    New-Item -ItemType Directory -Force -Path (Join-Path $script:Sandbox '.claude') | Out-Null
    Set-Content -Path (Join-Path $script:Sandbox '.claude/.active-plan') -Value 'feature-activa' -Encoding utf8
    Write-TasksFile (Join-Path $script:Sandbox 'plans/feature-activa/tasks.md') @('- [x] 1. hecha')
    Write-TasksFile (Join-Path $script:Sandbox 'plans/otra-feature/tasks.md') @('- [ ] 1. pendiente en otra feature')
    $result = & $script:Script -ProjectDir $script:Sandbox
    $result | Should -Be 'tasks OK'
    $LASTEXITCODE | Should -Be 0
  }
}
