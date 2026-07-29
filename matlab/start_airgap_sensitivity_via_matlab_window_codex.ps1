$ErrorActionPreference = "Stop"

Add-Type -AssemblyName Microsoft.VisualBasic

$workdir = "C:\Users\dohyu\Documents\MATLAB\spm"
$logPath = Join-Path $workdir "start_airgap_sensitivity_via_matlab_window_codex.log"
$command = "cd C:\Users\dohyu\Documents\MATLAB\spm; clear run_v_ipm_m19_torque_sweep_codex default_v_ipm_m19_settings_codex; analyze_v_ipm_m19_airgap_sensitivity_5point_codex"
$matlabProc = Get-Process MATLAB -ErrorAction Stop | Select-Object -First 1

Set-Content -Path $logPath -Value ("[{0}] START PID={1}`r`n" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $matlabProc.Id)
$activated = [Microsoft.VisualBasic.Interaction]::AppActivate($matlabProc.Id)
Add-Content -Path $logPath -Value ("[{0}] AppActivate={1}`r`n" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $activated)
if (-not $activated) {
    throw "Could not activate the existing MATLAB Desktop window. No keys were sent."
}

$wshell = New-Object -ComObject WScript.Shell
Start-Sleep -Milliseconds 700
$wshell.SendKeys("^u")
Start-Sleep -Milliseconds 200
$wshell.SendKeys($command)
Start-Sleep -Milliseconds 200
$wshell.SendKeys("~")

Add-Content -Path $logPath -Value ("[{0}] SENT {1}`r`n" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $command)
