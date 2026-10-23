# Verdi 🌱

I'm building Verdi to automatically turn everyday activity into a clearer picture of personal carbon emissions—and help people reduce them.

**Automatic tracking is the core product:** with the user's permission, phone signals and consumer data should identify journeys, electricity use and other activities, reconcile overlapping evidence, and feed a transparent emissions engine. Manual logging is a fallback.

## What works in this prototype

- **Phone trip detection:** Android and iOS location streams, explicit permission, distance calculation, quality filtering and journey segmentation while the app is open.
- **Review queue:** detected journeys are saved as summaries. Users confirm transport mode before an estimate enters their footprint. Raw coordinates are not saved or uploaded.
- **Consumer-data import:** choose a normalized utility CSV; daily electricity readings become reviewable estimates automatically. This is an import, not a live utility-account connection.
- **Duplicate checks:** repeated utility record IDs are skipped; conflicting records within a file are rejected. Overlapping logged activity must be resolved before confirmation.
- **Personal footprint:** local saving, monthly category totals, calculation provenance, basic category-based guidance and travel comparisons.
- **Rewards preview:** hypothetical eco-points; no redeemable balance or cash rewards yet.

**Implemented does not mean device-validated:** the native location code has compile/type checks, but permissions, GPS behavior, battery use and end-to-end tracking still need real-device testing. Tracking stops when the app leaves the foreground; always-on background tracking is not implemented.

Live banking, smart-home and travel-account connections, automatic transport-mode classification, real offsets, and reward redemption remain to be built. They need provider integrations, a backend and verification rules. We do not infer accurate purchase emissions from transaction amounts alone.

## Try automatic tracking

1. Run the app on an Android or iOS device and open **Auto track**.
2. Tap **Enable phone tracking**, read the consent notice and allow precise location.
3. Keep Verdi open during the journey. A segment of at least 100 metres and 60 seconds is queued after two minutes stationary, a location gap, or stopping tracking.
4. Review the detected distance and choose the actual mode. Discard walking, unsupported modes or incorrect detections.
5. Confirm to add the estimate to your journal and monthly footprint.

The detector uses timestamped coordinates and accuracy, not a trained model. It cannot reliably distinguish car, bus, train or cycling from speed alone. Segmentation thresholds are initial engineering assumptions that need field calibration. Interrupted segments are labeled partial; no distance is filled in across missing data.

## Import utility readings

Under **Auto track**, enter a consistent utility-account nickname and choose a CSV with this exact format:

```csv
record_id,date,kwh
reading-001,2026-01-01,12.5
reading-002,2026-01-02,10.2
```

Use daily consumption (not cumulative meter readings), stable provider record IDs, ISO dates and positive kWh. Normalize your provider's export to these columns first. The importer accepts up to 1,000 rows / 1 MB and rejects the entire file if validation fails. Quoted CSV fields are not supported. Reusing the nickname and IDs prevents reimporting accepted, queued or discarded records. Account nicknames distinguish accounts; they are not credentials.

Review each reading before confirmation. Electricity is assigned to the reading's calendar day using the current US-average factor. Monthly bills, live utility polling, regional grids and provider-specific formats are not yet supported.

## How our algorithm works

Verdi uses a rule-based ingestion and calculation pipeline. Phone location and imported readings produce candidates; only reviewed activities enter the footprint. It does not currently use machine learning.

1. **Collect and review evidence.** Detect a phone journey, import a utility reading, or enter an activity manually. Confirm its type, quantity and date. Check duplicates before accepting it.
2. **Select the matching factor.** The US pilot supports passenger cars, buses, commuter rail, electricity, and unassisted cycling.
3. **Calculate emissions.** Multiply the quantity by the activity's emission factor:

   ```text
   estimated emissions (kg CO₂e) = quantity × emission factor
   ```

   CO₂e means carbon dioxide equivalent: a common unit for comparing greenhouse gases.

4. **Keep the calculation traceable.** Each entry saves the factor value, version, source and assumptions used. Future factor updates do not silently rewrite previous entries. Tap an entry to inspect its calculation.
5. **Build the monthly picture.** Select entries within the current calendar month, ignore duplicate IDs, and sum emissions by category. Old demo entries remain in the journal but are excluded from pilot totals.

### Where the factors come from

The catalog is pinned to the [EPA's January 2025 Emission Factors Hub](https://www.epa.gov/system/files/documents/2025-01/ghg-emission-factors-hub-2025.pdf): travel from Table 10, electricity from Table 6, and global warming potentials from Table 11. Electricity uses the US average based on eGRID 2023 data.

The engine converts CO₂, methane and nitrous oxide into CO₂e using 100-year global warming potentials of 1, 28 and 265 respectively. It then normalizes the source units to kg CO₂e per kilometre or kWh. Cycling's zero factor is our operational-emissions assumption, not an EPA lifecycle estimate.

### Example: comparing a 20 km commute

Using the current catalog, rounded for display:

| Choice | Factor | Estimated emissions |
| --- | ---: | ---: |
| Solo passenger car | 0.18552 kg CO₂e/km | 3.71 kg CO₂e |
| Commuter rail | 0.08325 kg CO₂e/passenger-km | 1.67 kg CO₂e |

```text
potential reduction = distance × (car factor − alternative factor)
                    ≈ 2.05 kg CO₂e for this journey

preview eco-points = floor(unrounded potential reduction × 10)
                   = 20 points
```

The app calculates with full precision and rounds only for display. This comparison is hypothetical: it does not prove an actual emissions reduction, add an activity, or issue redeemable points.

### What these estimates cover

- Travel estimates cover operations, assuming one occupant for a car. Bus and commuter rail factors are already per passenger.
- Electricity uses a national fallback, not the user's utility mix, and excludes transmission losses.
- Manufacturing, upstream fuel production, and cycling-related food are outside the current calculation boundaries.
- Totals cover only logged activities. Missing entries do not mean zero emissions, and overlap checks help flag possible duplicates but are not full cross-provider reconciliation.
- Food, shopping, and waste are not available for new pilot entries until suitable factors are implemented. Rewards remain a demo.

The calculation engine lives in [carbon.dart](lib/domain/carbon.dart), with the versioned catalog in [emission_factors.dart](lib/domain/emission_factors.dart). See [the algorithm notes](docs/ALGORITHM.md) for conversion formulas and remaining validation work.

## Run locally

```sh
flutter pub get
flutter run -d chrome
```

For phone tracking, use `flutter devices` and `flutter run -d <device-id>` on a configured Android/iOS device. Web supports the dashboard and file imports, but not native phone tracking.

```sh
flutter analyze
flutter test
dart run tool/check_automation.dart
```

See [the build roadmap](docs/ROADMAP.md), [algorithm notes](docs/ALGORITHM.md), and [automatic tracking implementation and device checks](docs/AUTOMATIC_TRACKING.md).
