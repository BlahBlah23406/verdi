# Verdi 🌱

Introduces Verdi, its automatic tracking algorithm, and the current development focus.

I'm building Verdi to automatically turn everyday activity into a clearer picture of personal carbon emissions—and help people reduce them.

**Automatic tracking is the core product:** with the user's permission, phone signals and consumer data should identify journeys, electricity use and other activities, reconcile overlapping evidence, and feed a transparent emissions engine. Manual logging is a fallback.

## Current focus: prepping for DubHacks Next

Verdi is in development, not a released app. I'm working on the Flutter implementation and the algorithm that connects phone activity and consumer data to explainable emissions estimates. The code has initial checks, but the complete app still needs device testing and validation.

The current implementation explores foreground phone trip detection, utility-data imports, activity review, duplicate checks, and carbon calculations. Always-on background tracking, live banking and utility connections, automatic transport-mode classification, real offsets, and redeemable rewards are future work.

## From everyday data to an estimate

```text
Consented phone signals + consumer data
                  ↓
       Validate and filter evidence
                  ↓
       Detect activity candidates
                  ↓
       Check duplicates and review
                  ↓
       Apply a sourced emission factor
                  ↓
       Explain impact and alternatives
```

**Phone signals:** timestamped location samples provide a starting point for detecting journeys. The current detector filters inaccurate fixes and implausible jumps, estimates distance, and separates segments at stops or signal gaps. It requires at least 100 metres and 60 seconds for a candidate. These thresholds need field calibration. Transport mode still needs confirmation because speed alone cannot reliably distinguish a car, bus, train or bicycle.

**Consumer data:** daily electricity readings are the first import path. The algorithm validates dates and kWh quantities, associates records with an account and stable record ID, and checks for duplicates before creating activity candidates. Live provider connections are part of the longer-term vision; the current code works with normalized utility files.

**Review and traceability:** only confirmed candidates enter the footprint. The current implementation stores trip summaries rather than raw coordinates, and preserves each activity's data source and calculation assumptions. Missing evidence is treated as a coverage gap, not proof of zero emissions.

## How our algorithm works

Verdi uses a rule-based ingestion and calculation pipeline. Phone location and imported readings produce candidates; only reviewed activities enter the footprint. It does not currently use machine learning.

1. **Collect and review evidence.** Detect a phone journey, import a utility reading, or enter an activity manually. Confirm its type, quantity and date. Check duplicates before accepting it.
2. **Select the matching factor.** The US pilot supports passenger cars, buses, commuter rail, electricity, and unassisted cycling.
3. **Calculate emissions.** Multiply the quantity by the activity's emission factor:

   ```text
   estimated emissions (kg CO₂e) = quantity × emission factor
   ```

   CO₂e means carbon dioxide equivalent: a common unit for comparing greenhouse gases.

4. **Keep the calculation traceable.** Each entry saves the factor value, version, source and assumptions used. Future factor updates do not silently rewrite previous entries. This makes previous estimates explainable and reproducible.
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

## Project notes

- [Algorithm details](docs/ALGORITHM.md)
- [Automatic tracking design and remaining validation](docs/AUTOMATIC_TRACKING.md)
- [Build roadmap](docs/ROADMAP.md)
- [File overview](docs/FILES.md)
