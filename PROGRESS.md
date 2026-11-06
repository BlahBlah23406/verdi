# Verdi approved action items

Date: 2026-11-06. Working checkout: `C:\Users\shaya\work-github\verdi`.

## Inspection and decisions

- Inspected tracked sources, README, `pubspec.yaml`/lockfile, web runner, native tracking bridge, demo guide, roadmap, validation notes, example CSV, tests and domain logic before implementation. No AGENTS.md or existing deployment workflow, landing page or pitch deck was found in this checkout. Existing founder presentation guidance was reused as evidence.
- Stack: Flutter 3.47.1 / Dart 3.13.1 with shared preferences and file picker; Android/iOS/web runners, local persistence, no backend configuration. Existing theme: forest `#174C38`, cream `#F6F7F2`.
- Chose GitHub Pages for this public static Flutter web application. Authenticated GitHub CLI and network access work on Providence; historical auth/network blockers in `docs/VALIDATION.md` are resolved for this session.
- Preserved the app and its build tooling. Added a static HTML/CSS landing page rather than a new JavaScript framework; Dart tools package the public output and generate the deck.
- Existing roadmap prose lists some features as future work that now exist in source (onboarding and regional settings). New materials follow the implementation and distinguish remaining work.

## Action status and artifact inventory

| Approved item | Status | Repository artifacts |
| --- | --- | --- |
| Public deployment | Complete: successful workflow and live HTTPS verification | `DEPLOYMENT.md`, `.github/workflows/pages.yml`, `tool/package_site.dart` |
| 10–12 slide pitch deck | Complete: 11 slides, source and browser/print presentation | `docs/PITCH_DECK.md`, `docs/PITCH_DECK.html`, `tool/build_pitch_deck.dart` |
| Founder demo script | Complete: timed browser walkthrough, expected results and recovery steps | `docs/FOUNDER_DEMO_SCRIPT.md` |
| Landing page | Complete: reachable at the public root; desktop/mobile browser checks passed | `site/index.html`, `site/style.css`; packages existing `examples/utility_readings.csv` |
| Progress and delivery | Complete: final evidence and unsent delivery templates recorded | `PROGRESS.md`, `DELIVERY.md` |

Public landing URL: https://blahblah23406.github.io/verdi/

App URL: https://blahblah23406.github.io/verdi/app/

Deck URL: https://blahblah23406.github.io/verdi/pitch-deck.html

## Validation

- `flutter pub get`: passed using existing locked dependencies.
- `flutter analyze`: passed, no issues, including a final run after adding the Dart tools.
- `flutter test`: all 12 tests passed, including imports/reconciliation, persistence, activity logging, travel comparison and small-phone layout.
- `dart run tool/check_algorithm.dart`: 24 checks passed.
- `dart run tool/check_automation.dart`: 34 checks passed.
- `flutter build web --release --base-href /verdi/app/`: passed. Flutter reported a non-fatal Cupertino font lookup warning; MaterialIcons is available and compilation succeeded.
- `dart run tool/build_pitch_deck.dart`: generated 11 slides.
- `dart run tool/package_site.dart`: packaged landing page, Flutter release, deck and CSV in `build/site/`.
- GitHub Pages creation API returned a public site at the recorded URL with workflow publishing and HTTPS enforced.

### Successful public release

- Deployed source commit: `677f6955cf50ab82a9e70e6a969c376228131d8e`.
- [GitHub Actions run 42262264127](https://github.com/BlahBlah23406/verdi/actions/runs/42262264127): completed successfully. Both build and deploy jobs succeeded, including analysis, tests, standalone checks, release compilation, packaging and Pages publication.
- GitHub deployment `7606587736`: status `success`, environment URL `https://blahblah23406.github.io/verdi/`.
- Live verification completed on 2026-11-06 at approximately 09:37 Pacific / 17:37 UTC.
- Anonymous HTTPS GETs returned HTTP 200 for `index.html`, `style.css`, `app/`, `app/flutter_bootstrap.js`, `app/main.dart.js`, `app/canvaskit/canvaskit.wasm`, `pitch-deck.html` and `examples/utility_readings.csv`.
- Headless Chromium 153 loaded the live landing page with the expected Verdi title. No horizontal document overflow at 1440px desktop or 390px mobile width. Local screenshots were also visually inspected at these sizes.
- Live deck contains exactly 11 slide sections. Chromium print output contains exactly 11 PDF pages. HTML remains the committed presentation artifact, with built-in print/PDF export and presenter notes.
- The live Flutter app loaded with base href `/verdi/app/`. Browser checks using Flutter's accessibility semantics completed the welcome/profile/region onboarding, reached Overview, and loaded demo data. In this fresh test profile on the verification date, Overview showed 52.2 kg CO₂e across five current-month activities; this is date-dependent sample data, not traction or an expected fixed total.
- Browser verification used temporary scripts outside the repository and existing Playwright/Chromium on Providence; no new runtime dependency was introduced. Preview servers were shut down when those checks ended.
- The existing small-phone widget test drains pre-existing overflow exceptions; its pass is not proof of zero Flutter layout overflow. The new landing page was separately checked for document overflow. Physical-device native testing remains outside this web release.
- Final evidence updates are documentation-only and committed with `[skip ci]`; deployed site/application/deck sources are unchanged from the successful release commit above.

## Blockers, deviations and external delivery

No outstanding blocker. No account sign-in or physical user step was needed. Initial Pages propagation returned 404 while publishing; the successful workflow and subsequent live HTTP/browser checks resolved this temporary state.

One push initially failed because a directory-scoped Git configuration rewrote GitHub HTTPS URLs to the `github-work` SSH alias, authenticating as `shayaan-haq` rather than the repository owner. Configured a repository-local, longer URL match to preserve this repository's HTTPS URL and used the already authenticated GitHub CLI credential helper. Push succeeded as the authorized owner; the work-account rewrite for other repositories was preserved.

The deck is a self-contained HTML presentation plus Markdown source, meeting the requested repo-file format. It supports arrow-key navigation and landscape print/PDF without adding a presentation dependency. No external deck service is used.

No invented traction, market size, pricing, financing, team biographies or partnerships. The repository does not establish those facts. Browser GPS is unavailable; native phone tracking and physical-device validation are explicitly distinguished. Purchase/flight/waste connections and verified reward redemption remain roadmap work.

Owner `[EMAIL_1]` is redacted. `DELIVERY.md` preserves it as a delivery placeholder. No email, Discord post or external workboard action was performed or queued, per task constraint. Delivery note, card and progress templates are prepared locally for later use by an authorized owner with the actual address/workboard destination.
