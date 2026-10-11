BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot

  function Get-Frontmatter([string]$Path) {
    $lines = Get-Content $Path
    if ($lines[0] -ne '---') { throw "sin frontmatter: $Path" }
    $closingIndex = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -eq '---') { $closingIndex = $i; break }
    }
    if ($closingIndex -lt 0) { throw "frontmatter sin cierre: $Path" }
    $yamlLines = $lines[1..($closingIndex - 1)]
    $result = @{}
    foreach ($line in $yamlLines) {
      if ($line -match '^([a-zA-Z_-]+):\s*(.*)$') { $result[$Matches[1]] = $Matches[2].Trim() }
    }
    return $result
  }
}

Describe 'bossdream-project.md (comando)' {
  BeforeAll {
    $script:CommandPath = Join-Path $script:PluginRoot 'commands/bossdream-project.md'
    $script:Content = Get-Content $script:CommandPath -Raw
  }

  It 'existe' {
    Test-Path $script:CommandPath | Should -BeTrue
  }

  It 'tiene frontmatter con name/description/disable-model-invocation/arguments' {
    $fm = Get-Frontmatter $script:CommandPath
    $fm.name | Should -Be 'bossdream-project'
    $fm['disable-model-invocation'] | Should -Be 'true'
    $script:Content | Should -Match 'arguments:'
    $script:Content | Should -Match 'contexto'
  }

  It 'invoca project-scaffold.ps1 (Increment 1) y no invoca scripts de otro plugin' {
    $script:Content | Should -Match 'project-scaffold\.ps1'
    $script:Content | Should -Not -Match 'plugins/(?!BossDream)[A-Za-z-]+/commands'
    $script:Content | Should -Not -Match 'plugins/(?!BossDream)[A-Za-z-]+/scripts'
  }

  It 'incluye la tabla de clasificacion Simple/Medio/Complejo' {
    $script:Content | Should -Match 'Simple'
    $script:Content | Should -Match 'Medio'
    $script:Content | Should -Match 'Complejo'
  }

  It 'nunca marca validation.json como ready (regla explicita)' {
    $script:Content | Should -Match 'Nunca marca .validation\.json. como .ready.'
  }
}

Describe 'epic-planner/SKILL.md' {
  BeforeAll {
    $script:SkillPath = Join-Path $script:PluginRoot 'skills/epic-planner/SKILL.md'
  }

  It 'existe' {
    Test-Path $script:SkillPath | Should -BeTrue
  }

  It 'tiene frontmatter con name/description/arguments' {
    $fm = Get-Frontmatter $script:SkillPath
    $fm.name | Should -Be 'epic-planner'
    $fm.description | Should -Not -BeNullOrEmpty
  }

  It 'documenta explicitamente que en Simple no propone nada' {
    $content = Get-Content $script:SkillPath -Raw
    $content | Should -Match 'Simple.*no se propone nada'
  }
}
