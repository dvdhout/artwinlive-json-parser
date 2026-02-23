param(
    [Parameter(Mandatory = $false)]
    [string]$Url = "",

    [Parameter(Mandatory = $false)]
    [string]$OutDir = ".\\output",

    [Parameter(Mandatory = $false)]
    [switch]$OnlyPublic,

    [Parameter(Mandatory = $false)]
    [switch]$NoExport,

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
        SummaryTitle = 'Widgetoverzicht (gesorteerd op status)'
        Created = 'Aangemaakt'
        Legend = 'Legenda'
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
        ConsoleSummary = 'Samenvatting'
        TotalItems = 'Totaal items'
        Public = 'Publiek'
        Upcoming = 'Komende items (eerste 25)'
        MarkdownSummary = 'Markdown samenvatting:'
        ExportedFiles = 'Geexporteerde bestanden:'
    }
} else {
    @{
        SummaryTitle = 'Widget Summary (Ordered by Status)'
        Created = 'Created'
        Legend = 'Legend'
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
        ConsoleSummary = 'Summary'
        TotalItems = 'Total items'
        Public = 'Public'
        Upcoming = 'Upcoming entries (first 25)'
        MarkdownSummary = 'Markdown summary:'
        ExportedFiles = 'Exported files:'
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
        [string]$Html
    )

    $match = [regex]::Match($Html, '\[(?:.|\r|\n)*\]')
    if (-not $match.Success) {
        throw "Could not find embedded JSON array in page content."
    }

    return $match.Value
}

function To-ReadableRow {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    [pscustomobject]@{
        gig_id       = $Item.gig_id
        start        = $Item.date_start
        end          = $Item.date_end
        private      = [int]$Item.private
        status       = [int]$Item.status
        status_description = Get-StatusDescription -Status ([int]$Item.status)
        title        = if ([string]::IsNullOrWhiteSpace($Item.event.title)) { "(empty)" } else { $Item.event.title }
        venue        = if ([string]::IsNullOrWhiteSpace($Item.venue.name)) { "(empty)" } else { $Item.venue.name }
        city         = if ([string]::IsNullOrWhiteSpace($Item.venue.city)) { "(empty)" } else { $Item.venue.city }
        country      = if ([string]::IsNullOrWhiteSpace($Item.venue.country)) { "(empty)" } else { $Item.venue.country }
        schedule     = $Item.schedule_name
        publish_date = $Item.publish_date
        change_date  = $Item.change_date
    }
}

function Write-MarkdownStatusSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$Rows,

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

    $orderedRows = @($Rows | Sort-Object @{ Expression = { $statusOrder[[int]$_.status] } }, @{ Expression = { [datetime]$_.start } }, title)

    $lines = @()
    $lines += "# $($Text.SummaryTitle)"
    $lines += ""
    $lines += "- $($Text.Created): $CreatedAt"
    $lines += "- $($Text.Legend): $Legend"
    $lines += "- $($Text.Total): $(@($orderedRows).Count)"
    $lines += ""

    $statuses = @(1, 0, 2)
    foreach ($status in $statuses) {
        $statusRows = @($orderedRows | Where-Object { $_.status -eq $status })
        $label = Get-StatusDescription -Status $status

        $lines += "## $($Text.Status) $status ($label) - $($Text.TotalInline): $($statusRows.Count)"
        $lines += ""

        if ($statusRows.Count -eq 0) {
            $lines += $Text.NoEvents
            $lines += ""
            continue
        }

        $lines += "| $($Text.Start) | $($Text.End) | $($Text.Private) | $($Text.Title) | $($Text.Venue) | $($Text.City) | $($Text.Country) | $($Text.GigId) |"
        $lines += "|---|---|---:|---|---|---|---|---|"

        foreach ($row in $statusRows) {
            $safeTitle = [string]$row.title -replace '\|', '\\|'
            $safeVenue = [string]$row.venue -replace '\|', '\\|'
            $safeCity = [string]$row.city -replace '\|', '\\|'
            $safeCountry = [string]$row.country -replace '\|', '\\|'
            $lines += "| $($row.start) | $($row.end) | $($row.private) | $safeTitle | $safeVenue | $safeCity | $safeCountry | $($row.gig_id) |"
        }

        $lines += ""
    }

    Set-Content -Path $Path -Value $lines -Encoding UTF8
}

$Url = Resolve-SourceUrl -RequestedUrl $Url

Write-Host "Fetching widget data..." -ForegroundColor Cyan
$response = Invoke-WebRequest -Uri $Url -UseBasicParsing

$jsonRaw = Get-EmbeddedJsonArray -Html $response.Content
$items = $jsonRaw | ConvertFrom-Json

if (-not $items -or $items.Count -eq 0) {
    throw "No schedule items found in parsed JSON payload."
}

$rows = $items |
    Sort-Object { [datetime]$_.date_start } |
    ForEach-Object { To-ReadableRow -Item $_ }

if ($OnlyPublic) {
    $rows = $rows | Where-Object { $_.private -eq 0 }
}

$totalCount = $rows.Count
$privateCount = ($rows | Where-Object { $_.private -eq 1 }).Count
$publicCount = ($rows | Where-Object { $_.private -eq 0 }).Count

$status0 = ($rows | Where-Object { $_.status -eq 0 }).Count
$status1 = ($rows | Where-Object { $_.status -eq 1 }).Count
$status2 = ($rows | Where-Object { $_.status -eq 2 }).Count
$legend = Get-StatusLegendString

Write-Host "" 
Write-Host $Text.ConsoleSummary -ForegroundColor Green
Write-Host "-------"
Write-Host "$($Text.TotalItems) : $totalCount"
Write-Host "$($Text.Public)      : $publicCount"
Write-Host "$($Text.Private)     : $privateCount"
Write-Host "Status 0    : $status0"
Write-Host "Status 1    : $status1"
Write-Host "Status 2    : $status2"
Write-Host "$($Text.Legend)     : $legend"

Write-Host ""
Write-Host $Text.Upcoming -ForegroundColor Green
Write-Host "---------------------------"
$rows |
    Select-Object -First 25 start, end, private, status, status_description, title, venue, city, country |
    Format-Table -AutoSize

New-Item -Path $OutDir -ItemType Directory -Force | Out-Null
$summaryTimestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$summaryPath = Join-Path $OutDir "artwin-summary-$summaryTimestamp.md"
Write-MarkdownStatusSummary -Path $summaryPath -Rows $rows -CreatedAt (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Legend $legend

Write-Host ""
Write-Host $Text.MarkdownSummary -ForegroundColor Yellow
Write-Host "- $summaryPath"

if (-not $NoExport) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $jsonPath = Join-Path $OutDir "artwin-parsed-$timestamp.json"
    $csvPath = Join-Path $OutDir "artwin-parsed-$timestamp.csv"

    $rows | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8
    $rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

    Write-Host ""
    Write-Host $Text.ExportedFiles -ForegroundColor Yellow
    Write-Host "- $jsonPath"
    Write-Host "- $csvPath"
}