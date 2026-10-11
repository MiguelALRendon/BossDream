BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  Import-Module (Join-Path $script:PluginRoot 'scripts/prompt-matchers.psm1') -Force -WarningAction SilentlyContinue
}

Describe 'Test-BossdreamPlanPrompt' {
  It 'matchea "/bossdream-plan"' {
    Test-BossdreamPlanPrompt '/bossdream-plan' | Should -Be $true
  }

  It 'matchea "/bossdream-core:bossdream-plan"' {
    Test-BossdreamPlanPrompt '/bossdream-core:bossdream-plan' | Should -Be $true
  }

  It 'matchea un namespace nunca antes visto "/otro-plugin-futuro:bossdream-plan"' {
    Test-BossdreamPlanPrompt '/otro-plugin-futuro:bossdream-plan' | Should -Be $true
  }

  It 'no matchea texto sin ninguno de esos comandos' {
    Test-BossdreamPlanPrompt 'que hora es' | Should -Be $false
  }

  It 'no matchea un comando de implement' {
    Test-BossdreamPlanPrompt '/bossdream-implement' | Should -Be $false
  }
}

Describe 'Test-BossdreamImplementPrompt' {
  It 'matchea "/bossdream-implement"' {
    Test-BossdreamImplementPrompt '/bossdream-implement' | Should -Be $true
  }

  It 'matchea "/bossdream-core:bossdream-implement"' {
    Test-BossdreamImplementPrompt '/bossdream-core:bossdream-implement' | Should -Be $true
  }

  It 'matchea un namespace nunca antes visto "/otro-plugin-futuro:bossdream-implement"' {
    Test-BossdreamImplementPrompt '/otro-plugin-futuro:bossdream-implement' | Should -Be $true
  }

  It 'no matchea texto sin ninguno de esos comandos' {
    Test-BossdreamImplementPrompt 'que hora es' | Should -Be $false
  }

  It 'no matchea un comando de plan' {
    Test-BossdreamImplementPrompt '/bossdream-plan' | Should -Be $false
  }
}

Describe 'Test-BossdreamModePrompt' {
  It 'matchea "/bossdream-mode plan" sin alias y captura el modo' {
    Test-BossdreamModePrompt '/bossdream-mode plan' | Should -Be 'plan'
  }

  It 'matchea "/bossdream-core:bossdream-mode clear" con alias de namespace y captura el modo' {
    Test-BossdreamModePrompt '/bossdream-core:bossdream-mode clear' | Should -Be 'clear'
  }

  It 'no matchea texto sin el comando' {
    Test-BossdreamModePrompt 'que hora es' | Should -Be $null
  }
}
