# Automatic tracking implementation

The business plan's Solutions section makes phone and consumer-data collection central. The first implemented path is:

Phone location / normalized utility export → validate → derive activity candidates → check existing records → user review → versioned carbon estimate → dashboard.

## Phone path

Android `LocationManager` and iOS `CLLocationManager` feed a Flutter EventChannel. The user explicitly enables collection and grants precise, foreground location permission. Denied/restricted permissions, disabled services and stream errors stop collection with a visible explanation. Stop remains available even if saving fails.

`TripDetector` accepts finite in-range coordinates with accuracy of 50 m or better, in increasing timestamp order. The UI rejects fixes older than 30 seconds or more than 5 seconds into the future. Haversine distance measures accepted segments; movement must exceed both a 10 m floor and the larger endpoint accuracy. Segments exceeding 70 m/s are filtered as implausible for this commuting pilot.

A candidate requires at least 100 m and 60 seconds. Two minutes without significant movement closes it when the next location update arrives. Gaps longer than 120 seconds split trips without interpolating distance. Stopping collection saves a qualifying partial segment. Foreground exit stops the native stream and flushes a partial candidate. If the process is abruptly killed, the in-progress segment may be lost.

These are engineering heuristics, not measured confidence levels or a trained activity-recognition model. Urban GPS drift, tunnels, curves, slow traffic and mixed-mode trips require calibration. Average speed is shown as evidence but never used to assert a transport mode. Users confirm car, bus, commuter rail or bicycle, or discard unsupported journeys such as walking. Vehicle occupancy remains one person for car estimates.

Raw coordinates remain in memory only. Pending summaries contain timestamps, distance and a source ID; they survive restart once saved. Tracking does not resume automatically after leaving the app. Background location, motion sensors, maps, navigation routing and trained mode classification are not implemented.

## Consumer-data path

The file picker reads normalized daily utility CSVs. Schema and bounds are enforced before any candidates are queued. Inputs are daily kWh, not money or cumulative meter values. Account nickname + provider record ID form a stable identity. No provider credentials are collected.

Exact IDs already queued, accepted or discarded are skipped. Conflicting duplicate IDs within a single file fail the entire import. Overlapping travel intervals or electricity dates with existing entries block confirmation until the user resolves the overlap. This conservative electricity check also flags different utility accounts on the same date; multi-meter reconciliation remains future work. Renaming an account changes its identity, so it must remain consistent across imports.

Confirmation saves the activity before removing the candidate. If interrupted between writes, retry detects the existing activity ID and removes the pending item without counting it twice. Queue writes are serialized; failures retain the in-memory queue and expose a retry action. Shared preferences is prototype storage, not a transactional or server-authoritative ledger.

## References for native integration

- [Flutter platform channels](https://docs.flutter.dev/platform-integration/platform-channels)
- [Android location permissions](https://developer.android.com/develop/sensors-and-location/location/permissions)
- [Apple foreground location authorization](https://developer.apple.com/documentation/corelocation/cllocationmanager/requestwheninuseauthorization())

## Required physical-device acceptance checks

1. Deny permission; verify explanation, no tracking and manual app access.
2. Allow approximate location only; verify precise-location guidance.
3. Enable precise location, travel a known route with the app open, then stop. Compare distance against a reference and inspect the candidate.
4. Remain stationary; check drift does not create false trips. Try tunnels and GPS gaps; confirm they do not add straight-line missing distance.
5. Disable location while collecting; verify tracking stops. Background/lock the phone; confirm foreground-only behavior and partial-trip labeling.
6. Confirm a mode; verify exactly one activity and its stored source/factor. Restart and ensure the summary persists.
7. Reimport the sample utility file; confirm no duplicate candidates. Confirm overlapping entries are blocked.
8. Measure battery impact and distance error across representative devices before a user pilot.

Full account integration requires provider selection, authentication/consent flows, backend token storage, webhook ingestion, and provider-specific reconciliation. Financial rewards require verified reduction baselines and a server-owned ledger. No external accounts or payment systems are connected by this implementation.
