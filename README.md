# Verdi 🌱

I'm building Verdi: an app to help people understand their carbon footprint and make lower-emission choices.

Right now, I'm working on the Flutter app and its first carbon-estimation algorithm. The prototype includes an activity journal, a monthly emissions breakdown, local saving, and a travel comparison with a rewards preview.

This is early development. The US pilot uses published EPA factors for commuting and electricity; rewards are a demo, and banking, automatic tracking, real offsets, and payments are planned.

## How our algorithm works

Verdi currently uses a transparent, rule-based calculation engine. It estimates the emissions associated with the activities you log; it does not yet automatically detect activities or use machine learning.

1. **Log an activity.** Enter a journey in kilometres or home electricity use in kWh, along with its date.
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
- Totals cover only logged activities. Missing entries do not mean zero emissions, and different IDs for the same real-world activity are not yet reconciled.
- Food, shopping, and waste are not available for new pilot entries until suitable factors are implemented. Rewards remain a demo.

The calculation engine lives in [carbon.dart](lib/domain/carbon.dart), with the versioned catalog in [emission_factors.dart](lib/domain/emission_factors.dart). See [the algorithm notes](docs/ALGORITHM.md) for conversion formulas and remaining validation work.

## Run locally

```sh
flutter pub get
flutter run -d chrome
```

The project also includes Android and iOS runners. Use `flutter devices` to select a configured device.

```sh
flutter analyze
flutter test
```

See [the build roadmap](docs/ROADMAP.md) and [algorithm notes](docs/ALGORITHM.md).
