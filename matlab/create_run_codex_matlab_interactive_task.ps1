$taskName = "CodexMatlabInteractive"
$scriptPath = "C:\Users\dohyu\Documents\MATLAB\spm\run_matlab_interactive_probe_codex.ps1"
$taskCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

schtasks /create `
  /tn $taskName `
  /sc once `
  /st 23:59 `
  /rl highest `
  /it `
  /tr $taskCmd `
  /f

schtasks /run /tn $taskName
