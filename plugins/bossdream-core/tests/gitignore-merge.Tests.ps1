BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:ScaffoldScript = Join-Path $script:PluginRoot 'scripts/project-scaffold.ps1'
}

Describe 'project-scaffold.ps1 - merge de .gitignore para .active-project' {

  BeforeEach {
    $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("gitignore-merge-test-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $script:Sandbox | Out-Null
    $env:CLAUDE_PLUGIN_ROOT = $script:PluginRoot
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
    Remove-Item Env:\CLAUDE_PLUGIN_ROOT -ErrorAction SilentlyContinue
  }

  It 'agrega .claude/.active-project a un .gitignore que no existia' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-970' -ProjectName 'Demo' -Classification 'Simple' | Out-Null

    $gitignorePath = Join-Path $script:Sandbox '.gitignore'
    Test-Path $gitignorePath | Should -BeTrue
    (Get-Content $gitignorePath) | Should -Contain '.claude/.active-project'
  }

  It 'preserva el contenido existente de .gitignore (append, no overwrite)' {
    $gitignorePath = Join-Path $script:Sandbox '.gitignore'
    Set-Content $gitignorePath -Value @('node_modules/', 'bin/') -Encoding utf8

    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-971' -ProjectName 'Demo' -Classification 'Simple' | Out-Null

    $lines = Get-Content $gitignorePath
    $lines | Should -Contain 'node_modules/'
    $lines | Should -Contain 'bin/'
    $lines | Should -Contain '.claude/.active-project'
  }

  It 'es idempotente: correr el scaffold dos veces (proyectos distintos) no duplica la linea' {
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo-a' -ProjectId 'REQ-972' -ProjectName 'Demo A' -Classification 'Simple' | Out-Null
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo-b' -ProjectId 'REQ-973' -ProjectName 'Demo B' -Classification 'Simple' | Out-Null

    $lines = @(Get-Content (Join-Path $script:Sandbox '.gitignore'))
    @($lines | Where-Object { $_ -eq '.claude/.active-project' }).Count | Should -Be 1
  }

  It 'no duplica si la linea ya existia de antes en .gitignore' {
    $gitignorePath = Join-Path $script:Sandbox '.gitignore'
    Set-Content $gitignorePath -Value @('.claude/.active-project') -Encoding utf8

    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-974' -ProjectName 'Demo' -Classification 'Simple' | Out-Null

    $lines = @(Get-Content $gitignorePath)
    @($lines | Where-Object { $_ -eq '.claude/.active-project' }).Count | Should -Be 1
  }
}
