param(
  [string]$ProjectDir = $env:CLAUDE_PROJECT_DIR,
  [Parameter(Mandatory=$true)][string]$ProjectSlug,
  [Parameter(Mandatory=$true)][string]$File
)
$ErrorActionPreference = 'Stop'

if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }
$validationPath = Join-Path $ProjectDir "bossdream_projects/$ProjectSlug/.bossdream-project/validation.json"

function Write-NotFound {
  (@{ status = 'not-found'; findings = @() } | ConvertTo-Json -Compress -Depth 4)
  exit 0
}

if (-not (Test-Path $validationPath)) { Write-NotFound }

$validation = Get-Content $validationPath -Raw | ConvertFrom-Json
$hasDoc = ($validation.PSObject.Properties.Name -contains 'documents') -and ($validation.documents.PSObject.Properties.Name -contains $File)
if (-not $hasDoc) { Write-NotFound }

$docEntry = $validation.documents.$File
$checksBloqueados = @($docEntry.checks | Where-Object { $_.status -eq 'blocked' } | ForEach-Object {
  [PSCustomObject]@{ id = $_.id; findings = @($_.findings) }
})

$exemptions = if ($validation.PSObject.Properties.Name -contains 'exemptions') { @($validation.exemptions) } else { @() }
$exemptionsExistentes = @($exemptions | Where-Object { $_.file -eq $File })

$result = [PSCustomObject]@{
  status = 'ok'
  file = $File
  documentStatus = $docEntry.status
  checksBloqueados = $checksBloqueados
  intentosBloqueado = if ($docEntry.PSObject.Properties.Name -contains 'intentosBloqueado') { $docEntry.intentosBloqueado } else { 0 }
  ultimoCheckBloqueado = if ($docEntry.PSObject.Properties.Name -contains 'ultimoCheckBloqueado') { $docEntry.ultimoCheckBloqueado } else { $null }
  exemptions = $exemptionsExistentes
}
$result | ConvertTo-Json -Depth 8
exit 0
