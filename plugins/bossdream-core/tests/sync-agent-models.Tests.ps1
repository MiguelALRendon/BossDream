BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:SyncScript = Join-Path $script:PluginRoot 'scripts/sync-agent-models.ps1'

  function Invoke-SyncAgentModelsDirect([string]$ProjectDir) {
    & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:SyncScript -ProjectDir $ProjectDir
  }

  function Invoke-SyncAgentModelsHook([string]$FilePath, [string]$ProjectDir) {
    $payload = @{ cwd = $ProjectDir; tool_name = 'Edit'; tool_input = @{ file_path = $FilePath } } | ConvertTo-Json -Compress
    $payload | & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:SyncScript
  }

  function Write-SyncBossdreamConfig {
    param(
      [string]$ProjectDir,
      [string]$DefaultModel,
      [hashtable]$AgentModels,
      [switch]$NoModelsSection
    )
    if ($NoModelsSection) {
      $cfg = @{ other = 'value' }
    } else {
      $models = @{}
      if ($DefaultModel) { $models.default = $DefaultModel }
      if ($AgentModels) { $models.agents = $AgentModels }
      $cfg = @{ models = $models }
    }
    $cfg | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $ProjectDir 'bossdream.json') -Encoding utf8
  }

  function New-AgentFile {
    param(
      [string]$ProjectDir,
      [string]$AgentName,
      [string]$Model,
      [string]$FileName
    )
    $dir = Join-Path $ProjectDir 'plugins/bossdream-core/agents'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    if (-not $FileName) { $FileName = "$AgentName.md" }
    $path = Join-Path $dir $FileName
    $content = "---`nname: $AgentName`nmodel: $Model`n---`n`nBody.`n"
    [System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))
    return $path
  }
}

Describe 'sync-agent-models.ps1' {

  BeforeEach {
    $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("sync-agent-models-test-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $script:Sandbox | Out-Null
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
  }

  It 'agente con modelo distinto al configurado -> reescribe el frontmatter y reporta el cambio' {
    Write-SyncBossdreamConfig -ProjectDir $script:Sandbox -DefaultModel 'claude-haiku' -AgentModels @{ 'my-agent' = 'claude-sonnet-5' }
    $agentPath = New-AgentFile -ProjectDir $script:Sandbox -AgentName 'my-agent' -Model 'claude-haiku'

    $output = Invoke-SyncAgentModelsDirect -ProjectDir $script:Sandbox

    $output | Should -Match 'my-agent: claude-haiku -> claude-sonnet-5'
    $rewritten = [System.IO.File]::ReadAllText($agentPath)
    $rewritten | Should -Match '(?m)^model:\s*claude-sonnet-5\s*$'
  }

  It 'agente con modelo ya sincronizado -> no toca el archivo (hash identico antes/despues)' {
    Write-SyncBossdreamConfig -ProjectDir $script:Sandbox -DefaultModel 'claude-haiku' -AgentModels @{ 'my-agent' = 'claude-sonnet-5' }
    $agentPath = New-AgentFile -ProjectDir $script:Sandbox -AgentName 'my-agent' -Model 'claude-sonnet-5'
    $hashBefore = (Get-FileHash -Algorithm SHA256 -Path $agentPath).Hash

    $output = Invoke-SyncAgentModelsDirect -ProjectDir $script:Sandbox

    $output | Should -Match "sin cambios"
    $hashAfter = (Get-FileHash -Algorithm SHA256 -Path $agentPath).Hash
    $hashAfter | Should -Be $hashBefore
  }

  It 'agente sin entrada en models.agents -> hace fallback a models.default' {
    Write-SyncBossdreamConfig -ProjectDir $script:Sandbox -DefaultModel 'claude-sonnet-5' -AgentModels @{ 'other-agent' = 'claude-opus' }
    $agentPath = New-AgentFile -ProjectDir $script:Sandbox -AgentName 'my-agent' -Model 'old-model'

    $output = Invoke-SyncAgentModelsDirect -ProjectDir $script:Sandbox

    $output | Should -Match 'my-agent: old-model -> claude-sonnet-5'
    $rewritten = [System.IO.File]::ReadAllText($agentPath)
    $rewritten | Should -Match '(?m)^model:\s*claude-sonnet-5\s*$'
  }

  It 'modo hook con tool_input.file_path=bossdream.json -> corre la sincronizacion' {
    Write-SyncBossdreamConfig -ProjectDir $script:Sandbox -DefaultModel 'claude-sonnet-5' -AgentModels @{}
    $agentPath = New-AgentFile -ProjectDir $script:Sandbox -AgentName 'my-agent' -Model 'old-model'
    $hookFilePath = Join-Path $script:Sandbox 'bossdream.json'

    $output = Invoke-SyncAgentModelsHook -FilePath $hookFilePath -ProjectDir $script:Sandbox

    $output | Should -Match 'my-agent: old-model -> claude-sonnet-5'
    $rewritten = [System.IO.File]::ReadAllText($agentPath)
    $rewritten | Should -Match '(?m)^model:\s*claude-sonnet-5\s*$'
  }

  It 'modo hook con tool_input.file_path de otro archivo -> sale sin tocar nada' {
    Write-SyncBossdreamConfig -ProjectDir $script:Sandbox -DefaultModel 'claude-sonnet-5' -AgentModels @{}
    $agentPath = New-AgentFile -ProjectDir $script:Sandbox -AgentName 'my-agent' -Model 'old-model'
    $hashBefore = (Get-FileHash -Algorithm SHA256 -Path $agentPath).Hash
    $otherFilePath = Join-Path $script:Sandbox 'src/foo.ps1'

    $output = Invoke-SyncAgentModelsHook -FilePath $otherFilePath -ProjectDir $script:Sandbox

    $output | Should -BeNullOrEmpty
    $hashAfter = (Get-FileHash -Algorithm SHA256 -Path $agentPath).Hash
    $hashAfter | Should -Be $hashBefore
  }

  It 'bossdream.json sin seccion models -> mensaje informativo sin error' {
    Write-SyncBossdreamConfig -ProjectDir $script:Sandbox -NoModelsSection

    $output = Invoke-SyncAgentModelsDirect -ProjectDir $script:Sandbox

    $output | Should -Match "no tiene seccion 'models'"
    $LASTEXITCODE | Should -Be 0
  }
}
