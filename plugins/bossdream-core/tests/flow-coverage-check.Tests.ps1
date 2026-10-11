BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/flow-coverage-check.ps1'

  function New-JsonFile($Object) {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + '.json')
    $Object | ConvertTo-Json -Depth 8 | Set-Content $path -Encoding utf8
    return $path
  }
}

Describe 'flow-coverage-check.ps1' {

  BeforeEach {
    # Pipeline del Increment 8: flujo de 4 pasos con 1 transicion de rollback
    $script:Flow = @{
      steps = @('generar_factura', 'timbrar', 'enviar', 'registrar_pago')
      rollbackEdges = @(@{ from = 'timbrar'; to = 'generar_factura' })
    }
    $script:FlowPath = New-JsonFile $script:Flow
  }

  AfterEach {
    Remove-Item $script:FlowPath -Force -ErrorAction SilentlyContinue
    if ($script:CatalogPath) { Remove-Item $script:CatalogPath -Force -ErrorAction SilentlyContinue }
  }

  It 'pipeline del Increment 8 - un catalogo SIN el caso de rollback queda blocked, con la transicion faltante listada' {
    $catalog = @{
      cases = @(
        @{ name = 'happy-path'; path = @('generar_factura', 'timbrar', 'enviar', 'registrar_pago') }
      )
    }
    $script:CatalogPath = New-JsonFile $catalog

    $result = & $script:Script -FlowDefinitionPath $script:FlowPath -CatalogPath $script:CatalogPath | ConvertFrom-Json

    $result.status | Should -Be 'blocked'
    $result.missing | Should -Contain 'timbrar->generar_factura'
  }

  It 'pipeline del Increment 8 - un catalogo CON el caso de rollback explicito queda pass, cobertura completa' {
    $catalog = @{
      cases = @(
        @{ name = 'happy-path'; path = @('generar_factura', 'timbrar', 'enviar', 'registrar_pago') },
        @{ name = 'rollback-en-timbrado'; path = @('generar_factura', 'timbrar', 'generar_factura') }
      )
    }
    $script:CatalogPath = New-JsonFile $catalog

    $result = & $script:Script -FlowDefinitionPath $script:FlowPath -CatalogPath $script:CatalogPath | ConvertFrom-Json

    $result.status | Should -Be 'pass'
    $result.missing.Count | Should -Be 0
    $result.coveredCount | Should -Be $result.expectedCount
  }

  It 'cuenta correctamente transiciones esperadas vs generadas cuando faltan varias' {
    $catalog = @{
      cases = @(
        @{ name = 'solo-primer-paso'; path = @('generar_factura', 'timbrar') }
      )
    }
    $script:CatalogPath = New-JsonFile $catalog

    $result = & $script:Script -FlowDefinitionPath $script:FlowPath -CatalogPath $script:CatalogPath | ConvertFrom-Json

    $result.expectedCount | Should -Be 4
    $result.coveredCount | Should -Be 1
    $result.missing.Count | Should -Be 3
  }

  It 'un flujo sin rollbackEdges solo exige las transiciones lineales' {
    $flowSinRollback = @{ steps = @('a', 'b', 'c') }
    $flowPath = New-JsonFile $flowSinRollback
    $catalog = @{ cases = @(@{ name = 'happy'; path = @('a', 'b', 'c') }) }
    $catalogPath = New-JsonFile $catalog

    try {
      $result = & $script:Script -FlowDefinitionPath $flowPath -CatalogPath $catalogPath | ConvertFrom-Json
      $result.status | Should -Be 'pass'
      $result.expectedCount | Should -Be 2
    } finally {
      Remove-Item $flowPath, $catalogPath -Force -ErrorAction SilentlyContinue
    }
  }
}
