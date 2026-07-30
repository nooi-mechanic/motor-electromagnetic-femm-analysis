$matlab = "C:\Program Files\MATLAB\R2024a\bin\matlab.exe"
& $matlab `
  -logfile "C:\Users\dohyu\Documents\MATLAB\spm\run_analyze_v_ipm_m19_theta5deg_casewise.log" `
  -batch "addpath('C:\femm42\mfiles'); run('C:\Users\dohyu\Documents\MATLAB\spm\analyze_v_ipm_m19_theta5deg_casewise.m')"
