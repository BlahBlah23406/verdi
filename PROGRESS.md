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
| Public deployment | Configured; first publication verification in progress | `DEPLOYMENT.md`, `.github/workflows/pages.yml`, `tool/package_site.dart` |
| 10–12 slide pitch deck | Complete: 11 slides, source and browser/print presentation | `docs/PITCH_DECK.md`, `docs/PITCH_DECK.html`, `tool/build_pitch_deck.dart` |
| Founder demo script | Complete: timed browser walkthrough, expected results and recovery steps | `docs/FOUNDER_DEMO_SCRIPT.md` |
| Landing page | Implemented and packaged; public verification in progress | `site/index.html`, `site/style.css`; packages existing `examples/utility_readings.csv` |
| Progress and delivery | Prepared; final evidence to be added after publication | `PROGRESS.md`, `DELIVERY.md` |

Public landing URL: https://blahblah23406.github.io/verdi/

App URL: https://blahblah23406.github.io/verdi/app/

Deck URL: https://blahblah23406.github.io/verdi/pitch-deck.html

## Validation

- `flutter pub get`: passed using existing locked dependencies.
- `flutter analyze`: passed, no issues (before added Dart tools; final check follows).
- `flutter test`: all 12 tests passed, including imports/reconciliation, persistence, activity logging, travel comparison and small-phone layout.
- `dart run tool/check_algorithm.dart`: 24 checks passed.
- `dart run tool/check_automation.dart`: 34 checks passed.
- `flutter build web --release --base-href /verdi/app/`: passed. Flutter reported a non-fatal Cupertino font lookup warning; MaterialIcons is available and compilation succeeded.
- `dart run tool/build_pitch_deck.dart`: generated 11 slides.
- `dart run tool/package_site.dart`: packaged landing page, Flutter release, deck and CSV in `build/site/`.
- GitHub Pages creation API returned a public site at the recorded URL with workflow publishing and HTTPS enforced.

## Blockers, deviations and external delivery

No account sign-in blocker encountered. Live deployment verification is pending the initial workflow at the time of this entry; it is not yet claimed complete.

The deck is a self-contained HTML presentation plus Markdown source, meeting the requested repo-file format. It supports arrow-key navigation and landscape print/PDF without adding a presentation dependency. No external deck service is used.

No invented traction, market size, pricing, financing, team biographies or partnerships. The repository does not establish those facts. Browser GPS is unavailable; native phone tracking and physical-device validation are explicitly distinguished. Purchase/flight/waste connections and verified reward redemption remain roadmap work.

Owner `[EMAIL_1]` is redacted. `DELIVERY.md` preserves it as a delivery placeholder. No email, Discord post or external workboard action was performed or queued, per task constraint. Delivery note, card and progress templates are prepared locally for later use by an authorized owner with the actual address/workboard destination.
