# Verdi — VC Demo Guide

**One-page briefing for investor presentations**

---

## What Verdi Does

Verdi turns everyday activity into a clear picture of personal carbon emissions — and helps people reduce them. Users grant consent for phone sensors and utility data; Verdi detects journeys, imports electricity readings, and calculates emissions using EPA-sourced factors. Every estimate is traceable: users can see exactly how each number was derived.

**The core insight:** people want to reduce their footprint but can't see it. Verdi makes the invisible visible.

---

## Demo Flow (5 minutes)

1. **Open the app** → onboarding appears: welcome screen, select vehicle type (gasoline/hybrid/EV/diesel), set occupancy, choose electricity region (Pacific Northwest, California, Texas, Northeast, US average).
2. **Overview screen** → shows monthly CO₂e total with category breakdown (Travel, Home). Profile card shows selected settings. "Before vs After" visualization shows current footprint vs potential reduction.
3. **Tap "Log activity"** → add a car journey (e.g., 20 km). See it appear in the overview with emissions calculated in real-time.
4. **"Reduce" tab** → slide the distance slider, switch between car/bus/train/bicycle. See potential CO₂e savings and eco-points preview.
5. **"Auto track" tab** → shows the automatic detection pipeline: phone trip detection and utility data import with review queue.
6. **Settings** → change electricity region and watch factors update.

**Demo Mode:** Tap the demo button on the overview to load sample activities (car trips, electricity, bus commutes) for a populated demo without needing real GPS data.

---

## Market Opportunity

- **Consumer carbon tracking** is emerging as ESG pressures and climate awareness drive demand for personal accountability tools.
- **Regulatory tailwinds:** corporate ESG mandates create B2B2C opportunities — employers offer carbon tracking as a benefit.
- **Adjacent markets:** utility companies need customer engagement tools; EV adoption creates demand for comparative emissions visibility.
- **Data moat:** consented behavioral + consumption data enables personalized reduction recommendations, carbon offset matching, and aggregate insights.

---

## Traction & Technology

- **Working prototype** built in Flutter (cross-platform: iOS, Android, web).
- **EPA-sourced emission factors** (2025 Emission Factors Hub, eGRID 2023) — not made-up numbers.
- **Automatic tracking engine:** foreground phone trip detection with distance estimation, stop detection, and duplicate checking. Utility CSV import with validation and review queue.
- **Traceable calculations:** every activity stores its factor version, source, and metadata — fully auditable.
- **Regional electricity factors** for 4 US regions + national average.
- **Web build available** for browser-based demos — no install required.

---

## Roadmap

| Phase | Status | Key Milestones |
|-------|--------|----------------|
| **Pilot** | ✅ Current | US commuting + electricity, manual + auto tracking, web build |
| **Useful** | Next | Regional expansion, device validation, user pilot, baseline + coverage indicators |
| **Trusted** | Then | Auth, backend, connected accounts (utility/banking), background tracking |
| **Incentives** | Then | Verified reductions, reward ledger, offset partnerships |
| **Scale** | Later | Business dashboards, subscriptions, partner reporting, org analytics |

---

## Key Talking Points

- **"Automatic, not manual."** The core product is passive tracking — phone sensors + utility data. Manual logging is the fallback, not the primary flow.
- **"Traceable by design."** Every emission number links back to its factor, source, and calculation. No black boxes.
- **"EPA factors, not guesses."** Using the EPA 2025 Emission Factors Hub — the same source regulators use.
- **"Cross-platform from day one."** Flutter gives us iOS, Android, and web from one codebase.
- **"Privacy-first architecture."** Data stays on-device in the prototype. Backend requires explicit consent and account deletion flows.
- **"Reductions, not just measurement."** The Reduce tab shows actionable alternatives — that's the path to behavior change.

---

## Serving the Demo

```bash
cd C:\Users\shaya\verdi-verify
flutter build web
cd build\web
python -m http.server 8080
# Open http://localhost:8080 in browser
```

---

*Verdi — small steps, lasting change.*
