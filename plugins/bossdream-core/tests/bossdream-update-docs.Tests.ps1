BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:CommandPath = Join-Path $script:PluginRoot 'commands/bossdream-update-docs.md'
  $script:SkillPath = Join-Path $script:PluginRoot 'skills/traceability-sync/SKILL.md'
}

Describe 'bossdream-update-docs.md (comando)' {
  BeforeAll { $script:Content = Get-Content $script:CommandPath -Raw }

  It 'existe' { Test-Path $script:CommandPath | Should -BeTrue }

  It 'tiene frontmatter con name/description/arguments' {
    $script:Content | Should -Match 'name:\s*bossdream-update-docs'
    $script:Content | Should -Match 'alcance_nuevo'
  }

  It 'invoca epic-planner, traceability-sync y validation-check.ps1, nunca scripts de otro plugin' {
    $script:Content | Should -Match 'epic-planner'
    $script:Content | Should -Match 'traceability-sync'
    $script:Content | Should -Match 'validation-check\.ps1'
    $script:Content | Should -Not -Match 'plugins/(?!BossDream)[A-Za-z-]+/commands'
    $script:Content | Should -Not -Match 'plugins/(?!BossDream)[A-Za-z-]+/scripts'
  }

  It 'nunca marca validation.json como ready (regla explicita)' {
    $script:Content | Should -Match 'Nunca marca .+ready'
  }
}

Describe 'traceability-sync/SKILL.md' {
  BeforeAll { $script:Content = Get-Content $script:SkillPath -Raw }

  It 'existe' { Test-Path $script:SkillPath | Should -BeTrue }

  It 'tiene frontmatter con name/description' {
    $script:Content | Should -Match 'name:\s*traceability-sync'
  }

  It 'invoca traceability-build.ps1 y declara que el JSON nunca se edita a mano' {
    $script:Content | Should -Match 'traceability-build\.ps1'
    $script:Content | Should -Match 'nunca se edita a mano'
  }
}
