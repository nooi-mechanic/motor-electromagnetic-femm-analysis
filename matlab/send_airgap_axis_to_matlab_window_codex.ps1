$ErrorActionPreference = "Stop"

Add-Type -AssemblyName Microsoft.VisualBasic

$wshell = New-Object -ComObject WScript.Shell
$logPath = "C:\Users\dohyu\Documents\MATLAB\spm\send_airgap_axis_to_matlab_window_codex.log"
$cmd = "cd('C:\Users\dohyu\Documents\MATLAB\spm'); analyze_v_ipm_m19_current_only_airgap_axis_codex"
$matlabProc = Get-Process MATLAB -ErrorAction Stop | Select-Object -First 1

Set-Content -Path $logPath -Value ("[{0}] START`r`n" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Add-Content -Path $logPath -Value ("[{0}] PID={1}`r`n" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $matlabProc.Id)

$activated = [Microsoft.VisualBasic.Interaction]::AppActivate($matlabProc.Id)
Add-Content -Path $logPath -Value ("[{0}] AppActivateByPid={1}`r`n" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $activated)

Start-Sleep -Milliseconds 500
$wshell.SendKeys("^u")
Start-Sleep -Milliseconds 200
$wshell.SendKeys($cmd)
Start-Sleep -Milliseconds 200
$wshell.SendKeys("~")

Add-Content -Path $logPath -Value ("[{0}] SENT`r`n" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
