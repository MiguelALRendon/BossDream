BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:SkillPath = Join-Path $script:PluginRoot 'skills/flow-test-gen/SKILL.md'
  $script:Content = Get-Content $script:SkillPath -Raw
}

Describe 'flow-test-gen/SKILL.md' {

  It 'existe' {
    Test-Path $script:SkillPath | Should -BeTrue
  }

  It 'tiene frontmatter con name/description' {
    $script:Content | Should -Match 'name:\s*flow-test-gen'
  }

  It 'invoca flow-coverage-check.ps1 para autoverificarse antes de presentar el catalogo' {
    $script:Content | Should -Match 'flow-coverage-check\.ps1'
  }

  It 'declara que no se agrega ningun agente nuevo para esta skill' {
    $script:Content | Should -Match 'No se agrega ningun agente'
  }

  It 'declara la integracion con /bossdream-implement sin modificar bossdream-implement.md' {
    $script:Content | Should -Match 'bossdream-implement\.md'
    $script:Content | Should -Not -Match 'plugins/(?!BossDream)[A-Za-z-]+/commands/bossdream-implement\.md.*modific'
  }

  It 'declara la nota final obligatoria de validacion humana/UAT' {
    $script:Content | Should -Match 'UAT'
  }

  It 'no referencia scripts/comandos de otro plugin' {
    $script:Content | Should -Not -Match 'plugins/(?!BossDream)[A-Za-z-]+/scripts'
  }
}
