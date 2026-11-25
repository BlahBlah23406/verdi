# Validation

## Reviewed electricity flow and core audit — 2026-11-20 Pacific

- Resumed `capsule-7016c8935853` on `redmond-connections-accounting`; preserved all existing uncommitted work. Added **Auto track → Review into evidence archive**, reachable from the connections directory's electricity import route. Users can paste/select normalized CSV, reuse a pseudonymous meter, choose Pacific service dates, factor, quality, personal share and decision, preview and explicitly save. Journal/dashboard totals remain separate.
- Review batches record reviewer, reason, file-authorization acknowledgement, quality, factor and source revisions. Revisions and receipts now commit in one archive preferences write; meter registration is separate. Failed writes, rebuilt previews after restart, corrupt receipts, replay, correction and stale heads have regression tests. Evidence quality is explicitly asserted by the reviewer, never inferred from normalized CSV.
- Core audit fixed cross-period identity conflicts, incompatible accounting bases within canonical groups, tuple ordering, aliased containment, inverted supporting relationships, blocked evidence classification and invalid/overflowing pilot inputs.
- Final implementation helper `b21f2559` ran `flutter test --no-pub`: **110 tests passed**. This includes end-to-end widget review/save/reload/correction, failure/retry, concurrent changes and 360 px / 1.5× text layout checks. Earlier jobs `047f152d` and `21a7d293` built/audited the core; read-only integration review `074e8b5b` identified the quality and split-write issues fixed by the final helper. Coordinator read every report and reviewed the changed source and regression assertions.
- Coordinator independently ran `flutter analyze --no-pub`: **no issues**; `tool/check_algorithm.dart`: **28 checks**; `tool/check_automation.dart`: **37 checks**; `tool/check_utility_review.dart`: **10 checks**, passing under UTC, America/Los_Angeles, Pacific/Auckland and Pacific/Kiritimati. The monthly check uses independent numeric expected values: 31 Pacific daily readings retain 31 revisions, 30 fit October UTC, one is held; replay adds none; one correction changes the expected estimate without increasing counted records. The synthetic meter/payment example remains **52.744809405287995 kg CO₂e**, payment suppressed, seven sectors missing.
- Coordinator's own Flutter test attempt was blocked before execution by the sandbox denying the runner's localhost socket. The 110-test result above is the helper's completed execution, not a claimed coordinator rerun. Checks use `/private/tmp/verdi-flutter-sdk`, with `DASH__SUPPRESS_ANALYTICS=true`.
- Coordinator final `flutter build web --no-pub`: **release built successfully**; Wasm dry run succeeded. The existing CupertinoIcons font-family warning remains (app uses Material icons). `git diff --check`: passed. No native provider account/export/bill, physical phone, account authorization or real reward system was tested. Supported input remains positive daily normalized electricity CSV, the pinned national fallback factor, and the narrow America/Los_Angeles service-day resolver (2007–2030). UTC-boundary days are held without proration. These checks do not prove a complete household footprint or provider compatibility. See [core acceptance](CORE_ACCEPTANCE.md).


## Reviewed utility evidence adapter — 2026-11-19 Pacific

- Added a pure normalized-electricity adapter with explicit account/meter namespaces, raw record IDs, review decisions, UTC service intervals, complete factor snapshots and personal shares. Corrections name the current predecessor; withdrawals retain history. No import UI, persistence or dashboard wiring was added.
- Distributed implementation: agent-comms job `363fcc01` (Claude). Reviewed the source and all 12 new tests locally. The helper also reports the adapter tests passing under UTC, Pacific/Auckland, America/Los_Angeles and Pacific/Kiritimati.
- Coordinator checks: `flutter test --no-pub`: **78 tests passed**. `flutter analyze --no-pub`: no issues. `git diff --check`: passed. Checks used the existing writable SDK clone at `/private/tmp/verdi-flutter-sdk`.
- Synthetic tests cover nickname-independent identity, account isolation, explicit UTC/DST bounds, factor compatibility, pending review holds, serialization, atomic replay/conflicts, corrections with stale relationships, withdrawals/reinstatement and report attribution. These establish normalized-format behavior, not native provider compatibility or consent validation.
- Time-zone offsets and review decisions remain caller assertions; no named-zone database or durable reviewer identity/reason is captured. UTC-month boundary crossings remain held without proration. Older unseen revisions cannot be backfilled through the adapter after a newer head exists.

## Evidence history inspection and accounting hardening — 2026-11-19 Pacific

- Added **Auto track → Inspect evidence history**, a read-only UTC-month view of experimental reconciliation, separate accounting bases, missing sectors, source/factor revisions, withdrawals and relationship decisions. Empty and unreadable archives remain unchanged; existing imports do not populate this store.
- A distributed read-only review (`5fad832d`, Claude on code-47) identified disjoint-period aliases, weaker reviewed fallback over unreviewed physical data, and failed-write preference caching. Locally reproduced them with regression fixtures and fixed them: canonical conflicts now remain held across monthly windows; equal/stronger unreviewed evidence blocks weaker fallback; failed writes reload durable preferences before subsequent reads/retries.
- `flutter test --no-pub`: **66 tests passed**, including five new screen tests and four accounting/storage regressions. Screen checks cover navigation, corrected revision/provenance inspection, cross-month holds, corrupt-storage recovery, withdrawals/stale relationships and a 360 px viewport at 1.5× text scale.
- `flutter analyze --no-pub`: no issues. `git diff --check`: passed. Synthetic archive preview remains approximately 52.745 kg CO₂e with the matched payment suppressed and seven sectors missing.
- `flutter build web --no-pub`: release built successfully. Flutter emitted a font-family warning for CupertinoIcons; the app uses Material icons. Native builds and physical-device behavior remain unverified.
- The installed SDK cache is read-only in this session. Checks used an APFS clone at `/private/tmp/verdi-flutter-sdk`, with the same pinned SDK and cached dependencies. No SDK permissions were changed. The preferences platform interface is now an explicit dev dependency at its already locked version for physical-write failure tests.

## Redmond connection and accounting foundation — 2026-11-18 Pacific

- Resumed capsule `capsule-8c7448cdc86e` as historical context; preserved the newer local `main` at `cd41920` and worked on `redmond-connections-accounting`.
- Official-source connection research is in [Connections](CONNECTIONS_WASHINGTON.md), checked November 19 UTC / November 18 Pacific. No real utility account, native provider export, ORCA file, bank connection or vehicle was tested. Documentation support is distinct from sample-tested compatibility and live authorization.
- `flutter test --no-pub`: **28 tests passed**, including 16 new ledger tests, the existing ingestion checks and widget flows. The runner required local loopback socket access outside the default sandbox. An existing narrow-phone selector overflow surfaced during the suite; expanding the dropdown content to available width fixed it.
- `flutter analyze --no-pub`: passed with no issues. `git diff --check` passed.
- `dart run tool/preview_footprint.dart`: synthetic electricity/payment reconciliation ran successfully; one 300 kWh household reading with a declared half share produces approximately 52.745 kg CO₂e using the existing US national fallback. The matching payment is suppressed; seven other sectors remain explicitly missing. This is not a Redmond-specific factor or real household observation.
- The prototype remains separate from app totals. Provider-native ingestion, account authorization, entity/interval containment matching, regional factor selection, food/goods/heating factors and quantified uncertainty still require implementation and validation.

## Historical checks — 2026-10-23

Records completed checks, environment limitations, and outstanding validation.

- `flutter analyze`: passed with no issues.
- `dart run tool/check_algorithm.dart`: 24 algorithm checks passed, including invalid inputs, serialization, historical factors, date windows, duplicate IDs, totals, scenarios, EPA reference conversions, source persistence and legacy compatibility.
- `flutter test`: blocked before tests ran because this environment denied binding the test runner's localhost socket. Algorithm/store and widget tests are included, but their Flutter-runner results are unverified.
- `flutter build web --no-pub`: blocked by network access while Flutter attempted to download its missing Web SDK. A release build has not been verified.
- `dart run tool/check_automation.dart`: 34 checks passed for trip detection, signal filtering, gap handling, utility CSV validation, source identity, serialization and overlap checks.
- Android location bridge: compiled directly with the cached Kotlin compiler, Android SDK and Flutter embedding.
- iOS location bridge: Swift type-check passed against the iOS simulator SDK and Flutter framework.
- Full Android/iOS app builds, physical-device permissions, GPS accuracy, background transitions and battery behavior remain unverified. Native source checks do not replace device testing.
- GitHub repository creation: attempted with `gh repo create BlahBlah23406/verdi --private --source=. --remote=origin --push`; failed to connect to api.github.com. Retried after the EPA update with the same connectivity failure. `gh auth status` also reports an invalid login; this needs rechecking once connectivity is available. No remote repository was created by this session.

On a machine/session with network access and local socket access, run:

```sh
flutter pub get
flutter analyze
flutter test
dart run tool/check_algorithm.dart
dart run tool/check_automation.dart
flutter build web
flutter run -d chrome
```

To publish the local repository, authenticate GitHub CLI if needed, then run from this project directory:

```sh
gh auth status
gh repo create BlahBlah23406/verdi --private --description 'Building Verdi: a Flutter carbon-tracking app and estimation algorithm.' --source=. --remote=origin --push
```
