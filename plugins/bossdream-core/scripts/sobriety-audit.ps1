param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('framework')]
  [string]$Scope,
  [string]$Components
)
$ErrorActionPreference = 'Stop'

function Test-ReemplazaAValido($Componente, $Nombres) {
  $reemplazaA = $Componente.reemplaza_a
  if ($null -eq $reemplazaA -or [string]::IsNullOrWhiteSpace([string]$reemplazaA)) { return $false }
  if ($reemplazaA -eq $Componente.nombre) { return $false }
  return $Nombres -contains $reemplazaA
}

function Get-VeredictoComponente($Componente, $Nombres) {
  if (Test-ReemplazaAValido $Componente $Nombres) {
    return [ordered]@{
      nombre      = $Componente.nombre
      tipo        = $Componente.tipo
      justificado = $false
      razon       = "declara reemplaza_a: '$($Componente.reemplaza_a)' - duplica a un componente ya existente en el registro"
    }
  }
  return [ordered]@{
    nombre      = $Componente.nombre
    tipo        = $Componente.tipo
    justificado = $true
    razon       = 'no declara reemplaza_a sobre ningun otro componente del registro - aporta valor propio'
  }
}

function Get-AuditoriaDesdeRegistro($Path) {
  if (-not (Test-Path $Path)) {
    return [ordered]@{ status = 'blocked'; razon = @("components-registry.json no encontrado en '$Path'") }
  }
  $registro = Get-Content -Encoding utf8 $Path -Raw | ConvertFrom-Json
  $componentes = @($registro.componentes)
  $nombres = @($componentes | ForEach-Object { $_.nombre })
  $out = @($componentes | ForEach-Object { Get-VeredictoComponente $_ $nombres })
  return [ordered]@{ componentes = $out }
}

function Get-ComponentesReales($PluginRoot) {
  $out = [System.Collections.Generic.List[object]]::new()
  $agentsDir = Join-Path $PluginRoot 'agents'
  if (Test-Path $agentsDir) {
    Get-ChildItem -Path $agentsDir -Filter '*.md' -File | ForEach-Object {
      $out.Add([ordered]@{ nombre = $_.BaseName; tipo = 'agente' })
    }
  }
  $skillsDir = Join-Path $PluginRoot 'skills'
  if (Test-Path $skillsDir) {
    Get-ChildItem -Path $skillsDir -Directory | ForEach-Object {
      $out.Add([ordered]@{ nombre = $_.Name; tipo = 'gate' })
    }
  }
  $scriptsDir = Join-Path $PluginRoot 'scripts'
  if (Test-Path $scriptsDir) {
    Get-ChildItem -Path $scriptsDir -Filter '*.ps1' -File | ForEach-Object {
      $out.Add([ordered]@{ nombre = $_.BaseName; tipo = 'artefacto' })
    }
  }
  return , @($out)
}

function Get-AuditoriaDesdeRepo($PluginRoot) {
  $componentes = Get-ComponentesReales $PluginRoot
  $out = @($componentes | ForEach-Object {
    [ordered]@{
      nombre      = $_.nombre
      tipo        = $_.tipo
      justificado = $true
      razon       = 'componente real del repo, sin declaracion de reemplazo (reemplaza_a no existe en artefactos reales)'
    }
  })
  return [ordered]@{ componentes = $out }
}

if ($Components) {
  $result = Get-AuditoriaDesdeRegistro $Components
} else {
  $pluginRoot = Split-Path -Parent $PSScriptRoot
  $result = Get-AuditoriaDesdeRepo $pluginRoot
}

($result | ConvertTo-Json -Depth 10)
if ($result.status -eq 'blocked') { exit 1 }
exit 0
