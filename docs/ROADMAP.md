# From business plan to pilot

## First slice — implemented

- Flutter project with Android, iOS and web runners.
- Manual activity entry, dates, validation and deletion.
- Device-local persistence and monthly category breakdown.
- Pure Dart estimation engine with versioned demo factors.
- Travel alternative comparison and explicitly hypothetical reward preview.
- Algorithm, persistence and widget-flow tests.

## Next: make the estimates useful

Choose one pilot region and one primary use case, such as personal commuting. Validate emission factors and boundaries with a domain expert. Add onboarding, user settings, units/currency, edit/export, and a meaningful baseline with coverage indicators. Test the experience with a small group of users before automating collection.

## Then: trusted accounts and integrations

Introduce authentication, a backend database, consent, account deletion and secure data handling. Add one data source at a time: travel import or utility data first, banking later if it proves necessary. Keep provenance and reconcile overlapping sources. Background sensor tracking requires explicit permissions, battery testing and platform-specific implementation.

## Then: real incentives and offsets

Define a sustainable reward budget and partner agreements. Implement verified reduction eligibility and a server-owned ledger. Evaluate offset providers and track project verification and retirement evidence. Add payments only after these workflows are defined. Keep gross emissions, estimated reductions and retired offsets separate.

## Later business scope

Business dashboards, subscriptions, partner reporting and aggregated organizational analytics follow validation of the consumer experience. The plan's financial projections, patents, partnership and accuracy claims are business assumptions, not implemented product capabilities.

## Development

`flutter analyze` and `flutter test` check the app. `flutter build web` creates a browser release; Android/iOS releases also require installed native toolchains and signing configuration. The current factors and rewards must remain labeled as demo until validated replacements are shipped.
