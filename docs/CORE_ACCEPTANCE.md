# Core product acceptance

Verdi's first useful product slice is an explainable electricity estimate from a person's authorized records. A connection directory alone does not deliver that result. The working slice must preserve meter identity, show what will count, save the review, and produce the same result after replay and reload.

## Supported path

Use **Auto track → Review into evidence archive** with normalized daily `record_id,date,kwh` CSV. Reuse the saved meter on subsequent imports. Review the service time zone, factor, evidence quality, personal share and decision, preview, then save to the evidence archive. This experimental archive remains separate from the activity journal and dashboard until those two accounting paths are reconciled.

The electricity factor is the pinned EPA US-average fallback. It is not a PSE factor or a measurement of a household's specific electricity emissions. Pacific service days are resolved independently of the device time zone. Acknowledging file authorization records a local statement, not provider OAuth or verified account ownership.

## Evidence required for acceptance

| Scenario | Required behavior | Regression evidence |
| --- | --- | --- |
| First import | Explicit review, attributable quantity × factor × share, durable source identity | `utility_review_test.dart`, `utility_review_screen_test.dart` |
| Repeat import | No second copy or extra emissions | Utility review and adapter tests |
| Changed reading or assumptions | Explicit correction approval; retain prior revision | Utility review and adapter tests |
| Another save after preview | Reject stale meter state; ask for a new preview | Utility review service/store and screen tests |
| Disk write fails or app restarts | Save neither evidence nor receipt on failure; rebuild and retry without loss or duplication | Utility review and archive storage tests |
| Source is estimated or uncertain | Require an explicit quality choice; do not silently rank normalized CSV as measured data | Utility review service and widget tests |
| Unreadable storage | Preserve data and block writes | Utility review and archive tests |
| Spring/fall clock change | Correct 23/25-hour UTC service interval | `service_zone_test.dart` |
| Meter plus matching payment | Count energy once; retain payment as nonadditive evidence | Ledger/archive tests and `tool/preview_footprint.dart` |
| Home charging inside home meter | No extra emissions for contained charging; conflicting containment held | `evidence_archive_test.dart` |
| Conflicting source or incompatible accounting basis | Hold for review, including conflicts outside the requested month | `footprint_ledger_test.dart`, `evidence_archive_test.dart` |
| Missing or partial coverage | Never infer a complete month or zero for missing categories | Ledger, archive and review preview tests |

These are synthetic software checks. They establish behavior for supported normalized inputs, not native provider compatibility, account connectivity, or physical measurement accuracy.

## Gate before a real household pilot

1. Obtain a consented, de-identified provider export and its corresponding bill. Confirm commodity, meter, service dates, actual versus estimated readings and units. Reconcile quantities at source precision, with every discrepancy explained.
2. Test repeat downloads and an actual provider correction. Preserve stable identity across file names and nicknames. Document fields the native format lacks instead of guessing them.
3. Resolve local billing months and cross-month intervals. The current UTC-month archive holds boundary-crossing days; it cannot certify a fully reconciled local monthly bill.
4. Reconcile archive and journal activity before offering one dashboard total. Test shared homes, home EV energy and off-home charging without duplication.
5. Verify account consent/revocation, deletion and secured persistence before live connections. Test phone collection and permissions on physical devices before promising automatic journey coverage.

## Business claims supported by this work

Demonstrate reviewed normalized imports, reproducible estimates, correction history and explicit coverage gaps. Do not present researched providers as live connections, software test counts as an accuracy percentage, or hypothetical rewards as issued value. A credible pilot result is a source-reconciled household period with an understandable audit trail; provider expansion follows that evidence.
