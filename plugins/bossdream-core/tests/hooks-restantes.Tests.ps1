BeforeAll {
  $script:Scripts = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts'
  $script:HostExe = (Get-Process -Id $PID).Path

  function Invoke-Script([string]$Name, [string]$StdIn, [string[]]$Arguments = @()) {
    $out = if ($null -ne $StdIn) { $StdIn | & $script:HostExe -NoProfile -File (Join-Path $script:Scripts "$Name.ps1") @Arguments } else { & $script:HostExe -NoProfile -File (Join-Path $script:Scripts "$Name.ps1") @Arguments }
    return [PSCustomObject]@{ Output = ($out -join "`n"); ExitCode = $LASTEXITCODE }
  }

  function Set-Pipeline([string]$Cmd) {
    @{ stages = @(@{ id = 'etapa'; order = 1; cmd = $Cmd; tier = 'local'; blocking = 'hard' }) } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $script:Proj 'pipeline.json') -Encoding utf8
    @{ maxBlocks = 2 } | ConvertTo-Json | Set-Content (Join-Path $script:Proj 'completion.json') -Encoding utf8
    New-Item -ItemType File -Force -Path (Join-Path $script:Proj '.claude/.bossdream-dirty') | Out-Null
  }

  function New-Project {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("hooks-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path (Join-Path $dir '.claude') | Out-Null
    return $dir
  }
}

Describe 'readiness.ps1' {
  BeforeEach { $script:Proj = New-Project }
  AfterEach { Remove-Item -Recurse -Force $script:Proj -ErrorAction SilentlyContinue }

  It 'fija .work-mode=plan con /bossdream-plan' {
    $payload = @{ cwd = $script:Proj; prompt = '/bossdream-plan quiero algo' } | ConvertTo-Json -Compress
    Invoke-Script 'readiness' $payload | Out-Null
    (Get-Content (Join-Path $script:Proj '.claude/.work-mode') -Raw).Trim() | Should -Be 'plan'
  }

  It 'fija .work-mode=implement con /bossdream-implement' {
    $payload = @{ cwd = $script:Proj; prompt = '/bossdream-implement' } | ConvertTo-Json -Compress
    Invoke-Script 'readiness' $payload | Out-Null
    (Get-Content (Join-Path $script:Proj '.claude/.work-mode') -Raw).Trim() | Should -Be 'implement'
  }

  It '/bossdream-mode chore fija chore y clear lo borra' {
    Invoke-Script 'readiness' (@{ cwd = $script:Proj; prompt = '/bossdream-mode chore' } | ConvertTo-Json -Compress) | Out-Null
    (Get-Content (Join-Path $script:Proj '.claude/.work-mode') -Raw).Trim() | Should -Be 'chore'
    Invoke-Script 'readiness' (@{ cwd = $script:Proj; prompt = '/bossdream-mode clear' } | ConvertTo-Json -Compress) | Out-Null
    Test-Path (Join-Path $script:Proj '.claude/.work-mode') | Should -BeFalse
  }

  It 'un prompt cualquiera no cambia el modo' {
    Set-Content (Join-Path $script:Proj '.claude/.work-mode') -Value 'chore' -NoNewline
    Invoke-Script 'readiness' (@{ cwd = $script:Proj; prompt = 'hola' } | ConvertTo-Json -Compress) | Out-Null
    (Get-Content (Join-Path $script:Proj '.claude/.work-mode') -Raw).Trim() | Should -Be 'chore'
  }

  It 'sin carpeta plans/ inyecta el recordatorio; con plans/ no dice nada' {
    $payload = @{ cwd = $script:Proj; prompt = 'hola' } | ConvertTo-Json -Compress
    (Invoke-Script 'readiness' $payload).Output | Should -Match 'plans/'
    New-Item -ItemType Directory -Force -Path (Join-Path $script:Proj 'plans') | Out-Null
    (Invoke-Script 'readiness' $payload).Output | Should -BeNullOrEmpty
  }

  It 'consume el marcador .bossdream-dirty' {
    New-Item -ItemType File -Force -Path (Join-Path $script:Proj '.claude/.bossdream-dirty') | Out-Null
    Invoke-Script 'readiness' (@{ cwd = $script:Proj; prompt = 'hola' } | ConvertTo-Json -Compress) | Out-Null
    Test-Path (Join-Path $script:Proj '.claude/.bossdream-dirty') | Should -BeFalse
  }
}

Describe 'stop-completion.ps1' {
  BeforeEach { $script:Proj = New-Project }
  AfterEach { Remove-Item -Recurse -Force $script:Proj -ErrorAction SilentlyContinue }

  It 'sin marcador no corre nada' {
    Set-Pipeline 'exit 1'
    Remove-Item (Join-Path $script:Proj '.claude/.bossdream-dirty') -Force
    (Invoke-Script 'stop-completion' (@{ cwd = $script:Proj } | ConvertTo-Json -Compress)).Output | Should -BeNullOrEmpty
  }

  It 'con stop_hook_active no corre nada aunque haya marcador' {
    Set-Pipeline 'exit 1'
    $r = Invoke-Script 'stop-completion' (@{ cwd = $script:Proj; stop_hook_active = $true } | ConvertTo-Json -Compress)
    $r.Output | Should -BeNullOrEmpty
  }

  It 'pipeline en verde no bloquea' {
    Set-Pipeline 'exit 0'
    (Invoke-Script 'stop-completion' (@{ cwd = $script:Proj } | ConvertTo-Json -Compress)).Output | Should -BeNullOrEmpty
  }

  It 'pipeline en rojo bloquea y al segundo intento escala' {
    Set-Pipeline 'exit 1'
    $payload = @{ cwd = $script:Proj } | ConvertTo-Json -Compress
    ((Invoke-Script 'stop-completion' $payload).Output | ConvertFrom-Json).decision | Should -Be 'block'
    New-Item -ItemType File -Force -Path (Join-Path $script:Proj '.claude/.bossdream-dirty') | Out-Null
    ((Invoke-Script 'stop-completion' $payload).Output | ConvertFrom-Json).systemMessage | Should -Match 'NO cumplido'
  }
}

Describe 'docdrift-check.ps1' {
  BeforeEach { $script:Proj = New-Project }
  AfterEach { Remove-Item -Recurse -Force $script:Proj -ErrorAction SilentlyContinue }

  It 'sin docs/_inbox sale en 0' {
    (Invoke-Script 'docdrift-check' $null @('-ProjectDir', $script:Proj)).ExitCode | Should -Be 0
  }

  It 'con una nota en _inbox falla' {
    New-Item -ItemType Directory -Force -Path (Join-Path $script:Proj 'docs/_inbox') | Out-Null
    Set-Content (Join-Path $script:Proj 'docs/_inbox/nota.txt') -Value 'x'
    $r = Invoke-Script 'docdrift-check' $null @('-ProjectDir', $script:Proj)
    $r.ExitCode | Should -Be 1
    $r.Output | Should -Match 'nota.txt'
  }

  It 'solo README.md en _inbox pasa' {
    New-Item -ItemType Directory -Force -Path (Join-Path $script:Proj 'docs/_inbox') | Out-Null
    Set-Content (Join-Path $script:Proj 'docs/_inbox/README.md') -Value 'x'
    (Invoke-Script 'docdrift-check' $null @('-ProjectDir', $script:Proj)).ExitCode | Should -Be 0
  }
}

Describe 'gherkin-check.ps1' {
  BeforeEach { $script:Proj = New-Project }
  AfterEach { Remove-Item -Recurse -Force $script:Proj -ErrorAction SilentlyContinue }

  It 'sin .feature sale en 0' {
    (Invoke-Script 'gherkin-check' $null @('-ProjectDir', $script:Proj)).ExitCode | Should -Be 0
  }

  It 'un .feature con exactamente un @happy y @cubre pasa' {
    $f = "Feature: x`n  @happy @cubre:AC-1`n  Scenario: ok`n    Given algo`n    When pasa`n    Then bien`n"
    Set-Content (Join-Path $script:Proj 'a.feature') -Value $f
    (Invoke-Script 'gherkin-check' $null @('-ProjectDir', $script:Proj)).ExitCode | Should -Be 0
  }

  It 'un .feature sin @happy falla' {
    $f = "Feature: x`n  @cubre:AC-1`n  Scenario: ok`n    Given algo`n"
    Set-Content (Join-Path $script:Proj 'a.feature') -Value $f
    $r = Invoke-Script 'gherkin-check' $null @('-ProjectDir', $script:Proj)
    $r.ExitCode | Should -Be 1
    $r.Output | Should -Match '@happy'
  }

  It 'ignora la plantilla _TEMPLATE' {
    New-Item -ItemType Directory -Force -Path (Join-Path $script:Proj 'plans/_TEMPLATE') | Out-Null
    Set-Content (Join-Path $script:Proj 'plans/_TEMPLATE/x.feature') -Value "Feature: vacio`n"
    (Invoke-Script 'gherkin-check' $null @('-ProjectDir', $script:Proj)).ExitCode | Should -Be 0
  }
}

Describe 'style-check.ps1' {
  BeforeEach { $script:Proj = New-Project }
  AfterEach { Remove-Item -Recurse -Force $script:Proj -ErrorAction SilentlyContinue }

  It 'sin CSS sale en 0' {
    (Invoke-Script 'style-check' $null @('-ProjectDir', $script:Proj)).ExitCode | Should -Be 0
  }

  It 'un color quemado falla' {
    Set-Content (Join-Path $script:Proj 'a.css') -Value 'a { color: #ff0000; }'
    $r = Invoke-Script 'style-check' $null @('-ProjectDir', $script:Proj)
    $r.ExitCode | Should -Be 1
    $r.Output | Should -Match 'color quemado'
  }

  It 'un token var() pasa' {
    Set-Content (Join-Path $script:Proj 'a.css') -Value 'a { color: var(--color-text); }'
    (Invoke-Script 'style-check' $null @('-ProjectDir', $script:Proj)).ExitCode | Should -Be 0
  }

  It 'la fuente del tema esta exenta' {
    @{ style = @{ themeSource = 'theme/tokens.css' } } | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $script:Proj 'bossdream.json')
    New-Item -ItemType Directory -Force -Path (Join-Path $script:Proj 'theme') | Out-Null
    Set-Content (Join-Path $script:Proj 'theme/tokens.css') -Value ':root { --c: #fff; }'
    (Invoke-Script 'style-check' $null @('-ProjectDir', $script:Proj)).ExitCode | Should -Be 0
  }
}
