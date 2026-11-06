# Verdi pitch deck

11 slides. Repository-grounded prototype pitch, prepared 2026-11-06.
Present `PITCH_DECK.html` in a browser; use its navigation or arrow keys. Print to PDF for one slide per page. These slides distinguish shipped prototype behavior from business hypotheses and roadmap work. No customer, revenue, funding, market-size, partnership or founder-biography claims are established by the repository.

## Slide 1 — Verdi

**Everyday choices. A clearer footprint.**

- Personal carbon tracking and reduction prototype.
- Everyday travel and electricity data, translated into traceable estimates.
- Working Flutter foundation for the broader multi-source vision.

Speaker note: Open with what the prototype can demonstrate today. The repository also calls the broader business vision “Carton”; Verdi is the app name used here.

Evidence: `README.md`, `pubspec.yaml`, `lib/main.dart`.

## Slide 2 — The problem we are addressing

**A footprint needs more than a number.**

- Manually logging every activity creates work for the user.
- Travel, home energy and other consumption evidence arrive from different sources.
- An estimate is more useful when its source, assumptions and coverage are visible.

Speaker note: This is the problem framing in the repository, not a quantified market study or a validated customer finding. The opportunity is to reduce logging burden while preserving review and traceability.

Evidence: `README.md`, `docs/AUTOMATIC_TRACKING.md`.

## Slide 3 — The product approach

**Collect → review → calculate → explain.**

- Detect phone journeys on native mobile or import daily electricity readings.
- Review candidates and check duplicate or overlapping evidence before confirmation.
- Preserve the emission factor, version, source and assumptions with each activity.
- Show a monthly picture and explore alternatives.

Speaker note: This is a rule-based pipeline, not a machine-learning system. Browser phone GPS is not implemented; show CSV review in the public web demo.

Evidence: `lib/domain/automation.dart`, `lib/domain/carbon.dart`, `docs/ALGORITHM.md`.

## Slide 4 — What works today

**A working prototype with a focused US pilot scope.**

- Manual entries, local persistence, onboarding and settings.
- Monthly travel and home breakdown; per-activity calculation details.
- Utility CSV import, persistent review queue and overlap checks.
- Travel alternatives, sample demo data and hypothetical eco-points.

Speaker note: Foreground Android/iOS phone tracking is implemented but physical-device behavior still needs validation. Data is saved locally; there is no connected-account backend.

Evidence: `lib/main.dart`, `lib/features/automation_screen.dart`, `lib/data/`, `docs/VALIDATION.md`.

## Slide 5 — A concrete reduction comparison

**Compare a 20 km solo car journey with commuter rail.**

- Car: approximately 3.71 kg CO₂e.
- Commuter rail: approximately 1.67 kg CO₂e.
- Potential difference: approximately 2.05 kg CO₂e.
- Preview rule: 20 eco-points; no redemption or verified reward claim.

Speaker note: Figures use the repository's EPA 2025 operational averages and rounding. These are attributed-emissions comparisons, not measured reductions. The UI may display one decimal place. Lifecycle manufacturing and upstream fuel are outside the current boundary.

Evidence: `README.md` commute example, `lib/domain/emission_factors.dart`, `lib/main.dart` Reduce view.

## Slide 6 — Trust through traceability

**Show the calculation behind the estimate.**

- Quantity × emission factor = estimated kg CO₂e.
- Core travel/electricity factors reference EPA 2025; regional electricity uses eGRID 2023.
- Historical entries retain their saved factor and metadata.
- Missing evidence is a coverage gap, not proof of zero emissions.

Speaker note: Flights, product purchases and waste use placeholder factors and should not be presented as validated pilot categories. Average factors do not establish individual measurement accuracy.

Evidence: `docs/ALGORITHM.md`, `lib/domain/emission_factors.dart`, `lib/domain/regional_factors.dart`, `lib/domain/carbon.dart`.

## Slide 7 — The multi-source vision

**Connect more evidence without losing the paper trail.**

- Today: phone journey detection on native mobile, utility CSV and manual entry.
- Scaffolded: purchase, flight and waste data source interfaces.
- Planned: live providers, connected-account consent and cross-source reconciliation.
- Planned: background sensing after platform, permission and battery validation.

Speaker note: The planned integrations are not connected services today. Avoid implying bank, airline, utility or municipal partnerships exist.

Evidence: `lib/domain/data_source.dart`, `docs/ROADMAP.md` Phase 3.

## Slide 8 — Business direction to validate

**Prove consumer usefulness before expanding the business scope.**

- Current focus: a consumer commuting and electricity experience.
- Roadmap possibilities: subscriptions and business dashboards.
- Potential partner reporting and organizational analytics follow consumer validation.
- Reward economics require a sustainable budget and partner agreements.

Speaker note: These are directions in the repository roadmap, not a launched business model. Pricing, market size, willingness to pay and acquisition economics are not established in the repo.

Evidence: `docs/ROADMAP.md` Phases 4–5, `docs/DEMO_GUIDE.md`.

## Slide 9 — Technical foundation and proof

**A demonstrable product, with explicit validation boundaries.**

- Flutter runners for web, Android and iOS; pure Dart estimation logic.
- Shared preferences for local data; file picker for imports.
- Existing algorithm, automation, persistence and widget-flow checks.
- Remaining: physical-device tracking, factor review and real user-pilot validation.

Speaker note: Tests support implementation correctness; they do not establish real-world accuracy, adoption or traction. Consult PROGRESS.md for the checks executed for this release. No user or revenue metrics are supplied.

Evidence: `pubspec.yaml`, `test/`, `tool/check_algorithm.dart`, `tool/check_automation.dart`, `docs/VALIDATION.md`.

## Slide 10 — Milestones ahead

**Useful estimates → trusted accounts → verified incentives.**

- Next: validate collection on devices, refine factors, establish coverage and baselines, run a user pilot.
- Then: authentication, backend, secure consent and provider connections.
- Then: server-owned reward ledger and verified reduction eligibility.
- Later: subscriptions, dashboards and partner reporting.

Speaker note: This sequencing comes from the roadmap. Some early-roadmap features such as onboarding and regional settings already exist in code; these are not presented as future work. Dates, staffing and budgets are not committed.

Evidence: `docs/ROADMAP.md`, `lib/features/onboarding_screen.dart`, `lib/domain/regional_factors.dart`.

## Slide 11 — See the foundation. Test the next assumptions.

**Explore the prototype and review the path to a pilot.**

- Public demo: https://blahblah23406.github.io/verdi/
- Walk through logging, calculation provenance, travel comparison and CSV review.
- Next discussion: device validation, factor review, pilot coverage and incentive feasibility.
- Funding amount, terms and financial projections are not specified in the repository.

Speaker note: Invite feedback on the demonstrated workflow and planned validation. Do not imply a funding round or commitments. Use docs/FOUNDER_DEMO_SCRIPT.md for the live walkthrough.

Evidence: `docs/ROADMAP.md`, `docs/FOUNDER_DEMO_SCRIPT.md`, `DEPLOYMENT.md`.
