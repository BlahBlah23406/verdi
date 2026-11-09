# Verdi Ten Minute Pitch Speech

1294 spoken words. 135 words per minute plus 26 seconds of visual pauses.

## Slide 1 Verdi

0:00–0:45

Visual cue: Pause on the product name. Let the opening land.

I'm Shayaan Haq, the founder of Verdi. Most people can name a choice they would like to make more sustainably. The harder part is making that choice again tomorrow, understanding whether it mattered, and receiving something useful in return. Verdi connects personal activity to practical recommendations, rewards for supported reductions, and optional contributions. A second experience helps institutions understand the programs they support. Today, I want to show you where the product is, what a customer can actually do, and the evidence I want to earn next. This is a working pilot with a clearly labeled synthetic demo.

## Slide 2 The missing connection

0:45–1:30

Visual cue: Trace activity, understanding, incentive and the next choice.

Consider a commute. A bank statement might show a transit payment. A phone might record movement. A travel receipt might describe a journey. Consumers usually have to connect those pieces themselves. At the same time, an institution funding a sustainability program needs to know whether people participate and where the program can help. Verdi's starting problem is this gap between everyday evidence and a useful reason to act. Verdi brings the evidence together, makes the estimate understandable, and connects the experience to an incentive that can bring someone back.

## Slide 3 One product two experiences

1:30–2:20

Visual cue: Trace the shared evidence layer between the consumer and institution.

Verdi has two linked experiences. For a person, the question is simple: what can I do next, and what benefit could that unlock? For a program owner, the question is different: what are participants engaging with, and where should the program focus its resources? Both experiences use the same underlying activity database. Sharing remains a separate choice for the participant. Financial institutions are a potential distribution path as banking integration develops. The institutional product could support subscriptions, while sponsored offers could help fund the consumer incentive experience. Those are business hypotheses I still need to validate with buyers.

## Slide 4 A day with Verdi

2:20–3:20

Visual cue: Walk the audience through the screenshot and select each journey step. Allow eight seconds for the visual.

Here is the consumer experience. Alex is a fictional account in Verdi's demo, already connected to sample travel, home-energy, banking and device records. Alex sees the activity the app has observed, a reward balance, and a suggested next action. The account persists across refreshes. When a new travel receipt arrives, it enters a review queue. Alex can confirm it or dismiss it. Confirmation updates the activity journal and the relevant totals. For home electricity, a user can also import a utility CSV and review those readings. The aim is to make participation feel like a short, useful interaction. The current real-provider paths are narrower than the demo, and I show those limits openly rather than presenting fictional connections as live partners.

## Slide 5 The evidence behind the estimate

3:20–4:10

Visual cue: Tap the source, review and calculation stages. Point to the preserved factor version.

The calculation starts with physical activity evidence. The engine validates the quantity, keeps stable record identities, checks for duplicate or conflicting records, and preserves the factor used for the estimate. Verdi's current operational scope focuses on commuting and electricity, using pinned EPA factors and a labeled national electricity fallback. A bank payment alone does not establish distance or travel mode, so the engine does not turn spending into guessed mileage. It also keeps appliance readings from being added blindly on top of a whole-home meter. These choices matter because an incentive system needs a calculation I can explain. Verdi's estimates still have boundaries. They do not yet describe every product, flight or source in a person's full lifestyle footprint.

## Slide 6 A reason to return

4:10–5:05

Visual cue: Run the reward example once. Leave the simulation label visible.

This is the part that makes Verdi useful beyond an emissions total. The pilot can compare completed months with comparable daily travel and utility coverage. Missing records cannot earn a reduction reward. The program rule normalizes the length of the month and caps the points awarded. In the synthetic walkthrough, Alex earns six hundred and sixty-five points and redeems a two-hundred-point transit offer. The balance becomes four hundred and sixty-five, and that state persists in the ledger. These are simulated rewards, not delivered discounts or carbon credits. The next business test is whether an attractive, funded reward makes people return, and whether a program owner sees enough value to keep supporting it.

## Slide 7 Contributions on your terms

5:05–6:00

Visual cue: Use the round-up example and its monthly cap. Pause for five seconds.

Rewards are one part of the experience. Optional contributions are another. A customer may want to round up eligible purchases and direct that small amount toward a supported project. The current demo shows how that could work with a monthly cap. A twelve-dollar-and-forty-five-cent purchase creates a fifty-five-cent pledge. A whole-dollar purchase, a pending charge or a refund contributes zero under Verdi's current rule. The ledger handles repeated requests without multiplying the pledge. Today, this is a contribution simulation. The demo does not move money, retire offsets or promise tax deductions. Real settlement and project fulfillment require the right partners. Customers must remain in control.

## Slide 8 Insight for program owners

6:00–6:50

Visual cue: Move from the consumer to the institution screenshot and highlight the period selector.

Now look at the institutional side. A program owner can compare reporting periods, examine the mix of observed activity, and see how many consenting participants contribute. This report comes from the same database as the consumer experience. An analyst is restricted to their assigned organization. The current implementation suppresses reports and cells below a minimum cohort size. These basic safeguards need further validation. These reports describe participating accounts. They are not a complete corporate emissions inventory or proof that the program caused a reduction. The value I want to establish is practical: can this information help a campus or employer choose a better intervention and understand participation without exposing individual journals?

## Slide 9 A coach with a clear role

6:50–7:35

Visual cue: Show the journey comparison. Keep the computed scenario separate from the AI explanation.

The coaching layer helps a person interpret an action. For example, I can calculate a scenario that replaces part of a car journey with a comparable bus journey, then explain the assumptions and possible difference. I have implemented an Ollama Cloud connection for that explanation, with calculated guidance available if the model is unavailable. A live credentialed AI test is still pending. The model does not choose the emission factor, issue points or control money. Those decisions remain in code and the ledger. AI should make the next choice clearer. I do not want confident language to hide gaps in the underlying evidence.

## Slide 10 Where the product stands

7:35–8:20

Visual cue: Point to built capabilities first, then the remaining external dependencies.

There is a concrete foundation here today. I have Flutter consumer and institutional interfaces, a shared SQLite backend, persistent review and consent flows, and a reward ledger. The browser builds work, and Android and iOS Simulator builds succeed. Verdi's checks cover the calculation logic, duplicate handling, reward replay, concurrent redemption and access boundaries. I also have a server-side Plaid sync adapter for an already authorized account, tested against the provider protocol. That does not mean consumer onboarding or live utility and transit connections are finished. Physical-device tracking validation, trusted provider baselines, and real reward fulfillment remain important work. Verdi's next milestone is a reliable consented pilot that can produce evidence beyond a demonstration.

## Slide 11 Capital follows the next proof

8:20–9:15

Visual cue: Follow the three-stage funding timeline. The months are proposed windows, not commitments.

Verdi's funding plan follows those milestones. In an initial zero-to-three-month window, I would focus on integration readiness and pilot preparation. Potential support includes founder resources, student startup competitions and university entrepreneurship programs. The Dempsey Startup Competition is one route to explore, subject to founder eligibility and its application cycle. In a proposed three-to-six-month pilot window, I would pursue a paid design partnership or sponsored reward budget with a campus, employer or financial institution. After a pilot produces credible evidence of retention and buyer demand, I could approach angels or accelerators for a pre-seed round to expand the product. These are potential sources, not secured commitments. The timing should follow what I learn, rather than forcing a large raise ahead of the evidence.

## Slide 12 The next proof is a real pilot

9:15–10:00

Visual cue: Hold the closing screen for five seconds before questions.

The next proof for Verdi is whether this experience creates sustained value for both sides. Will people connect useful evidence, return to review it, and respond to a reward they care about? Will an institution pay for a program whose participation and evidence quality it can understand? I want to test those questions with a focused pilot, measure the results, and improve the product around what customers actually do. This is a working foundation for incentives and institutional insight, ready for a focused pilot. I am looking for pilot partners, relevant introductions, and investors who want to help me build that proof. Thank you.
