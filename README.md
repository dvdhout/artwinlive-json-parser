# Artwin Widget Parser

This repository contains context files and a PowerShell parser for Artwin widget schedule data.

## Source

- Widget URL: https://artwinlive.com/widgets/Msi1GseWOav7x74brmWfWtYp

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

## Context Links

- Chat context: [context/chat-context-2026-02-23.md](context/chat-context-2026-02-23.md)
- Widget source context: [context/widget-source-context.json](context/widget-source-context.json)
- Source-control best practices: [context/source-control-best-practices.md](context/source-control-best-practices.md)
- Sample parser output: [context/parser-output-sample.md](context/parser-output-sample.md)
