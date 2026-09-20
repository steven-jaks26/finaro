# Phase 5 — FIX16 UX Migration Notes

Finaro is not presented as a generic bookkeeping application. The primary user journey is:

`Current financial state → future consequence → risk → action`

## Home
- Current balance is the visual anchor.
- Forecast trend is visible without entering another screen.
- Minimum future balance and date are explicit.
- Negative-day count is explicit.
- Risk is communicated with icon + text, not color alone.
- One primary fast action leads to Smart Input.

## Financial
- Records are grouped by income, expense and liability.
- Opening balance remains explicit.
- Categories are visible but do not become business-logic constants.
- Destructive actions are secondary and exposed through menus.

## Smart Input
- Natural language is the primary interaction.
- The user sees a preview before persistence.
- Missing/uncertain amount is surfaced instead of invented.
- The local parser is deliberately deterministic and limited; production AI belongs to the AI Gateway phase.

## Forecast
- Horizon selection uses canonical project horizons.
- Selection does not mutate stored financial records.
- Risk summary is above detail.

## Trust
- Offline and encrypted-local-storage messaging is visible.
- Backup and subscription screens do not pretend that later phases are already live.
