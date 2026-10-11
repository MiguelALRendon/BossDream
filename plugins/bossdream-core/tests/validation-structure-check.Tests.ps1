BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/validation-structure-check.ps1'

  function Invoke-StructureCheck([string]$Content, [string]$DocType, [string]$Classification) {
    $tmpFile = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + '.md')
    [System.IO.File]::WriteAllText($tmpFile, $Content, (New-Object System.Text.UTF8Encoding($false)))
    try {
      $args = @{ DocumentPath = $tmpFile; DocType = $DocType; PluginRoot = $script:PluginRoot }
      if ($Classification) { $args.Classification = $Classification }
      $out = & $script:Script @args
      return ($out | ConvertFrom-Json)
    } finally {
      Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
    }
  }
}

Describe 'validation-structure-check.ps1' {

  It 'detecta placeholder de plantilla sin llenar en understanding.md' {
    $content = [System.IO.File]::ReadAllText((Join-Path $script:PluginRoot 'templates/_PROJECT_TEMPLATE/understanding.md'), [System.Text.Encoding]::UTF8)
    $result = Invoke-StructureCheck -Content $content -DocType 'understanding.md'
    $result.status | Should -Be 'blocked'
    ($result.findings -join ' ') | Should -Match 'placeholder'
  }

  It 'pasa cuando todas las secciones y contenido real estan presentes en understanding.md' {
    $content = [System.IO.File]::ReadAllText((Join-Path $script:PluginRoot 'templates/_PROJECT_TEMPLATE/understanding.md'), [System.Text.Encoding]::UTF8)
    $content = $content.Replace('[Descripción breve, en palabras del negocio, de qué está pasando o qué se necesita resolver.]', 'Los clientes no pueden ver su saldo en tiempo real.')
    $content = $content.Replace('[Qué se espera lograr con esta solución, en una o dos frases.]', 'Que el cliente vea su saldo actualizado al segundo.')
    $result = Invoke-StructureCheck -Content $content -DocType 'understanding.md'
    $result.status | Should -Be 'pass'
  }

  It 'Complejo exige bloque Epic y Feature presentes en requirements.md' {
    $content = "## User Stories — siempre presente`n## Tabla resumen de trazabilidad"
    $result = Invoke-StructureCheck -Content $content -DocType 'requirements.md' -Classification 'Complejo'
    $result.status | Should -Be 'blocked'
    ($result.findings -join ' ') | Should -Match 'falta el bloque Epic'
    ($result.findings -join ' ') | Should -Match 'falta el bloque Feature'
  }

  It 'Simple exige que NO existan los bloques Epic ni Feature en requirements.md' {
    $content = "## Epic — algo`n## Feature — algo`n## User Stories — siempre presente`n## Tabla resumen de trazabilidad"
    $result = Invoke-StructureCheck -Content $content -DocType 'requirements.md' -Classification 'Simple'
    $result.status | Should -Be 'blocked'
    ($result.findings -join ' ') | Should -Match 'no debe tener bloque Epic'
    ($result.findings -join ' ') | Should -Match 'no debe tener bloque Feature'
  }

  It 'Medio exige Feature presente y Epic ausente en requirements.md' {
    $content = "## Reglas de negocio relevantes`n## Feature — algo`n## User Stories — siempre presente`n## Tabla resumen de trazabilidad"
    $result = Invoke-StructureCheck -Content $content -DocType 'requirements.md' -Classification 'Medio'
    $result.status | Should -Be 'pass'
  }

  It 'detecta campos faltantes en un caso de prueba (DocType TC)' {
    $content = "# TC-001`n| Campo | Detalle |`n|---|---|`n| **Escenario** | login exitoso |"
    $result = Invoke-StructureCheck -Content $content -DocType 'TC'
    $result.status | Should -Be 'blocked'
    ($result.findings -join ' ') | Should -Match 'Precondiciones'
  }

  It 'modo batch (-DocumentPaths/-DocTypes) con un solo documento devuelve un array de 1 elemento' {
    $tmpFile = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + '.md')
    [System.IO.File]::WriteAllText($tmpFile, "# Doc`n## 1. cosa", (New-Object System.Text.UTF8Encoding($false)))
    try {
      $out = & $script:Script -DocumentPaths @($tmpFile) -DocTypes @('requirements.md') -PluginRoot $script:PluginRoot
      $parsed = $out | ConvertFrom-Json
      $parsed.Count | Should -Be 1
      $parsed[0].path | Should -Be $tmpFile
      $parsed[0].status | Should -Be 'blocked'
    } finally {
      Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
    }
  }

  It 'modo batch procesa N documentos con DocType/Classification distintos por indice, en orden' {
    $tmpTc = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + '.md')
    $tmpReq = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + '.md')
    $tcContent = @"
# TC-001 — Login exitoso
**Relacionado con:** US-001 / AC-001.1
| Campo | Detalle |
|---|---|
| **Escenario** | Login con credenciales validas |
| **Precondiciones** | Usuario existente y activo |
| **Datos de prueba** | usuario1 / clave123 |
| **Pasos** | 1. Ir a login 2. Escribir credenciales 3. Enviar |
| **Resultado esperado** | Redirige al dashboard |
| **Resultado obtenido** | Redirige al dashboard |
| **Evidencia** | captura-001.png |
| **Estado** | Paso |
"@
    [System.IO.File]::WriteAllText($tmpTc, $tcContent, (New-Object System.Text.UTF8Encoding($false)))
    $reqContent = "## User Stories — siempre presente`n## Tabla resumen de trazabilidad"
    [System.IO.File]::WriteAllText($tmpReq, $reqContent, (New-Object System.Text.UTF8Encoding($false)))
    try {
      $out = & $script:Script -DocumentPaths @($tmpTc, $tmpReq) -DocTypes @('TC', 'requirements.md') -Classifications @('', 'Complejo') -PluginRoot $script:PluginRoot
      $parsed = $out | ConvertFrom-Json
      $parsed.Count | Should -Be 2
      $parsed[0].path | Should -Be $tmpTc
      $parsed[0].status | Should -Be 'pass'
      $parsed[1].path | Should -Be $tmpReq
      $parsed[1].status | Should -Be 'blocked'
      ($parsed[1].findings -join ' ') | Should -Match 'falta el bloque Epic'
    } finally {
      Remove-Item $tmpTc, $tmpReq -Force -ErrorAction SilentlyContinue
    }
  }

  It 'pasa un caso de prueba con todos los campos llenos' {
    $content = @"
# TC-001 — Login exitoso
**Relacionado con:** US-001 / AC-001.1
| Campo | Detalle |
|---|---|
| **Escenario** | Login con credenciales validas |
| **Precondiciones** | Usuario existente y activo |
| **Datos de prueba** | usuario1 / clave123 |
| **Pasos** | 1. Ir a login 2. Escribir credenciales 3. Enviar |
| **Resultado esperado** | Redirige al dashboard |
| **Resultado obtenido** | Redirige al dashboard |
| **Evidencia** | captura-001.png |
| **Estado** | Paso |
"@
    $result = Invoke-StructureCheck -Content $content -DocType 'TC'
    $result.status | Should -Be 'pass'
  }
}
