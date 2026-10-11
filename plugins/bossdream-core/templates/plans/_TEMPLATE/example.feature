Feature: <feature>
  Como <rol>
  Quiero <objetivo>
  Para <beneficio>

  # Adversarial primero (como usuario, no como programador). Cada escenario lleva @cubre.
  # Un solo @happy por flujo, al final. Marcadores: @happy, @borde, @error, @cubre:<flujo/funcion>.

  @borde @cubre:<flujo-o-funcion>
  Scenario: <caso limite o borde>
    Dado <precondicion>
    Cuando <accion en el limite>
    Entonces <resultado esperado>

  @error @cubre:<flujo-o-funcion>
  Scenario: <entrada invalida o fallo>
    Dado <precondicion>
    Cuando <accion invalida>
    Entonces <el sistema rechaza / avisa el error>

  @happy @cubre:<flujo-o-funcion>
  Scenario: <camino feliz>
    Dado <precondicion valida>
    Cuando <accion normal>
    Entonces <resultado exitoso>
