$ErrorActionPreference = 'Stop'
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $j = $raw | ConvertFrom-Json } catch { exit 0 }

$path = $j.tool_input.file_path
if (-not $path) { exit 0 }
$ext = [System.IO.Path]::GetExtension($path).ToLower()

$proj = [string]$j.cwd
if (-not $proj) { $proj = $env:CLAUDE_PROJECT_DIR }
Import-Module (Join-Path $PSScriptRoot 'plugin-paths.psm1')
if ($proj) { $proj = Get-ProjectRoot $proj }

# extensiones de codigo desde bossdream.json: default universal + lo que anexo el stack-pack en /bossdream-init
$codeExt = @('.css', '.scss', '.sql', '.ps1')
if ($proj) {
  try {
    $bd = Get-Content -Encoding utf8 (Join-Path $proj 'bossdream.json') -Raw | ConvertFrom-Json
    if ($bd.codeExtensions) { $codeExt = @($bd.codeExtensions) }
  } catch {}
}
if ($codeExt -notcontains $ext) { exit 0 }

$texts = @()
if ($j.tool_input.new_string) { $texts += [string]$j.tool_input.new_string }
if ($j.tool_input.content) { $texts += [string]$j.tool_input.content }
if ($j.tool_input.edits) { foreach ($e in $j.tool_input.edits) { if ($e.new_string) { $texts += [string]$e.new_string } } }
if ($texts.Count -eq 0) { exit 0 }

# dialecto de comentarios por extension: cada patron solo aplica al lenguaje donde de verdad es un comentario.
# antes se aplicaban TODOS los patrones a cualquier extension de $codeExt (bug real: un .ps1 con dos
# lineas "--variable" -CLI, no comentario- se marcaba como "comentarios SQL -- consecutivos").
$sqlExt = @('.sql')
$psExt = @('.ps1', '.psm1', '.psd1')
$razorExt = @('.razor', '.cshtml')
$cLikeExt = @('.cs', '.js', '.ts', '.jsx', '.tsx', '.vue', '.java', '.go', '.cpp', '.c', '.h')
$cssLikeExt = @('.css', '.scss')
$slashCommentExt = $cLikeExt + $razorExt + @('.scss')
$blockCommentExt = $cLikeExt + $razorExt + $cssLikeExt
$regionExt = $cLikeExt + $razorExt + $psExt

$violations = @()
foreach ($t in $texts) {
  if ($blockCommentExt -contains $ext) {
    if ($t -match '(?s)/\*.*?\r?\n.*?\*/') { $violations += 'bloque /* */ multi-linea' }
    if ($t -match '(?m)/\*\s*=+') { $violations += 'separador decorativo' }
  }
  if ($razorExt -contains $ext) {
    if ($t -match '(?s)@\*.*?\r?\n.*?\*@') { $violations += 'bloque Razor @* *@ multi-linea' }
  }
  if ($slashCommentExt -contains $ext) {
    if ($t -match '(?m)^[ \t]*//.*\r?\n[ \t]*//') { $violations += 'comentarios // consecutivos' }
    if ($t -match '(?m)//\s*-{4,}') { $violations += 'separador decorativo' }
    if ($t -match '(?im)//\s*(added|updated|changed|this (handles|is)|for now|fixed for|to handle)') { $violations += 'breadcrumb de IA' }
  }
  if ($regionExt -contains $ext) {
    if ($t -match '#region|#endregion') { $violations += 'marca #region' }
  }
  if ($sqlExt -contains $ext) {
    if ($t -match '(?m)^[ \t]*--.*\r?\n[ \t]*--') { $violations += 'comentarios SQL -- consecutivos' }
    if ($t -match '(?im)--\s*(added|updated|changed|this (handles|is)|for now|fixed for|to handle)') { $violations += 'breadcrumb de IA' }
  }
  if ($psExt -contains $ext) {
    if ($t -match '(?s)<#.*?\r?\n.*?#>') { $violations += 'bloque PowerShell <# #> multi-linea' }
    if ($t -match '(?m)^[ \t]*#(?!region|endregion).*\r?\n[ \t]*#(?!region|endregion)') { $violations += 'comentarios # consecutivos' }
    if ($t -match '(?im)#\s*(added|updated|changed|this (handles|is)|for now|fixed for|to handle)') { $violations += 'breadcrumb de IA' }
  }
}

if ($violations.Count -gt 0) {
  $reason = 'Politica de comentarios (tolerancia cero): ' + (($violations | Select-Object -Unique) -join '; ') + '. Elimina el comentario; solo se permite 1 linea con WHY no inferible.'
  (@{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'; permissionDecisionReason = $reason } } | ConvertTo-Json -Compress -Depth 5)
}
exit 0
