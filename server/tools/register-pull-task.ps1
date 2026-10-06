# Registers a daily Windows scheduled task that runs the BigQuery pull.
# StartWhenAvailable: if the PC was off at 09:00, run as soon as it is back on.
$cmd = Join-Path $PSScriptRoot 'pull.cmd'
$action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c `"$cmd`""
$trigger = New-ScheduledTaskTrigger -Daily -At 9:00AM
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)
Register-ScheduledTask -TaskName 'AnalyticTrackerPull' -Action $action -Trigger $trigger `
  -Settings $settings -Description 'Daily BigQuery pull for AnalyticTracker' -Force
