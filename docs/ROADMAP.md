# From business plan to pilot

Maps the Carton business plan to implemented foundations and future product milestones.

## Phase 1 — Pilot (implemented)

- Flutter project with Android, iOS and web runners.
- Foreground phone trip detection on Android/iOS, consent and OS permission handling.
- Daily utility CSV import, persistent review queue, duplicate/overlap checks and source metadata.
- Manual activity entry as a fallback, dates, validation and deletion.
- Device-local persistence and monthly category breakdown.
- Pure Dart estimation engine with versioned EPA factors for a US commuting/electricity pilot.
- Regional electricity factors (eGRID 2023) for 4 US regions + national average.
- Travel alternative comparison and hypothetical reward preview.
- **Carton alignment:** automated tracking (phone GPS + utility CSV), initial emission factors, traceable calculations.
- Algorithm, persistence and widget-flow tests.

## Phase 2 — Useful estimates (next)

Narrow the geography, add regional electricity and vehicle settings, and independently review the EPA factor implementation with a domain expert. Add onboarding, user settings, units/currency, edit/export, and a meaningful baseline with coverage indicators. Validate the automatic collection on physical devices before a user pilot; see [acceptance checks](AUTOMATIC_TRACKING.md).

**Carton alignment:**
- Refine down-to-user granularity — per-activity source metadata, coverage indicators, baseline tracking.
- Begin correlating data from multiple sources for the same period (e.g., phone trip + utility reading on the same day).
- Add category-specific emission factors for products, food, and waste (replacing placeholders).
- Validate the incentive model with real month-over-month data.

## Phase 3 — Trusted accounts and integrations

Introduce authentication, a backend database, connected-account consent, account deletion and secure data handling. Replace normalized file imports with a selected utility provider connection; then integrate banking/travel data according to provider capabilities. Keep provenance and reconcile overlapping sources. Background sensor tracking requires explicit permissions, battery testing and platform-specific implementation.

**Carton alignment — this is where the multi-front vision scales:**
- **Purchase history:** connect banking data via Plaid or similar to automatically import transactions and map them to product emission categories.
- **Flight history:** integrate airline booking APIs or boarding-pass scanning to capture flight emissions automatically.
- **Waste tracking:** connect municipal waste-weighing data or smart-bin sensors to track landfill, recycling, and compost streams.
- **Utility connections:** replace CSV import with live utility provider OAuth connections.
- **Cross-source correlation:** reconcile overlapping evidence from multiple sources (e.g., a flight booked via banking data should match a flight in airline data).
- **Background tracking:** always-on sensor tracking with platform-specific battery optimisation.

## Phase 4 — Real incentives and offsets

Define a sustainable reward budget and partner agreements. Implement verified reduction eligibility and a server-owned ledger. Evaluate offset providers and track project verification and retirement evidence. Add payments only after these workflows are defined. Keep gross emissions, estimated reductions and retired offsets separate.

**Carton alignment — the incentive system becomes real:**
- Replace the preview `IncentiveService` with a server-owned reward ledger.
- Define verified reduction baselines (not just month-over-month comparisons).
- Partner with brands for redeemable rewards (discounts, carbon offsets, eco-products).
- Track reduction eligibility with evidence — verified commute changes, measured energy reductions, waste diversion.
- Separate gross emissions, estimated reductions, and retired offsets in the user-facing dashboard.
- Evaluate offset providers and track project verification and retirement evidence.

## Phase 5 — Business scope

Business dashboards, subscriptions, partner reporting and aggregated organizational analytics follow validation of the consumer experience. The plan's financial projections, patents, partnership and accuracy claims are business assumptions, not implemented product capabilities.

**Carton alignment:**
- **Business dashboards:** aggregated, anonymised emissions data for corporate ESG reporting.
- **Partner reporting:** carbon reduction metrics for employer-sponsored programs and utility company engagement tools.
- **Subscriptions:** premium features (advanced analytics, custom factors, team challenges).
- **Organisational analytics:** cohort-level insights, team competitions, departmental footprint tracking.
- **Data moat:** consented behavioural + consumption data enables personalised reduction recommendations and aggregate insights.

## Development

`flutter analyze` and `flutter test` check the app. `flutter build web` creates a browser release; Android/iOS releases also require installed native toolchains and signing configuration. Published factors are average estimates; rewards remain a preview until eligibility and verification are implemented.
