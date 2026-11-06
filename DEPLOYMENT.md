# Public deployment

Public landing page: https://blahblah23406.github.io/verdi/

Flutter application: https://blahblah23406.github.io/verdi/app/

Pitch deck: https://blahblah23406.github.io/verdi/pitch-deck.html

## Target and architecture

GitHub Pages was selected after inspection: the repository is public, the application already has a Flutter web runner, dependencies use local storage/file import, and no backend or Firebase project configuration is present. Pages can serve the landing page and compiled web app without adding a service or inventing backend requirements. The browser demo does not implement native phone GPS.

`site/index.html` and `site/style.css` supply the landing page. `web/index.html` remains the Flutter bootstrap. The application is built with `/verdi/app/` as its base URL. `tool/package_site.dart` combines them into ignored `build/site/`, including the deck and sample utility CSV. Only this directory is uploaded; repository files and credentials are not included wholesale.

## Setup performed

- Authenticated GitHub CLI as the repository owner on Providence.
- Enabled public Pages with `build_type=workflow` through the GitHub API; HTTPS is enforced.
- Added `.github/workflows/pages.yml`, triggered by pushes to `main` or manual dispatch.
- The workflow builds and tests using Flutter 3.47.1 / Dart 3.13.1, matching the available toolchain and `pubspec.yaml` constraint.
- Build job has read-only repository access; deployment uses Pages write and OIDC permissions through GitHub Actions. No Firebase credentials are required.

## Reproduce the site locally (PowerShell)

From the repository root with Flutter 3.47.1 on PATH:

```powershell
flutter pub get
flutter analyze
flutter test
dart run tool/check_algorithm.dart
dart run tool/check_automation.dart
dart run tool/build_pitch_deck.dart
flutter build web --release --base-href /verdi/app/
dart run tool/package_site.dart
```

The generated files are in `build/site/`. Preview from a parent directory exposing that folder at `/verdi/` to preserve the app's compiled base path. Serving `build/site` directly at `/` will show the landing page but will not match the app's `/verdi/app/` base path. For application-only development use `flutter run -d chrome`.

## Publish subsequent changes

Commit and push reviewed source changes to `main`. GitHub Actions runs analysis, the existing tests and standalone checks, builds the release, packages `build/site/`, uploads it with `actions/upload-pages-artifact`, and publishes with `actions/deploy-pages`. If the deck Markdown changes, run `dart run tool/build_pitch_deck.dart` and commit the generated HTML as well.

With GitHub CLI, inspect or rerun deployment from the repo root:

```powershell
gh run list --workflow pages.yml
gh workflow run pages.yml --ref main
gh api repos/BlahBlah23406/verdi/pages
```

Repository settings: https://github.com/BlahBlah23406/verdi/settings/pages

Deployment history: https://github.com/BlahBlah23406/verdi/actions/workflows/pages.yml

If restoring a prior version is needed, revert the source commit and push to `main`; the same workflow redeploys it. Do not commit generated Flutter release files. Changing the repository name or adding a custom domain requires updating the compiled base href and documented URLs.

## Verification and limitations

Release evidence, workflow run and live verification are recorded in `PROGRESS.md`. Analysis, tests and local web compilation passed on Providence. Earlier network/authentication limitations in `docs/VALIDATION.md` describe a prior session and were not reproduced here.

The application stores data in the browser on this device. Clearing site data removes it; there is no cloud sync. Native Android/iOS tracking, device permissions, battery behavior and real-world accuracy are outside web deployment validation. Placeholder factors and preview rewards retain the scope described in the README.

Implementation references: [GitHub Pages custom workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages), [Flutter web releases](https://docs.flutter.dev/deployment/web), [Flutter base URL](https://docs.flutter.dev/ui/navigation/url-strategies).
