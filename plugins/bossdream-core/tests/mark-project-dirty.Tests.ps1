BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:ScaffoldScript = Join-Path $script:PluginRoot 'scripts/project-scaffold.ps1'
  $script:MarkScript = Join-Path $script:PluginRoot 'scripts/mark-project-dirty.ps1'

  function Invoke-MarkDirty([string]$FilePath, [string]$ProjectDir) {
    $payload = @{ cwd = $ProjectDir; tool_input = @{ file_path = $FilePath } } | ConvertTo-Json -Compress
    $payload | & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:MarkScript
  }
}

Describe 'mark-project-dirty.ps1' {

  BeforeEach {
    $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("mark-dirty-test-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $script:Sandbox | Out-Null
    $env:CLAUDE_PLUGIN_ROOT = $script:PluginRoot
    & $script:ScaffoldScript -ProjectDir $script:Sandbox -ProjectSlug 'demo' -ProjectId 'REQ-800' -ProjectName 'Demo' -Classification 'Medio' | Out-Null
    $script:DestDir = Join-Path $script:Sandbox 'bossdream_projects/demo'
    $script:DotDir = Join-Path $script:DestDir '.bossdream-project'
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
    Remove-Item Env:\CLAUDE_PLUGIN_ROOT -ErrorAction SilentlyContinue
  }

  It 'marca pending SOLO el documento editado, sin tocar el estado de los demas (pipeline del Increment 6)' {
    $validation = Get-Content (Join-Path $script:DotDir 'validation.json') -Raw | ConvertFrom-Json
    $validation.documents.'requirements.md' = [PSCustomObject]@{ status = 'verified'; documentFingerprint = 'fp-2'; checks = @() }
    $validation.documents.'tests/test-approach.md' = [PSCustomObject]@{ status = 'verified'; documentFingerprint = 'fp-3'; checks = @() }
    $validation.overallStatus = 'ready'
    $validation | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $script:DotDir 'validation.json') -Encoding utf8

    $editedPath = Join-Path $script:DestDir 'requirements.md'
    Invoke-MarkDirty -FilePath $editedPath -ProjectDir $script:Sandbox | Out-Null

    $validationAfter = Get-Content (Join-Path $script:DotDir 'validation.json') -Raw | ConvertFrom-Json
    $validationAfter.documents.'requirements.md'.status | Should -Be 'pending'
    $validationAfter.documents.'tests/test-approach.md'.status | Should -Be 'verified'
    $validationAfter.overallStatus | Should -Be 'blocked'
  }

  It 'no hace nada si el archivo editado no esta bajo bossdream_projects/<activo>/' {
    $outsideFile = Join-Path $script:Sandbox 'nota-suelta.md'
    Set-Content $outsideFile -Value 'algo' -Encoding utf8
    $validationBefore = Get-Content (Join-Path $script:DotDir 'validation.json') -Raw

    Invoke-MarkDirty -FilePath $outsideFile -ProjectDir $script:Sandbox | Out-Null

    $validationAfter = Get-Content (Join-Path $script:DotDir 'validation.json') -Raw
    $validationAfter | Should -Be $validationBefore
  }

  It 'no hace nada sobre un archivo nuevo que todavia no esta registrado en validation.json' {
    New-Item -ItemType Directory -Force -Path (Join-Path $script:DestDir 'tests/cases') | Out-Null
    $newTc = Join-Path $script:DestDir 'tests/cases/TC-777.md'
    Set-Content $newTc -Value '# TC-777' -Encoding utf8
    $validationBefore = Get-Content (Join-Path $script:DotDir 'validation.json') -Raw | ConvertFrom-Json

    Invoke-MarkDirty -FilePath $newTc -ProjectDir $script:Sandbox | Out-Null

    $validationAfter = Get-Content (Join-Path $script:DotDir 'validation.json') -Raw | ConvertFrom-Json
    ($validationAfter.documents.PSObject.Properties.Name -contains 'tests/cases/TC-777.md') | Should -BeFalse
    $validationAfter.overallStatus | Should -Be $validationBefore.overallStatus
  }

  It 'ignora archivos que no son .md' {
    $psFile = Join-Path $script:DestDir 'algo.ps1'
    Set-Content $psFile -Value 'Write-Output 1' -Encoding utf8
    $validationBefore = Get-Content (Join-Path $script:DotDir 'validation.json') -Raw

    Invoke-MarkDirty -FilePath $psFile -ProjectDir $script:Sandbox | Out-Null

    $validationAfter = Get-Content (Join-Path $script:DotDir 'validation.json') -Raw
    $validationAfter | Should -Be $validationBefore
  }

  It 'no marca pending si el contenido reescrito es identico (fingerprint real coincide)' {
    $editedPath = Join-Path $script:DestDir 'requirements.md'
    $bytes = [System.IO.File]::ReadAllBytes($editedPath)
    $realFingerprint = (Get-FileHash -Path $editedPath -Algorithm SHA256).Hash

    $validation = Get-Content (Join-Path $script:DotDir 'validation.json') -Raw | ConvertFrom-Json
    $validation.documents.'requirements.md' = [PSCustomObject]@{ status = 'verified'; documentFingerprint = $realFingerprint; checks = @() }
    $validation.overallStatus = 'ready'
    $validation | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $script:DotDir 'validation.json') -Encoding utf8

    [System.IO.File]::WriteAllBytes($editedPath, $bytes)
    Invoke-MarkDirty -FilePath $editedPath -ProjectDir $script:Sandbox | Out-Null

    $validationAfter = Get-Content (Join-Path $script:DotDir 'validation.json') -Raw | ConvertFrom-Json
    $validationAfter.documents.'requirements.md'.status | Should -Be 'verified'
    $validationAfter.overallStatus | Should -Be 'ready'
  }

  It 'no revienta con stdin vacio o sin proyecto activo' {
    '' | & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $script:MarkScript
    $LASTEXITCODE | Should -Be 0
  }
}
