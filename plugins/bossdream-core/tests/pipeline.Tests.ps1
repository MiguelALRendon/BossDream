BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:PipelineScript = Join-Path $script:PluginRoot 'scripts/pipeline.ps1'

  function New-Sandbox {
    $sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid())
    New-Item -ItemType Directory -Path $sandbox | Out-Null
    return $sandbox
  }

  function New-PluginCandidate([string]$SandboxRoot, [string]$PluginName) {
    $pluginDir = Join-Path $SandboxRoot "plugins/$PluginName"
    New-Item -ItemType Directory -Path (Join-Path $pluginDir '.claude-plugin') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $pluginDir 'scripts') -Force | Out-Null
    Set-Content -Path (Join-Path $pluginDir '.claude-plugin/plugin.json') -Value ('{"name":"' + $PluginName + '"}')
    return (Join-Path $pluginDir 'scripts')
  }

  function New-LocalHooksDir([string]$SandboxRoot) {
    $localDir = Join-Path $SandboxRoot '.claude/bossdream-hooks'
    New-Item -ItemType Directory -Path $localDir -Force | Out-Null
    return $localDir
  }

  function New-HookSiblingsDriftPipeline([string]$SandboxRoot) {
    $cfg = @{ stages = @(@{ id = 'hook-siblings-drift'; order = 12; internal = 'hook-siblings-sync'; tier = 'local'; blocking = 'hard'; args = @('-Mode', 'Check') }) }
    $cfg | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $SandboxRoot 'pipeline.json') -Encoding utf8
  }

  function Invoke-Pipeline([string]$SandboxRoot) {
    $out = & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:PipelineScript -ProjectDir $SandboxRoot -Tier local 2>&1
    return [PSCustomObject]@{ Output = ($out -join "`n"); ExitCode = $LASTEXITCODE }
  }
}

Describe 'pipeline.ps1' {
  It 'etapa hook-siblings-drift bloquea (hard) cuando hay discrepancia plugin/local' {
    $sandbox = New-Sandbox
    try {
      $pluginScripts = New-PluginCandidate $sandbox 'bossdream-core'
      $localHooks = New-LocalHooksDir $sandbox
      Set-Content -Path (Join-Path $pluginScripts 'a.ps1') -Value 'Write-Output "nuevo"'
      Set-Content -Path (Join-Path $localHooks 'a.ps1') -Value 'Write-Output "viejo"'
      New-HookSiblingsDriftPipeline $sandbox

      $result = Invoke-Pipeline $sandbox

      $result.ExitCode | Should -Be 1
      $result.Output | Should -Match 'hook-siblings-drift'
      (Get-Content (Join-Path $localHooks 'a.ps1') -Raw) | Should -Match 'viejo'
    } finally {
      Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
    }
  }

  It 'etapa hook-siblings-drift pasa (y no modifica nada) cuando plugin y local coinciden' {
    $sandbox = New-Sandbox
    try {
      $pluginScripts = New-PluginCandidate $sandbox 'bossdream-core'
      $localHooks = New-LocalHooksDir $sandbox
      Set-Content -Path (Join-Path $pluginScripts 'a.ps1') -Value 'Write-Output 1'
      Set-Content -Path (Join-Path $localHooks 'a.ps1') -Value 'Write-Output 1'
      New-HookSiblingsDriftPipeline $sandbox

      $result = Invoke-Pipeline $sandbox

      $result.ExitCode | Should -Be 0
    } finally {
      Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
    }
  }

  It 'pasa el modo Check via el campo args de la etapa, nunca Sync (no copia el archivo del plugin sobre el local)' {
    $sandbox = New-Sandbox
    try {
      $pluginScripts = New-PluginCandidate $sandbox 'bossdream-core'
      $localHooks = New-LocalHooksDir $sandbox
      Set-Content -Path (Join-Path $pluginScripts 'a.ps1') -Value 'Write-Output "plugin"'
      Set-Content -Path (Join-Path $localHooks 'a.ps1') -Value 'Write-Output "local"'
      New-HookSiblingsDriftPipeline $sandbox

      Invoke-Pipeline $sandbox | Out-Null

      (Get-Content (Join-Path $localHooks 'a.ps1') -Raw) | Should -Match 'local'
      (Get-Content (Join-Path $pluginScripts 'a.ps1') -Raw) | Should -Match 'plugin'
    } finally {
      Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
    }
  }
}
