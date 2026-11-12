# Multi-source and institutional demo

All providers and people in this demo are simulated. No credentials, live
accounts, server-side identity or institutional access controls are configured.

1. Complete onboarding and enable VC Demo Mode on Overview.
2. Open Auto track and sync multi-source feeds. Utility, transit, smart device
   and banking adapters generate candidates; reconciliation combines matching
   signals and repeat syncs skip duplicates. Review and confirm candidates to
   add them to the personal journal. Banking estimates use sample inference
   rules and need user review.
3. Open Institutional Dashboard. The consent card calculates a report directly
   from four fictional reviewed personal journals using the same Activity model
   and stored emission factors as the personal app. Two journals initially
   consent; one can opt in interactively and one never consents.
4. Toggle sample member 1 sharing. The participant count and category totals
   update immediately. Turn it off to demonstrate withdrawal. Copy the report
   to inspect totals without individual IDs, transactions or journals.
5. Switch organizations to explore the larger illustrative scenarios, department
   breakdowns and monthly trends. Those preset scenarios are separate from the
   calculated consent cohort; they are not audited inventories.

The pure Dart InstitutionalAggregator filters by organization, current explicit
consent and a half-open reporting period. Withdrawal removes the entire journal
from subsequent reports. Duplicate activity IDs are counted once per member.
Legacy estimates are excluded. Period selection uses activity start dates.
Consent is in-memory sample state and resets when switching organizations or
reopening the dashboard. It is not a production consent ledger. Category totals
alone do not provide anonymity guarantees for small cohorts.

The charger sample represents a separate workplace meter so it is outside the
sample home utility boundary. Product estimates use placeholder factors.
