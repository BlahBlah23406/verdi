# Validation — 2026-10-23

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
