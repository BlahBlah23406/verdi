# Verdi

Verdi connects everyday activity to incentives for lower-impact choices and useful institutional program analytics. Consumers get explainable estimates, personal guidance, a reward ledger and optional round-up pledges. Campuses, employers and eventually financial institutions get a separate application for consented program reporting.

This is a **local pilot implementation**, continued from agent-comms `capsule-91fc43f9d941`, repository base `8b3ddbf`. It is not a released financial product. The old public GitHub Pages site does not contain this update.

## Applications

| Build | Flutter entry | Data |
| --- | --- | --- |
| Consumer pilot | `lib/main.dart` | Empty live database, administrator-issued session |
| Institution pilot | `lib/main_institution.dart` | Same live database, organization-scoped analyst session |
| Redmond connection demo | `lib/main_redmond_demo.dart` | Cedar Household, simulated automatic provider updates |
| Consumer investor demo | `lib/main_demo.dart` | Prefilled synthetic accounts in a separate SQLite database |
| Institution investor demo | `lib/main_demo_institution.dart` | Synthetic program reports from the same demo database |
| Earlier prototype | `lib/main_legacy.dart` | Original device-local tracking and trip review, retained for field validation |

Flutter source targets Android, iOS and web. Web release builds and tests are verified. See [current validation](docs/VALIDATION_V3.md) for native build results and limits.

## Run the Redmond connection demo

From this directory, run `./tool/run_redmond_demo.sh` and open [Cedar Household](http://127.0.0.1:8788/). Flutter and Python 3 are required. The browser opens the fictional household automatically. The server listens on loopback and uses a separate local SQLite database, `verdi-redmond-demo.sqlite`.

1. Open **Set up your sources**. Authorize PSE electricity and gas, ORCA and banking with **Allow demo access**. Each permission screen describes the fields the simulated source shares.
2. Close the page for 15 seconds with the server running, then reopen it. The server keeps collecting independently of the browser.
3. Choose **Simulate expired access** on any source. Its history stays visible. Choose **Reconnect** to resume automatically, or **Disconnect** to stop collection.

Each collection cycle takes about 10 seconds. Each source advances through a simulated calendar. Electricity arrives as daily totals and gas arrives on monthly statements, with one prior statement available at first sync. Restarting the server keeps the household and its consent history. For a clean second household run, set `VERDI_DEMO_DB` to an unused SQLite path and `VERDI_DEMO_PORT` to an unused port.

**What the demo validates.** The Plaid simulation runs the production transaction parser against local cursor responses. The utility simulation models separate electricity kWh and natural-gas therms and statement periods. The ORCA simulation uses documented tap fields and real Link 2 Line station names. Tap data never supplies a destination or journey distance. All usage, fares and charges are fictional. Consent, expiration and collection cadence are simulated. The credentialed Plaid Sandbox, Arcadia Sandbox and live provider feeds require separate validation. [Plaid Transactions](https://plaid.com/docs/api/products/transactions/#transactionssync) · [Arcadia Plug Sandbox](https://docs.arcadia.com/docs/sandbox-testing) · [myORCA activity](https://support.myorca.com/hc/en-us/articles/10010238382093-Navigating-myORCA-com) · [Link 2 Line](https://www.soundtransit.org/ride-with-us/routes-schedules/2-line) · [PSE combined bill](https://www.pse.com/en/account-and-billing/my-bill/howtoreadyourbill/Combined-Gas-and-Electric) · [Link fares](https://www.soundtransit.org/ride-with-us/how-to-pay/fares?tab=2)

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
python3 backend/provision.py --db /tmp/verdi-live.sqlite --config /tmp/verdi-private.json --user pilot-1 --name 'Pilot User' --org pilot-org --region redmond
python3 backend/platform.py --db /tmp/verdi-live.sqlite --config /tmp/verdi-private.json
flutter run -t lib/main.dart --dart-define=VERDI_API=http://127.0.0.1:8787
```

The administrator shares the token from the private config with the intended pilot user. Restart the backend after provisioning. On Android and iOS, a successful consumer sign-in is remembered in device secure storage until sign-out or session rejection. Web and institution tokens stay in memory. A reachable HTTPS backend is required for distribution.

Start at **Today → Set up your sources**. Each live connection requires a one-time authorization and must keep collecting without scheduled work from residents.

- **Phone travel.** On Android or iOS, choose **Enable trip detection** and allow precise location while Verdi is in use. Detection resumes while Verdi is open after the app verifies the session and travel connection. Verdi keeps coordinates in memory and saves estimated distances on the phone. Users can review the mode and send a summary to the journal. These estimates are ineligible for reward coverage. Turn detection off or disconnect Travel to stop collection. Background capture and physical-device battery and accuracy testing are still open.
- **Banking.** Enable an administrator-provisioned Plaid account once. The server handles recurring sync independently of app launches. If consent expires, the account needs reauthorization. Self-serve Plaid Link is still pending.
- **PSE electricity and gas.** Automatic household access is pending. PSE documents automatic EnergyCAP data exchange for commercial, industrial and multifamily use. For single-household accounts, validate electric and gas access separately through a provider-authorized channel such as Arcadia Plug Connect. Verify the actual account class, available fields and recurring updates before enabling the source. [PSE EnergyCAP eligibility](https://www.pse.com/pages/property-management-services/EnergyCAP) · [Arcadia provider coverage](https://docs.arcadia.com/docs/provider-coverage) · [Arcadia Connect](https://docs.arcadia.com/docs/plug-intervals)
- **ORCA.** Automatic personal card history requires an authorized feed. The public myORCA guide documents card activity for eligible riders. Confirm partner access and which journey details the feed can supply before enabling an ORCA connection. [myORCA card activity](https://support.myorca.com/hc/en-us/articles/10010238382093-Navigating-myORCA-com)

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

The backend implements Plaid `/transactions/sync` for a previously authorized account. Configure `PLAID_USER`, `PLAID_CLIENT_ID`, `PLAID_SECRET`, `PLAID_ACCESS_TOKEN` and `PLAID_ENV` privately on the server. The default environment is `sandbox`. Set `VERDI_SYNC_ENABLED=1` to start scheduled sync with the live API process. The worker polls for due work in the running service and defaults to an hourly provider sync. Set `VERDI_SYNC_INTERVAL_SECONDS` and `VERDI_SYNC_MAX_BACKOFF_SECONDS` to tune the schedule. Use one worker per SQLite database. Paging completes before SQLite updates the cursor. Failed pagination retains the old cursor, and pending replacements and removals update the transaction ledger.

The consumer Plaid Link/OAuth flow, multi-item encrypted token vault, webhooks and provider-side revocation remain open. Disconnect stops syncing in Verdi and keeps confirmed history. Protocol tests use mocked responses and live validation requires authorized provider credentials. [Plaid Transactions sync](https://plaid.com/docs/api/products/transactions/#transactionssync) · [Plaid reauthorization](https://plaid.com/docs/link/update-mode/)

The Green Button parser and accounting archive support historical evidence work. Current resident onboarding uses automatically maintained sources. Demo connection fixtures are synthetic and labeled in the app.

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
