# Parser Output Sample

This file documents example output produced by:

`powershell -ExecutionPolicy Bypass -File .\scripts\parse-artwin-widget.ps1 -NoExport`

## Example summary

- Total items: 29
- Public: 11
- Private: 18
- Status 0: 6
- Status 1: 6
- Status 2: 17

## Example rows (trimmed)

| start | end | private | status | title | venue | city | country |
|---|---|---:|---:|---|---|---|---|
| 2026-04-12 14:00:00 | 2026-04-12 17:30:00 | 0 | 1 | Lente Live 2026 | LENTELIVE | Terwolde | NL |
| 2026-04-26 22:15:00 | 2026-04-27 00:30:00 | 0 | 1 | Koningsnacht Berlicum | BERLICUM PLEIN | Berlicum Nb | NL |
| 2026-06-28 18:00:00 | 2026-06-28 22:00:00 | 0 | 1 | Dorpsfeest Akkrum | FEESTTENT AKKRUM | Akkrum | NL |
| 2026-08-06 20:00:00 | 2026-08-06 23:00:00 | 0 | 0 | Wiellerronde Oostvorne | Oostvorne | Oostvorne | NL |
| 2027-02-07 20:00:00 | 2027-02-07 22:45:00 | 0 | 1 | Carnaval 2027 | OIRSCHOT | Oirschot | NL |

## Notes

- This is documentation only; generated files in `output/` stay untracked.
- Values may change when the upstream widget data changes.