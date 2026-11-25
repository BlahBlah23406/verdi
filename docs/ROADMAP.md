# From business plan to pilot

Maps the business plan to implemented foundations and future product milestones.

## First slice — implemented

- Flutter project with Android, iOS and web runners.
- Foreground phone trip detection on Android/iOS, consent and OS permission handling.
- Daily utility CSV import, persistent review queue, duplicate/overlap checks and source metadata.
- Manual activity entry as a fallback, dates, validation and deletion.
- Device-local persistence and monthly category breakdown.
- Pure Dart estimation engine with versioned EPA factors for a US commuting/electricity pilot.
- Travel alternative comparison and explicitly hypothetical reward preview.
- Algorithm, persistence and widget-flow tests.

## Next: make the estimates useful

The initial pilot is US commuting and home electricity; the next geographic focus is Redmond, then greater Seattle, then Washington. Follow the [provider-by-provider connection gates](CONNECTIONS_WASHINGTON.md) and [broader accounting plan](FOOTPRINT_ACCOUNTING_PLAN.md): start with a reconciled PSE month and confirmed journeys, add reviewed local factors and vehicle settings, then purchases and other missing sectors. Independently review factors and accounting boundaries with a domain expert. Add onboarding, user settings, units/currency, edit/export, and a meaningful baseline with coverage indicators. Validate the automatic collection on physical devices before a user pilot; see [acceptance checks](AUTOMATIC_TRACKING.md).

## Then: trusted accounts and integrations

The experimental archive has a read-only evidence history screen and a tested, pure [reviewed utility adapter](EVIDENCE_ARCHIVE.md#reviewed-utility-adapter) that turns normalized readings into revisions with scoped pseudonymous identities, explicit UTC intervals, factor snapshots and replay/correction/withdrawal checks. The app now exposes a normalized-electricity review and preview flow with durable meter pseudonyms, Pacific service-day resolution, reviewer records and guarded saves. Predecessor validation runs inside the archive write queue, and changed meter state invalidates a preview. Keep this path separate from dashboard totals until reconciliation and attribution against the journal are tested. Follow the [core acceptance gates](CORE_ACCEPTANCE.md) before calling a household pilot ready. Relationship approval, real consented provider samples and billing/interval reconciliation remain separate rollout gates.

Introduce authentication, a backend database, connected-account consent, account deletion and secure data handling. Replace normalized file imports with a selected utility provider connection; then integrate banking/travel data according to provider capabilities. Keep provenance and reconcile overlapping sources. Background sensor tracking requires explicit permissions, battery testing and platform-specific implementation.

## Then: real incentives and offsets

Define a sustainable reward budget and partner agreements. Implement verified reduction eligibility and a server-owned ledger. Evaluate offset providers and track project verification and retirement evidence. Add payments only after these workflows are defined. Keep gross emissions, estimated reductions and retired offsets separate.

## Later business scope

Business dashboards, subscriptions, partner reporting and aggregated organizational analytics follow validation of the consumer experience. The plan's financial projections, patents, partnership and accuracy claims are business assumptions, not implemented product capabilities.

## Development

`flutter analyze` and `flutter test` check the app. `flutter build web` creates a browser release; Android/iOS releases also require installed native toolchains and signing configuration. Published factors are average estimates; rewards remain a demo until eligibility and verification are implemented.
