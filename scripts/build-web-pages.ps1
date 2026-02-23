param(
    [Parameter(Mandatory = $false)]
    [string]$StateDir = ".\\site-data",

    [Parameter(Mandatory = $false)]
    [string]$DocsDir = ".\\docs"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function HtmlEncode {
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$Text
    )

    if ($null -eq $Text) { return '' }
    return [System.Net.WebUtility]::HtmlEncode($Text)
}

function Parse-DateSafe {
    param(
        [Parameter(Mandatory = $false)]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    try {
        return [datetime]::Parse($Value)
    }
    catch {
        return $null
    }
}

function Status-Order {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Status
    )

    switch ($Status) {
        1 { return 0 }
        0 { return 1 }
        2 { return 2 }
        default { return 99 }
    }
}

function Build-Style {
    return @"
<style>
body { font-family: Segoe UI, Arial, sans-serif; margin: 24px; color: #1f2937; }
h1, h2 { margin-bottom: 8px; }
.meta { color: #4b5563; margin-bottom: 12px; }
.card { padding: 12px; border: 1px solid #e5e7eb; border-radius: 8px; margin-bottom: 16px; }
table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
th, td { border: 1px solid #e5e7eb; padding: 8px; text-align: left; font-size: 13px; vertical-align: top; }
th { background: #f9fafb; }
.small { color: #6b7280; font-size: 12px; }
a { color: #2563eb; text-decoration: none; }
a:hover { text-decoration: underline; }
</style>
"@
}

function Build-StatusCountRows {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$Items
    )

    $groups = $Items | Group-Object status | Sort-Object { [int]$_.Name }
    $rows = foreach ($group in $groups) {
        $sample = @($group.Group | Select-Object -First 1)[0]
        "<tr><td>$([int]$group.Name)</td><td>$(HtmlEncode([string]$sample.status_description))</td><td>$($group.Count)</td></tr>"
    }

    if (@($rows).Count -eq 0) {
        return '<tr><td colspan="3">No data</td></tr>'
    }

    return ($rows -join "`n")
}

function Build-EventRows {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$Items,

        [Parameter(Mandatory = $false)]
        [int]$Max = 300
    )

    $rows = foreach ($item in @($Items | Select-Object -First $Max)) {
        "<tr><td>$(HtmlEncode([string]$item.date_start))</td><td>$(HtmlEncode([string]$item.date_end))</td><td>$([int]$item.status) ($(HtmlEncode([string]$item.status_description)))</td><td>$([int]$item.private)</td><td>$(HtmlEncode([string]$item.title))</td><td>$(HtmlEncode([string]$item.venue_name))</td><td>$(HtmlEncode([string]$item.venue_city))</td><td>$(HtmlEncode([string]$item.venue_country))</td><td>$(HtmlEncode([string]$item.gig_id))</td></tr>"
    }

    if (@($rows).Count -eq 0) {
        return '<tr><td colspan="9">No events</td></tr>'
    }

    return ($rows -join "`n")
}

function Build-HistoryChangeRows {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$Rows,

        [Parameter(Mandatory = $false)]
        [int]$Max = 400
    )

    $items = @($Rows | Select-Object -First $Max)
    if ($items.Count -eq 0) {
        return '<tr><td colspan="5">No changes</td></tr>'
    }

    $html = foreach ($row in $items) {
        "<tr><td>$(HtmlEncode([string]$row.report_created))</td><td>$(HtmlEncode([string]$row.gig_id))</td><td>$(HtmlEncode([string]$row.date_start))</td><td>$(HtmlEncode([string]$row.title))</td><td>$(HtmlEncode([string]$row.details))</td></tr>"
    }

    return ($html -join "`n")
}

$snapshotsDir = Join-Path $StateDir 'snapshots'
$reportsDir = Join-Path $StateDir 'reports'

New-Item -Path $DocsDir -ItemType Directory -Force | Out-Null

$snapshotFiles = @()
if (Test-Path $snapshotsDir) {
    $snapshotFiles = @(Get-ChildItem -Path $snapshotsDir -Filter 'widget-snapshot-*.json' | Sort-Object LastWriteTime)
}

if ($snapshotFiles.Count -eq 0) {
    $emptyHtml = @"
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <title>Artwin Dashboard</title>
  $(Build-Style)
</head>
<body>
  <h1>Artwin Dashboard</h1>
  <p class="meta">No snapshot data available yet.</p>
  <p>Run tracker first to generate data.</p>
</body>
</html>
"@

    Set-Content -Path (Join-Path $DocsDir 'index.html') -Value $emptyHtml -Encoding UTF8
    Set-Content -Path (Join-Path $DocsDir 'history.html') -Value $emptyHtml -Encoding UTF8
    Write-Host "Generated empty docs pages (no snapshots found)."
    exit 0
}

$latestSnapshotFile = $snapshotFiles[-1]
$latestSnapshot = Get-Content -Path $latestSnapshotFile.FullName -Raw | ConvertFrom-Json
$items = @($latestSnapshot.items)

$now = Get-Date
$upcoming = @($items | Where-Object {
    $endDt = Parse-DateSafe -Value ([string]$_.date_end)
    $null -ne $endDt -and $endDt -ge $now
} | Sort-Object @{ Expression = { Status-Order -Status ([int]$_.status) } }, @{ Expression = { Parse-DateSafe -Value ([string]$_.date_start) } })

$past = @($items | Where-Object {
    $endDt = Parse-DateSafe -Value ([string]$_.date_end)
    $null -ne $endDt -and $endDt -lt $now
} | Sort-Object @{ Expression = { Parse-DateSafe -Value ([string]$_.date_end) } } -Descending)

$statusCountRows = Build-StatusCountRows -Items $items
$upcomingRows = Build-EventRows -Items $upcoming -Max 300
$pastRows = Build-EventRows -Items $past -Max 500

$latestLegend = if ([string]::IsNullOrWhiteSpace([string]$latestSnapshot.items[0].status_description)) { '' } else {
    $desc0 = @($items | Where-Object { [int]$_.status -eq 0 } | Select-Object -First 1)[0].status_description
    $desc1 = @($items | Where-Object { [int]$_.status -eq 1 } | Select-Object -First 1)[0].status_description
    $desc2 = @($items | Where-Object { [int]$_.status -eq 2 } | Select-Object -First 1)[0].status_description
    "0=$desc0, 1=$desc1, 2=$desc2"
}

$indexHtml = @"
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <title>Artwin - Current Summary</title>
  $(Build-Style)
</head>
<body>
  <h1>Current Summary</h1>
  <p class="meta">Latest snapshot: $(HtmlEncode($latestSnapshotFile.Name))</p>
  <p class="meta">Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | <a href="history.html">View history</a></p>

  <div class="card">
    <strong>Total items:</strong> $($items.Count)<br/>
    <strong>Legend:</strong> $(HtmlEncode($latestLegend))
  </div>

  <h2>Status Totals</h2>
  <table>
    <thead><tr><th>Status</th><th>Description</th><th>Total</th></tr></thead>
    <tbody>
      $statusCountRows
    </tbody>
  </table>

  <h2>Upcoming / Active Events</h2>
  <table>
    <thead>
      <tr><th>Start</th><th>End</th><th>Status</th><th>Private</th><th>Title</th><th>Venue</th><th>City</th><th>Country</th><th>Gig ID</th></tr>
    </thead>
    <tbody>
      $upcomingRows
    </tbody>
  </table>

  <p class="small">Status order is 1 first, then 0, then 2.</p>
</body>
</html>
"@

Set-Content -Path (Join-Path $DocsDir 'index.html') -Value $indexHtml -Encoding UTF8

$reportFiles = @()
if (Test-Path $reportsDir) {
    $reportFiles = @(Get-ChildItem -Path $reportsDir -Filter 'change-report-*.json' | Sort-Object LastWriteTime -Descending)
}

$removedRows = @()
$otherChangeRows = @()

foreach ($reportFile in $reportFiles) {
    $reportObj = Get-Content -Path $reportFile.FullName -Raw | ConvertFrom-Json
    $reportCreated = [string]$reportObj.created_at

    foreach ($removed in @($reportObj.removed)) {
        $removedRows += [pscustomobject]@{
            report_created = $reportCreated
            gig_id         = [string]$removed.gig_id
            date_start     = [string]$removed.date_start
            title          = [string]$removed.title
            details        = "removed from latest snapshot"
        }
    }

    foreach ($added in @($reportObj.added)) {
        $otherChangeRows += [pscustomobject]@{
            report_created = $reportCreated
            gig_id         = [string]$added.gig_id
            date_start     = [string]$added.date_start
            title          = [string]$added.title
            details        = "added"
        }
    }

    foreach ($changed in @($reportObj.changed)) {
        $details = "changed fields: " + [string]$changed.change_count
        $otherChangeRows += [pscustomobject]@{
            report_created = $reportCreated
            gig_id         = [string]$changed.gig_id
            date_start     = [string]$changed.date_start
            title          = [string]$changed.title
            details        = $details
        }
    }
}

$removedRows = @($removedRows | Sort-Object @{ Expression = { Parse-DateSafe -Value ([string]$_.report_created) } } -Descending)
$otherChangeRows = @($otherChangeRows | Sort-Object @{ Expression = { Parse-DateSafe -Value ([string]$_.report_created) } } -Descending)

$removedHtmlRows = Build-HistoryChangeRows -Rows $removedRows -Max 500
$otherChangesHtmlRows = Build-HistoryChangeRows -Rows $otherChangeRows -Max 500

$historyHtml = @"
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <title>Artwin - History</title>
  $(Build-Style)
</head>
<body>
  <h1>History</h1>
  <p class="meta">Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | <a href="index.html">View current summary</a></p>

  <h2>Past Events</h2>
  <table>
    <thead>
      <tr><th>Start</th><th>End</th><th>Status</th><th>Private</th><th>Title</th><th>Venue</th><th>City</th><th>Country</th><th>Gig ID</th></tr>
    </thead>
    <tbody>
      $pastRows
    </tbody>
  </table>

  <h2>Cancelled / Removed Events</h2>
  <table>
    <thead><tr><th>Report Time</th><th>Gig ID</th><th>Start</th><th>Title</th><th>Details</th></tr></thead>
    <tbody>
      $removedHtmlRows
    </tbody>
  </table>

  <h2>Other Changes (Added + Changed)</h2>
  <table>
    <thead><tr><th>Report Time</th><th>Gig ID</th><th>Start</th><th>Title</th><th>Details</th></tr></thead>
    <tbody>
      $otherChangesHtmlRows
    </tbody>
  </table>
</body>
</html>
"@

Set-Content -Path (Join-Path $DocsDir 'history.html') -Value $historyHtml -Encoding UTF8

Write-Host "Generated docs pages:"
Write-Host "- $(Join-Path $DocsDir 'index.html')"
Write-Host "- $(Join-Path $DocsDir 'history.html')"
