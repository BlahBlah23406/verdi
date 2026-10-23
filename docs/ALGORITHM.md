# Carbon engine v0.1

The pure Dart engine lives in `lib/domain/carbon.dart`, independent of Flutter widgets and storage.

## Current calculation

`emissions (kg CO₂e) = quantity × factor (kg CO₂e / unit)`

Each manual entry stores an ID, activity type, quantity, date, note, factor value, and factor version. Historical results retain the factor originally used. Monthly reporting uses local calendar boundaries [month start, next month start), deduplicating exact IDs. An entry on the last day of the previous month is excluded. Different IDs for the same real-world activity are not yet detected.

| Activity | Unit | Illustrative factor |
| --- | --- | --- |
| Solo car journey | km | 0.20 |
| Bus journey | passenger km | 0.08 |
| Train journey | passenger km | 0.04 |
| Bicycle journey | km | 0.00 |
| Electricity | kWh | 0.30 |
| Food purchases | USD | 0.50 |
| Other purchases | USD | 0.35 |
| Landfill waste | kg | 0.60 |

**These are invented demo constants for product development, not figures extracted from an official dataset.** They are not suitable for carbon reporting, offset purchases, or verified reward issuance. Bicycle zero means zero in this simplified travel model, not zero lifecycle impact. Spend estimates are coarse placeholders; prices alone do not determine emissions. Users should log each activity once rather than both fuel spend and the corresponding journey.

Travel scenarios calculate `km × (car factor − alternative factor)`. Demo points equal `floor(potential reduction × 10)`. Scenarios are hypothetical and do not change the journal or create a redeemable balance. No offset is subtracted from gross emissions.

## Next algorithm work

1. Select pilot geography and accounting boundaries (direct vs lifecycle emissions).
2. Import reviewed, licensed factor records with source URL, publication year, geography, unit, scope and uncertainty. Candidate reference: [UK government 2026 conversion factors](https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2026). US electricity needs regional grid data, not a UK default.
3. Prefer measured quantities to spend proxies. Add travel mode/occupancy and electricity region. Do not combine factors with inconsistent boundaries.
4. Add import provenance and reconciliation of overlapping transactions, sensor trips and receipts. Never treat unmatched data as zero emissions.
5. Compare reductions only across comparable periods with sufficient coverage. Missing logs must not generate rewards.
6. Add server-side verification, fraud controls and an idempotent reward ledger before redeemable points.
7. Calibrate against independently calculated examples and document uncertainty before making accuracy claims.

## Storage

Activities are JSON in device-local shared preferences. Persistence follows the [Flutter key-value storage pattern](https://docs.flutter.dev/cookbook/persistence/key-value). This is suitable for this small prototype, not a financial ledger or durable cloud backup. Unreadable saved data blocks edits to avoid overwriting it. There is no login, sync, encryption layer or export yet. Clearing app/browser data removes entries.
