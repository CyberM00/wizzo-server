# Register the board as a Windows scheduled task so it starts with the machine
# and keeps serving whether or not anyone is logged in.
#
#   powershell -ExecutionPolicy Bypass -File deploy\install-task.ps1
#
# Run it from an elevated prompt if you want it to start at boot rather than at
# logon. Remove it again with:
#
#   Unregister-ScheduledTask -TaskName "Wizzo Server" -Confirm:$false

param(
    [int]$Port = 5000,
    # At logon is the safe default: it needs no elevation, and on a gaming PC the
    # machine is logged in whenever anyone wants the board anyway.
    [ValidateSet("Logon", "Boot")]
    [string]$Trigger = "Logon",
    [string]$Python = ""
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$entry = Join-Path $root "wizzo.py"
if (-not (Test-Path $entry)) {
    throw "wizzo.py not found next to this script; run it from inside the checkout"
}

# Prefer a virtualenv in the checkout, then whatever python is on PATH. pythonw
# avoids a console window appearing on every logon.
if (-not $Python) {
    $venv = Join-Path $root ".venv\Scripts\pythonw.exe"
    if (Test-Path $venv) {
        $Python = $venv
    }
    else {
        $found = Get-Command pythonw.exe -ErrorAction SilentlyContinue
        if (-not $found) { $found = Get-Command python.exe -ErrorAction SilentlyContinue }
        if (-not $found) { throw "no python found on PATH; pass -Python <path to pythonw.exe>" }
        $Python = $found.Source
    }
}

# Task Scheduler does not collect stdout, so the log goes to a file here. The
# board truncates it each run.
$logDir = Join-Path $env:LOCALAPPDATA "WizzoServer"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir "wizzo.log"

$arguments = "`"$entry`" --host 0.0.0.0 --port $Port --log-file `"$log`""
$action = New-ScheduledTaskAction -Execute $Python -Argument $arguments -WorkingDirectory $root

if ($Trigger -eq "Boot") {
    $trigger = New-ScheduledTaskTrigger -AtStartup
}
else {
    $trigger = New-ScheduledTaskTrigger -AtLogon
}

# Stopping it because the machine went idle, or because it has been running for
# three days, is the opposite of what a server should do.
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit 0 `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName "Wizzo Server" -Action $action -Trigger $trigger `
    -Settings $settings -Description "Serves the Wizzo kneeboard on port $Port" -Force | Out-Null

Write-Host "Registered 'Wizzo Server' to start at $($Trigger.ToLower())."
Write-Host "  python: $Python"
Write-Host "  log:    $log"
Write-Host ""
Write-Host "Start it now with:  Start-ScheduledTask -TaskName 'Wizzo Server'"
Write-Host "Then open http://localhost:$Port on this machine, or the LAN address it logs."
