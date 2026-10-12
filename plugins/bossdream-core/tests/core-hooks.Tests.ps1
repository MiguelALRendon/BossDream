BeforeAll {
  $script:Scripts = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts'

  function Invoke-Hook([string]$Name, [hashtable]$Payload) {
    $json = $Payload | ConvertTo-Json -Compress -Depth 6
    $out = $json | & (Get-Process -Id $PID).Path -NoProfile -File (Join-Path $script:Scripts "$Name.ps1")
    return [PSCustomObject]@{ Output = ($out -join "`n"); ExitCode = $LASTEXITCODE }
  }

  function Get-Decision($Result) {
    if (-not $Result.Output) { return $null }
    return ($Result.Output | ConvertFrom-Json).hookSpecificOutput.permissionDecision
  }
}

Describe 'command-lock.ps1' {
  It 'deniega git reset --hard' {
    $r = Invoke-Hook 'command-lock' @{ tool_input = @{ command = 'git reset --hard HEAD~1' } }
    Get-Decision $r | Should -Be 'deny'
  }

  It 'deniega git push --force' {
    $r = Invoke-Hook 'command-lock' @{ tool_input = @{ command = 'git push origin main --force' } }
    Get-Decision $r | Should -Be 'deny'
  }

  It 'deniega rm -rf sobre la raiz' {
    $r = Invoke-Hook 'command-lock' @{ tool_input = @{ command = 'rm -rf /' } }
    Get-Decision $r | Should -Be 'deny'
  }

  It 'deja pasar un comando inocuo sin salida' {
    $r = Invoke-Hook 'command-lock' @{ tool_input = @{ command = 'git status' } }
    $r.Output | Should -BeNullOrEmpty
    $r.ExitCode | Should -Be 0
  }

  It 'no revienta con entrada vacia o JSON invalido' {
    $hostExe = (Get-Process -Id $PID).Path
    $script = Join-Path $script:Scripts 'command-lock.ps1'
    '' | & $hostExe -NoProfile -File $script | Out-Null
    $LASTEXITCODE | Should -Be 0
    'no es json' | & $hostExe -NoProfile -File $script | Out-Null
    $LASTEXITCODE | Should -Be 0
  }
}

Describe 'comment-check.ps1' {
  It 'deniega un bloque /* */ multilinea en .css' {
    $r = Invoke-Hook 'comment-check' @{ tool_input = @{ file_path = 'a.css'; content = "/* uno`ndos */`nbody{}" } }
    Get-Decision $r | Should -Be 'deny'
  }

  It 'deniega dos lineas # consecutivas en .ps1' {
    $r = Invoke-Hook 'comment-check' @{ tool_input = @{ file_path = 'a.ps1'; content = "# uno`n# dos`n`$x = 1" } }
    Get-Decision $r | Should -Be 'deny'
  }

  It 'permite un comentario de una sola linea con el porque' {
    $r = Invoke-Hook 'comment-check' @{ tool_input = @{ file_path = 'a.ps1'; content = "# 5.1 no soporta -AsHashtable`n`$x = 1" } }
    $r.Output | Should -BeNullOrEmpty
  }

  It 'ignora extensiones que no son codigo' {
    $r = Invoke-Hook 'comment-check' @{ tool_input = @{ file_path = 'a.md'; content = "# uno`n# dos" } }
    $r.Output | Should -BeNullOrEmpty
  }

  It 'un --flag de CLI repetido en .ps1 no cuenta como comentario SQL' {
    $r = Invoke-Hook 'comment-check' @{ tool_input = @{ file_path = 'a.ps1'; content = "git --no-pager`n--version" } }
    $r.Output | Should -BeNullOrEmpty
  }
}

Describe 'plan-lock.ps1' {
  BeforeEach {
    $script:Proj = Join-Path ([System.IO.Path]::GetTempPath()) ("plan-lock-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path (Join-Path $script:Proj '.claude') | Out-Null
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Proj -ErrorAction SilentlyContinue
  }

  It 'en modo plan deniega editar codigo' {
    Set-Content (Join-Path $script:Proj '.claude/.work-mode') -Value 'plan' -NoNewline
    $r = Invoke-Hook 'plan-lock' @{ cwd = $script:Proj; tool_input = @{ file_path = (Join-Path $script:Proj 'x.ps1') } }
    Get-Decision $r | Should -Be 'deny'
  }

  It 'en modo plan deniega editar .work-mode' {
    Set-Content (Join-Path $script:Proj '.claude/.work-mode') -Value 'plan' -NoNewline
    $r = Invoke-Hook 'plan-lock' @{ cwd = $script:Proj; tool_input = @{ file_path = (Join-Path $script:Proj '.claude/.work-mode') } }
    Get-Decision $r | Should -Be 'deny'
  }

  It 'en modo plan deniega editar codigo aunque el cwd sea una subcarpeta del proyecto' {
    Set-Content (Join-Path $script:Proj '.claude/.work-mode') -Value 'plan' -NoNewline
    $sub = Join-Path $script:Proj 'src/modulo'
    New-Item -ItemType Directory -Force -Path $sub | Out-Null
    $r = Invoke-Hook 'plan-lock' @{ cwd = $sub; tool_input = @{ file_path = (Join-Path $sub 'x.ps1') } }
    Get-Decision $r | Should -Be 'deny'
  }

  It 'en modo plan permite editar un .md' {
    Set-Content (Join-Path $script:Proj '.claude/.work-mode') -Value 'plan' -NoNewline
    $r = Invoke-Hook 'plan-lock' @{ cwd = $script:Proj; tool_input = @{ file_path = (Join-Path $script:Proj 'plan.md') } }
    $r.Output | Should -BeNullOrEmpty
  }

  It 'en modo chore permite editar codigo' {
    Set-Content (Join-Path $script:Proj '.claude/.work-mode') -Value 'chore' -NoNewline
    $r = Invoke-Hook 'plan-lock' @{ cwd = $script:Proj; tool_input = @{ file_path = (Join-Path $script:Proj 'x.ps1') } }
    $r.Output | Should -BeNullOrEmpty
  }

  It 'ruta de dominio sin spec activa deniega; con .active-plan permite' {
    @{ planLock = @{ enabled = $true; requirePaths = @('src/**'); exemptPaths = @(); exemptModes = @('chore') } } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $script:Proj 'bossdream.json')
    $payload = @{ cwd = $script:Proj; tool_input = @{ file_path = (Join-Path $script:Proj 'src/app.cs') } }
    Get-Decision (Invoke-Hook 'plan-lock' $payload) | Should -Be 'deny'
    Set-Content (Join-Path $script:Proj '.claude/.active-plan') -Value 'mi-feature'
    (Invoke-Hook 'plan-lock' $payload).Output | Should -BeNullOrEmpty
  }
}

Describe 'mark-dirty.ps1' {
  BeforeEach {
    $script:Proj = Join-Path ([System.IO.Path]::GetTempPath()) ("mark-dirty-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $script:Proj | Out-Null
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Proj -ErrorAction SilentlyContinue
  }

  It 'editar un .ps1 crea .claude/.bossdream-dirty' {
    Invoke-Hook 'mark-dirty' @{ cwd = $script:Proj; tool_input = @{ file_path = 'a.ps1' } } | Out-Null
    Test-Path (Join-Path $script:Proj '.claude/.bossdream-dirty') | Should -BeTrue
  }

  It 'editar un .md no crea el marcador' {
    Invoke-Hook 'mark-dirty' @{ cwd = $script:Proj; tool_input = @{ file_path = 'a.md' } } | Out-Null
    Test-Path (Join-Path $script:Proj '.claude/.bossdream-dirty') | Should -BeFalse
  }
}
