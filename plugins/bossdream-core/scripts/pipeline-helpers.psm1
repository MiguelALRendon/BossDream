function Test-FieldFilled($Value) {
  if ($null -eq $Value) { return $false }
  if ($Value -is [string]) { return -not [string]::IsNullOrWhiteSpace($Value) }
  if ($Value -is [System.Collections.IEnumerable]) {
    $count = 0
    foreach ($item in $Value) { $count++ }
    return $count -gt 0
  }
  return $true
}

function New-GateResult($Data, $Missing) {
  $result = [ordered]@{}
  foreach ($key in $Data.Keys) { $result[$key] = $Data[$key] }
  if ($Missing.Count -eq 0) { $result.status = 'pass' } else { $result.status = 'blocked'; $result.razon = @($Missing) }
  return $result
}

function Validate-ItemFields($ItemArray, $FieldNames, $ItemPath) {
  $missing = [System.Collections.Generic.List[string]]::new()
  for ($i = 0; $i -lt $ItemArray.Count; $i++) {
    $item = $ItemArray[$i]
    foreach ($field in $FieldNames) {
      if (-not (Test-FieldFilled $item.$field)) { $missing.Add("$ItemPath[$i].$field vacio o ausente") }
    }
  }
  return , $missing
}

function Validate-RootFields($Plan, $FieldNames) {
  $missing = [System.Collections.Generic.List[string]]::new()
  foreach ($field in $FieldNames) {
    if (-not (Test-FieldFilled $Plan.$field)) { $missing.Add("$field vacio o ausente") }
  }
  return , $missing
}

function New-HardFailure($Condicion) {
  return [ordered]@{ status = 'failed'; severidad = 'hard'; condicion_de_bloqueo = $Condicion; escape_hatch = $null }
}

function Get-DiffFileEntries($DiffPath) {
  $lines = Get-Content -Encoding utf8 $DiffPath
  $files = [System.Collections.Generic.List[object]]::new()
  $current = $null
  foreach ($line in $lines) {
    if ($line.StartsWith('--- ')) {
      if ($current) { $files.Add($current) }
      $current = [ordered]@{ oldPath = $line.Substring(4).Trim(); newPath = $null; added = 0; removed = 0 }
      continue
    }
    if ($line.StartsWith('+++ ') -and $current) { $current.newPath = $line.Substring(4).Trim(); continue }
    if (-not $current) { continue }
    if ($line.StartsWith('+') -and -not $line.StartsWith('+++')) { $current.added++; continue }
    if ($line.StartsWith('-') -and -not $line.StartsWith('---')) { $current.removed++; continue }
  }
  if ($current) { $files.Add($current) }
  return , @($files)
}

function Get-DiffFilePath($Entry) {
  $raw = if ($Entry.newPath -and $Entry.newPath -ne '/dev/null') { $Entry.newPath } else { $Entry.oldPath }
  return ($raw -replace '^[ab]/', '')
}

function Get-OtherPlanningArtifacts($ProjectDir, $ExcludeIdTarea) {
  if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }
  $dir = Join-Path $ProjectDir '.bossdream-project/artifacts/planning'
  if (-not (Test-Path $dir)) { return , @() }
  $files = Get-ChildItem -Path $dir -Filter '*.artifact.json' -File -ErrorAction SilentlyContinue
  $out = [System.Collections.Generic.List[object]]::new()
  foreach ($f in @($files)) {
    try { $artifact = Get-Content -Encoding utf8 $f.FullName -Raw | ConvertFrom-Json } catch { continue }
    if ($artifact.estado -eq 'consumido') { continue }
    if ($ExcludeIdTarea -and $artifact.id_tarea -eq $ExcludeIdTarea) { continue }
    $out.Add($artifact)
  }
  return , @($out)
}

function Get-ArchivosCompartidos($MisArchivos, $OtroArchivos) {
  return , @(@($OtroArchivos) | Where-Object { $MisArchivos -contains $_ })
}

function Get-ProjectFiles($ProjectDir, $Include, $ExcludeDirs = @('node_modules', '.git', 'bin', 'obj', 'dist', 'build', 'vendor', 'target', '.venv', '__pycache__')) {
  $files = Get-ChildItem -Path $ProjectDir -Recurse -File -Include $Include -ErrorAction SilentlyContinue
  if (-not $files) { return , @() }
  $pattern = ($ExcludeDirs | ForEach-Object { [regex]::Escape($_) }) -join '|'
  $excludeRx = [regex]"[\\/]($pattern)[\\/]"
  return , @(@($files) | Where-Object { -not $excludeRx.IsMatch($_.FullName) })
}

Export-ModuleMember -Function *
