BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:ScaffoldScript = Join-Path $script:PluginRoot 'scripts/project-scaffold.ps1'
  $script:RollupTemplate = Join-Path $script:PluginRoot 'templates/_PROJECT_TEMPLATE/roadmap.md'
}

Describe 'roadmap.md (plantilla de rollup)' {

  It 'existe y declara explicitamente que no es ejecutable' {
    Test-Path $script:RollupTemplate | Should -BeTrue
    $content = Get-Content $script:RollupTemplate -Raw
    $content | Should -Match 'NO un .plan\.md. ejecutable'
    $content | Should -Match 'QA Increment'
  }

  It 'NO se copia en project-scaffold.ps1 (solo se genera cuando corre /bossdream-plan, no antes)' {
    $sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("rollup-scaffold-test-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
    $env:CLAUDE_PLUGIN_ROOT = $script:PluginRoot
    try {
      & $script:ScaffoldScript -ProjectDir $sandbox -ProjectSlug 'demo' -ProjectId 'REQ-950' -ProjectName 'Demo' -Classification 'Simple' | Out-Null
      Test-Path (Join-Path $sandbox 'bossdream_projects/demo/roadmap.md') | Should -BeFalse
    } finally {
      Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
      Remove-Item Env:\CLAUDE_PLUGIN_ROOT -ErrorAction SilentlyContinue
    }
  }

  It 'project-scaffold.ps1 copia plan-context-inject.ps1 y registra 2 entradas UserPromptSubmit (validation-lock + plan-context-inject)' {
    $sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("rollup-hooks-test-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
    $env:CLAUDE_PLUGIN_ROOT = $script:PluginRoot
    try {
      & $script:ScaffoldScript -ProjectDir $sandbox -ProjectSlug 'demo' -ProjectId 'REQ-951' -ProjectName 'Demo' -Classification 'Simple' | Out-Null
      Test-Path (Join-Path $sandbox '.claude/bossdream-hooks/plan-context-inject.ps1') | Should -BeTrue

      $settings = Get-Content (Join-Path $sandbox '.claude/settings.json') -Raw | ConvertFrom-Json
      $commands = @($settings.hooks.UserPromptSubmit | ForEach-Object { $_.hooks } | ForEach-Object { $_.command })
      ($commands -join ' ') | Should -Match 'validation-lock\.ps1'
      ($commands -join ' ') | Should -Match 'plan-context-inject\.ps1'
    } finally {
      Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
      Remove-Item Env:\CLAUDE_PLUGIN_ROOT -ErrorAction SilentlyContinue
    }
  }
}
