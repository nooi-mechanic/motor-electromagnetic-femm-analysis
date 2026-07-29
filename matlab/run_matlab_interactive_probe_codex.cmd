@echo off
cd /d C:\Users\dohyu\Documents\MATLAB\spm
if exist matlab_interactive_probe_output.txt del /f /q matlab_interactive_probe_output.txt
if exist matlab_interactive_probe.log del /f /q matlab_interactive_probe.log
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "matlab_nodesktop_probe_codex" -logfile "C:\Users\dohyu\Documents\MATLAB\spm\matlab_interactive_probe.log"
