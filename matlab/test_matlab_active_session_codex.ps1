$cmd = @"
try
  fid = fopen(fullfile(pwd, 'matlab_active_session_probe.txt'), 'a');
  fprintf(fid, '[%s] active session ok\n', datestr(now, 31));
  fclose(fid);
  disp('ACTIVE_SESSION_OK');
catch ME
  disp(getReport(ME, 'extended'));
  rethrow(ME);
end
"@

powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\dohyu\Documents\MATLAB\spm\invoke_matlab_active_session_codex.ps1" -Command $cmd
