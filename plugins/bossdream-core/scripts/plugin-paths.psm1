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
function Get-ProjectRoot([string]$Start) {
  $homeDir = [Environment]::GetFolderPath('UserProfile')
  $dir = $Start
  while ($dir) {
    if (($dir -ne $homeDir) -and (Test-Path (Join-Path $dir '.claude') -PathType Container)) { return $dir }
    $dir = Split-Path $dir -Parent
  }
  if ($env:CLAUDE_PROJECT_DIR) { return $env:CLAUDE_PROJECT_DIR }
  return $Start
}
Export-ModuleMember -Function Get-CanonicalPluginScriptsDir, Get-ProjectRoot
