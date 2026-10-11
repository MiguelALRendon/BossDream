BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/read-budget.ps1'

  function Invoke-ContextBudget([string]$ToolName, [hashtable]$ToolInput) {
    $payload = @{ tool_name = $ToolName; tool_input = $ToolInput } | ConvertTo-Json -Compress
    $payload | & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:Script
  }
}

Describe 'read-budget.ps1' {

  AfterEach {
    Remove-Item Env:\CLAUDE_PLUGIN_OPTION_ENABLE_READ_BUDGET_HOOK -ErrorAction SilentlyContinue
  }

  Context 'hook activado' {

    BeforeEach {
      $env:CLAUDE_PLUGIN_OPTION_ENABLE_READ_BUDGET_HOOK = 'true'
    }

    It 'pide confirmacion en Read sin limit' {
      $result = Invoke-ContextBudget -ToolName 'Read' -ToolInput @{ file_path = 'foo.md' }

      $json = $result | ConvertFrom-Json
      $json.hookSpecificOutput.permissionDecision | Should -Be 'ask'
      $json.hookSpecificOutput.permissionDecisionReason | Should -Match 'Read sin limit'
    }

    It 'pide confirmacion en Grep content sin head_limit' {
      $result = Invoke-ContextBudget -ToolName 'Grep' -ToolInput @{ pattern = 'foo'; output_mode = 'content' }

      $json = $result | ConvertFrom-Json
      $json.hookSpecificOutput.permissionDecision | Should -Be 'ask'
      $json.hookSpecificOutput.permissionDecisionReason | Should -Match 'Grep content sin head_limit'
    }

    It 'pasa sin pedir nada en Read con limit' {
      $result = Invoke-ContextBudget -ToolName 'Read' -ToolInput @{ file_path = 'foo.md'; limit = 50 }

      $result | Should -BeNullOrEmpty
    }

    It 'pasa sin pedir nada en Grep content con head_limit' {
      $result = Invoke-ContextBudget -ToolName 'Grep' -ToolInput @{ pattern = 'foo'; output_mode = 'content'; head_limit = 20 }

      $result | Should -BeNullOrEmpty
    }
  }

  Context 'hook desactivado' {

    It 'no hace nada aunque el caso sea pedible, si la env var esta en false' {
      $env:CLAUDE_PLUGIN_OPTION_ENABLE_READ_BUDGET_HOOK = 'false'

      $result = Invoke-ContextBudget -ToolName 'Read' -ToolInput @{ file_path = 'foo.md' }

      $result | Should -BeNullOrEmpty
    }

    It 'no hace nada aunque el caso sea pedible, si la env var no esta seteada' {
      Remove-Item Env:\CLAUDE_PLUGIN_OPTION_ENABLE_READ_BUDGET_HOOK -ErrorAction SilentlyContinue

      $result = Invoke-ContextBudget -ToolName 'Read' -ToolInput @{ file_path = 'foo.md' }

      $result | Should -BeNullOrEmpty
    }
  }
}
