BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:MarkScript = Join-Path $script:PluginRoot 'scripts/validation-mark-mechanical.ps1'

  function New-Sandbox {
    $sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("validation-mark-mechanical-test-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
    return $sandbox
  }

  function New-ValidationFixture([string]$Sandbox, [string]$Slug, [hashtable]$Validation) {
    $dotDir = Join-Path $Sandbox "bossdream_projects/$Slug/.bossdream-project"
    New-Item -ItemType Directory -Force -Path $dotDir | Out-Null
    $validationPath = Join-Path $dotDir 'validation.json'
    $Validation | ConvertTo-Json -Depth 10 | Set-Content $validationPath -Encoding utf8
    return $validationPath
  }

  function Write-Utf8([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
  }

  function Invoke-MarkMechanical([string]$Sandbox, [string]$Slug, [string]$Pattern, [string]$Reason) {
    $output = & (Get-Process -Id $PID).Path -File $script:MarkScript -ProjectSlug $Slug -DocPattern "$Pattern" -Reason $Reason -ProjectDir $Sandbox
    return [PSCustomObject]@{ Output = $output; ExitCode = $LASTEXITCODE }
  }

  function Get-DocEntry($Validation, [string]$DocKey) {
    return $Validation.documents.PSObject.Properties[$DocKey].Value
  }
}

Describe 'validation-mark-mechanical.ps1' {

  BeforeEach {
    $script:Sandbox = New-Sandbox
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
  }

  It 'documento verified con contenido cambiado -> actualiza fingerprint, preserva status verified, agrega entrada al log' {
    $docKey = 'tests/cases/TC-001.md'
    $destDir = Join-Path $script:Sandbox 'bossdream_projects/demo'
    New-Item -ItemType Directory -Force -Path (Join-Path $destDir 'tests/cases') | Out-Null
    $docPath = Join-Path $destDir $docKey
    Write-Utf8 $docPath "# TC-001`ncontenido despues de la correccion de ruta"

    New-ValidationFixture $script:Sandbox 'demo' @{
      overallStatus = 'ready'
      exemptions = @()
      documents = @{
        $docKey = @{ status = 'verified'; documentFingerprint = 'hash-vieja-simulada'; checks = @() }
      }
    } | Out-Null

    $result = Invoke-MarkMechanical $script:Sandbox 'demo' 'tests/cases/TC-0*.md' 'correccion de ruta, sin cambio semantico'

    $result.ExitCode | Should -Be 0

    $realHash = (Get-FileHash -Path $docPath -Algorithm SHA256).Hash
    $validationPath = Join-Path $destDir '.bossdream-project/validation.json'
    $validationAfter = Get-Content $validationPath -Raw | ConvertFrom-Json
    $entry = Get-DocEntry $validationAfter $docKey
    $entry.documentFingerprint | Should -Be $realHash
    $entry.status | Should -Be 'verified'

    $logPath = Join-Path $destDir '.bossdream-project/validation-mechanical-overrides.log'
    Test-Path $logPath | Should -Be $true
    (Get-Content $logPath -Raw) | Should -Match ([regex]::Escape($docKey))
    ($result.Output -join "`n") | Should -Match 'actualizados=1'
  }

  It 'documento needs-semantic-review que matchea el patron -> no se toca nada, aparece en omitidos (no verified)' {
    $docKey = 'tests/cases/TC-002.md'
    $destDir = Join-Path $script:Sandbox 'bossdream_projects/demo'
    New-Item -ItemType Directory -Force -Path (Join-Path $destDir 'tests/cases') | Out-Null
    Write-Utf8 (Join-Path $destDir $docKey) "# TC-002`ncontenido"

    New-ValidationFixture $script:Sandbox 'demo' @{
      overallStatus = 'ready'
      exemptions = @()
      documents = @{
        $docKey = @{ status = 'needs-semantic-review'; documentFingerprint = 'hash-vieja-simulada'; checks = @() }
      }
    } | Out-Null

    $result = Invoke-MarkMechanical $script:Sandbox 'demo' 'tests/cases/TC-0*.md' 'correccion de ruta, sin cambio semantico'

    $result.ExitCode | Should -Be 0
    $outputText = $result.Output -join "`n"
    $outputText | Should -Match 'omitidos \(no verified\)'
    $outputText | Should -Match ([regex]::Escape($docKey))

    $validationAfter = Get-Content (Join-Path $destDir '.bossdream-project/validation.json') -Raw | ConvertFrom-Json
    $entry = Get-DocEntry $validationAfter $docKey
    $entry.documentFingerprint | Should -Be 'hash-vieja-simulada'
    $entry.status | Should -Be 'needs-semantic-review'
  }

  It 'documento verified cuyo fingerprint ya coincide -> no se marca como actualizado' {
    $docKey = 'tests/cases/TC-003.md'
    $destDir = Join-Path $script:Sandbox 'bossdream_projects/demo'
    New-Item -ItemType Directory -Force -Path (Join-Path $destDir 'tests/cases') | Out-Null
    $docPath = Join-Path $destDir $docKey
    Write-Utf8 $docPath "# TC-003`ncontenido sin cambios"
    $realHash = (Get-FileHash -Path $docPath -Algorithm SHA256).Hash

    New-ValidationFixture $script:Sandbox 'demo' @{
      overallStatus = 'ready'
      exemptions = @()
      documents = @{
        $docKey = @{ status = 'verified'; documentFingerprint = $realHash; checks = @() }
      }
    } | Out-Null

    $result = Invoke-MarkMechanical $script:Sandbox 'demo' 'tests/cases/TC-0*.md' 'correccion de ruta, sin cambio semantico'

    $result.ExitCode | Should -Be 0
    $outputText = $result.Output -join "`n"
    $outputText | Should -Match 'actualizados=0'
    $outputText | Should -Not -Match ([regex]::Escape($docKey))

    $validationAfter = Get-Content (Join-Path $destDir '.bossdream-project/validation.json') -Raw | ConvertFrom-Json
    (Get-DocEntry $validationAfter $docKey).documentFingerprint | Should -Be $realHash
  }

  It 'documento que matchea el patron pero no existe en disco -> aparece en no encontrados, sin error' {
    $docKey = 'tests/cases/TC-004.md'
    $destDir = Join-Path $script:Sandbox 'bossdream_projects/demo'

    New-ValidationFixture $script:Sandbox 'demo' @{
      overallStatus = 'ready'
      exemptions = @()
      documents = @{
        $docKey = @{ status = 'verified'; documentFingerprint = 'hash-vieja-simulada'; checks = @() }
      }
    } | Out-Null

    $result = Invoke-MarkMechanical $script:Sandbox 'demo' 'tests/cases/TC-0*.md' 'correccion de ruta, sin cambio semantico'

    $result.ExitCode | Should -Be 0
    $outputText = $result.Output -join "`n"
    $outputText | Should -Match 'no encontrados en disco'
    $outputText | Should -Match ([regex]::Escape($docKey))

    $validationAfter = Get-Content (Join-Path $destDir '.bossdream-project/validation.json') -Raw | ConvertFrom-Json
    (Get-DocEntry $validationAfter $docKey).documentFingerprint | Should -Be 'hash-vieja-simulada'
  }

  It 'validation.json inexistente -> mensaje claro, exit 1, sin crashear' {
    $result = Invoke-MarkMechanical $script:Sandbox 'fantasma' '*.md' 'correccion de ruta, sin cambio semantico'

    $result.ExitCode | Should -Be 1
    ($result.Output -join "`n") | Should -Match 'no existe validation\.json'
  }
}
