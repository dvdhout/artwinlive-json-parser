param(
    [Parameter(Mandatory = $false)]
    [string]$Url = "",

    [Parameter(Mandatory = $false)]
    [string]$StateDir = ".\\state",

    [Parameter(Mandatory = $false)]
    [int]$RetentionDays = 90,

    [Parameter(Mandatory = $false)]
    [switch]$FailOnChange
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$StatusDescriptions = @{
    0 = 'optie'
    1 = 'definitief'
    2 = 'bezet'
}

function Get-StatusDescription {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Status
    )

    if ($StatusDescriptions.ContainsKey($Status)) {
        return $StatusDescriptions[$Status]
    }

    return 'onbekend'
}

function Resolve-SourceUrl {
    param(
        [Parameter(Mandatory = $false)]
        [string]$RequestedUrl
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedUrl)) {
        return $RequestedUrl
    }

    if (-not [string]::IsNullOrWhiteSpace($env:ARTWIN_WIDGET_SOURCE_URL)) {
        return $env:ARTWIN_WIDGET_SOURCE_URL
    }

    throw "No source URL configured. Set ARTWIN_WIDGET_SOURCE_URL or pass -Url."
}

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
        status_description = Get-StatusDescription -Status ([int]$Item.status)
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
            $lines += "- $($item.gig_id): $($item.date_start) | $($item.title) | private=$($item.private) status=$($item.status) ($($item.status_description))"
        }
        $lines += ""
    }

    if (@($Report.removed).Count -gt 0) {
        $lines += "## Removed"
        $lines += ""
        foreach ($item in @($Report.removed) | Select-Object -First 20) {
            $lines += "- $($item.gig_id): $($item.date_start) | $($item.title) | private=$($item.private) status=$($item.status) ($($item.status_description))"
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

function Write-MarkdownStatusSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$Items,

        [Parameter(Mandatory = $true)]
        [string]$CreatedAt
    )

    $statusOrder = @{
        1 = 0
        0 = 1
        2 = 2
    }

    $orderedItems = @($Items | Sort-Object @{ Expression = { $statusOrder[[int]$_.status] } }, @{ Expression = { [datetime]$_.date_start } }, title)

    $lines = @()
    $lines += "# Widget Summary (Ordered by Status)"
    $lines += ""
    $lines += "- Created: $CreatedAt"
    $lines += "- Legend: 0=optie, 1=definitief, 2=bezet"
    $lines += "- Total: $(@($orderedItems).Count)"
    $lines += ""

    foreach ($status in @(1, 0, 2)) {
        $statusItems = @($orderedItems | Where-Object { $_.status -eq $status })
        $label = Get-StatusDescription -Status $status
        $lines += "## Status $status ($label) - totaal: $($statusItems.Count)"
        $lines += ""

        if ($statusItems.Count -eq 0) {
            $lines += "_No events._"
            $lines += ""
            continue
        }

        $lines += "| Start | End | Private | Title | Venue | City | Country | Gig ID |"
        $lines += "|---|---|---:|---|---|---|---|---|"

        foreach ($item in $statusItems) {
            $safeTitle = [string]$item.title -replace '\|', '\\|'
            $safeVenue = [string]$item.venue_name -replace '\|', '\\|'
            $safeCity = [string]$item.venue_city -replace '\|', '\\|'
            $safeCountry = [string]$item.venue_country -replace '\|', '\\|'
            $lines += "| $($item.date_start) | $($item.date_end) | $($item.private) | $safeTitle | $safeVenue | $safeCity | $safeCountry | $($item.gig_id) |"
        }

        $lines += ""
    }

    Set-Content -Path $Path -Value $lines -Encoding UTF8
}

$Url = Resolve-SourceUrl -RequestedUrl $Url

Write-Host "Fetching widget data..." -ForegroundColor Cyan
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
$statusSummaryPath = Join-Path $reportsDir "status-summary-$timestamp.md"

$report | ConvertTo-Json -Depth 10 | Set-Content -Path $reportJsonPath -Encoding UTF8
Write-MarkdownReport -Path $reportMdPath -Report $report
Write-MarkdownStatusSummary -Path $statusSummaryPath -Items $normalizedItems -CreatedAt (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

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
Write-Host "- Status summary MD: $statusSummaryPath"

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
