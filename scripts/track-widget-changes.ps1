param(
    [Parameter(Mandatory = $false)]
    [string]$Url = "https://artwinlive.com/widgets/Msi1GseWOav7x74brmWfWtYp",

    [Parameter(Mandatory = $false)]
    [string]$StateDir = ".\\state",

    [Parameter(Mandatory = $false)]
    [int]$RetentionDays = 90,

    [Parameter(Mandatory = $false)]
    [switch]$FailOnChange
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-EmbeddedJsonArray {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Html
    )

    $match = [regex]::Match($Html, '\[(?:.|\r|\n)*\]')
    if (-not $match.Success) {
        throw "Could not find embedded JSON array in page content."
    }

    return $match.Value
}

function Normalize-WidgetItem {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    [pscustomobject]@{
        gig_id            = [string]$Item.gig_id
        schedule_id       = [string]$Item.schedule_id
        schedule_name     = [string]$Item.schedule_name
        date_start        = [string]$Item.date_start
        date_end          = [string]$Item.date_end
        virtual_date_start = [string]$Item.virtual_date_start
        virtual_date_end  = [string]$Item.virtual_date_end
        publish_date      = [string]$Item.publish_date
        change_date       = [string]$Item.change_date
        status            = [int]$Item.status
        private           = [int]$Item.private
        title             = [string]$Item.event.title
        venue_name        = [string]$Item.venue.name
        venue_city        = [string]$Item.venue.city
        venue_country     = [string]$Item.venue.country
    }
}

function To-Lookup {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$Items
    )

    $lookup = @{}
    foreach ($item in $Items) {
        $key = [string]$item.gig_id
        if ([string]::IsNullOrWhiteSpace($key)) {
            continue
        }

        $lookup[$key] = $item
    }

    return $lookup
}

function Get-FieldDiffs {
    param(
        [Parameter(Mandatory = $true)]
        $Old,

        [Parameter(Mandatory = $true)]
        $New,

        [Parameter(Mandatory = $true)]
        [string[]]$Fields
    )

    $diffs = @()
    foreach ($field in $Fields) {
        $oldValue = [string]$Old.$field
        $newValue = [string]$New.$field
        if ($oldValue -cne $newValue) {
            $diffs += [pscustomobject]@{
                field = $field
                old   = $oldValue
                new   = $newValue
            }
        }
    }

    return @($diffs)
}

function Write-MarkdownReport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        $Report
    )

    $lines = @()
    $lines += "# Widget Change Report"
    $lines += ""
    $lines += "- Created: $($Report.created_at)"
    $lines += "- Source: $($Report.source_url)"
    $lines += "- Previous snapshot: $($Report.previous_snapshot)"
    $lines += "- Current snapshot: $($Report.current_snapshot)"
    $lines += ""
    $lines += "## Summary"
    $lines += ""
    $lines += "- Added: $($Report.summary.added)"
    $lines += "- Removed: $($Report.summary.removed)"
    $lines += "- Changed: $($Report.summary.changed)"
    $lines += ""

    if (@($Report.added).Count -gt 0) {
        $lines += "## Added"
        $lines += ""
        foreach ($item in @($Report.added) | Select-Object -First 20) {
            $lines += "- $($item.gig_id): $($item.date_start) | $($item.title) | private=$($item.private) status=$($item.status)"
        }
        $lines += ""
    }

    if (@($Report.removed).Count -gt 0) {
        $lines += "## Removed"
        $lines += ""
        foreach ($item in @($Report.removed) | Select-Object -First 20) {
            $lines += "- $($item.gig_id): $($item.date_start) | $($item.title) | private=$($item.private) status=$($item.status)"
        }
        $lines += ""
    }

    if (@($Report.changed).Count -gt 0) {
        $lines += "## Changed"
        $lines += ""
        foreach ($change in @($Report.changed) | Select-Object -First 20) {
            $lines += "- $($change.gig_id): $($change.change_count) field change(s)"
            foreach ($diff in $change.diffs) {
                $lines += "  - $($diff.field): '$($diff.old)' -> '$($diff.new)'"
            }
        }
        $lines += ""
    }

    Set-Content -Path $Path -Value $lines -Encoding UTF8
}

Write-Host "Fetching widget data from: $Url" -ForegroundColor Cyan
$response = Invoke-WebRequest -Uri $Url -UseBasicParsing

$jsonRaw = Get-EmbeddedJsonArray -Html $response.Content
$rawItems = $jsonRaw | ConvertFrom-Json

if (-not $rawItems -or $rawItems.Count -eq 0) {
    throw "No schedule items found in parsed JSON payload."
}

$normalizedItems = $rawItems |
    ForEach-Object { Normalize-WidgetItem -Item $_ } |
    Sort-Object { [datetime]$_.date_start }, gig_id

$snapshotsDir = Join-Path $StateDir "snapshots"
$reportsDir = Join-Path $StateDir "reports"
New-Item -Path $snapshotsDir -ItemType Directory -Force | Out-Null
New-Item -Path $reportsDir -ItemType Directory -Force | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$snapshotPath = Join-Path $snapshotsDir "widget-snapshot-$timestamp.json"

$previousSnapshotFile = Get-ChildItem -Path $snapshotsDir -Filter "widget-snapshot-*.json" |
    Sort-Object LastWriteTime |
    Select-Object -Last 1

$previousItems = @()
$previousSnapshotName = "(none)"

if ($null -ne $previousSnapshotFile) {
    $previousSnapshotName = $previousSnapshotFile.Name
    $previousContent = Get-Content -Path $previousSnapshotFile.FullName -Raw | ConvertFrom-Json
    $previousItems = @($previousContent.items)
}

$currentSnapshot = [pscustomobject]@{
    created_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    source_url = $Url
    item_count = $normalizedItems.Count
    items      = $normalizedItems
}

$currentSnapshot | ConvertTo-Json -Depth 8 | Set-Content -Path $snapshotPath -Encoding UTF8

$trackedFields = @(
    'date_start',
    'date_end',
    'virtual_date_start',
    'virtual_date_end',
    'status',
    'private',
    'title',
    'venue_name',
    'venue_city',
    'venue_country',
    'schedule_name',
    'publish_date',
    'change_date'
)

$currentById = To-Lookup -Items $normalizedItems
$previousById = To-Lookup -Items $previousItems

$added = @()
$removed = @()
$changed = @()

foreach ($gigId in $currentById.Keys) {
    if (-not $previousById.ContainsKey($gigId)) {
        $added += $currentById[$gigId]
        continue
    }

    $diffs = Get-FieldDiffs -Old $previousById[$gigId] -New $currentById[$gigId] -Fields $trackedFields
    if (@($diffs).Count -gt 0) {
        $changed += [pscustomobject]@{
            gig_id       = $gigId
            title        = $currentById[$gigId].title
            date_start   = $currentById[$gigId].date_start
            change_count = @($diffs).Count
            diffs        = @($diffs)
        }
    }
}

foreach ($gigId in $previousById.Keys) {
    if (-not $currentById.ContainsKey($gigId)) {
        $removed += $previousById[$gigId]
    }
}

$report = [pscustomobject]@{
    created_at        = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    source_url        = $Url
    previous_snapshot = $previousSnapshotName
    current_snapshot  = [System.IO.Path]::GetFileName($snapshotPath)
    summary           = [pscustomobject]@{
        added   = $added.Count
        removed = $removed.Count
        changed = $changed.Count
    }
    added             = @($added | Sort-Object { [datetime]$_.date_start }, gig_id)
    removed           = @($removed | Sort-Object { [datetime]$_.date_start }, gig_id)
    changed           = @($changed | Sort-Object { [datetime]$_.date_start }, gig_id)
}

$reportJsonPath = Join-Path $reportsDir "change-report-$timestamp.json"
$reportMdPath = Join-Path $reportsDir "change-report-$timestamp.md"

$report | ConvertTo-Json -Depth 10 | Set-Content -Path $reportJsonPath -Encoding UTF8
Write-MarkdownReport -Path $reportMdPath -Report $report

Write-Host ""
Write-Host "Change summary" -ForegroundColor Green
Write-Host "--------------"
Write-Host "Added   : $($report.summary.added)"
Write-Host "Removed : $($report.summary.removed)"
Write-Host "Changed : $($report.summary.changed)"

if ($report.summary.changed -gt 0) {
    Write-Host ""
    Write-Host "Changed items (first 10):" -ForegroundColor Yellow
    $report.changed |
        Select-Object -First 10 gig_id, date_start, title, change_count |
        Format-Table -AutoSize
}

Write-Host ""
Write-Host "Saved:" -ForegroundColor Cyan
Write-Host "- Snapshot: $snapshotPath"
Write-Host "- Report JSON: $reportJsonPath"
Write-Host "- Report MD: $reportMdPath"

if ($RetentionDays -gt 0) {
    $cutoff = (Get-Date).AddDays(-1 * $RetentionDays)
    Get-ChildItem -Path $snapshotsDir -Filter "widget-snapshot-*.json" |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Remove-Item -Force -ErrorAction SilentlyContinue

    Get-ChildItem -Path $reportsDir -Filter "change-report-*.*" |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

$hasChanges = ($report.summary.added + $report.summary.removed + $report.summary.changed) -gt 0
if ($FailOnChange -and $hasChanges) {
    exit 2
}
