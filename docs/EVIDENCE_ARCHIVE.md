# Evidence history and relationships

The experimental accounting layer now retains source revisions and explicitly reviewed relationships. It is separate from the current activity journal and monthly dashboard. It does not connect accounts, infer a match, parse a native provider export, or certify a complete footprint.

## Record contract

`EvidenceArchive` stores immutable `EvidenceRevision` objects. A reference contains a source namespace, record ID and integer revision. The source namespace must identify an account/meter within a consented source, not simply `PSE` or `bank`. Use pseudonyms rather than account numbers. Adapters must distinguish provider corrections from repeated downloads and map them to revisions; arrival time is not evidence that a reading supersedes another one. The [utility adapter](#reviewed-utility-adapter) below does this from explicit reviewer input.

A revision contains its UTC receipt timestamp and a `FootprintEvidence` snapshot, including quantity/unit, UTC service interval, sector, boundary, review status, declared personal share and the complete selected factor. A null payload explicitly withdraws a record. It is not a negative reading or a zero-emissions activity.

Appending is atomic and returns a new archive. An identical replay keeps the original record; a conflicting payload for an existing revision fails the entire append. The highest numbered revision per source record is current, independent of arrival order. Older records and factors remain available for explanation. Reviewing or changing a factor is a new revision, not an edit to history.

## Reviewed utility adapter

`UtilityEvidenceAdapter` ([source](../lib/domain/utility_evidence_adapter.dart)) is a pure, experimental converter from normalized `parseUtilityCsv` electricity candidates (`record_id,date,kwh`) into archive revisions. It remains a pure converter; **Auto track → Review into evidence archive** now calls it through a guarded preview and persistence service. The review records a local file-authorization acknowledgement and reviewer provenance. It does not read provider-native exports, establish compatibility with a provider, verify account ownership, or populate dashboard totals.

- **Scoped identity.** One adapter instance covers one consented account/meter. Its `sourceNamespace` (for example `pse-meter:home-a`) becomes the archive source; it must be non-empty, trimmed, at most 120 characters and not the import format name `utility-csv`. Choosing a pseudonym rather than an account number or bare provider name is the caller's responsibility — the adapter cannot verify it. The record ID is the raw CSV `record_id`, decoded from the candidate ID rather than the description. Candidates parsed under a different account nickname are rejected, and renaming the nickname does not change the archive identity. Raw record IDs must be unique per meter.
- **Explicit review.** Each reading needs a `UtilityReadingReview`: provider/reviewer revision number (never allocated by the adapter), optional `supersedes`, UTC receipt time, decision (`approved` or `pendingReview`, no default), coverage key, boundary, quality and personal share in (0, 1]. Pending readings are archived as unreviewed evidence, which the ledger holds rather than counts. A kWh reading cannot be marked as a spend estimate.
- **Explicit UTC interval.** CSV dates are local civil days with no zone. The reviewer supplies the UTC service interval; `civilDayInUtc` derives it from the offsets in force at the day's start and end, so daylight-saving days are 23 or 25 hours. Local `DateTime`s, intervals outside 23–25 hours, and bounds outside the plausible UTC-offset range (−12:00 to +14:00) for that civil date are rejected. These are plausibility checks; the caller must verify the actual named zone and its offsets. A day that crosses a UTC month boundary is held by the monthly report, not prorated.
- **Factor snapshot.** The complete selected `FootprintFactor` is copied into the revision. It must be an electricity kWh factor whose boundary equals the reviewed boundary. Zero, negative, non-finite or implausibly large (>1,000,000 kWh) quantities are rejected; an absent reading is not zero consumption.
- **Replay, correction and withdrawal.** `append` applies changes in order and throws on the first error, leaving the input archive unchanged. Same revision with an identical payload is a no-op replay; a different payload under the same revision is a conflict. A revision without `supersedes` is accepted only for a record with no revisions. A correction must name the current head exactly, so stale or guessed predecessors fail; it therefore also requires corrections to arrive in revision order. `withdrawal` creates a null payload that must supersede the current head; it is not a zero reading, cannot be repeated on a withdrawn record, and a later reading revision may reinstate the record. Corrections make relationships tied to the old revision stale until re-reviewed.

`test/utility_evidence_adapter_test.dart` covers these cases with synthetic readings and a fixture factor, including archive JSON round trips and a reconciled monthly report.

## Relationship contract

Every relationship has an immutable ID/revision, two exact source-revision references, a kind, a review flag and an explanatory reason. It must reference existing source revisions. A relationship revision may update the decision or endpoint revision numbers, while retaining the same two source identities. Earlier decisions remain in the archive; the highest relationship revision is current.

| Kind | Accounting behavior |
| --- | --- |
| `sameComponent` | Union the explicitly matched coverage groups, then let the ledger choose the strongest reviewed evidence. Unequal periods, sectors, boundaries or conflicting equally strong calculations remain unresolved. |
| `supports` | Treat supporting evidence as an alternative for the same reviewed component, not an additive emission. A matched utility payment can support a meter; it cannot silently replace physical evidence missing its factor. Both observations must be reviewed. The normalized payment service interval must match the bill component, not merely its transaction date. |
| `containedIn` | A child is already inside the parent quantity: retain it as nonadditive evidence if the parent is accepted. Examples include known home EV charging inside home electricity. Require compatible physical units, service intervals, personal allocation and factor basis. Never infer containment solely from the same address or day. |
| `separateComponent` | Preserve distinct components, but hold contradictory matches/containment rather than counting them anyway. It does not bypass the ledger's ordinary duplicate/conflict checks. |

Corrections invalidate relationships tied to older source revisions until they are reviewed again. Unreviewed, stale or contradictory relationships hold affected canonical groups for review. A withdrawal cannot silently turn a former supporting bank payment into an accepted replacement estimate.

Canonical groups are validated **before** containment can suppress their evidence. Stronger aliases must fit the parent, equally strong conflicting aliases are held, and child quantities aggregate against the canonical parent even when the parent has several source records. Children cannot exceed the parent or overlap one another in this conservative first version. Nested or competing containment is held. Equal units do not establish physical equivalence; the reviewer/adapter still owns that assertion.

Canonical conflicts also hold when an alias falls entirely outside the requested reporting month. A payment in the following month cannot become a second consumption estimate merely because its matched meter is outside that window. Equal or stronger unreviewed evidence blocks a weaker reviewed fallback until review is complete.

The final report preserves included evidence, suppressed alternatives/children, issues, missing expected sectors and subtotals by boundary/GWP/method. Records crossing reporting boundaries are held rather than prorated. A contained travel-energy observation does not automatically create a travel subtotal or prove that the rest of the person's travel is covered; category attribution is still separate work.

## Local storage and limits

### In-app inspection

**Auto track → Inspect evidence history** opens a read-only view of the persisted archive. Choose a UTC month to see accepted estimates separated by boundary/GWP/method, included and nonadditive record counts, unresolved issues and sectors with no accepted evidence. Source cards retain all revisions and factor provenance, including explicit withdrawals. Relationship cards show historical/current decisions and whether their referenced source revisions have changed. Month boundaries are exclusive; cross-month records stay unresolved rather than being prorated. No universal footprint total or completeness percentage is inferred.

An empty archive does not create demonstration records or imply zero emissions. Current activity imports and the journal still use their existing stores and do not feed this archive. Unreadable archives remain untouched; reload permits retry after restoring valid data. The history screen cannot approve relationships, change factors or edit history. The separate electricity review screen can create new source revisions after an explicit preview; it cannot edit older revisions in place.

`EvidenceArchiveStore` stores a versioned JSON archive in a separate preferences key. Appends are queued per store instance, reloaded before writing, and rejected when the existing archive is unreadable. Failed writes do not poison subsequent retries. This is a local prototype, not an encrypted database or multiwriter service; use one store instance per preferences key. It is wired to normalized electricity review, but not live provider ingestion or the activity dashboard, and must not store credentials or access tokens. Production still needs a secured backend, explicit consent references, retention/deletion, transactional concurrency and source reconciliation.

Because preferences cache values before disk writes finish, failed writes trigger a reload of durable state. If that reload also fails, this store blocks reads until a later append can reload successfully; it does not present the failed payload as saved.

Further work includes provider-native schemas and real sample validation; interval splitting and billing reconciliation; controlled component/boundary identifiers; allocation across people; measured-versus-estimated coverage denominators; regional factor selection; and a review UI for archive relationships. This implementation deliberately does not infer any of those from a merchant label or connector count.

Run `dart run tool/preview_footprint.dart` for a synthetic meter/payment match with an archive serialization round trip. The example uses the existing EPA US-average fallback, not a newly validated Redmond factor. `test/evidence_archive_test.dart` exercises corrections, withdrawals, replay, storage, cross-source matching, aliases, contradictory decisions and containment.

## Normalized electricity review

The review screen accepts pasted normalized CSV or a selected CSV file, reuses durable random meter pseudonyms, and asks for a service zone, factor, personal share, decision, reviewer, reason and file-authorization acknowledgement. A changed reading or assumption requires explicit correction confirmation. Any form edit invalidates its preview. Save rechecks archived meter revisions inside the write queue, then applies the adapter's predecessor rules. A stale preview must be rebuilt. The legacy basic importer remains available; archive saves do not create journal activities.

`ServiceZone` currently resolves only `America/Los_Angeles` civil days from 2007 through 2030, independently of the device zone. It follows the US DST rules documented by [NIST](https://www.nist.gov/pml/time-and-frequency-division/popular-links/daylight-saving-time-dst): transitions occur at 02:00, after midnight on the transition day. These rules are a pinned, narrow implementation, not a bundled IANA timezone database or a guarantee against future rule changes.

The accounting preview uses UTC months and holds boundary-crossing readings. It does not reconcile a complete Pacific billing month, select a local utility factor, or establish that a normalized reading was an actual measurement. See [core acceptance](CORE_ACCEPTANCE.md) for real-household pilot gates.

### Review quality and save receipts

Normalized CSV has no actual/estimated flag. The review therefore requires an explicit evidence-quality choice: actual measured quantity, reviewed quantity, or model/utility estimate. Approval is a separate decision. A reviewed estimate does not become a measurement merely because someone approved it. Quality changes create a correction revision and remain visible in the batch receipt.

New batch receipts are committed with their evidence revisions in one `EvidenceArchiveStore` preferences write. The meter registry remains in `UtilityReviewStore`; historical batch records there remain readable. The archive store preserves and validates receipts on subsequent appends. Readings cannot be durably saved by the review service while their receipt is left waiting for a second write. This remains a device-local, single-store-instance prototype, not a transactional multiwriter backend. Backups must preserve the store's full persisted value, including its review metadata; a domain-only archive JSON export does not include store metadata.
