BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:CommandPath = Join-Path $script:PluginRoot 'commands/bossdream-testcase.md'
  $script:Content = Get-Content $script:CommandPath -Raw
}

Describe 'bossdream-testcase.md (comando)' {

  It 'existe' {
    Test-Path $script:CommandPath | Should -BeTrue
  }

  It 'tiene frontmatter con name/description/disable-model-invocation/arguments' {
    $script:Content | Should -Match 'name:\s*bossdream-testcase'
    $script:Content | Should -Match 'disable-model-invocation:\s*true'
    $script:Content | Should -Match 'escenario'
  }

  It 'invoca testcase-register.ps1 y no referencia nada de otro plugin' {
    $script:Content | Should -Match 'testcase-register\.ps1'
    $script:Content | Should -Not -Match 'plugins/(?!BossDream)[A-Za-z-]+/commands'
    $script:Content | Should -Not -Match 'plugins/(?!BossDream)[A-Za-z-]+/scripts'
  }

  It 'declara explicitamente que Simple no usa casos de prueba formales' {
    $script:Content | Should -Match 'Simple.*no.*casos de prueba formales'
  }

  It 'nunca marca validation.json como ready (regla explicita)' {
    $script:Content | Should -Match 'Nunca marca .validation\.json. como .ready.'
  }
}
