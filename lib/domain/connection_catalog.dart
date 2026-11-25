// Overview: Describes researched connection routes without implying live authorization.
enum ConnectionRegion {
  redmond('Redmond'),
  greaterSeattle('Greater Seattle'),
  washington('Washington');

  const ConnectionRegion(this.label);
  final String label;
}

enum ConnectionReadiness {
  normalizedImport('Normalized file import available'),
  sampleNeeded('Import not available yet'),
  authorizationNeeded('Account connection not available yet'),
  contextOnly('Public context, not personal activity');

  const ConnectionReadiness(this.label);
  final String label;
}

class ConnectionOption {
  const ConnectionOption({
    required this.id,
    required this.name,
    required this.category,
    required this.region,
    required this.readiness,
    required this.evidence,
    required this.benefit,
    required this.access,
    required this.limit,
    required this.sourceUrl,
  });
  final String id, name, category, evidence, benefit, access, limit, sourceUrl;
  final ConnectionRegion region;
  final ConnectionReadiness readiness;
}

/// Rollout order, not guaranteed service areas. Always check the actual account.
const connectionCatalog = <ConnectionOption>[
  ConnectionOption(
    id: 'pse-electricity',
    name: 'PSE electricity',
    category: 'Home energy',
    region: ConnectionRegion.redmond,
    readiness: ConnectionReadiness.normalizedImport,
    evidence: 'Electricity use in kWh, meter and service dates.',
    benefit: 'Measures home electricity, including electric heating and home charging.',
    access: 'Download your own usage from myPSE → My usage → Green Button. Verdi currently accepts only daily data converted to record_id,date,kwh CSV in Auto track. Use a stable account nickname.',
    limit: 'A native PSE export has not been sample-tested. No live PSE sync is connected. Calculations use the existing US-average electricity factor, not PSE’s supply mix. Home charging must not be counted twice.',
    sourceUrl: 'https://www.pse.com/en/account-and-billing/time-of-use/tou-faq',
  ),
  ConnectionOption(
    id: 'pse-gas',
    name: 'PSE natural gas',
    category: 'Heating and cooking',
    region: ConnectionRegion.redmond,
    readiness: ConnectionReadiness.sampleNeeded,
    evidence: 'Therms, bill period and actual or estimated reading.',
    benefit: 'Closes the gap for gas heating, hot water and cooking.',
    access: 'Prepare a bill with usage and service dates; share only the fields needed for a future reviewed import.',
    limit: 'Gas import and gas factors are not available in the app. Electricity download support does not establish gas interval support. A dollar amount does not measure therms.',
    sourceUrl: 'https://www.pse.com/-/media/Project/PSE/Portal/Rate-documents/summ_gas_prices_2026_09_01.pdf',
  ),
  ConnectionOption(
    id: 'orca',
    name: 'ORCA card activity',
    category: 'Daily travel',
    region: ConnectionRegion.redmond,
    readiness: ConnectionReadiness.sampleNeeded,
    evidence: 'Tap time, location, agency and fare; journey distance still needs confirmation.',
    benefit: 'Helps confirm transit journeys alongside phone trip summaries.',
    access: 'myORCA documents activity exports for cards with full account access. Load Only access cannot view activity. Export only your own travel history.',
    limit: 'The importer needs a real sample before support can be claimed. A tap may not identify the destination. Top-ups and passes are not journeys. No public third-party account API has been verified.',
    sourceUrl: 'https://support.myorca.com/hc/en-us/articles/10010238382093-Navigating-myORCA-com',
  ),
  ConnectionOption(
    id: 'receipts',
    name: 'Food and purchase receipts',
    category: 'Food and goods',
    region: ConnectionRegion.redmond,
    readiness: ConnectionReadiness.sampleNeeded,
    evidence: 'Items, pack sizes, mass, quantities, price and returns.',
    benefit:
        'Distinguishes what you bought instead of guessing from a store name.',
    access: 'Use selected paper or digital receipts. Fred Meyer documents receipts in Purchase History in eligible markets. A future import should request individual files, not your entire mailbox.',
    limit: 'Receipt import and product factors are not available yet. Item count is not mass. Mixed baskets, restaurant meals, gifts and cash purchases need separate treatment. Match receipts to bank payments to avoid duplicates.',
    sourceUrl: 'https://www.fredmeyer.com/i/receipt',
  ),
  ConnectionOption(
    id: 'banking',
    name: 'Bank transactions',
    category: 'Purchases and services',
    region: ConnectionRegion.redmond,
    readiness: ConnectionReadiness.authorizationNeeded,
    evidence:
        'Posted amount, currency, merchant, category and transaction updates.',
    benefit: 'Finds purchases and services absent from receipts or activity records.',
    access: 'A future Plaid connection requires explicit account authorization, supported institutions and secure server-side credentials. Do not enter bank credentials in Verdi.',
    limit: 'No bank is connected. Spend estimates are coarse and need reviewed factors. Transfers, card repayments and top-ups are not consumption. Utility bills and physical journeys replace matching spend estimates.',
    sourceUrl: 'https://plaid.com/docs/api/products/transactions/',
  ),
  ConnectionOption(
    id: 'redmond-water',
    name: 'Redmond water and wastewater',
    category: 'Water',
    region: ConnectionRegion.redmond,
    readiness: ConnectionReadiness.sampleNeeded,
    evidence: 'Metered volume in the bill’s original unit and service period.',
    benefit: 'Adds water supply and treatment once suitable local factors are reviewed.',
    access: 'Use a utility statement. If water is included in rent, ask for the building’s usage and a clear allocation rather than treating your share as zero.',
    limit: 'No consumption API, importer or local water factor is implemented. Fixed service charges are not water volume. Account for hot-water energy only once.',
    sourceUrl: 'https://www.redmond.gov/448/Online-Utility-Payments',
  ),
  ConnectionOption(
    id: 'redmond-waste',
    name: 'Recology or your local hauler',
    category: 'Waste',
    region: ConnectionRegion.redmond,
    readiness: ConnectionReadiness.sampleNeeded,
    evidence: 'Service type, pickup schedule and weighed waste by material when available.',
    benefit: 'Helps separate landfill, compost and recycling habits.',
    access: 'Check your service address and bill. Recology serves Redmond city limits; nearby unincorporated addresses may have another hauler. A weighed diary is stronger evidence than cart size.',
    limit: 'No waste import or reviewed waste factors are available. Cart capacity is not disposed mass. Recycling benefits must not be subtracted as speculative credits from the footprint.',
    sourceUrl: 'https://www.redmond.gov/389/Recycling-Waste-Reduction',
  ),
  ConnectionOption(
    id: 'flights-lodging',
    name: 'Flights and lodging',
    category: 'Trips away',
    region: ConnectionRegion.redmond,
    readiness: ConnectionReadiness.sampleNeeded,
    evidence: 'Completed flight legs, cabin and passengers; stayed room-nights and sharing.',
    benefit: 'Includes occasional travel outside Washington that local daily tracking can miss.',
    access: 'Select an itinerary, boarding pass or hotel folio. Confirm travel actually happened and record cancellations separately.',
    limit: 'These imports and factors are not implemented. Booking date is not travel date, and fare alone is a weak substitute for distance. Count the stay or journey once across bookings, receipts and card charges.',
    sourceUrl: 'https://www.alaskaair.com/trips',
  ),
  ConnectionOption(
    id: 'city-light',
    name: 'Seattle City Light',
    category: 'Home energy',
    region: ConnectionRegion.greaterSeattle,
    readiness: ConnectionReadiness.sampleNeeded,
    evidence: 'Electricity use in kWh and 15-minute intervals where available.',
    benefit: 'Measures homes in its service area using their own meter data.',
    access: 'City Light documents usage exports through the Utility Services website. Use your service account and select the data you want to share.',
    limit: 'Native export compatibility and solar channels need a sample. No live account connection exists. Do not use City Light’s mix for a PSE household.',
    sourceUrl:
        'https://powerlines.seattle.gov/2023/12/06/new-energy-usage-view/',
  ),
  ConnectionOption(
    id: 'snopud',
    name: 'Snohomish PUD',
    category: 'Home energy',
    region: ConnectionRegion.greaterSeattle,
    readiness: ConnectionReadiness.sampleNeeded,
    evidence:
        'Electricity usage and billing history; water volume when applicable.',
    benefit: 'Extends household coverage into the PUD’s service area.',
    access: 'MySnoPUD documents usage charts and billing history. Begin with a customer statement or an export sample if available.',
    limit: 'A native export format and Green Button support have not been established here. No live connection or provider-specific parser is available.',
    sourceUrl: 'https://www.snopud.com/account/my-account/mysnopud-info/',
  ),
  ConnectionOption(
    id: 'chargepoint',
    name: 'ChargePoint charging',
    category: 'Driving and charging',
    region: ConnectionRegion.greaterSeattle,
    readiness: ConnectionReadiness.sampleNeeded,
    evidence: 'Charging-session kWh, time and location where supplied.',
    benefit: 'Finds off-home charging missing from the home electricity meter.',
    access: 'ChargePoint documents downloadable monthly statements in the app’s Charging Activity area.',
    limit: 'The statement format needs sample validation. No account is connected. Home charging is already inside home electricity; battery energy and wall energy can differ.',
    sourceUrl: 'https://www.chargepoint.com/drivers/support/faqs/how-do-i-check-my-chargepoint-charging-activity',
  ),
  ConnectionOption(
    id: 'regional-transit',
    name: 'Sound Transit and Metro routes',
    category: 'Daily travel',
    region: ConnectionRegion.greaterSeattle,
    readiness: ConnectionReadiness.contextOnly,
    evidence: 'Stops, routes, shapes, timetables and service updates.',
    benefit: 'Can help interpret confirmed phone or ORCA journeys.',
    access: 'Public agency feeds need no personal account. Matching precise journeys still requires user permission.',
    limit: 'A timetable does not prove you rode. Use individual agency feeds because the consolidated feed retires at the end of 2026. Link light rail cannot silently use the app’s commuter-rail factor.',
    sourceUrl: 'https://www.soundtransit.org/help-contacts/business-information/open-transit-data-otd/otd-downloads',
  ),
  ConnectionOption(
    id: 'tesla',
    name: 'Tesla vehicle data',
    category: 'Driving and charging',
    region: ConnectionRegion.greaterSeattle,
    readiness: ConnectionReadiness.authorizationNeeded,
    evidence: 'Supported vehicle, odometer and charging data under owner-approved scopes.',
    benefit: 'May improve vehicle energy and distance estimates for supported owners.',
    access: 'A registered third-party app and owner authorization are required. Only necessary read access should be requested.',
    limit: 'No Tesla account is connected. Exact field coverage, commercial access and a real vehicle must be tested. Other vehicles need other inputs; command permissions are unnecessary.',
    sourceUrl:
        'https://developer.tesla.com/docs/fleet-api/authentication/overview',
  ),
  ConnectionOption(
    id: 'other-utilities',
    name: 'Other Washington utilities',
    category: 'Home energy',
    region: ConnectionRegion.washington,
    readiness: ConnectionReadiness.sampleNeeded,
    evidence:
        'Billed kWh, meter channels, service dates and original water units.',
    benefit: 'Extends coverage provider by provider, starting with Tacoma.',
    access: 'Tacoma Public Utilities documents bills and usage views in MyAccount. Check your actual utility rather than choosing by postal city.',
    limit: 'A Washington label does not establish statewide compatibility. Tacoma, Avista and individual PUDs each need their own sample and authorization checks.',
    sourceUrl:
        'https://www.mytpu.org/payment-billing/ways-to-pay/about-myaccount/',
  ),
  ConnectionOption(
    id: 'ferries',
    name: 'Washington State Ferries',
    category: 'Trips away',
    region: ConnectionRegion.washington,
    readiness: ConnectionReadiness.contextOnly,
    evidence: 'Sailings, terminals, vessels and schedule times.',
    benefit: 'Can identify a route for a user-confirmed crossing.',
    access: 'A public schedule API is documented. Personal crossing evidence must come from the user, not from the schedule alone.',
    limit: 'No ferry importer or reviewed factor is implemented. Confirm walk-on or vehicle travel, occupants and actual boarding. Reservation and fare amounts are not passenger distance.',
    sourceUrl:
        'https://www.wsdot.wa.gov/ferries/api/schedule/documentation/rest.html',
  ),
];

List<ConnectionOption> connectionsThrough(ConnectionRegion region) =>
    connectionCatalog.where((c) => c.region.index <= region.index).toList();
