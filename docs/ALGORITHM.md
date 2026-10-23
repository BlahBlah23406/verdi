# US pilot calculation engine

Documents emission formulas, factor sources, calculation boundaries, and remaining validation.

The pilot covers commuting and home electricity. New entries use a pinned, source-backed catalog. This is a first implementation against published tables, not independent scientific validation or certification.

## Reference and conversion

Source: [EPA January 2025 Emission Factors Hub](https://www.epa.gov/system/files/documents/2025-01/ghg-emission-factors-hub-2025.pdf), retrieved October 23, 2026. Version: `us-epa-2025-v1`.

| Table / row | CO₂ | CH₄ | N₂O | Source units |
| --- | ---: | ---: | ---: | --- |
| 10 / Passenger car | .297 | .0059 | .0053 | kg CO₂, g CH₄/N₂O per vehicle-mile |
| 10 / Bus | .066 | .0046 | .0019 | kg CO₂, g CH₄/N₂O per passenger-mile |
| 10 / Commuter rail | .133 | .0105 | .0026 | kg CO₂, g CH₄/N₂O per passenger-mile |
| 6 / US average electricity | 771.5 | .057 | .008 | lb gas / MWh |

Table 11 uses AR5 100-year GWPs: CH₄=28, N₂O=265. Travel: `(CO₂ + CH₄×28/1000 + N₂O×265/1000) / 1.609344`. Electricity: `(CO₂ + CH₄×28 + N₂O×265) × 0.45359237/1000`.

Electricity is a national fallback using eGRID 2023, excludes transmission losses, and is not a utility-specific estimate. Travel is operational, excludes upstream fuel and manufacturing; car assumes one occupant. Bus/rail are per passenger. Bicycle zero is Verdi's operational boundary assumption, not an EPA factor or a lifecycle claim.

## Product behavior

`emissions = quantity × factor`. Distance is entered in km; electricity in kWh. Tap a journal entry to inspect the source and calculation. The entry snapshots its factor, version, source, scope, geography and date, preserving historical values across future catalog changes.

Old demo records remain readable and deletable, with their original values. The pilot overview excludes them. Food, shopping and waste have no reviewed pilot factors and cannot be newly logged; the engine rejects requests for those factors rather than returning zero. Earlier experiments remain visible as legacy entries.

Period queries use local calendar boundaries [start, end) and deduplicate exact IDs. Different IDs for the same event are not detected yet. Manual logs and foreground phone collection can omit activities, so totals represent confirmed coverage only. Automatic ingestion and review are documented in [Automatic tracking](AUTOMATIC_TRACKING.md).

Travel comparisons subtract attributed average emissions for the same distance. They are hypothetical; they do not prove a marginal reduction. The reward preview remains `floor(potential reduction × 10)`, with no issued balance or monetary value. No offsets are deducted from gross emissions.

## Remaining validation

Select a more specific pilot area and add utility/grid-region selection, car type and occupancy. Independently review reference transcription and boundaries. Quantify uncertainty where supported; no confidence interval is currently claimed. Pinned publication dates are explicit, and factors are not automatically described as the latest dataset. Add consistent coverage and baseline rules before calculating observed reductions or issuing rewards.

Activities use device-local JSON in shared preferences. There is no cloud backup or encryption layer. Corrupt saved data blocks edits to avoid overwriting it.
