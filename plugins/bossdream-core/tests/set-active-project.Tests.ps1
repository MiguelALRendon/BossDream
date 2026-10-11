BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/set-active-project.ps1'
  $script:ScaffoldScript = Join-Path $script:PluginRoot 'scripts/project-scaffold.ps1'
}

Describe 'set-active-project.ps1' {

  BeforeEach {
    $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("set-active-project-test-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $script:Sandbox | Out-Null
    $env:CLAUDE_PLUGIN_ROOT = $script:PluginRoot
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-960' -ProjectName 'Demo' -Classification 'Medio' | Out-Null
    $script:ActiveProjectFile = Join-Path $script:Sandbox '.claude/.active-project'
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
    Remove-Item Env:\CLAUDE_PLUGIN_ROOT -ErrorAction SilentlyContinue
  }

  It 'activa un proyecto existente y reporta clasificacion + validation.json overallStatus' {
    $output = & $script:Script -ProjectDir $script:Sandbox -Action activate -ProjectSlug 'demo'

    (Get-Content $script:ActiveProjectFile -Raw).Trim() | Should -Be 'demo'
    $output | Should -Match 'ACTIVATED'
    $output | Should -Match 'Medio'
    $output | Should -Match 'blocked'
  }

  It 'error claro y lista disponibles si el slug no existe' {
    & $script:Script -ProjectDir $script:Sandbox -Action activate -ProjectSlug 'no-existe'
    $LASTEXITCODE | Should -Be 1
  }

  It 'error claro (no crea nada) al intentar activar un slug inexistente' {
    $output = & $script:Script -ProjectDir $script:Sandbox -Action activate -ProjectSlug 'no-existe'
    $output | Should -Match 'no existe'
    $output | Should -Match 'demo'
    Test-Path (Join-Path $script:Sandbox 'bossdream_projects/no-existe') | Should -BeFalse
  }

  It 'permite cambiar de un proyecto activo a otro sin tocar el primero' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'segundo' -ProjectId 'REQ-961' -ProjectName 'Segundo' -Classification 'Simple' | Out-Null

    & $script:Script -ProjectDir $script:Sandbox -Action activate -ProjectSlug 'demo' | Out-Null
    (Get-Content $script:ActiveProjectFile -Raw).Trim() | Should -Be 'demo'

    & $script:Script -ProjectDir $script:Sandbox -Action activate -ProjectSlug 'segundo' | Out-Null
    (Get-Content $script:ActiveProjectFile -Raw).Trim() | Should -Be 'segundo'

    # el primer proyecto sigue intacto en su carpeta
    Test-Path (Join-Path $script:Sandbox 'bossdream_projects/demo/.bossdream-project/project.json') | Should -BeTrue
  }

  It 'clear borra el puntero y permite volver a modo normal' {
    & $script:Script -ProjectDir $script:Sandbox -Action activate -ProjectSlug 'demo' | Out-Null
    Test-Path $script:ActiveProjectFile | Should -BeTrue

    $output = & $script:Script -ProjectDir $script:Sandbox -Action clear
    Test-Path $script:ActiveProjectFile | Should -BeFalse
    $output | Should -Match 'CLEARED'
  }

  It 'clear es un no-op seguro si no habia nada activo' {
    # el scaffold del BeforeEach ya deja 'demo' activo - limpiamos primero para probar el no-op real
    & $script:Script -ProjectDir $script:Sandbox -Action clear | Out-Null
    $output = & $script:Script -ProjectDir $script:Sandbox -Action clear
    $LASTEXITCODE | Should -Be 0
    ($output -join ' ') | Should -Match 'no habia ningun proyecto activo'
  }

  It 'status informa el proyecto activo y los disponibles, sin cambiar nada' {
    & $script:Script -ProjectDir $script:Sandbox -Action activate -ProjectSlug 'demo' | Out-Null
    $before = (Get-Content $script:ActiveProjectFile -Raw)

    $output = & $script:Script -ProjectDir $script:Sandbox -Action status
    $joined = $output -join ' '

    $joined | Should -Match "'demo' esta activo"
    $joined | Should -Match 'demo'
    (Get-Content $script:ActiveProjectFile -Raw) | Should -Be $before
  }

  It 'status sin proyecto activo dice "ninguno activo (modo normal)"' {
    # el scaffold del BeforeEach ya deja 'demo' activo - limpiamos primero para probar el estado real
    & $script:Script -ProjectDir $script:Sandbox -Action clear | Out-Null
    $output = & $script:Script -ProjectDir $script:Sandbox -Action status
    ($output -join ' ') | Should -Match 'ninguno activo'
  }

  It 'activate falla limpio sin -ProjectSlug' {
    & $script:Script -ProjectDir $script:Sandbox -Action activate
    $LASTEXITCODE | Should -Be 1
  }
}
