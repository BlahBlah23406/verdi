# Verdi 🌱

Automated, multi-source carbon tracking with unprecedented granularity — and incentives for reducing your footprint.

Verdi harnesses everyday sensors, on-device metrics, and third-party user data to build a detailed, down-to-user picture of personal carbon emissions. Instead of asking people to manually log every activity, Verdi correlates data from multiple sources — phone GPS, utility readings, purchase history, flight data, and waste streams — into one transparent, traceable emissions engine.

## The Carton vision

**1. Automated tracking.** Consented phone signals and consumer data sources identify journeys, electricity use, purchases, flights, and waste — then reconcile overlapping evidence into activity candidates. Manual logging is a fallback, not the primary flow.

**2. Precision wide-scale tracking on multiple fronts.** Verdi does not stop at car trips and electricity. It tracks product emissions, travel emissions (including flights), waste emissions, and home energy — all correlated into a single footprint.

**3. Unprecedented carbon data granularity.** Detailed down-to-user metrics unveil individual-level emission sources. Every activity stores its factor, version, source, and assumptions — fully auditable, no black boxes.

**4. Incentive system.** Verdi correlates data from various sources to track and reward users for decreasing their carbon footprint. Earn eco-points for month-over-month reductions. Rewards are preview-only in the current prototype; a verified reward ledger requires a backend and trusted baselines.

## What's implemented vs what's on the roadmap

| Feature | Status |
| --- | --- |
| Phone GPS trip detection (foreground) | ✅ Implemented |
| Utility CSV import (electricity) | ✅ Implemented |
| Manual activity logging | ✅ Implemented |
| EPA-sourced emission factors (travel, electricity) | ✅ Implemented |
| Regional electricity factors (eGRID 2023) | ✅ Implemented |
| Monthly breakdown and travel comparison | ✅ Implemented |
| Demo mode with sample data | ✅ Implemented |
| Rewards / incentive preview (rule-based) | ✅ Implemented |
| Multi-front data source interfaces (purchase, flight, waste) | ✅ Scaffolded (stubs) |
| Extended emission factors (flights, products, waste) | ✅ Placeholder factors |
| Live utility provider connections | 🔜 Roadmap (Phase 3) |
| Purchase / banking data integration | 🔜 Roadmap (Phase 3) |
| Flight history integration | 🔜 Roadmap (Phase 3) |
| Waste tracking integration | 🔜 Roadmap (Phase 3) |
| Background sensor tracking | 🔜 Roadmap (Phase 3) |
| Verified reward ledger and redemption | 🔜 Roadmap (Phase 4) |
| Business dashboards and partner reporting | 🔜 Roadmap (Phase 5) |

## From everyday data to an estimate

```text
Consented phone signals + consumer data sources
                  ↓
       Validate and filter evidence
                  ↓
       Detect activity candidates
                  ↓
       Check duplicates and review
                  ↓
       Apply a sourced emission factor
                  ↓
       Explain impact, alternatives, and rewards
```

**Phone signals:** timestamped location samples provide a starting point for detecting journeys. The current detector filters inaccurate fixes and implausible jumps, estimates distance, and separates segments at stops or signal gaps. Transport mode still needs user confirmation.

**Consumer data:** daily electricity readings are the first import path. The data source interface (`DataSource` pattern) is designed to accommodate purchase, flight, and waste data alongside utility readings — stubs are in place for each.

**Review and traceability:** only confirmed candidates enter the footprint. Each activity's data source and calculation assumptions are preserved. Missing evidence is treated as a coverage gap, not proof of zero emissions.

**Incentives:** the `IncentiveService` compares month-over-month emissions and awards preview eco-points (10 points per kg of reduction). This is rule-based and local — no backend needed yet.

## How our algorithm works

Verdi uses a rule-based ingestion and calculation pipeline. Phone location and imported readings produce candidates; only reviewed activities enter the footprint. It does not currently use machine learning.

1. **Collect and review evidence.** Detect a phone journey, import a utility reading, or enter an activity manually. Confirm its type, quantity and date. Check duplicates before accepting it.
2. **Select the matching factor.** The US pilot supports passenger cars, buses, commuter rail, electricity, and unassisted cycling. Extended placeholder factors cover flights, products, and waste.
3. **Calculate emissions.** Multiply the quantity by the activity's emission factor:

   ```text
   estimated emissions (kg CO₂e) = quantity × emission factor
   ```

   CO₂e means carbon dioxide equivalent: a common unit for comparing greenhouse gases.

4. **Keep the calculation traceable.** Each entry saves the factor value, version, source and assumptions used. Future factor updates do not silently rewrite previous entries.
5. **Build the monthly picture.** Select entries within the current calendar month, ignore duplicate IDs, and sum emissions by category.
6. **Compute rewards.** Compare this month's total to last month's. If emissions dropped, award eco-points proportional to the reduction.

### Where the factors come from

The core catalog is pinned to the [EPA's January 2025 Emission Factors Hub](https://www.epa.gov/system/files/documents/2025-01/ghg-emission-factors-hub-2025.pdf): travel from Table 10, electricity from Table 6, and global warming potentials from Table 11.

Extended factors for the Carton multi-front vision are research-sourced placeholders:
- **Flights:** UK DEFRA 2024 conversion factors (short-haul and long-haul economy).
- **Products:** EPA EIO-LCA-based estimate (~0.35 kg CO₂e/USD).
- **Waste:** EPA WARM model mixed MSW landfill factor.

These placeholders carry higher uncertainty and need category-specific refinement before pilot use.

### Example: comparing a 20 km commute

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

### What these estimates cover

- Travel estimates cover operations, assuming one occupant for a car. Bus and commuter rail factors are already per passenger.
- Electricity uses a national fallback or selected regional factor, and excludes transmission losses.
- Extended factors (flights, products, waste) are placeholders with higher uncertainty.
- Manufacturing, upstream fuel production, and cycling-related food are outside the current calculation boundaries.
- Totals cover only logged activities. Missing entries do not mean zero emissions.
- Rewards remain a preview — no points are redeemable or transferable yet.

The calculation engine lives in [carbon.dart](lib/domain/carbon.dart), with the versioned catalog in [emission_factors.dart](lib/domain/emission_factors.dart), the data source pattern in [data_source.dart](lib/domain/data_source.dart), and the incentive system in [incentive_service.dart](lib/domain/incentive_service.dart).

## Project notes

- [Public demo and deployment](DEPLOYMENT.md) — landing page and browser app on GitHub Pages
- [11-slide pitch deck](docs/PITCH_DECK.html) ([Markdown source](docs/PITCH_DECK.md))
- [Founder demo script](docs/FOUNDER_DEMO_SCRIPT.md)
- [Action-item progress](PROGRESS.md) and [prepared delivery materials](DELIVERY.md)

- [Algorithm details](docs/ALGORITHM.md)
- [Automatic tracking design and remaining validation](docs/AUTOMATIC_TRACKING.md)
- [Build roadmap](docs/ROADMAP.md)
- [File overview](docs/FILES.md)

## Development

```sh
flutter pub get
flutter analyze
flutter test
flutter build web
```

Published factors are average estimates; rewards remain a preview until eligibility and verification are implemented.
