$matlab = "C:\Program Files\MATLAB\R2024a\bin\matlab.exe"
$out = "C:\Users\dohyu\Documents\MATLAB\spm\matlab_interactive_probe_output.txt"
$log = "C:\Users\dohyu\Documents\MATLAB\spm\matlab_interactive_probe.log"
$workdir = "C:\Users\dohyu\Documents\MATLAB\spm"

if (Test-Path $out) {
  Remove-Item $out -Force
}
if (Test-Path $log) {
  Remove-Item $log -Force
}

$cmd = "try, cd('$workdir'); matlab_nodesktop_probe_codex; catch ME, disp(getReport(ME,'extended')); exit(1); end; exit(0);"

& $matlab `
  -logfile $log `
  -sd $workdir `
  -r $cmd
