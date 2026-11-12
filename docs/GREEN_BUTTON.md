# Real utility adapter: Green Button Download My Data

The default `MultiSourceRegistry` now contains a real, initially disconnected
`GreenButtonUtilityAdapter`. Auto track → **Choose Green Button XML** constructs
it from a user-selected utility export and runs the same ingestion/review queue
used by multi-source tracking. No utility API credentials are invented. The
existing four simulated adapters remain available only through
`MultiSourceRegistry.demo()` / **Load simulated demo feeds** for the VC demo.

Download your utility's Green Button **Download My Data** XML, then select it in
the app with an account nickname. Importing requires no backend or cloud upload.
The nickname is for display; changing it cannot bypass deduplication. This is a
real data-format adapter, not an authorized Green Button Connect My Data live
subscription. Provider OAuth/onboarding remains future work.

Supported subset: an Atom feed (`http://www.w3.org/2005/Atom`) containing ESPI
(`http://naesb.org/espi`) ReadingType, MeterReading and IntervalBlock resources.
Each MeterReading's related link must resolve to a ReadingType; each block's up
link must resolve to its MeterReading. HTTP(S) resource links may be absolute or
relative to inherited `xml:base`; they are identifiers only and never fetched.
Different XML prefixes work. Files without resolvable links are rejected rather
than guessing which unit applies.

Only electricity (`commodity=1`), energy (`kind=12`), forward consumption
(`flowDirection=1`), incremental intervals (`accumulationBehaviour=4`), Wh
(`uom=72`) with an explicit power-of-ten multiplier are accepted. Conversion is
`kWh = integer value × 10^powerOfTenMultiplier / 1000`. Each interval uses UTC Unix
seconds and its own positive duration. Cumulative counters, power in W, reactive
energy, export/net metering, gas and overlapping tariff/phase readings require
separate explicit semantics and are rejected. The parser does not silently
interpret these as electricity consumption.

Limits: 1 MB, at most 10,000 entries/readings, duration ≤31 days, 1,000,000 kWh per
interval, nonnegative integer values and end ≤now +5 minutes. Zero usage creates
no activity. DTD/entity declarations, malformed XML, missing units/linkage,
conflicting same-interval values and overlaps within a meter fail the entire
import before persistence. Identical duplicate intervals collapse; importing a
previously reviewed/dismissed/pending identity queues nothing. A later utility
correction with the same interval ID is not automatically substituted: review
and remove the prior journal entry before importing the correction. Do not
auto-sync estimates as billing truth.

Only summaries, hashed canonical meter-resource identity, timestamps, kWh,
display nickname and utility quality flags reach the queue. Customer resources,
raw XML, meter URLs and account numbers are not retained. SHA-256 hashing is
pseudonymization, not anonymization. Utility quality flags are preserved but not
independently verified; imported rows do not display a made-up confidence score.
The existing local queue/journal use SharedPreferences (not encrypted). The
backend ledger is a separate explicit encrypted upload; see `docs/BACKEND.md`.

Real energy intervals bypass the demo reconciliation heuristic: adjacent
intervals/meters are additive and must not be averaged as corroborating signals.
Existing confirmed-overlap checks conservatively skip overlapping activities;
multiple meters for the same time may need independent account-aware journal
handling in a future pilot. Use one meter per import/review session if overlap
warnings occur. No institutional dashboard receives raw user records.

Run `flutter test test/green_button_test.dart` and `flutter test`. The
`examples/green-button-electricity.xml` file is a synthetic interoperability
fixture with two one-hour readings totaling 2 kWh, **not real customer usage**.
Validate an authorized actual utility export on-device before pilot release.

Sources: [Green Button API resource linkage](https://greenbuttonalliance.github.io/OpenESPI-GreenButton-API-Documentation/),
[Wh/multiplier semantics](https://www.greenbuttonalliance.org/poweroftenmultiplier),
[ESPI schema](https://dev.greenbuttonalliance.org/espiusecase.html),
[reading-quality semantics](https://www.greenbuttonalliance.org/accuracy).
