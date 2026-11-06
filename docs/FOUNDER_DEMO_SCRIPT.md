# Verdi founder demo script

Target: 6–7 minutes. Browser-first walkthrough of the working prototype.
Landing page: https://blahblah23406.github.io/verdi/
App: https://blahblah23406.github.io/verdi/app/

## Preparation

1. Use a fresh browser profile with local storage available. Verdi saves data on this device and does not require an account. Avoid clearing a real user's saved activities.
2. Open the public landing page and download its sample utility CSV link (`examples/utility_readings.csv`). It contains January 2026 readings; these will appear in Activities, not the current month's total.
3. Keep `docs/PITCH_DECK.html` and this script available. Use the default US-average electricity region and solo occupancy for consistency with the commute example.
4. Rehearse on the actual browser. GPS capture is a native Android/iOS feature, not part of the browser demo. Do not grant or request browser GPS for this walkthrough.
5. For a populated overview use Load demo data on an empty Overview. Sample dates are relative to today, so totals can vary, especially near the start of a month. Never promise a fixed demo total. Prefer a fresh profile to repeating Clear; the demo Clear action empties saved activities.

## 0:00–0:40 — Introduce the problem on the landing page

Action: Show the hero, commute comparison, and “From everyday data to an estimate” section. Select Explore Verdi.

Say: “Verdi helps people understand their everyday carbon footprint. The broader vision is to bring several consented data sources into one traceable estimate. Today, I'll show the working foundation: travel and electricity tracking, reviewable imports, and comparisons that explain the numbers.”

Expected: The landing page links into the Flutter application at `/verdi/app/`.

## 0:40–1:15 — Onboard and establish scope

Action: In a new profile, continue through welcome, vehicle/occupancy and electricity-region selection; use one occupant and US average, then Get started. Returning profiles open Overview directly.

Say: “This prototype saves data locally. We choose a region for electricity and collect profile settings, but the core car estimate uses an average passenger-car factor; this is not a vehicle-specific measurement.”

Expected: Overview appears, with bottom navigation for Overview, Activities, Reduce, Rewards and Auto track.

## 1:15–2:00 — Show the monthly picture

Action: On an empty Overview select Load demo data. Point out the sample-data banner, current-month total and category breakdown.

Say: “These are sample activities, not customer usage. The monthly view adds up what has been recorded. Missing data does not imply zero emissions, and this is not a complete lifecycle footprint.”

Expected: Sample travel/electricity entries and monthly categories appear. The exact total depends on today's date. If sample loading is unavailable because entries already exist, continue with those entries and identify their origin honestly, or switch to a fresh profile.

## 2:00–2:50 — Add and inspect a traceable activity

Action: Select Log activity. Choose Car journey, enter 20 km, leave today's date, optionally label it “Demo commute”, and Save activity. Open Activities and tap that record to display Calculation details.

Say: “We multiply the quantity by a sourced factor. This record retains its factor, version, source and assumptions, so future factor updates do not silently rewrite this entry.”

Expected: The record persists, Overview includes it in today's month, and its details show the saved factor metadata. The repository's average solo-car estimate for 20 km is about 3.71 kg CO₂e; list displays may round to 3.7 kg.

## 2:50–3:40 — Compare a practical alternative

Action: Close details, choose Reduce, set the distance to 20 km and select commuter rail. Keep occupancy at one.

Say: “The same 20 km journey is approximately 3.71 kg for an average solo car and 1.67 kg for commuter rail, a potential difference of about 2.05 kg CO₂e. This compares attributed operational emissions; it does not measure a real reduction from a trip we observed.”

Expected: Approximately 2.0 kg potential reduction at the UI's precision and 20 eco-points. If the slider is hard to set exactly, explain the displayed distance rather than reading the 20 km example as the live result.

## 3:40–4:50 — Demonstrate the import review loop

Action: Choose Auto track. Point out the browser message that phone detection is available on Android/iOS. Under Import electricity data, set a stable account nickname such as “Demo utility”, select Choose utility CSV, and select the downloaded example. Inspect candidates before selecting Confirm activity for one reading. Open Activities and inspect the confirmed electricity record.

Say: “This is an imported file, not a live utility connection. Evidence enters a review queue before changing the footprint. We preserve source identity and check overlapping evidence. These sample readings are from January, so the current monthly total should not increase.”

Expected: Two readings are queued in a fresh profile. Confirmed readings enter Activities once. Reimporting with the same account nickname should not create a second confirmed copy; existing overlaps may instead be flagged. A different nickname changes source identity, so do not change it during this demonstration.

## 4:50–5:30 — Explain incentives honestly

Action: Open Rewards and point out its preview labeling and multi-source overview.

Say: “The incentive service previews a rule of ten eco-points per kilogram of month-over-month reduction. The Reduce tab previews points for a hypothetical alternative. Neither is a verified reward ledger. Points are not redeemable or transferable, and fewer logged activities alone do not prove a reduction.”

Expected: A reward preview, potentially zero depending on the local dataset and month. Do not promise a fixed reward amount.

## 5:30–6:15 — Close on the next milestone

Action: Return to the landing page or slide 10 of the deck.

Say: “The next work is validation: physical-device tracking, factor review, coverage and baselines, and a real user pilot. Connected utility, purchase, flight and waste services, background tracking and verified rewards are roadmap work. The foundation is here to explore; the next discussion is what evidence makes the pilot useful and trustworthy.”

## Recovery and presenter boundaries

- If the app fails to load, retry once and use the deck with an explicit statement that the live demo is unavailable. Do not present a deck as proof that a failed app works.
- If import fails, show the exact `record_id,date,kwh` header and explain the validation message; the manual-entry and comparison flow remains available.
- If local storage is unavailable, use a normal browser profile that permits storage. Do not delete a user's data as a troubleshooting shortcut.
- No claims of validated accuracy, customers, revenue, partners, patents or committed financing are supported by this walkthrough.
- The implemented native location bridge still requires physical-device testing; a browser demo does not validate native permissions, GPS accuracy, battery behavior or background transitions.

Source basis: `README.md`, `docs/DEMO_GUIDE.md`, `docs/ROADMAP.md`, `lib/main.dart`, `lib/features/automation_screen.dart`, `lib/services/phone_tracking.dart`, `examples/utility_readings.csv`.
