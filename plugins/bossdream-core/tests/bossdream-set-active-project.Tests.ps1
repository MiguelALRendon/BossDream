BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:CommandPath = Join-Path $script:PluginRoot 'commands/bossdream-set-active-project.md'
  $script:Content = Get-Content $script:CommandPath -Raw
}

Describe 'bossdream-set-active-project.md (comando)' {

  It 'existe' {
    Test-Path $script:CommandPath | Should -BeTrue
  }

  It 'tiene frontmatter con name/description/disable-model-invocation/arguments' {
    $script:Content | Should -Match 'name:\s*bossdream-set-active-project'
    $script:Content | Should -Match 'disable-model-invocation:\s*true'
    $script:Content | Should -Match 'accion'
  }

  It 'invoca set-active-project.ps1 con las 3 acciones (activate/clear/status)' {
    $script:Content | Should -Match 'set-active-project\.ps1'
    $script:Content | Should -Match 'activate'
    $script:Content | Should -Match 'clear'
    $script:Content | Should -Match 'status'
  }

  It 'declara explicitamente que .active-project es local y no viaja por git' {
    $script:Content | Should -Match 'LOCAL'
    $script:Content | Should -Match 'nunca se comparte'
  }

  It 'declara que nunca crea un proyecto nuevo (eso es /bossdream-project)' {
    $script:Content | Should -Match 'Nunca crea un proyecto nuevo'
  }

  It 'no invoca ningun script/ruta de otro plugin' {
    $script:Content | Should -Not -Match 'plugins/(?!BossDream)[A-Za-z-]+/commands'
    $script:Content | Should -Not -Match 'plugins/(?!BossDream)[A-Za-z-]+/scripts'
  }
}
