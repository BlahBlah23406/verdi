# Personal footprint accounting plan

Research checked **2026-11-19 UTC** (2026-11-18 in Redmond). This is a proposed accounting policy and implementation plan, not certification of a complete footprint. Provider access is evaluated separately in [Connections](CONNECTIONS_WASHINGTON.md).

## Recommendation and current capability

Use a **hybrid system with deterministic accounting**. Rules handle units, factors, allocation, reconciliation and arithmetic. ML can extract receipt fields, suggest purchase categories, match candidate journeys to routes, and identify ambiguous evidence. A model must never invent an emission factor, silently decide an accounting boundary, or turn an unsupported category into zero. Begin with rules and user confirmation; add ML only when labeled local examples demonstrate an improvement.

The app currently calculates confirmed commuting and electricity records using its pinned EPA national catalog. It does not calculate food, purchases, gas, ferries, aviation, water or waste for new entries. The new `lib/domain/footprint_ledger.dart` is a separate experimental reconciliation foundation; it does not change journal or dashboard totals. No real connected household has been validated in this work.

## What a full picture means

Define the reporting subject first: one person, a household, or a household share. Maintain an explicit profile of residences and dates, occupants, vehicles, fuel types, utility service accounts, purchased electricity, and which accounts/cards are shared. A Redmond postal address does not establish a utility or municipal service area. Travel outside Washington must use the activity's geography, not the home address.

Use an annual consumption picture with monthly observations, and record which components are included. Do not label a sum of commuting and electricity a full personal footprint. An annualization is a separate scenario with its assumptions, never an observation.

| Component | Preferred observation | Proposed method and critical boundary |
| --- | --- | --- |
| Home electricity | Meter import, delivered kWh and period | Matched grid generation factor; retain import/export separately. Allocate shared home consumption once. |
| Home heating/cooking | Natural gas therms or fuel quantity | Fuel-specific combustion gases, with an independently sourced upstream component if included. Do not confuse therms with volume or count electric heat again. |
| Personal road travel | Vehicle fuel/energy use; confirmed distance as fallback | Allocate vehicle emissions by occupants or a declared household policy. Vehicle-km and passenger-km are distinct units. Fuel purchases require stock/period treatment; a full tank bought today need not be burned today. |
| Transit and ferries | Actual taps/confirmed journey legs plus route context | Service/mode and passenger distance; agency totals need a defensible allocation denominator. Link light rail is not commuter rail. Schedules alone are not evidence of a trip. |
| EV travel | Charging-session energy and location; home meter reconciliation | Home charging is a subset of home electricity. External charging adds only the uncounted energy. Battery-added energy and wall energy differ; losses need an explicit method. |
| Flights | Completed itinerary, passengers and cabin | Leg distance and a suitable aviation factor. Keep non-CO₂ aviation climate effects as a separately labeled scenario unless a reviewed policy incorporates them. A ticket price is a poor substitute. |
| Lodging | Stayed room-nights and number sharing | Hotel/region factor with disclosed boundary; reconcile booking, receipt and bank payment. |
| Food and drink | Itemized receipt, mass and product type | Product/category lifecycle factor with geography and production assumptions; restaurant meals need a different model. Unknown item mass is unresolved or a labeled fallback. |
| Goods and durable assets | Product-specific assessment; receipt quantity/material | Use an explicit purchase-year embodied-emissions policy. Optional amortized views must not also count the full purchase-year footprint. Second-hand and resale need a documented allocation policy, not automatic negative emissions. |
| Services and remaining purchases | Posted spend with reviewed category | Supply-chain spend factor only for otherwise uncovered components, with price-year/currency/price-basis normalization. Transfers and repayments are not purchases. |
| Water/wastewater | Meter volume and service period | Locally supported treatment/pumping factor; separate hot-water household energy already included in meters. Shared/building meters require allocation. |
| Solid waste | Material mass and actual treatment route | Inventory-compatible disposal/treatment factor. Cart capacity and collection frequency are proxies, not measured waste mass. |
| Housing/vehicle manufacturing, repairs, refrigerants and other gaps | Construction/product/service records when available | Define embodied allocation and gases explicitly. Keep missing components visible rather than adding unsupported average values. |

Optional public-service and infrastructure allocations need a separate declared policy and dataset. Investment/financed emissions, offsets, avoided emissions and rewards must remain separate from consumption totals. A personal framework borrows useful corporate accounting concepts but is not automatically a GHG Protocol corporate inventory.

## Evidence to account pipeline

1. **Consent and capture.** Request each source for a stated purpose, read only where possible, with expiration/revocation and deletion. Preserve original quantity, unit, timestamps/timezone, provider record ID, account pseudonym and consent reference. Minimize raw location and document retention. Production secrets belong on a secured backend, not device preferences.
2. **Normalize.** Parse strict provider schemas; distinguish actual/estimated/corrected meter readings, meter imports/exports, vehicle/passenger distance, money direction, pending/posted transactions, document date and service period. Reject or quarantine malformed units and timestamps. Stable source IDs and revisions make replay idempotent.
3. **Construct canonical activities and components.** Match evidence using account/meter/vehicle/person, service period, amount, route/time and explicit reference IDs. A match is not established by merchant name or the same day alone. Split overlaps into nonoverlapping intervals/components before calculating; keep ambiguous matches for review.
4. **Reconcile alternatives.** Choose the best valid evidence for the *same component and boundary*: measured physical quantities, reviewed physical quantities, validated model estimates, then spend estimates. This is a preference, not proof that every meter is accurate. Corrected bills supersede prior versions; equally strong conflicting evidence needs review. Never silently fall back to spend merely because the physical factor is missing.
5. **Select a reviewed factor.** Match activity, denominator, boundary, accounting method, geography, reporting/data year and gases/GWP. Follow a documented fallback chain and expose its reason. Snapshot factor and calculation version; historical changes require a separate recalculation version.
6. **Calculate and attribute.** Use full precision internally; round at display. Apply personal allocation once. Sum only compatible and nonoverlapping components. Retain an explanation linking accepted, suppressed and unresolved evidence.
7. **Report coverage.** Show observed estimates, modeled extensions, missing categories, disconnected sources, stale data, unresolved overlaps and covered intervals. One electricity reading means some electricity evidence, not complete monthly coverage. Do not infer zero from missing data.

For a physical component:

```text
component kg CO₂e = normalized quantity × reviewed kg CO₂e/unit × personal share
gas-resolved kg CO₂e = Σ(gas mass in kg × matching 100-year GWP)
spend component = eligible spend in factor's currency/price-year/basis × kg CO₂e/currency-unit
```

If a factor already expresses CO₂e, do not apply GWP again. A CO₂-only rate must be labeled CO₂ unless other gases are added consistently. Sector-level model factors are estimates, not measurement of the user's specific product. Personal allocation is a transparent convention; using an exact share does not make the underlying emissions exact.

## Reconciliation rules that must precede broader totals

| Evidence collision | Required treatment |
| --- | --- |
| PSE bill, interval file and utility bank payment | Meter intervals or bill total account for energy once; reconcile the bill period. Payment is supporting financial evidence, not additional energy emissions. |
| Home utility total and EV charging sessions | Assign home charging as a child component of that meter; either reclassify within the total or subtract it from home before adding to travel. Never add both full amounts. External charging requires location/account matching. |
| Odometer/fuel, phone trip, rideshare receipt and card charge | Match to the actual vehicle/trip and period; use one operational estimate. Do not erase a separate supplier upstream component if boundaries genuinely differ. |
| ORCA taps, bank top-up and phone route | Taps support journeys; top-ups and passes are payment mechanisms. Transfers can be multiple legs, not automatically multiple independent journeys. Unmatched tap-outs or endpoints need review. |
| Grocery receipt, retailer order and bank transaction | Replace only the matched portion with item estimates; allocate the remaining unclassified purchase once. A partial receipt must not erase the unobserved basket or add the complete bank spend. |
| Airline booking, cancellation, bank refund | Include completed travel; preserve revisions and payment changes separately. Money refunded does not itself create negative physical emissions. |
| Hotel room-night and spend factor | Choose one estimate for the same stay/boundary; avoid adding a broad travel-spend factor on top. |
| Food/goods lifecycle factor and disposal | Inspect included stages; add waste treatment only when outside the product boundary. A broad lifecycle label is insufficient to determine this. |
| Rent, mortgage, utility bills and building embodied estimate | Separate housing service/supply-chain assumptions, financing principal and actual operating energy. Do not apply a generic all-in housing factor alongside its included components. |
| Card repayment, linked bank transfer, shared account | Exclude financial transfers; avoid duplicating the original purchase and allocate shared consumption explicitly. Cash or unlinked accounts remain coverage gaps. |

The matching layer needs `supersedes`, `supports`, `same-component`, `contained-in` and `separate-component` relationships. Equality deduplication alone cannot solve interval-vs-bill or home-vs-EV containment. Keep all source evidence for audit under the retention policy; suppressing an estimate is not deleting its provenance.

## Regional electricity and factor governance

Start with the actual service account. For location-based electricity, establish the eGRID subregion using the location and supplier mapping; then pin the applicable total-output rate and gases. Do not assign all Washington accounts a state-production factor or assume the utility's fuel percentages describe the local grid. EPA currently documents **eGRID2023 revision 2, released June 12, 2025**; release year and data year are different. The current app's January 2025 catalog must remain identifiable rather than silently becoming the revised dataset. See [EPA detailed data](https://www.epa.gov/egrid/detailed-data) and [eGRID revisions](https://www.epa.gov/egrid/known-issues-data-notes-and-revisions).

Utility/supplier-based estimates and qualifying contractual claims are a second accounting view, never an extra amount added to the location-based estimate. The [GHG Protocol Scope 2 Guidance](https://ghgprotocol.org/scope-2-guidance) distinguishes the approaches and sets quality criteria for contractual instruments. Its cited guidance is corporate guidance, adapted here as a design principle. A green-tariff payment alone is not sufficient evidence to zero household electricity.

[Washington Commerce fuel-mix disclosures](https://www.commerce.wa.gov/energy-policy/electricity-policy/fuel-mix-disclosure/) describe supplier fuel shares and unspecified sources. They are useful for supplier identification, year matching and explanatory context. They are **not by themselves a complete kg CO₂e/kWh factor**: emissions rates, treatment of unspecified sources, gases, losses and accounting method still need a reviewed calculation.

Each production factor record should include immutable ID/version, exact source file and checksum, table/row, publication/retrieval/data dates, valid period, geography, activity subtype, denominator unit and basis, components included/excluded, gas masses or CO₂e status, GWP assessment/time horizon, attributional/marginal method, location/supplier method, price year/currency/purchaser-vs-producer basis if monetary, and uncertainty/limitations. Incompatible factor families cannot share a headline subtotal merely because their output says kg CO₂e.

[EPA's GHG Emission Factors Hub](https://www.epa.gov/climateleadership/ghg-emission-factors-hub) supplies defaults for several fuel, transport, electricity and waste calculations. The app currently pins its 2025 edition with AR5 GWPs; extending its coverage needs a verified transcription and matching boundary, not a guessed number. Average attribution factors cannot substantiate a claim about marginal emissions avoided by changing one trip.

[EPA USEEIO](https://www.epa.gov/land-research/us-environmentally-extended-input-output-useeio-models) and the [EPA supply-chain factor repository](https://github.com/USEPA/supply-chain-factors) are useful candidates for uncovered purchases. Before importing a release, verify its actual factor CSV, sector mapping, price year, margins and GWP set; do not take an aggregator's version label as evidence. Adjust transaction spend to that exact basis with a sourced deflator/currency policy. Different releases may use different characterization assumptions. Existing AR5 totals must not silently mix with an incompatible GWP basis.

For waste, use inventory-compatible treatment factors for the footprint. [EPA's comparison of Hub waste factors and WARM](https://nepis.epa.gov/Exe/ZyPURL.cgi?Dockey=P101B81H.txt) explains their different purposes. WARM's baseline/alternative benefits belong in a separate scenario; recycling avoided emissions cannot be subtracted from the user's gross footprint.

## Appropriate ML tasks and uncertainty

An OCR/LLM extractor may propose item names, mass, currency, dates and service periods, with page/line evidence and schema validation. A classifier may propose a constrained food or spend category; a trip model may suggest route/mode. Low-confidence and consequential ambiguous cases go to review. No model obtains consent, chooses unreviewed factors, assumes an unreadable quantity, or directly writes emissions totals.

Treat extraction confidence, classification probability, input measurement uncertainty, factor variability, allocation uncertainty and missing coverage as distinct quantities. Do not multiply model confidence into emissions or advertise a universal accuracy percentage. Begin with qualitative evidence labels and disclosed assumptions. Add ranges only with supported parameter distributions or explicit scenario bounds; correlated factors and shared allocation errors must remain correlated in any Monte Carlo analysis. Report model version and retain user corrections for evaluation under consent.

## Validation and rollout gates

1. **Redmond energy and journeys.** Obtain consented de-identified PSE exports and corresponding bills; verify meter/commodity, units, local timezone/DST, interval duration, revised readings and totals at source precision. Check one real ORCA export against visible card history, and confirm route legs against the user's record. Add gas only after a unit/factor review. A synthetic parser fixture does not validate provider compatibility.
2. **Reconciliation foundation.** Test idempotent replay, corrections, conflicting records, partial overlaps, cross-month bills, out-of-order pages, missing/zero quantities, negative net export, home EV containment, vehicle/passenger bases and household allocation. For every fixture account, accepted component quantities must reconcile to its independently constructed reference; discrepancies are explained rather than rounded away.
3. **Greater Seattle.** Repeat the meter and service-area validation for Seattle City Light and Snohomish PUD. Validate Link/Sounder/bus as separate modes. Use direct agency GTFS feeds; confirm actual trips before accounting. Do not extrapolate PSE export behavior to another provider.
4. **Purchases and travel breadth.** Validate a representative local set of grocery/restaurant/retail receipts, mixed baskets, cash/shared payments, bank pending-to-posted changes, refunds, flight cancellations and hotel stays. Independently annotate data and reconcile purchases to account history. Block unsupported factors; expose unmatched spend and missing categories.
5. **ML evaluation.** Use held-out people/households and time periods, including regional route changes and difficult receipts. Measure field extraction error, per-mode/category precision/recall, abstention and correction rates, plus the resulting kg CO₂e error against a human-reviewed calculation. This reference tests the pipeline, not the unknowable exact physical footprint. Choose deployment thresholds from pilot evidence, not invented targets.
6. **Washington expansion and review.** Add providers only after sample and consent tests, service mapping and factor review. Have a qualified accounting reviewer assess boundaries, allocation, spend mapping and uncertainty before a broad-footprint claim. Secure storage, revocation and deletion need end-to-end tests before real automatic connections.

Release readiness requires documented source permissions, replay/revision handling, reproducible factor snapshots, an explainable audit trail, validated component reconciliation and a visible coverage report. No provider is live-connected merely because documentation or an API exists.

## Prototype contract and remaining implementation

The experimental ledger accepts a caller-selected factor and explicitly reviewed evidence. It enforces unit/sector/boundary matching, positive UTC intervals, finite quantities, personal shares and nonnegative factors. It selects stronger evidence within a caller-established canonical coverage key, holds equally strong conflicting calculations and missing factors for review, and reports missing expected sectors. Conflicting revisions or coverage keys for the same source-record identity are withheld; unequal intervals within a canonical key and partial reporting intervals also require review. Factors require GWP and accounting-method identifiers. `kgCo2eByBasis` keeps subtotals separate by boundary, GWP set and accounting method.

It does **not** establish entity matches, split arbitrary overlaps, infer household shares, import new provider formats, select regional factors, correct price years, quantify uncertainty, implement source authentication, or generate a complete consumption footprint. A present sector is not a completeness percentage. Boundary, GWP and method identifiers are currently strings: production needs controlled values, typed component relationships and independently reviewed mappings before aggregating multiple factor families. External normalization must already distinguish actual physical zero from missing, net/export energy from consumption, and alternative estimates from additive components.

The next implementation now includes a [persisted revision/relationship prototype](EVIDENCE_ARCHIVE.md), exact-component matching and conservative containment. It retains correction history, requires reviewed relationships, checks canonical aliases before containment, and keeps home-charging children nonadditive when included in the parent meter. This remains separate from app totals; native schemas, automatic entity matching, arbitrary interval splitting, coverage denominators, consent/backend infrastructure and regional factor selection remain unfinished. Enable new categories in the app only after those paths have reviewed factors and real sample validation. Add the chosen ML tasks after the deterministic baseline and evaluation set exist.
