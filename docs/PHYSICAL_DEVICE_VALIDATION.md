# Physical-device validation

Status: **plan prepared; no physical-device results recorded**. Emulator tests,
source compilation and synthetic coordinates do not pass these gates. The
following acceptance thresholds are proposed pilot gates, not measured claims.

## Build and install

Use a real Android phone with GPS and a real iPhone. Record model, OS version,
app commit, build mode, permission state, battery health and ambient conditions.
Use at least one recent Android release supporting approximate location and one
iOS release supporting reduced accuracy; also cover the oldest OS supported by
the resolved plugins before release. The current iOS project targets iOS 16.0;
dependency platform minimums must be checked after `flutter pub get`.

From this repository, with Flutter installed and dependencies available:

```sh
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run --profile -d <actual-device-id>
```

The device ID comes from `flutter devices`; it is not a simulated device name.
Android package and iOS bundle ID are currently `com.verdi.verdi`. Release Android
builds currently use the debug signing configuration: suitable for this local
test, **not store distribution**. On macOS open `ios/Runner.xcworkspace`, select
your development team and connected phone, then allow development signing. Do
not commit team credentials or signing material. iOS installation cannot be
validated on this Windows host.

For account tests, apply `supabase/migrations` and follow `docs/BACKEND.md` first.
Use a nonproduction backend and test identities. Configure the real provider
callbacks, passkey relying-party domain and associated-domain files; an arbitrary
placeholder RP is not an accepted test. Never embed a service-role key in Flutter.
Repeat basic tracking tests without backend configuration: local use should work.

## What the current code actually does

`lib/features/automation_screen.dart` requests explicit consent and listens only
while foregrounded. `PhoneTracking` consumes the native event channel. Android
requests precise/coarse location together and polls GPS at a requested 5 seconds;
iOS requests When In Use and uses best accuracy. Both native bridges stop when
backgrounded; the Flutter lifecycle handler also finishes a partial trip.
There is no background location permission, service or entitlement to validate.

`TripDetector` rejects accuracy worse than 50 m, invalid coordinates, out-of-order
samples and speed above 70 m/s. The screen rejects stale samples older than
30 seconds and samples more than 5 seconds into the future. A gap above 120
seconds splits a journey. A candidate requires at least 100 m and 60 seconds of
movement, and a stop of at least 120 seconds finishes it. Mode is user confirmed.
Raw GPS coordinates are kept in memory only. Summaries/review queues are currently
stored locally by SharedPreferences; see the backend document for encryption
scope and migration limits before using sensitive data.

## GPS and lifecycle trials

Run each moving trial three times per device, with screen on, consistent phone
placement and independent reference distance (surveyed route or separately
recorded reference). Use only a safe passenger/operator arrangement; do not
interact with the phone while driving. Record UTC start/end, reference km,
candidate km, relative error, rejected sample count and screenshots.

| Trial | Steps | Proposed acceptance |
| --- | --- | --- |
| Open-sky walking/cycling | Travel a known 1-2 km route for >60 s; wait stationary >120 s | One candidate; median distance error <=10%, each run <=20%; travel mode remains unconfirmed |
| Urban/transit passenger | Repeat a >=5 km route with buildings/tunnel or urban canyon | No impossible jump accepted; median error <=20%; gaps create labeled partial summaries rather than guessed distance |
| Stationary drift | Enable tracking outdoors for 15 min without moving | No >100 m/60 s false trip; record rejected samples |
| Short journey | Move <100 m or <60 s, stop | No candidate |
| Manual stop | Travel >100 m/>60 s; tap Stop | Exactly one partial candidate; no further location indicators/updates |
| Background/lock | During a qualifying trip, Home/lock screen; return after 3 min | Tracking stops, partial saved once; no silent restart; explicit Enable required |
| Interrupt/restart | Start, stop, switch tabs, rotate, then kill/relaunch | No duplicate saved trip; persisted pending summary survives; tracking off after restart |
| Service loss | Disable system location midtrip; then restore | Clear stopped/unavailable status; no crash, no synthetic distance; explicit restart succeeds |
| Gap | Lose fixes >120 s then resume | Separate partials, no straight-line bridge over missing fixes |
| Review | Confirm one candidate, relaunch, then discard another | Only confirmed activity contributes to totals; no duplicates; dismissal survives restart |

Compute error as `100 * abs(candidate_km - reference_km) / reference_km`.
If a threshold fails, retain the failed evidence and diagnose; do not change
the threshold to declare success. Distances alone do not establish transport mode.

## Runtime permission matrix

Use OS app settings to reset permissions or reinstall **test data only**. On an
attached Android test device, reset with:

```sh
adb shell pm revoke com.verdi.verdi android.permission.ACCESS_FINE_LOCATION
adb shell pm revoke com.verdi.verdi android.permission.ACCESS_COARSE_LOCATION
adb shell am force-stop com.verdi.verdi
```

Open the app and run every row, recording dialog and resulting in-app status:

| State/action | Expected result |
| --- | --- |
| Fresh install, cancel Verdi consent | No OS prompt or location access; no candidate |
| Accept consent, deny OS request | Tracking stops with actionable message; import/manual entry still work |
| Deny permanently (Android) / denied (iOS) | Clear Settings guidance; no repeated forced prompts |
| Approximate Android / Precise off iOS | Explain precise-location requirement; stop cleanly; no misleading distance |
| Allow once / while using + precise | Foreground fixes arrive; permission is never escalated to Always/background |
| Revoke in Settings during tracking | Stop/error on next OS event; no crash; existing journal preserved |
| Disable Location services | Explicit unavailable/stopped state; restore + Enable works |
| Return from Settings | Permission is rechecked on Enable, not assumed from prior run |
| Navigate away / lock / terminate | Location indicator ceases; no background collection or automatic restart |

Also cancel Apple/Google/passkey system dialogs, deny authentication and disconnect
network: account errors must not mutate the local journal or grant membership.
Passkey enrollment requires a signed-in identity; verify sign-in on a compatible
physical device after association configuration, including user cancellation.

## Battery comparison

Use profile/release builds, battery >=50%, unplugged, same brightness, same route,
same connectivity, no screen recorder and no unrelated foreground workload.
Record battery temperature/health; alternate baseline/tracking order. Run at least
three matched 60-minute pairs per device: (A) app open with tracking off, (B) same
route and screen setting with tracking on. Include a stationary 60-minute pair.
Record percent lost per hour and, where available, OS energy/GPS attribution.

Android evidence commands on the test phone:

```sh
adb shell dumpsys batterystats --reset
adb shell dumpsys battery
# Run the timed trial, then:
adb shell dumpsys battery
adb shell dumpsys batterystats com.verdi.verdi > android-batterystats.txt
adb shell dumpsys location > android-location-after-stop.txt
```

On macOS, capture Instruments Energy Log (or Xcode's current energy profiling
instrument) for the equivalent foreground trial, plus Settings > Battery after
the trial. Keep identifiers/routes local and redact before sharing.

Proposed gates: median incremental drain `(B loss - A loss)` <=5 percentage points
per hour, no OS thermal warning and no continued Verdi GPS registration after
Stop/backgrounding. Record actual numbers even if below battery-percent
resolution; extend to two hours rather than report a false zero. These gates
must be accepted or adjusted with recorded reasoning before pilot enrollment.

## Real utility import and privacy checks

1. Auto track -> account nickname -> Choose Green Button XML. Import
   `examples/green-button-electricity.xml` (labeled synthetic fixture): exactly two
   pending readings, 1.25 and 0.75 kWh; no total changes before confirmation.
2. Confirm both: total consumption 2 kWh; import again, including with a changed
   nickname: zero new readings. Import malformed/unsupported XML: error, existing
   journal and queue preserved. Do not use Load simulated demo feeds for this test.
3. Repeat with an actual utility export whose use is authorized, on the supported
   interval subset in `docs/GREEN_BUTTON.md`. Independently compare source meter
   interval sum and imported kWh. Keep raw file off source control and backend.
4. Capture network traffic from your test device: no XML/account number/raw GPS
   uploaded. With explicitly enabled ledger upload, only ciphertext envelope and
   necessary identifiers reach Supabase. Verify another user/org member cannot
   read a user's ledger. Never log bearer tokens, key material or full GPS traces.
5. Sign out, switch user and attempt restore: keys/data must remain identity
   scoped. Test corrupted ciphertext fails without overwriting the journal.

## Results record (fill during physical run)

Copy this table to a local test record; keep all entries **NOT RUN** until tested.
Attach evidence file names, UTC timestamps and commit hash. A reproducible failure
blocks pilot release even if unit tests pass.

| Device/OS/build/commit | Case | Actual measurement/state | Expected gate | Evidence | Result |
| --- | --- | --- | --- | --- | --- |
| NOT RUN | GPS/lifecycle | NOT RUN | See trials | - | NOT RUN |
| NOT RUN | Permissions | NOT RUN | Every matrix row | - | NOT RUN |
| NOT RUN | Battery baseline/tracking | NOT RUN | <=5pp/h extra, no active GPS after Stop | - | NOT RUN |
| NOT RUN | Utility import | NOT RUN | Correct summed kWh, dedup, review | - | NOT RUN |
| NOT RUN | Auth/ledger/membership | NOT RUN | See backend validation | - | NOT RUN |

## Platform references

- [Android runtime location permissions](https://developer.android.com/develop/sensors-and-location/location/permissions/runtime)
- [Android battery statistics](https://developer.android.com/tools/dumpsys#battery)
- [Apple When In Use authorization](https://developer.apple.com/documentation/corelocation/cllocationmanager/requestwheninuseauthorization())
- [Flutter physical iOS device setup](https://docs.flutter.dev/platform-integration/ios/setup)
