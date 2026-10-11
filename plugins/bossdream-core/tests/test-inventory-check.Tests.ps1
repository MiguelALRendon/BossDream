BeforeAll {
  $script:PluginRoot = Split-Path -Parent $PSScriptRoot
  $script:Script = Join-Path $script:PluginRoot 'scripts/test-inventory-check.ps1'

  function New-InventoryFile($Object) {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + '.json')
    $Object | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding utf8
    return $path
  }

  function New-CompleteInventory {
    return @{
      behavior      = 'Plan Checks: 8 gates deterministas de plan-checks.ps1 evaluan pass/blocked sobre plan-draft.json'
      rules         = @(
        'gate evidence bloquea cuando falta source en una entrada de evidencia',
        'gate change-surface bloquea cuando consumidores[] esta vacio'
      )
      flows         = @(
        @{
          nombre                = 'plan-checks-gate-routing'
          estados                = @('gate-deterministico-pass', 'gate-deterministico-blocked', 'gate-semantico-requires-agent')
          transiciones_validas   = @('input->pass(exit0)', 'input->blocked(exit1)')
          transiciones_invalidas = @()
          dead_ends              = @()
          retries                = @()
          rollbacks              = @()
        }
      )
      happy_paths   = @('gate evidence: aprueba un plan completo con claim/source/confidence/impact')
      negative_paths = @('gate evidence: bloquea cuando falta source en una entrada de evidencia')
      boundaries    = @('plan-draft.json no existe -> reporta blocked')
      dependencies  = @()
      tests         = @(
        @{ id = 'It:gate evidence bloquea cuando falta source'; cubre = 'gate evidence bloquea cuando falta source en una entrada de evidencia' },
        @{ id = 'It:gate change-surface bloquea sin consumidores'; cubre = 'gate change-surface bloquea cuando consumidores[] esta vacio' },
        @{ id = 'It:exit code 0 cuando el gate pasa'; cubre = 'input->pass(exit0)' },
        @{ id = 'It:exit code 1 cuando el gate bloquea'; cubre = 'input->blocked(exit1)' }
      )
      evidence      = '21 casos Pester reales en tests/plan-checks.Tests.ps1, cada gate con caso pass y caso blocked'
      mocks_riesgosos    = @()
      assertions_debiles = @()
    }
  }
}

Describe 'test-inventory-check.ps1' {

  AfterEach {
    if ($script:TmpFile -and (Test-Path $script:TmpFile)) { Remove-Item $script:TmpFile -Force -ErrorAction SilentlyContinue }
  }

  It 'inventario completo con behavior/rules/transiciones cubiertas por tests[] -- pasa limpio' {
    $script:TmpFile = New-InventoryFile (New-CompleteInventory)
    $result = & $script:Script -InventoryPath $script:TmpFile | ConvertFrom-Json
    $result.status | Should -Be 'pass'
    $result.razon | Should -BeNullOrEmpty
  }

  It 'regla sin test correspondiente en tests[] -- bloquea con el detalle concreto de la regla' {
    $inventory = New-CompleteInventory
    $inventory.rules += 'regla nueva sin test asociado'
    $script:TmpFile = New-InventoryFile $inventory
    $result = & $script:Script -InventoryPath $script:TmpFile | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $result.razon | Should -Contain 'Missing validation coverage: regla nueva sin test asociado'
  }

  It 'transicion valida sin test correspondiente en tests[] -- bloquea con la transicion exacta' {
    $inventory = New-CompleteInventory
    $inventory.flows[0].transiciones_validas += 'blocked->requires-agent'
    $script:TmpFile = New-InventoryFile $inventory
    $result = & $script:Script -InventoryPath $script:TmpFile | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $result.razon | Should -Contain 'Missing flow transition: blocked->requires-agent'
  }

  It 'behavior presente pero tests[] completamente vacio -- bloquea comportamiento sin prueba' {
    $inventory = New-CompleteInventory
    $inventory.tests = @()
    $script:TmpFile = New-InventoryFile $inventory
    $result = & $script:Script -InventoryPath $script:TmpFile | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $result.razon | Should -Contain "Missing behavior coverage: $($inventory.behavior)"
  }

  It 'evidence vacio -- bloquea Evidence insufficient' {
    $inventory = New-CompleteInventory
    $inventory.evidence = ''
    $script:TmpFile = New-InventoryFile $inventory
    $result = & $script:Script -InventoryPath $script:TmpFile | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $result.razon | Should -Contain "Evidence insufficient: campo evidence vacio o placeholder generico ('')"
  }

  It 'falta una de las 9 claves fijas -- bloquea con el nombre del campo ausente' {
    $inventory = New-CompleteInventory
    $inventory.Remove('boundaries')
    $script:TmpFile = New-InventoryFile $inventory
    $result = & $script:Script -InventoryPath $script:TmpFile | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $result.razon | Should -Contain 'campo requerido ausente: boundaries'
  }

  It 'flows[] sin una de las 6 sub-claves fijas -- bloquea con la ruta exacta' {
    $inventory = New-CompleteInventory
    $inventory.flows[0].Remove('dead_ends')
    $script:TmpFile = New-InventoryFile $inventory
    $result = & $script:Script -InventoryPath $script:TmpFile | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $result.razon | Should -Contain 'flows[0].dead_ends ausente'
  }

  It 'genera la matriz de cobertura transiciones_cubiertas vs transiciones_no_cubiertas' {
    $inventory = New-CompleteInventory
    $inventory.flows[0].transiciones_validas += 'blocked->requires-agent'
    $script:TmpFile = New-InventoryFile $inventory
    $result = & $script:Script -InventoryPath $script:TmpFile | ConvertFrom-Json
    $result.transiciones_cubiertas | Should -Contain 'input->pass(exit0)'
    $result.transiciones_no_cubiertas | Should -Contain 'blocked->requires-agent'
  }

  It 'test unitario verde (metodo/transicion_relacionada) sin flujo end-to-end -- reporta metodos_incompletos' {
    $inventory = New-CompleteInventory
    $inventory.flows[0].transiciones_validas += 'Pending->Cancelled'
    $inventory.tests += @{ id = 'It:cancelOrder unitario'; cubre = 'cancelOrder aislado'; metodo = 'cancelOrder'; transicion_relacionada = 'Pending->Cancelled' }
    $script:TmpFile = New-InventoryFile $inventory
    $result = & $script:Script -InventoryPath $script:TmpFile | ConvertFrom-Json
    $result.metodos_incompletos.metodo | Should -Contain 'cancelOrder'
    $result.metodos_incompletos.mensaje | Should -Contain "tiene prueba unitaria verde, pero el flujo end-to-end Pending$([char]0x2192)Cancelled no est$([char]0xE1) cubierto"
  }

  It 'test-inventory.json inexistente -- bloquea con la ruta no encontrada' {
    $result = & $script:Script -InventoryPath 'Z:\ruta\que\no\existe.json' | ConvertFrom-Json
    $result.status | Should -Be 'blocked'
    $result.razon[0] | Should -Match 'no encontrado'
  }
}
