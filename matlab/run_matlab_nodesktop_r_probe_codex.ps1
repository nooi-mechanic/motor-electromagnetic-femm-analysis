$matlab = "C:\Program Files\MATLAB\R2024a\bin\matlab.exe"
$log = "C:\Users\dohyu\Documents\MATLAB\spm\matlab_nodesktop_r_probe.log"
$out = "C:\Users\dohyu\Documents\MATLAB\spm\matlab_nodesktop_r_probe_output.txt"

& $matlab `
  -nodesktop `
  -nojvm `
  -logfile $log `
  -r "fid=fopen('$out','a'); fprintf(fid,'nodesktop r probe ok\\n'); fclose(fid); disp('NODEDESKTOP_R_PROBE_OK'); exit"
