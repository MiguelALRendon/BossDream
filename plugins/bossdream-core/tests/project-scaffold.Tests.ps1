BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:ScaffoldScript = Join-Path $PluginRoot 'scripts/project-scaffold.ps1'
}

Describe 'project-scaffold.ps1' {

  BeforeEach {
    $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("bossdream-project-test-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $script:Sandbox | Out-Null
    $env:CLAUDE_PLUGIN_ROOT = $script:PluginRoot
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
    Remove-Item Env:\CLAUDE_PLUGIN_ROOT -ErrorAction SilentlyContinue
  }

  It 'crea el arbol completo de bossdream_projects/<proyecto>/ con una sola invocacion' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-001' -ProjectName 'Demo' -Classification 'Medio'

    $destDir = Join-Path $script:Sandbox 'bossdream_projects/demo'
    Test-Path (Join-Path $destDir 'overview.md') | Should -BeFalse
    Test-Path (Join-Path $destDir 'understanding.md') | Should -BeFalse
    Test-Path (Join-Path $destDir 'requirements.md') | Should -BeTrue
    Test-Path (Join-Path $destDir 'tests/test-approach.md') | Should -BeTrue
    Test-Path (Join-Path $destDir 'tests/_templates/test-case.md') | Should -BeTrue
    Test-Path (Join-Path $destDir '.bossdream-project/project.json') | Should -BeTrue
    Test-Path (Join-Path $destDir '.bossdream-project/validation.json') | Should -BeTrue
    Test-Path (Join-Path $destDir '.bossdream-project/traceability.json') | Should -BeTrue
    Test-Path (Join-Path $destDir '.bossdream-project/plan-progress.json') | Should -BeTrue
    Test-Path (Join-Path $script:Sandbox '.claude/.active-project') | Should -BeTrue

    $requerimientos = Get-Content (Join-Path $destDir 'requirements.md') -Raw
    $requerimientos | Should -Match 'Reglas de negocio relevantes'
  }

  It 'deja validation.json con overallStatus blocked y project.json con los datos recibidos' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-002' -ProjectName 'Demo Dos' -Classification 'Complejo' | Out-Null

    $destDir = Join-Path $script:Sandbox 'bossdream_projects/demo'
    $validation = Get-Content (Join-Path $destDir '.bossdream-project/validation.json') -Raw | ConvertFrom-Json
    $validation.overallStatus | Should -Be 'blocked'

    $project = Get-Content (Join-Path $destDir '.bossdream-project/project.json') -Raw | ConvertFrom-Json
    $project.id | Should -Be 'REQ-002'
    $project.name | Should -Be 'Demo Dos'
    $project.classification | Should -Be 'Complejo'
    $project.status | Should -Be 'draft'
  }

  It 'escribe .claude/.active-project con el slug del proyecto' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-003' -ProjectName 'Demo Tres' -Classification 'Simple' | Out-Null

    $activeProject = Get-Content (Join-Path $script:Sandbox '.claude/.active-project') -Raw
    $activeProject.Trim() | Should -Be 'demo'
  }

  It 'es idempotente: correrlo dos veces no duplica ni corrompe, la segunda corrida es un SKIP explicito' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-004' -ProjectName 'Demo Cuatro' -Classification 'Medio' | Out-Null
    $destDir = Join-Path $script:Sandbox 'bossdream_projects/demo'
    $firstProjectJson = Get-Content (Join-Path $destDir '.bossdream-project/project.json') -Raw

    $secondRunOutput = & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-999' -ProjectName 'Otro Nombre' -Classification 'Complejo'

    $secondRunOutput | Should -Match 'SKIP'
    $secondProjectJson = Get-Content (Join-Path $destDir '.bossdream-project/project.json') -Raw
    $secondProjectJson | Should -Be $firstProjectJson
  }

  It 'copia validation-lock.ps1 a .claude/bossdream-hooks/ y registra el hook UserPromptSubmit en settings.json (Increment 3)' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-005' -ProjectName 'Demo Cinco' -Classification 'Simple' | Out-Null

    Test-Path (Join-Path $script:Sandbox '.claude/bossdream-hooks/validation-lock.ps1') | Should -BeTrue

    $settings = Get-Content (Join-Path $script:Sandbox '.claude/settings.json') -Raw | ConvertFrom-Json
    $commands = @($settings.hooks.UserPromptSubmit | ForEach-Object { $_.hooks } | ForEach-Object { $_.command })
    ($commands -join ' ') | Should -Match 'validation-lock\.ps1'
  }

  It 'el merge de settings.json es idempotente: correr el scaffold dos veces (proyectos distintos) no duplica la entrada del hook' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo-a' -ProjectId 'REQ-006' -ProjectName 'Demo A' -Classification 'Simple' | Out-Null
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo-b' -ProjectId 'REQ-007' -ProjectName 'Demo B' -Classification 'Simple' | Out-Null

    $settings = Get-Content (Join-Path $script:Sandbox '.claude/settings.json') -Raw | ConvertFrom-Json
    $entries = @($settings.hooks.UserPromptSubmit)
    $validationGateEntries = @($entries | Where-Object { (@($_.hooks | ForEach-Object { $_.command }) -join ' ') -match 'validation-lock\.ps1' })
    $validationGateEntries.Count | Should -Be 1
  }

  It 'el merge de settings.json preserva contenido preexistente (no pisa hooks/permisos de otros plugins)' {
    $claudeDir = Join-Path $script:Sandbox '.claude'
    New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
    $existingSettings = [PSCustomObject]@{
      permissions = [PSCustomObject]@{ allow = @('Bash(dotnet build*)') }
      hooks = [PSCustomObject]@{
        UserPromptSubmit = @(
          [PSCustomObject]@{ hooks = @([PSCustomObject]@{ type = 'command'; command = 'powershell ... readiness.ps1'; timeout = 15 }) }
        )
      }
    }
    $existingSettings | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $claudeDir 'settings.json') -Encoding utf8

    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-008' -ProjectName 'Demo Ocho' -Classification 'Simple' | Out-Null

    $settings = Get-Content (Join-Path $claudeDir 'settings.json') -Raw | ConvertFrom-Json
    $settings.permissions.allow | Should -Contain 'Bash(dotnet build*)'
    $commands = @($settings.hooks.UserPromptSubmit | ForEach-Object { $_.hooks } | ForEach-Object { $_.command })
    ($commands -join ' ') | Should -Match 'readiness\.ps1'
    ($commands -join ' ') | Should -Match 'validation-lock\.ps1'
  }
}
