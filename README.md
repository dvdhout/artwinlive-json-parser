# Artwin Widget Parser

This repository contains context files and a PowerShell parser for Artwin widget schedule data.

## Source

- Configure source URL via environment variable:

```powershell
$env:ARTWIN_WIDGET_SOURCE_URL = "https://example.com/widgets/<id>"
```

## Status Legend

- Default (official Artwin):
	- `0` = `Tentative`
	- `1` = `Confirmed`
	- `2` = `Appointment`
- Optional Dutch translation mode:
	- `0` = `optie`
	- `1` = `definitief`
	- `2` = `bezet`

## Provider Semantics (Artwin)

Based on Artwin Knowledgebase documentation for XML/JSON widgets:

- Provider status: `0` = Tentative, `1` = Confirmed, `2` = Appointment
- Date fields: `DateStart/DateEnd` are real times; `VirtualDate*` can shift after-midnight gigs to previous day
- Visibility: private parties are not publicly published; publication date affects public visibility

This project uses official Artwin status labels by default and supports an optional Dutch translation mode.

## Project Structure

- `context/` chat notes and project context
- `scripts/` parsing scripts
- `output/` generated exports (ignored by git)

## Usage

Run parser (default URL):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\parse-artwin-widget.ps1
```

Optional Dutch status translation:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\parse-artwin-widget.ps1 -TranslateStatusToDutch
```

Or pass source explicitly (overrides env variable):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\parse-artwin-widget.ps1 -Url "https://example.com/widgets/<id>"
```

Public entries only:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\parse-artwin-widget.ps1 -OnlyPublic
```

Console output only (no exports):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\parse-artwin-widget.ps1 -NoExport
```

Each parser pass also creates a human-readable markdown summary ordered by status (status `1` first):

- `output/artwin-summary-YYYYMMDD-HHMMSS.md`

## Change Tracking

Track changes between runs (creates snapshot + report in `state/`):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\track-widget-changes.ps1
```

Optional Dutch status translation:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\track-widget-changes.ps1 -TranslateStatusToDutch
```

Or pass source explicitly:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\track-widget-changes.ps1 -Url "https://example.com/widgets/<id>"
```

Fail with exit code `2` when changes are detected:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\track-widget-changes.ps1 -FailOnChange
```

Optional retention window (days):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\track-widget-changes.ps1 -RetentionDays 30
```

### Schedule on Windows

Register a repeating scheduled task (default every 60 minutes):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\register-widget-tracker-task.ps1
```

Custom interval:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\register-widget-tracker-task.ps1 -IntervalMinutes 30
```

Outputs are written to:

- `state/snapshots/widget-snapshot-YYYYMMDD-HHMMSS.json`
- `state/reports/change-report-YYYYMMDD-HHMMSS.json`
- `state/reports/change-report-YYYYMMDD-HHMMSS.md`
- `state/reports/status-summary-YYYYMMDD-HHMMSS.md` (ordered by status, with `1` first)

## Context Links

- Chat context: [context/chat-context-2026-02-23.md](context/chat-context-2026-02-23.md)
- Widget source context: [context/widget-source-context.json](context/widget-source-context.json)
- Provider notes: [context/provider-artwin-notes.md](context/provider-artwin-notes.md)
- Source-control best practices: [context/source-control-best-practices.md](context/source-control-best-practices.md)
- Sample parser output: [context/parser-output-sample.md](context/parser-output-sample.md)
