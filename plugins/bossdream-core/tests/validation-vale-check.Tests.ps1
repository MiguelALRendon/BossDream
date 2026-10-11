BeforeAll {
. (Join-Path $PSScriptRoot 'stub-helpers.ps1')
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/validation-vale-check.ps1'
}

Describe 'validation-vale-check.ps1' {

  BeforeEach {
    $script:TmpFile = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + '.md')
    Set-Content $script:TmpFile -Value 'contenido de prueba' -Encoding utf8
  }

  AfterEach {
    Remove-Item $script:TmpFile -Force -ErrorAction SilentlyContinue
  }

  It 'responde skip (no bloquea) cuando el binario vale no esta instalado' {
    $originalPath = $env:PATH
    try {
      $env:PATH = ''
      $result = & $script:Script -DocumentPath $script:TmpFile -PluginRoot $script:PluginRoot | ConvertFrom-Json
      $result.status | Should -Be 'skip'
    } finally {
      $env:PATH = $originalPath
    }
  }

  It 'reporta blocked cuando un vale simulado devuelve alertas' {
    $stubDir = Join-Path ([System.IO.Path]::GetTempPath()) ("vale-stub-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $stubDir | Out-Null
    $stubPath = Join-Path $stubDir 'vale.cmd'
    $jsonOut = '{"doc.md":[{"Line":3,"Message":"Evita la palabra debil TBD"}]}'
    New-CommandStub $stubDir 'vale' $jsonOut

    $originalPath = $env:PATH
    try {
      $env:PATH = "$stubDir$([IO.Path]::PathSeparator)$originalPath"
      $result = & $script:Script -DocumentPath $script:TmpFile -PluginRoot $script:PluginRoot | ConvertFrom-Json
      $result.status | Should -Be 'blocked'
      ($result.findings -join ' ') | Should -Match 'TBD'
    } finally {
      $env:PATH = $originalPath
      Remove-Item -Recurse -Force $stubDir -ErrorAction SilentlyContinue
    }
  }

  It 'reporta pass cuando un vale simulado no encuentra alertas' {
    $stubDir = Join-Path ([System.IO.Path]::GetTempPath()) ("vale-stub-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $stubDir | Out-Null
    $stubPath = Join-Path $stubDir 'vale.cmd'
    New-CommandStub $stubDir 'vale' '{}'

    $originalPath = $env:PATH
    try {
      $env:PATH = "$stubDir$([IO.Path]::PathSeparator)$originalPath"
      $result = & $script:Script -DocumentPath $script:TmpFile -PluginRoot $script:PluginRoot | ConvertFrom-Json
      $result.status | Should -Be 'pass'
    } finally {
      $env:PATH = $originalPath
      Remove-Item -Recurse -Force $stubDir -ErrorAction SilentlyContinue
    }
  }

  It 'modo batch (-DocumentPaths) con un solo documento devuelve un array de 1 elemento, no un objeto suelto' {
    $originalPath = $env:PATH
    try {
      $env:PATH = ''
      $out = & $script:Script -DocumentPaths @($script:TmpFile) -PluginRoot $script:PluginRoot
      ([string]$out).TrimStart() | Should -Match '^\['
      $parsed = @($out | ConvertFrom-Json)
      $parsed.Count | Should -Be 1
      $parsed[0].path | Should -Be $script:TmpFile
      $parsed[0].status | Should -Be 'skip'
    } finally {
      $env:PATH = $originalPath
    }
  }

  It 'modo batch (-DocumentPaths) procesa N documentos con la misma logica que el modo singular, en orden' {
    $tmpFile2 = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + '.md')
    Set-Content $tmpFile2 -Value 'otro contenido de prueba' -Encoding utf8

    $stubDir = Join-Path ([System.IO.Path]::GetTempPath()) ("vale-stub-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $stubDir | Out-Null
    $jsonOut = '{"doc.md":[{"Line":3,"Message":"Evita la palabra debil TBD"}]}'
    New-CommandStub $stubDir 'vale' $jsonOut

    $originalPath = $env:PATH
    try {
      $env:PATH = "$stubDir$([IO.Path]::PathSeparator)$originalPath"
      $out = & $script:Script -DocumentPaths @($script:TmpFile, $tmpFile2) -PluginRoot $script:PluginRoot
      $parsed = $out | ConvertFrom-Json
      $parsed.Count | Should -Be 2
      $parsed[0].path | Should -Be $script:TmpFile
      $parsed[0].status | Should -Be 'blocked'
      $parsed[1].path | Should -Be $tmpFile2
      $parsed[1].status | Should -Be 'blocked'
    } finally {
      $env:PATH = $originalPath
      Remove-Item -Recurse -Force $stubDir -ErrorAction SilentlyContinue
      Remove-Item $tmpFile2 -Force -ErrorAction SilentlyContinue
    }
  }
}
