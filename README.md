# Verdi

Verdi connects everyday activity to incentives for lower-impact choices and useful institutional program analytics. Consumers get explainable estimates, personal guidance, a reward ledger and optional round-up pledges. Campuses, employers and eventually financial institutions get a separate application for consented program reporting.

This is a **local pilot implementation**, continued from agent-comms `capsule-91fc43f9d941`, repository base `8b3ddbf`. It is not a released financial product. The old public GitHub Pages site does not contain this update.

## Applications

| Build | Flutter entry | Data |
| --- | --- | --- |
| Consumer pilot | `lib/main.dart` | Empty live database, administrator-issued session |
| Institution pilot | `lib/main_institution.dart` | Same live database, organization-scoped analyst session |
| Consumer investor demo | `lib/main_demo.dart` | Prefilled synthetic accounts in a separate SQLite database |
| Institution investor demo | `lib/main_demo_institution.dart` | Synthetic program reports from the same demo database |
| Earlier prototype | `lib/main_legacy.dart` | Original device-local tracking and trip review, retained for field validation |

Flutter source targets Android, iOS and web. Web release builds and tests are verified. See [current validation](docs/VALIDATION_V3.md) for native build results and limits.

## Run the investor demo

From this directory:

```sh
flutter pub get
flutter build web --release -t lib/main_demo.dart --dart-define=VERDI_API=http://127.0.0.1:8787
python3 backend/platform.py --demo --db /tmp/verdi-demo.sqlite --static build/web --port 8787
```

Open `http://127.0.0.1:8787/` for the consumer and `http://127.0.0.1:8787/?view=institution` for the institution. The query switch exists only in the demo entry point. Demo tokens grant access only to fictional records.

The database seeds 72 fictional people across three organizations, with daily September/October 2026 travel and electricity, bank transactions, connection state and separate sharing consent. The consumer Alex Morgan belongs to Cascadia. Twenty people per institution initially consent to reports. Program figures are synthetic, not traction.

Walkthrough: check completed month under Rewards, simulate a redemption, enable the capped round-up pledge, sync Connections, confirm the new travel receipt, and inspect the institution report. Toggle sharing off to see aggregates change after refresh. Refresh/restart preserves the ledger. No money moves and no external reward is delivered.

For Android emulator development use `--dart-define=VERDI_API=http://10.0.2.2:8787`. Real devices need a reachable HTTPS backend, not the phone's loopback address. Configure an HTTPS API for mobile distribution.

## Run an empty live pilot

```sh
python3 backend/provision.py --db /tmp/verdi-live.sqlite --config /tmp/verdi-private.json --user pilot-1 --name 'Pilot User' --org pilot-org
python3 backend/platform.py --db /tmp/verdi-live.sqlite --config /tmp/verdi-private.json
flutter run -t lib/main.dart --dart-define=VERDI_API=http://127.0.0.1:8787
```

The administrator finds the newly issued bearer session in the private config and gives it to the intended pilot user. Enter it at sign-in. Sessions stay in memory in the app. Provision an analyst with `--role analyst` in the same organization. Restart the server after provisioning. This is simple administrator-provisioned pilot authentication, not consumer account signup, OIDC, credential recovery, or a production authorization service.

Enable Home energy, then import a CSV with `record_id,date,kwh`. For Green Button XML, provision the account with `--meter-timezone` using the meter's IANA time zone. For a Redmond meter, `--region redmond` selects Pacific time and the Northwest grid factor. For Washington meters outside Redmond, verify the provider and ZIP with [EPA Power Profiler](https://www.epa.gov/egrid/power-profiler) before choosing `--region nwpp`; the default is the national fallback.

In myPSE, open **My usage → Green Button**, choose a date range for one electric meter and export XML. Under **Connections**, enable **Home energy** and choose **Green Button XML**. Complete local days enter review. Replays skip duplicates, and the server rejects overlap with active CSV evidence for the same day. Use one whole-home electricity meter per pilot account. Choose a shorter export period if the file exceeds 5 MB. [PSE export instructions](https://www.pse.com/en/account-and-billing/time-of-use/tou-faq)

Enable **Travel receipts** and use **Log a trip** with your mode and distance. Self-reported trips enter review and contribute to activity estimates after confirmation. They cannot satisfy reward coverage. IoT submeter readings remain supporting evidence. Native phone/GPS upload and provider transit feeds are outside this pilot.

## Algorithms and accounting

- Core operational travel and electricity estimates use pinned EPA 2025 factors with saved factor versions. Electricity uses the labeled national fallback or EPA eGRID NWPP for a provisioned Northwest meter.
- Stable provider record IDs prevent replay from creating duplicate entries. Conflicting corrections fail atomically for review. Confirmed, pending and dismissed states persist.
- Reconciliation no longer merges same-source records, unrelated travel categories, or nested electricity meters. IDs use stable canonical encodings. Correlated sources do not artificially inflate confidence. Scores remain heuristics, not calibrated probabilities.
- A bank payment cannot establish a journey's mode, physical quantity or travel date. No mileage inference from fare, flight-ticket or fuel spend remains.
- Monthly pilot rewards require complete daily travel and utility coverage for two completed months. Daily averages normalize month length. The rule floors at 10 points per estimated kg and caps awards at 2,000 points. It does not prove additionality or causality. Imported evidence is not provider-attested, so this is not a verified financial incentive system.
- SQLite transactions and unique keys prevent duplicate reward claims, concurrent overspending and repeated redemption requests. Real redemption is disabled without a fulfillment system.
- Round-ups use integer cents. Whole dollars, pending charges and refunds contribute zero. Monthly pledge caps and replay handling are deterministic. This version records **demo pledges**, not transfers, donations, retirement of offsets or receipts for tax deductions.
- Flights, food, products and waste need reviewed quantity models and factors before entering the new backend. Old placeholder factors remain isolated in the earlier prototype.

## Provider integrations

The backend implements Plaid `/transactions/sync` for a **previously authorized** account. Configure `PLAID_USER`, `PLAID_CLIENT_ID`, `PLAID_SECRET`, `PLAID_ACCESS_TOKEN` and `PLAID_ENV` on the server. Default environment is `sandbox`. Enable the bank connection and sync. Paging completes before SQLite updates the cursor. A failed/mutated page retains the old cursor. Pending replacements and removals update the transaction ledger.

The consumer Plaid Link/OAuth flow, multi-item encrypted token vault, webhooks and account revocation at the provider still need integration. Disconnect currently stops Verdi imports but does not revoke provider tokens. No Plaid credentials or live account were supplied, so this adapter has protocol tests, not a credentialed live validation.

Utility data enters through normalized CSV or supported Green Button XML exports. Plaid is the only provider sync in the live app. Utility OAuth, smart-device authorization and transit-provider API agreements are pending. Demo connection fixtures are synthetic and labeled in the app.

## Ollama Cloud coach

Set `OLLAMA_HOST=https://ollama.com`, `OLLAMA_MODEL`, and `OLLAMA_API_KEY` in a private JSON file passed through `--config`, or in server environment variables. Keys never enter Flutter. Restart the API after configuration. Only a compact calculated travel scenario leaves the server, without names, transactions or raw GPS. Model text is advisory; it cannot change factors, issue points, execute tools or move money. A timed-out/failed model call falls back to calculated guidance. Model prose itself still requires factual evaluation.

Official integration sources: [Ollama authentication](https://github.com/ollama/ollama/blob/main/docs/api/authentication.mdx), [Plaid sync](https://plaid.com/docs/api/products/transactions/#transactionssync), [EPA factors](https://www.epa.gov/climateleadership/ghg-emission-factors-hub).

## Institutional reports

Analysts see only their assigned organization's fixed aggregates from sharing participants. A report/cell requires at least ten contributing participants. There is no consumer journal or bank record endpoint for analysts. Reports identify period, factor boundaries and participant coverage. They are not an audited corporate inventory or a causal impact study. The threshold is basic suppression, not differential privacy or a guarantee against repeated-query inference.

## Verification

```sh
flutter analyze
flutter test
dart run tool/check_algorithm.dart
dart run tool/check_automation.dart
python3 backend/test_platform.py -v
python3 backend/test_connectors.py -v
```

The backend intentionally binds loopback. Before a real hosted pilot, add a production server behind HTTPS, managed identity, secret storage, database backups, observability, rate limits, provider-attested imports and incident/recovery processes. Do not expose the standard-library local test server directly to the internet.

## Current investor presentation

The new visual [web deck](docs/PITCH_DECK.html) credits Shayaan Haq as sole founder. [Published private deck](https://verdi-product-pitch.arcticmount4.chatgpt.site) · [Ten-minute speech](https://docs.google.com/document/d/1A5xjrClxmx4lrV-JX8B0lFH6Rkk-mqRQAQt8Z8MexGI/edit). Details and controls: [pitch guide](docs/PITCH_DECK.md).
