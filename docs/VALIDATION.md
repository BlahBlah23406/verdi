# Validation — 2026-10-23

- `flutter analyze`: passed with no issues.
- `dart run tool/check_algorithm.dart`: 24 algorithm checks passed, including invalid inputs, serialization, historical factors, date windows, duplicate IDs, totals, scenarios, EPA reference conversions, source persistence and legacy compatibility.
- `flutter test`: blocked before tests ran because this environment denied binding the test runner's localhost socket. Algorithm/store and widget tests are included, but their Flutter-runner results are unverified.
- `flutter build web --no-pub`: blocked by network access while Flutter attempted to download its missing Web SDK. A release build has not been verified.
- Native Android/iOS builds and device behavior have not been verified.
- GitHub repository creation: attempted with `gh repo create BlahBlah23406/verdi --private --source=. --remote=origin --push`; failed to connect to api.github.com. Retried after the EPA update with the same connectivity failure. `gh auth status` also reports an invalid login; this needs rechecking once connectivity is available. No remote repository was created by this session.

On a machine/session with network access and local socket access, run:

```sh
flutter pub get
flutter analyze
flutter test
flutter build web
flutter run -d chrome
```

To publish the local repository, authenticate GitHub CLI if needed, then run from this project directory:

```sh
gh auth status
gh repo create BlahBlah23406/verdi --private --description 'Building Verdi: a Flutter carbon-tracking app and estimation algorithm.' --source=. --remote=origin --push
```
