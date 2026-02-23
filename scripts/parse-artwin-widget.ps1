param(
    [Parameter(Mandatory = $false)]
    [string]$Url = "https://artwinlive.com/widgets/Msi1GseWOav7x74brmWfWtYp",

    [Parameter(Mandatory = $false)]
    [string]$OutDir = ".\\output",

    [Parameter(Mandatory = $false)]
    [switch]$OnlyPublic,

    [Parameter(Mandatory = $false)]
    [switch]$NoExport
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
        title        = if ([string]::IsNullOrWhiteSpace($Item.event.title)) { "(empty)" } else { $Item.event.title }
        venue        = if ([string]::IsNullOrWhiteSpace($Item.venue.name)) { "(empty)" } else { $Item.venue.name }
        city         = if ([string]::IsNullOrWhiteSpace($Item.venue.city)) { "(empty)" } else { $Item.venue.city }
        country      = if ([string]::IsNullOrWhiteSpace($Item.venue.country)) { "(empty)" } else { $Item.venue.country }
        schedule     = $Item.schedule_name
        publish_date = $Item.publish_date
        change_date  = $Item.change_date
    }
}

Write-Host "Fetching widget data from: $Url" -ForegroundColor Cyan
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

Write-Host "" 
Write-Host "Summary" -ForegroundColor Green
Write-Host "-------"
Write-Host "Total items : $totalCount"
Write-Host "Public      : $publicCount"
Write-Host "Private     : $privateCount"
Write-Host "Status 0    : $status0"
Write-Host "Status 1    : $status1"
Write-Host "Status 2    : $status2"

Write-Host ""
Write-Host "Upcoming entries (first 25)" -ForegroundColor Green
Write-Host "---------------------------"
$rows |
    Select-Object -First 25 start, end, private, status, title, venue, city, country |
    Format-Table -AutoSize

if (-not $NoExport) {
    New-Item -Path $OutDir -ItemType Directory -Force | Out-Null

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $jsonPath = Join-Path $OutDir "artwin-parsed-$timestamp.json"
    $csvPath = Join-Path $OutDir "artwin-parsed-$timestamp.csv"

    $rows | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8
    $rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

    Write-Host ""
    Write-Host "Exported files:" -ForegroundColor Yellow
    Write-Host "- $jsonPath"
    Write-Host "- $csvPath"
}