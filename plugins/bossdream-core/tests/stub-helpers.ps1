function New-CommandStub([string]$Dir, [string]$Name, [string]$Output) {
  if ([Environment]::OSVersion.Platform -eq 'Win32NT') {
    Set-Content (Join-Path $Dir "$Name.cmd") -Value ("@echo off`r`necho " + $Output) -Encoding ascii
    return
  }
  $path = Join-Path $Dir $Name
  [System.IO.File]::WriteAllText($path, "#!/bin/sh`nprintf '%s\n' '$Output'`n")
  chmod +x $path
}

function New-LoggingHostStub([string]$Dir, [string]$LogFile) {
  $hostExe = (Get-Process -Id $PID).Path
  if ([Environment]::OSVersion.Platform -eq 'Win32NT') {
    $path = Join-Path $Dir 'host-stub.cmd'
    Set-Content $path -Value ("@echo off`r`necho %* >> `"$LogFile`"`r`n`"$hostExe`" %*") -Encoding ascii
    return $path
  }
  $path = Join-Path $Dir 'host-stub.sh'
  [System.IO.File]::WriteAllText($path, "#!/bin/sh`necho `"`$@`" >> '$LogFile'`nexec '$hostExe' `"`$@`"`n")
  chmod +x $path
  return $path
}
