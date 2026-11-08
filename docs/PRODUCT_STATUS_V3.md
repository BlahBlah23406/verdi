# Verdi product status — 2026-11-08

## Capsule audit

The exact requested capsule was found on code-47 at `/home/ubuntu/.agent-comms/capsules/verdi-20261108_capsule-91fc43f9d941.json`. It originated from R2-D2 on Providence. Its implementation was available in GitHub repository `BlahBlah23406/verdi` at `8b3ddbf`.

The Mac's `/Users/shaya/verdi` was an older version and was not modified. All work here continues from the newer repository in this output workspace. Nothing has been pushed or deployed to the public site.

Baseline code had simulated adapters reporting connected, hard-coded institutional organizations, a client-side demo data toggle, and no shared account backend. We executed 25 Flutter tests successfully, rather than relying on the capsule's report of 29. Existing demo video was referenced by the capsule but not included in the repository; this task does not claim to have reviewed that video.

## Business alignment

The supplied business plan describes incentives, automated contributions, institutional data/reporting, and financial-institution distribution. The update centers those product loops. It does not present Verdi as a generic personal calculator. The first operational scope remains commuting and electricity because broader product, flight and waste models need validation.

The original pitch deck's four revenue streams and proposed $600,000/20% equity ask remain in the updated deck as proposals. Unverified patents, exclusive bank contracts, accuracy multipliers, tax deductibility guarantees and guaranteed investor returns were removed. Original financial forecasts contain inconsistent tables and loan/equity wording; no replacement forecasts or traction figures were invented.

## Implemented in this branch

- Separate Flutter consumer, institution, synthetic-consumer and synthetic-institution entry points.
- SQLite account, connection, evidence, transaction, reward, pledge and audit state.
- Idempotent normalized ingestion and review, matching-period pilot reward rule, serialized redemption and capped integer-cent round-ups.
- Shared consumer/institution reports with organization authorization, sharing consent and basic cohort suppression.
- Real Plaid sync adapter for a preauthorized pilot account, with cursor/pagination and pending/reversal handling.
- Server-only Ollama Cloud explanation of computed scenarios, with timeout/failure fallback and no model authority over money or points.
- Conservative reconciliation fixes and preservation of evidence provenance after confirmation.
- Responsive Flutter screens and browser-verified synthetic demo.
- Editable 13-slide VC product deck plus PDF, preserving original cover photography and logo.

## Still required

Live credentials and provider onboarding; consumer OAuth/Link; robust hosted identity and encrypted token management; utility/transit/IoT partner integrations; verified imported baselines; bank settlement, charitable disbursement and reward fulfillment; corrections/reversals to awarded points; lifecycle models for other categories; native phone-signal upload; field accuracy/battery testing; real-user pilot, willingness-to-pay and incentive economics.

The live app can accept administrator-provisioned accounts, source-consented normalized evidence and utility CSVs. It is a runnable pilot foundation. It is not ready for an unsupervised nationwide consumer launch. US reach currently means national operational factors with explicit coverage boundaries, not guaranteed access to every US utility, bank or transit agency.
