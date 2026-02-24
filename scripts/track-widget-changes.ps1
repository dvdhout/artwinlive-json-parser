param(
    [Parameter(Mandatory = $false)]
    [string]$Url = "",

    [Parameter(Mandatory = $false)]
    [string]$StateDir = ".\\state",

    [Parameter(Mandatory = $false)]
    [int]$RetentionDays = 90,

    [Parameter(Mandatory = $false)]
    [switch]$FailOnChange,

    [Parameter(Mandatory = $false)]
    [switch]$TranslateStatusToDutch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$StatusDescriptionsOfficial = @{
    0 = 'Tentative'
    1 = 'Confirmed'
    2 = 'Appointment'
}

$StatusDescriptionsDutch = @{
    0 = 'optie'
    1 = 'definitief'
    2 = 'bezet'
}

$StatusDescriptions = if ($TranslateStatusToDutch) { $StatusDescriptionsDutch } else { $StatusDescriptionsOfficial }

$Text = if ($TranslateStatusToDutch) {
    @{
        ChangeReportTitle = 'Widget wijzigingsrapport'
        SummaryTitle = 'Samenvatting'
        Created = 'Aangemaakt'
        PreviousSnapshot = 'Vorige snapshot'
        CurrentSnapshot = 'Huidige snapshot'
        Legend = 'Legenda'
        Added = 'Toegevoegd'
        Removed = 'Verwijderd'
        Changed = 'Gewijzigd'
        AddedSection = 'Toegevoegd'
        RemovedSection = 'Verwijderd'
        ChangedSection = 'Gewijzigd'
        FieldChanges = 'veldwijziging(en)'
        StatusSummaryTitle = 'Widgetoverzicht (gesorteerd op status)'
        Total = 'Totaal'
        Status = 'Status'
        TotalInline = 'totaal'
        NoEvents = '_Geen events._'
        Start = 'Start'
        End = 'Einde'
        Private = 'Prive'
        Title = 'Titel'
        Venue = 'Locatie'
        City = 'Plaats'
        Country = 'Land'
        GigId = 'Gig ID'
        ConsoleChangeSummary = 'Wijzigingsoverzicht'
        ChangedItems = 'Gewijzigde items (eerste 10):'
        Saved = 'Opgeslagen:'
        Snapshot = 'Snapshot'
        ReportJson = 'Rapport JSON'
        ReportMd = 'Rapport MD'
        StatusSummaryMd = 'Statusoverzicht MD'
    }
} else {
    @{
        ChangeReportTitle = 'Widget Change Report'
        SummaryTitle = 'Summary'
        Created = 'Created'
        PreviousSnapshot = 'Previous snapshot'
        CurrentSnapshot = 'Current snapshot'
        Legend = 'Legend'
        Added = 'Added'
        Removed = 'Removed'
        Changed = 'Changed'
        AddedSection = 'Added'
        RemovedSection = 'Removed'
        ChangedSection = 'Changed'
        FieldChanges = 'field change(s)'
        StatusSummaryTitle = 'Widget Summary (Ordered by Status)'
        Total = 'Total'
        Status = 'Status'
        TotalInline = 'total'
        NoEvents = '_No events._'
        Start = 'Start'
        End = 'End'
        Private = 'Private'
        Title = 'Title'
        Venue = 'Venue'
        City = 'City'
        Country = 'Country'
        GigId = 'Gig ID'
        ConsoleChangeSummary = 'Change summary'
        ChangedItems = 'Changed items (first 10):'
        Saved = 'Saved:'
        Snapshot = 'Snapshot'
        ReportJson = 'Report JSON'
        ReportMd = 'Report MD'
        StatusSummaryMd = 'Status summary MD'
    }
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

function Get-StatusLegendString {
    $parts = @()
    foreach ($status in @(0, 1, 2)) {
        $parts += "$status=$((Get-StatusDescription -Status $status))"
    }

    return ($parts -join ', ')
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
        $Html
    )

    $htmlText = $null

    if ($Html -is [string]) {
        $htmlText = $Html
    }
    elseif ($Html -is [byte[]]) {
        $htmlText = [System.Text.Encoding]::UTF8.GetString($Html)
    }
    elseif ($Html -is [System.Array]) {
        $htmlText = ($Html | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
    }
    elseif ($null -ne $Html) {
        $htmlText = [string]$Html
    }

    if ([string]::IsNullOrWhiteSpace($htmlText)) {
        throw "Could not read HTML page content as text."
    }

    $match = [regex]::Match($htmlText, '\[(?:.|\r|\n)*\]')
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
    $lines += "# $($Text.ChangeReportTitle)"
    $lines += ""
    $lines += "- $($Text.Created): $($Report.created_at)"
    $lines += "- $($Text.PreviousSnapshot): $($Report.previous_snapshot)"
    $lines += "- $($Text.CurrentSnapshot): $($Report.current_snapshot)"
    $lines += ""
    $lines += "## $($Text.SummaryTitle)"
    $lines += ""
    $lines += "- $($Text.Legend): $($Report.legend)"
    $lines += "- $($Text.Added): $($Report.summary.added)"
    $lines += "- $($Text.Removed): $($Report.summary.removed)"
    $lines += "- $($Text.Changed): $($Report.summary.changed)"
    $lines += ""

    if (@($Report.added).Count -gt 0) {
        $lines += "## $($Text.AddedSection)"
        $lines += ""
        foreach ($item in @($Report.added) | Select-Object -First 20) {
            $lines += "- $($item.gig_id): $($item.date_start) | $($item.title) | private=$($item.private) status=$($item.status) ($($item.status_description))"
        }
        $lines += ""
    }

    if (@($Report.removed).Count -gt 0) {
        $lines += "## $($Text.RemovedSection)"
        $lines += ""
        foreach ($item in @($Report.removed) | Select-Object -First 20) {
            $lines += "- $($item.gig_id): $($item.date_start) | $($item.title) | private=$($item.private) status=$($item.status) ($($item.status_description))"
        }
        $lines += ""
    }

    if (@($Report.changed).Count -gt 0) {
        $lines += "## $($Text.ChangedSection)"
        $lines += ""
        foreach ($change in @($Report.changed) | Select-Object -First 20) {
            $lines += "- $($change.gig_id): $($change.change_count) $($Text.FieldChanges)"
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
        [string]$CreatedAt,

        [Parameter(Mandatory = $true)]
        [string]$Legend
    )

    $statusOrder = @{
        1 = 0
        0 = 1
        2 = 2
    }

    $orderedItems = @($Items | Sort-Object @{ Expression = { $statusOrder[[int]$_.status] } }, @{ Expression = { [datetime]$_.date_start } }, title)

    $lines = @()
    $lines += "# $($Text.StatusSummaryTitle)"
    $lines += ""
    $lines += "- $($Text.Created): $CreatedAt"
    $lines += "- $($Text.Legend): $Legend"
    $lines += "- $($Text.Total): $(@($orderedItems).Count)"
    $lines += ""

    foreach ($status in @(1, 0, 2)) {
        $statusItems = @($orderedItems | Where-Object { $_.status -eq $status })
        $label = Get-StatusDescription -Status $status
        $lines += "## $($Text.Status) $status ($label) - $($Text.TotalInline): $($statusItems.Count)"
        $lines += ""

        if ($statusItems.Count -eq 0) {
            $lines += $Text.NoEvents
            $lines += ""
            continue
        }

        $lines += "| $($Text.Start) | $($Text.End) | $($Text.Private) | $($Text.Title) | $($Text.Venue) | $($Text.City) | $($Text.Country) | $($Text.GigId) |"
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
    legend            = (Get-StatusLegendString)
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
Write-MarkdownStatusSummary -Path $statusSummaryPath -Items $normalizedItems -CreatedAt (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Legend (Get-StatusLegendString)

Write-Host ""
Write-Host $Text.ConsoleChangeSummary -ForegroundColor Green
Write-Host "--------------"
Write-Host "$($Text.Added)   : $($report.summary.added)"
Write-Host "$($Text.Removed) : $($report.summary.removed)"
Write-Host "$($Text.Changed) : $($report.summary.changed)"

if ($report.summary.changed -gt 0) {
    Write-Host ""
    Write-Host $Text.ChangedItems -ForegroundColor Yellow
    $report.changed |
        Select-Object -First 10 gig_id, date_start, title, change_count |
        Format-Table -AutoSize
}

Write-Host ""
Write-Host $Text.Saved -ForegroundColor Cyan
Write-Host "- $($Text.Snapshot): $snapshotPath"
Write-Host "- $($Text.ReportJson): $reportJsonPath"
Write-Host "- $($Text.ReportMd): $reportMdPath"
Write-Host "- $($Text.StatusSummaryMd): $statusSummaryPath"

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
