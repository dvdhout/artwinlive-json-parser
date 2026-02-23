# Chat Context (2026-02-23)

## Goal
Create a reusable setup for parsing Artwin widget data from:

- https://artwinlive.com/widgets/Msi1GseWOav7x74brmWfWtYp

## Requested in this chat

1. Create context files for this conversation.
2. Create a script to parse the widget information into a readable format.
3. Add a repository with a `main` branch to manage changes.

## Related docs

- Source-control best practices: [source-control-best-practices.md](source-control-best-practices.md)
- Project overview: [../README.md](../README.md)

## Notes about the widget payload

- The endpoint returns page content containing a JSON array of schedule items.
- Key fields include:
  - `gig_id`, `schedule_id`, `schedule_name`
  - `date_start`, `date_end`
  - `status`, `private`
  - `event.title`
  - `venue.name`, `venue.city`, `venue.country`

## Intended parser output

- Readable console table.
- Optional file exports for downstream usage.
- Separate summaries for public vs private/blocked items.