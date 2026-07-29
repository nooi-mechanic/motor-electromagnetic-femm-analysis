param(
  [Parameter(Mandatory = $true)]
  [string]$Command
)

$ErrorActionPreference = "Stop"

function Get-MatlabComObject {
  try {
    return [System.Runtime.InteropServices.Marshal]::GetActiveObject("Matlab.Application.Single")
  } catch {
  }

  try {
    return New-Object -ComObject "Matlab.Application.Single"
  } catch {
  }

  try {
    return [System.Runtime.InteropServices.Marshal]::GetActiveObject("Matlab.Application")
  } catch {
  }

  return New-Object -ComObject "Matlab.Application"
}

$matlab = Get-MatlabComObject
if ($null -eq $matlab) {
  throw "Could not attach to or create a MATLAB COM automation server."
}

$result = $matlab.Execute($Command)
if ($null -ne $result) {
  Write-Output $result
}
