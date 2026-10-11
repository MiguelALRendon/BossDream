function Get-CanonicalPluginScriptsDir([string]$ProjectDir) {
  $pluginsDir = Join-Path $ProjectDir 'plugins'
  $candidates = @(Get-ChildItem -Path $pluginsDir -Directory -ErrorAction SilentlyContinue | Where-Object {
    (Test-Path (Join-Path $_.FullName '.claude-plugin/plugin.json')) -and (Test-Path (Join-Path $_.FullName 'scripts'))
  })
  if ($candidates.Count -eq 0) {
    Write-Output "plugin-paths: no se encontro ningun plugin con .claude-plugin/plugin.json bajo '$pluginsDir'."
    exit 1
  }
  if ($candidates.Count -gt 1) {
    $names = ($candidates | ForEach-Object { $_.Name }) -join ', '
    Write-Output "plugin-paths: se encontraron multiples plugins candidatos bajo '$pluginsDir' ($names) - no se puede elegir automaticamente."
    exit 1
  }
  return Join-Path $candidates[0].FullName 'scripts'
}
Export-ModuleMember -Function Get-CanonicalPluginScriptsDir
