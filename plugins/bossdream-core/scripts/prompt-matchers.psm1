function Test-BossdreamPlanPrompt([string]$Prompt) {
  return [bool]($Prompt -match '(^|\s)/([^:\s][^:]*:)?bossdream-plan(\s|$)')
}
function Test-BossdreamImplementPrompt([string]$Prompt) {
  return [bool]($Prompt -match '(^|\s)/([^:\s][^:]*:)?bossdream-implement(\s|$)')
}
function Test-BossdreamModePrompt([string]$Prompt) {
  if ($Prompt -match '(^|\s)/([^:\s][^:]*:)?bossdream-mode\s+([a-zA-Z]+)') {
    return $Matches[3]
  }
  return $null
}
Export-ModuleMember -Function Test-BossdreamPlanPrompt, Test-BossdreamImplementPrompt, Test-BossdreamModePrompt
