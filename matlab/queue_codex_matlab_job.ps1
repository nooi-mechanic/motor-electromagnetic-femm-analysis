param(
  [Parameter(Mandatory = $true)]
  [string]$Command
)

$requestPath = "C:\Users\dohyu\Documents\MATLAB\spm\codex_job_request.txt"
$statusPath = "C:\Users\dohyu\Documents\MATLAB\spm\codex_job_status.txt"
$heartbeatPath = "C:\Users\dohyu\Documents\MATLAB\spm\codex_job_heartbeat.txt"
$lockPath = "C:\Users\dohyu\Documents\MATLAB\spm\codex_job_running.lock"

Set-Content -Path $requestPath -Value $Command -NoNewline
Write-Host "Queued command:"
Write-Host $Command

if (Test-Path $statusPath) {
  Write-Host "`nLast status:"
  Get-Content -Path $statusPath -Tail 5
}

if (Test-Path $heartbeatPath) {
  Write-Host "`nHeartbeat:"
  Get-Content -Path $heartbeatPath -Tail 1
}

if (Test-Path $lockPath) {
  Write-Host "`nLock file present: a job is currently running."
}
