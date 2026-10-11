BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:ScriptPath = Join-Path $script:PluginRoot 'scripts/hook-siblings-sync.ps1'

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

  function Invoke-Sync([string]$SandboxRoot, [string]$Mode) {
    $out = & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:ScriptPath -ProjectDir $SandboxRoot -Mode $Mode 2>&1
    return [PSCustomObject]@{ Output = ($out -join "`n"); ExitCode = $LASTEXITCODE }
  }
}

Describe 'hook-siblings-sync.ps1' {
  It 'Check pasa cuando los archivos comunes son idénticos' {
    $sandbox = New-Sandbox
    try {
      $pluginScripts = New-PluginCandidate $sandbox 'bossdream-core'
      $localHooks = New-LocalHooksDir $sandbox
      Set-Content -Path (Join-Path $pluginScripts 'a.ps1') -Value 'Write-Output 1'
      Set-Content -Path (Join-Path $localHooks 'a.ps1') -Value 'Write-Output 1'
      Set-Content -Path (Join-Path $pluginScripts 'b.ps1') -Value 'Write-Output 2'
      Set-Content -Path (Join-Path $localHooks 'b.ps1') -Value 'Write-Output 2'

      $result = Invoke-Sync $sandbox 'Check'

      $result.ExitCode | Should -Be 0
    } finally {
      Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
    }
  }

  It 'Check reporta la discrepancia y falla cuando un archivo difiere' {
    $sandbox = New-Sandbox
    try {
      $pluginScripts = New-PluginCandidate $sandbox 'bossdream-core'
      $localHooks = New-LocalHooksDir $sandbox
      Set-Content -Path (Join-Path $pluginScripts 'drift.ps1') -Value 'Write-Output "nuevo"'
      Set-Content -Path (Join-Path $localHooks 'drift.ps1') -Value 'Write-Output "viejo"'

      $result = Invoke-Sync $sandbox 'Check'

      $result.ExitCode | Should -Be 1
      $result.Output | Should -Match 'drift.ps1'
    } finally {
      Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
    }
  }

  It 'Sync copia el archivo del plugin sobre el local y deja los hashes iguales' {
    $sandbox = New-Sandbox
    try {
      $pluginScripts = New-PluginCandidate $sandbox 'bossdream-core'
      $localHooks = New-LocalHooksDir $sandbox
      Set-Content -Path (Join-Path $pluginScripts 'drift.ps1') -Value 'Write-Output "nuevo"'
      Set-Content -Path (Join-Path $localHooks 'drift.ps1') -Value 'Write-Output "viejo"'

      $result = Invoke-Sync $sandbox 'Sync'

      $result.ExitCode | Should -Be 0
      $pluginHash = (Get-FileHash -Path (Join-Path $pluginScripts 'drift.ps1') -Algorithm SHA256).Hash
      $localHash = (Get-FileHash -Path (Join-Path $localHooks 'drift.ps1') -Algorithm SHA256).Hash
      $localHash | Should -Be $pluginHash
    } finally {
      Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
    }
  }

  It 'Check detecta un archivo del plugin que falta POR COMPLETO en local (no solo distinto)' {
    $sandbox = New-Sandbox
    try {
      $pluginScripts = New-PluginCandidate $sandbox 'bossdream-core'
      $localHooks = New-LocalHooksDir $sandbox
      Set-Content -Path (Join-Path $pluginScripts 'huerfano.psm1') -Value 'function Foo {}'
      # no se crea huerfano.psm1 en $localHooks -- ausente por completo, no solo con contenido distinto

      $result = Invoke-Sync $sandbox 'Check'

      $result.ExitCode | Should -Be 1
      $result.Output | Should -Match 'huerfano.psm1'
    } finally {
      Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
    }
  }

  It 'Sync copia un archivo del plugin que faltaba por completo en local' {
    $sandbox = New-Sandbox
    try {
      $pluginScripts = New-PluginCandidate $sandbox 'bossdream-core'
      $localHooks = New-LocalHooksDir $sandbox
      Set-Content -Path (Join-Path $pluginScripts 'huerfano.psm1') -Value 'function Foo {}'

      $result = Invoke-Sync $sandbox 'Sync'

      $result.ExitCode | Should -Be 0
      Test-Path (Join-Path $localHooks 'huerfano.psm1') | Should -BeTrue
    } finally {
      Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
    }
  }

  It 'falla explícito cuando no hay ningún candidato con .claude-plugin/plugin.json bajo plugins/' {
    $sandbox = New-Sandbox
    try {
      New-Item -ItemType Directory -Path (Join-Path $sandbox 'plugins') -Force | Out-Null
      New-LocalHooksDir $sandbox | Out-Null

      $result = Invoke-Sync $sandbox 'Check'

      $result.ExitCode | Should -Be 1
      $result.Output | Should -Match 'no se encontro ningun plugin'
    } finally {
      Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
    }
  }

  It 'falla explícito cuando hay 2 candidatos con .claude-plugin/plugin.json bajo plugins/' {
    $sandbox = New-Sandbox
    try {
      New-PluginCandidate $sandbox 'PluginUno' | Out-Null
      New-PluginCandidate $sandbox 'PluginDos' | Out-Null
      New-LocalHooksDir $sandbox | Out-Null

      $result = Invoke-Sync $sandbox 'Check'

      $result.ExitCode | Should -Be 1
      $result.Output | Should -Match 'multiples plugins candidatos'
    } finally {
      Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
    }
  }
}
