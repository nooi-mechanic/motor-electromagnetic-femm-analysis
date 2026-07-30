$ErrorActionPreference = "Stop"

$baseDir = "C:\Users\dohyu\Documents\MATLAB\spm"
$invokeScript = Join-Path $baseDir "invoke_matlab_active_session_codex.ps1"
$logPath = Join-Path $baseDir "run_airgap_axis_via_active_session_codex.log"

Set-Location $baseDir
Set-Content -Path $logPath -Value ("[{0}] START`r`n" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))

$cmd = @"
cd('$baseDir');
try
  diary('run_airgap_axis_via_active_session_matlab_diary.txt');
  diary on;
  analyze_v_ipm_m19_current_only_airgap_axis_codex;
  diary off;
catch ME
  disp(getReport(ME, 'extended', 'hyperlinks', 'off'));
  try, diary off; catch, end
  rethrow(ME);
end
"@

powershell -NoProfile -ExecutionPolicy Bypass -File $invokeScript -Command $cmd *>> $logPath

Add-Content -Path $logPath -Value ("[{0}] END`r`n" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
