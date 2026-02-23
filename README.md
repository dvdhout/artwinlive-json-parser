# Artwin Widget Parser

This repository contains context files and a PowerShell parser for Artwin widget schedule data.

## Source

- Widget URL: [artwinlive widget](https://artwinlive.com/widgets/Msi1GseWOav7x74brmWfWtYp)

## Project Structure

- `context/` chat notes and project context
- `scripts/` parsing scripts
- `output/` generated exports (ignored by git)

## Usage

Run parser (default URL):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\parse-artwin-widget.ps1
```

Public entries only:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\parse-artwin-widget.ps1 -OnlyPublic
```

Console output only (no exports):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\parse-artwin-widget.ps1 -NoExport
```

## Change Tracking

Track changes between runs (creates snapshot + report in `state/`):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\track-widget-changes.ps1
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

## Context Links

- Chat context: [context/chat-context-2026-02-23.md](context/chat-context-2026-02-23.md)
- Widget source context: [context/widget-source-context.json](context/widget-source-context.json)
- Source-control best practices: [context/source-control-best-practices.md](context/source-control-best-practices.md)
- Sample parser output: [context/parser-output-sample.md](context/parser-output-sample.md)
