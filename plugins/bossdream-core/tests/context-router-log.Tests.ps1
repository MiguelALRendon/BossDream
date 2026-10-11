BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/context-router-log.ps1'
  $script:LiteralMotivo = 'ninguna fuente previa alcanzó, se escala a archivo completo'
}

Describe 'context-router-log.ps1' {

  BeforeEach {
    $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("context-router-log-test-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $script:Sandbox | Out-Null
    $script:LogPath = Join-Path $script:Sandbox '.bossdream-project/context-router.log'
  }

  AfterEach {
    Remove-Item -Recurse -Force $script:Sandbox -ErrorAction SilentlyContinue
  }

  It 'escribe una entrada valida con las 4 claves del contrato' {
    & $script:Script -ProjectDir $script:Sandbox -Pregunta 'que hace calcularDescuento' -NivelAlcanzado archivo_completo -TareaAsociada 'TC-053' | Out-Null

    $line = Get-Content $script:LogPath -Raw -Encoding utf8
    $entry = $line.Trim() | ConvertFrom-Json
    $entry.pregunta | Should -Be 'que hace calcularDescuento'
    $entry.nivel_alcanzado | Should -Be 'archivo_completo'
    $entry.tarea_asociada | Should -Be 'TC-053'
  }

  It 'en nivel archivo_completo fija motivo_escalada al texto literal exacto del contrato' {
    & $script:Script -ProjectDir $script:Sandbox -Pregunta 'q' -NivelAlcanzado archivo_completo -TareaAsociada 'T-1' | Out-Null

    $entry = (Get-Content $script:LogPath -Raw -Encoding utf8).Trim() | ConvertFrom-Json
    $entry.motivo_escalada | Should -Be $script:LiteralMotivo
  }

  It 'en cualquier otro nivel motivo_escalada es null' {
    & $script:Script -ProjectDir $script:Sandbox -Pregunta 'q' -NivelAlcanzado repo-map -TareaAsociada 'T-1' | Out-Null

    $entry = (Get-Content $script:LogPath -Raw -Encoding utf8).Trim() | ConvertFrom-Json
    $entry.motivo_escalada | Should -Be $null
  }

  It 'produce JSON Lines valido: cada linea del archivo es un objeto JSON independiente' {
    & $script:Script -ProjectDir $script:Sandbox -Pregunta 'q1' -NivelAlcanzado artefacto -TareaAsociada 'T-1' | Out-Null
    & $script:Script -ProjectDir $script:Sandbox -Pregunta 'q2' -NivelAlcanzado simbolo -TareaAsociada 'T-2' | Out-Null

    $lines = @(Get-Content $script:LogPath -Encoding utf8)
    $lines.Count | Should -Be 2
    foreach ($l in $lines) { { $l | ConvertFrom-Json } | Should -Not -Throw }
  }

  It 'agrega (append) sin sobrescribir entradas previas' {
    & $script:Script -ProjectDir $script:Sandbox -Pregunta 'primera' -NivelAlcanzado artefacto -TareaAsociada 'T-1' | Out-Null
    & $script:Script -ProjectDir $script:Sandbox -Pregunta 'segunda' -NivelAlcanzado rango -TareaAsociada 'T-2' | Out-Null
    & $script:Script -ProjectDir $script:Sandbox -Pregunta 'tercera' -NivelAlcanzado archivo_completo -TareaAsociada 'T-3' | Out-Null

    $lines = @(Get-Content $script:LogPath -Encoding utf8)
    $lines.Count | Should -Be 3
    ($lines[0] | ConvertFrom-Json).pregunta | Should -Be 'primera'
    ($lines[1] | ConvertFrom-Json).pregunta | Should -Be 'segunda'
    ($lines[2] | ConvertFrom-Json).pregunta | Should -Be 'tercera'
  }

  It 'rechaza un nivel_alcanzado fuera del vocabulario fijado' {
    { & $script:Script -ProjectDir $script:Sandbox -Pregunta 'q' -NivelAlcanzado 'no-existe' -TareaAsociada 'T-1' -ErrorAction Stop } | Should -Throw
  }

  It 'falla sin sobrescribir cuando tarea_asociada es solo espacios' {
    & $script:Script -ProjectDir $script:Sandbox -Pregunta 'q' -NivelAlcanzado artefacto -TareaAsociada '   ' | Out-Null
    $LASTEXITCODE | Should -Be 1
    Test-Path $script:LogPath | Should -BeFalse
  }

  It 'crea .bossdream-project/ si todavia no existe' {
    Test-Path (Join-Path $script:Sandbox '.bossdream-project') | Should -BeFalse
    & $script:Script -ProjectDir $script:Sandbox -Pregunta 'q' -NivelAlcanzado artefacto -TareaAsociada 'T-1' | Out-Null
    Test-Path $script:LogPath | Should -BeTrue
  }

  It 'rota el log a .old antes de escribir cuando supera el umbral' {
    New-Item -ItemType Directory -Force -Path (Split-Path $script:LogPath -Parent) | Out-Null
    Set-Content -Path $script:LogPath -Value 'contenido-viejo-que-supera-el-umbral' -Encoding utf8 -NoNewline
    $oldPath = "$($script:LogPath).old"
    Test-Path $oldPath | Should -BeFalse

    & $script:Script -ProjectDir $script:Sandbox -Pregunta 'q' -NivelAlcanzado artefacto -TareaAsociada 'T-1' -RotateThresholdBytes 10 | Out-Null

    Test-Path $oldPath | Should -BeTrue
    (Get-Content $oldPath -Raw) | Should -Match 'contenido-viejo-que-supera-el-umbral'
    $lines = @(Get-Content $script:LogPath -Encoding utf8)
    $lines.Count | Should -Be 1
    ($lines[0] | ConvertFrom-Json).pregunta | Should -Be 'q'
  }

  It 'sobrescribe un .old previo al rotar de nuevo' {
    New-Item -ItemType Directory -Force -Path (Split-Path $script:LogPath -Parent) | Out-Null
    Set-Content -Path "$($script:LogPath).old" -Value 'old-anterior' -Encoding utf8 -NoNewline
    Set-Content -Path $script:LogPath -Value 'contenido-nuevo-que-supera-el-umbral' -Encoding utf8 -NoNewline

    & $script:Script -ProjectDir $script:Sandbox -Pregunta 'q' -NivelAlcanzado artefacto -TareaAsociada 'T-1' -RotateThresholdBytes 10 | Out-Null

    (Get-Content "$($script:LogPath).old" -Raw) | Should -Match 'contenido-nuevo-que-supera-el-umbral'
  }

  It 'no rota si el log no supera el umbral' {
    & $script:Script -ProjectDir $script:Sandbox -Pregunta 'primera' -NivelAlcanzado artefacto -TareaAsociada 'T-1' | Out-Null
    & $script:Script -ProjectDir $script:Sandbox -Pregunta 'segunda' -NivelAlcanzado artefacto -TareaAsociada 'T-2' -RotateThresholdBytes 5MB | Out-Null

    Test-Path "$($script:LogPath).old" | Should -BeFalse
    $lines = @(Get-Content $script:LogPath -Encoding utf8)
    $lines.Count | Should -Be 2
  }
}
