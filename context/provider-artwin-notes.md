# Provider Notes (Artwin Knowledgebase)

Source index:

- https://support.artwinlive.com/knowledgebase

Referenced articles:

- XML/JSON Widget
- Managing gigs and appointments
- Website Widget (iframe)

## Confirmed provider semantics

### XML/JSON status values (official)

- `0` = Tentative
- `1` = Confirmed
- `2` = Appointment

### Date behavior

- `DateStart` / `DateEnd` are real date-time values.
- `VirtualDateStart` / `VirtualDateEnd` can shift events after midnight to the previous day (default behavior for night-time gigs, configurable in account/schedule settings).

### Visibility and publication

- Private parties are not published publicly.
- Public gigs can have a publication date/time.
- Website widget can include non-confirmed gigs when "Show all gigs" is enabled.

## Project interpretation used in this repo

For business readability in this project, status labels are currently:

- `0` = `optie`
- `1` = `definitief`
- `2` = `bezet`

This mapping is intentional for downstream users of these summaries.
