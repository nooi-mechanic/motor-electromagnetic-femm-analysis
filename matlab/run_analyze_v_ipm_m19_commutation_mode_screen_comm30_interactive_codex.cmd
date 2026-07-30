@echo off
cd /d C:\Users\dohyu\Documents\MATLAB\spm
if exist run_analyze_v_ipm_m19_commutation_mode_screen_comm30_interactive_codex.log del /f /q run_analyze_v_ipm_m19_commutation_mode_screen_comm30_interactive_codex.log
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "analyze_v_ipm_m19_commutation_mode_screen_comm30_codex" -logfile "C:\Users\dohyu\Documents\MATLAB\spm\run_analyze_v_ipm_m19_commutation_mode_screen_comm30_interactive_codex.log"
