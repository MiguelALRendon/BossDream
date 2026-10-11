BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/validation-trace-check.ps1'
}

Describe 'validation-trace-check.ps1' {

  BeforeEach {
    $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("validation-trace-test-" + [System.Guid]::NewGuid().ToString('N'))
    $script:DestDir = Join-Path $script:Sandbox 'bossdream_projects/demo'
    $script:DotDir = Join-Path $script:DestDir '.bossdream-project'
    New-Item -ItemType Directory -Force -Path $script:DotDir | Out-Null
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
  }

  It 'pasa cuando cada ID mencionado en un documento tiene nodo en traceability.json y viceversa' {
    Set-Content (Join-Path $script:DestDir 'requirements.md') -Value '## US-001 - algo, AC-001.1, TC-001' -Encoding utf8
    $trace = @{ stories = @{ 'US-001' = @{ acceptanceCriteria = @('AC-001.1'); tests = @('TC-001') } } }
    $trace | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $script:DotDir 'traceability.json') -Encoding utf8

    $result = & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | ConvertFrom-Json
    $result.status | Should -Be 'pass'
  }

  It 'detecta un ID huerfano (mencionado en texto, sin nodo en traceability.json)' {
    Set-Content (Join-Path $script:DestDir 'requirements.md') -Value '## US-002 - algo nuevo' -Encoding utf8
    @{} | ConvertTo-Json | Set-Content (Join-Path $script:DotDir 'traceability.json') -Encoding utf8

    $result = & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    ($result.findings -join ' ') | Should -Match 'huerfano'
    ($result.findings -join ' ') | Should -Match 'US-002'
  }

  It 'detecta un ID fantasma (existe en traceability.json, sin mencion en ningun documento)' {
    Set-Content (Join-Path $script:DestDir 'requirements.md') -Value '## nada relevante aqui' -Encoding utf8
    $trace = @{ 'REQ-001' = @{ stories = @{ 'US-003' = @{ acceptanceCriteria = @(); tests = @() } } } }
    $trace | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $script:DotDir 'traceability.json') -Encoding utf8

    $result = & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    ($result.findings -join ' ') | Should -Match 'fantasma'
    ($result.findings -join ' ') | Should -Match 'US-003'
  }

  It 'ignora los placeholders literales -XXX- de las plantillas (no son IDs reales)' {
    Set-Content (Join-Path $script:DestDir 'requirements.md') -Value '## US-XXX - plantilla, AC-XXX.1' -Encoding utf8
    @{} | ConvertTo-Json | Set-Content (Join-Path $script:DotDir 'traceability.json') -Encoding utf8

    $result = & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | ConvertFrom-Json
    $result.status | Should -Be 'pass'
  }

  It 'no marca huerfano el ID propio del proyecto (project.json.id), aunque no tenga nodo en traceability.json' {
    Set-Content (Join-Path $script:DestDir 'understanding.md') -Value '# REQ-042 - este mismo proyecto' -Encoding utf8
    @{} | ConvertTo-Json | Set-Content (Join-Path $script:DotDir 'traceability.json') -Encoding utf8
    @{ id = 'REQ-042' } | ConvertTo-Json | Set-Content (Join-Path $script:DotDir 'project.json') -Encoding utf8

    $result = & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | ConvertFrom-Json
    $result.status | Should -Be 'pass'
  }

  It 'usa el resultado cacheado (firma mtime+size sin cambios) y no relee contenido corrompido despues' {
    $reqPath = Join-Path $script:DestDir 'requirements.md'
    [System.IO.File]::WriteAllText($reqPath, '## US-001 - algo, AC-001.1, TC-001', [System.Text.Encoding]::UTF8)
    $trace = @{ stories = @{ 'US-001' = @{ acceptanceCriteria = @('AC-001.1'); tests = @('TC-001') } } }
    $trace | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $script:DotDir 'traceability.json') -Encoding utf8

    $first = & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | ConvertFrom-Json
    $first.status | Should -Be 'pass'

    $originalTime = (Get-Item $reqPath).LastWriteTimeUtc
    $corrupted = (Get-Content $reqPath -Raw) -replace 'US-001', 'US-002'
    [System.IO.File]::WriteAllText($reqPath, $corrupted, [System.Text.Encoding]::UTF8)
    (Get-Item $reqPath).LastWriteTimeUtc = $originalTime

    $second = & $script:Script -ProjectDir $script:Sandbox -ProjectSlug 'demo' | ConvertFrom-Json
    $second.status | Should -Be 'pass'
    ($second.findings -join ' ') | Should -Not -Match 'US-002'
  }
}
