param(
    [Parameter(Mandatory = $false)]
    [string]$TaskName = "ArtwinWidgetTracker",

    [Parameter(Mandatory = $false)]
    [int]$IntervalMinutes = 60,

    [Parameter(Mandatory = $false)]
    [string]$Url = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($IntervalMinutes -lt 5) {
    throw "IntervalMinutes must be >= 5."
}

if ([string]::IsNullOrWhiteSpace($Url)) {
    $Url = $env:ARTWIN_WIDGET_SOURCE_URL
}

if ([string]::IsNullOrWhiteSpace($Url)) {
    throw "No source URL configured. Set ARTWIN_WIDGET_SOURCE_URL or pass -Url."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$trackerScript = Join-Path $PSScriptRoot "track-widget-changes.ps1"

if (-not (Test-Path $trackerScript)) {
    throw "Tracker script not found: $trackerScript"
}

$argList = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$trackerScript`"",
    "-Url", "`"$Url`""
)

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument ($argList -join ' ') -WorkingDirectory $repoRoot

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2)
$trigger.Repetition.Interval = "PT${IntervalMinutes}M"
$trigger.Repetition.Duration = "P3650D"

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Description "Track Artwin widget changes" -Force | Out-Null

Write-Host "Scheduled task registered:" -ForegroundColor Green
Write-Host "- Name: $TaskName"
Write-Host "- Interval (minutes): $IntervalMinutes"
Write-Host "- Script: $trackerScript"
Write-Host "- WorkingDirectory: $repoRoot"
