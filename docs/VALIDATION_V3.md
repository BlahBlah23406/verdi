# Validation — November 8, 2026

This supersedes earlier validation reports for the V3 branch. Executed locally on triskelion, beginning at repository commit `8b3ddbf` from capsule-91fc43f9d941.

| Check | Result |
| --- | --- |
| Baseline Flutter suite before edits | 25 tests passed |
| Final Flutter suite | 35 tests passed |
| `flutter analyze` | No issues found |
| Standalone Dart algorithm checks | 24 checks passed |
| Standalone Dart automation checks | 34 checks passed |
| SQLite/API platform suite | 18 tests passed |
| Plaid connector contract suite | 3 tests passed |
| Randomized round-up invariants | 2,000 deterministic cases inside platform suite |
| Concurrent redemption | 20 competing requests across 8 workers, balance remains nonnegative |
| Synthetic Flutter web release | Built successfully |
| Consumer/institution pilot web release | Both built successfully |
| Android debug demo APK | Built successfully, Android emulator API endpoint configured |
| iOS Simulator debug demo app | Built successfully in `/private/tmp/verdi-native-v3` |
| Browser walkthrough | Consumer loads SQLite state, claims 665 points, redeems 200, displays 465 balance; institution reads 20 consenting participants from the same database |
| Pitch deck | All 13 slides rendered and visually inspected; package integrity, geometry and font checks passed; PDF rendered and inspected |

## Important implementation regressions covered

Replay idempotency and conflicting source corrections; source consent before imports; disconnected sources preserve history; missing coverage cannot earn points; factor-method mismatches cannot earn points; same-source/unsupported-category/nested-meter reconciliation; stable source identity and provenance; integer-cent caps; duplicate redemption keys and concurrent overspending; server-side session identity; analyst role and organization boundaries; sharing withdrawal and minimum cohort suppression; AI timeout/failure fallback and minimizing its input; Plaid pagination, cursor errors, pending replacements, currencies and removals.

## Native environment limits

The initial iOS simulator packaging attempts under Documents failed because iCloud/File Provider added Finder metadata to framework directories. A clean build from `/private/tmp` succeeded. No Flutter SDK security settings were changed. This machine has the iOS SDK but lacks the current simulator runtime, so the app was compiled and packaged but not launched in an iOS simulator. Android built using the available SDK; plugin Kotlin migration warnings remain upstream. The APK permits HTTP only for emulator/loopback development hosts. Release deployments should use HTTPS.

No physical device install, GPS accuracy study, background capture test or battery test was performed. The final browser walkthrough also synchronized and confirmed a receipt, increasing the consumer total from 201.7 to 202.4 kg while preserving its reward balance.

The native GPS code remains in the earlier local-only entry point and needs integration with the new account backend.

## Integration limits

Plaid transport was protocol-tested with mocked provider responses. No live Plaid credentials/account were provided. Consumer Link/OAuth is not complete. Utility imports use actual CSV parsing, validation and review, while live utility, transit and IoT OAuth remain to build.

The Ollama API path was tested against mocked responses and failure cases. A key has been requested via a private configuration file, but no real credentialed call is yet recorded. This does not count as live AI validation. AI prose is advisory and cannot authorize rewards or modify ledger/calculation state.

## Product limits

Imported records are not independently provider-attested. Monthly estimated reductions are program rules, not causally verified reductions or carbon credits. Corrections/reversals to already-issued reward awards need a follow-up accounting design. Round-up pledges and redemptions are simulated, and no charitable receipts or tax deductions are asserted. Cohort suppression is basic privacy protection, not differential privacy. Authentication is administrator-provisioned pilot bearer sessions, not a nationwide signup system.

The existing GitHub Pages deployment was not changed. No PR, push, production deployment, payment, email or external message was made.
