$matlab = "C:\Program Files\MATLAB\R2024a\bin\matlab.exe"
& $matlab `
  -logfile "C:\Users\dohyu\Documents\MATLAB\spm\run_analyze_axis_shortedge_ccf_local_sensitivity.log" `
  -batch "addpath('C:\femm42\mfiles'); run('C:\Users\dohyu\Documents\MATLAB\spm\analyze_axis_shortedge_ccf_local_sensitivity.m')"
