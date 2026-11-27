"""Fictional Puget Sound pilot households for the synthetic regional demo.

Households, names and quantities are invented. Only public facts are real: which utility serves
each city, transit lines, stop names and flat adult fares. Sources checked 2026-11-26:
- Sound Transit fares: https://www.soundtransit.org/fares ($3.00 flat adult Link 1/2 Line since
  2024-08-30; T Line adult $2.00) and
  https://www.soundtransit.org/get-to-know-us/news-events/news-releases/link-1-2-line-fares-changing-august-30
- King County Metro fares: https://kingcounty.gov/en/dept/metro/fares-and-payment/prices ($3.00 adult
  from 2025-09-01)
- 2 Line Bellevue stations: https://www.soundtransit.org/system-expansion/wilburton-station and
  https://bellevuewa.gov/city-government/departments/transportation/projects/east-link-light-rail/station-frequently-asked-questions/bellevue-downtown-station
- 1 Line stations: https://www.soundtransit.org/1
- Route 269 / South Sammamish P&R: https://kingcounty.gov/en/dept/metro/rider-tools/parking-locations
  and https://www.sammamish.us/our-community/getting-around/bus/
- RapidRide F Line: https://kingcounty.gov/en/dept/metro/travel-options/bus/rapidride (Renton Transit
  Center, Tukwila Sounder Station)
- T Line: https://www.soundtransit.org/ride-with-us/stations/tacoma-link-light-rail-stations
- PSE (electric in King County except Seattle, Pierce County except Tacoma; gas in Pierce County incl.
  Tacoma): https://www.pse.com/about-us and https://wa.gov/health-safety/public-utilities
- Seattle City Light: https://www.seattle.gov/city-light/about-us/what-we-do
- Tacoma Power: https://www.mytpu.org/about-tpu/services/power/about-tacoma-power/
- Smartcar read-only vehicle telemetry (odometer in default metric km via read_odometer; EV battery
  state of charge % and range km via read_battery; scoped OAuth permissions):
  https://smartcar.com/docs/api-reference/get-odometer ,
  https://smartcar.com/docs/api-reference/evs/get-battery-level ,
  https://smartcar.com/docs/api-reference/permissions , and
  https://smartcar.com/docs/api-reference/signals/odometer
- Enode home EV charger telemetry and charging energy sessions (kWh; developer docs behind login at
  platform.enode.com): https://enode.com/ and https://platform.enode.com/docs
"""

LINK_FARE_CENTS = 300
METRO_FARE_CENTS = 300
T_LINE_FARE_CENTS = 200

LEGACY_SOURCES = ('utility', 'orca', 'bank')

BANK = {'label': 'Bank account',
        'description': 'Synthetic Plaid-style transactions; payments are never converted into carbon estimates.'}

PROFILES = (
    {'id': 'redmond', 'uid': 'redmond-demo', 'name': 'Cedar Household', 'city': 'Redmond',
     'region': 'Redmond, WA (NWPP)',
     'scenario': 'Townhouse with PSE electricity and gas; commutes on the Sound Transit 2 Line.',
     'sources': LEGACY_SOURCES,
     'utility': {'label': 'Puget Sound Energy',
                 'description': 'Daily electricity totals and monthly natural gas statements from PSE.',
                 'kwh': (16, 120), 'therms': (27, 420)},
     'transit': {'label': 'ORCA card',
                 'description': 'Tap-ons at Redmond 2 Line stations; no alighting or distance inferred.',
                 'agency': 'Sound Transit', 'line': '2 Line', 'fare_cents': LINK_FARE_CENTS,
                 'am': ('Downtown Redmond station', 'Marymoor Village station'),
                 'pm': ('Redmond Technology station', 'Overlake Village station')}},
    {'id': 'bellevue', 'uid': 'bellevue-demo', 'name': 'Alder Household', 'city': 'Bellevue',
     'region': 'Bellevue, WA (NWPP)',
     'scenario': 'Downtown condo with PSE electricity and gas; rides the 2 Line between Bellevue Downtown and Wilburton; optional read-only EV odometer and battery telemetry.',
     'sources': ('utility', 'orca', 'bank', 'vehicle'),
     'utility': {'label': 'Puget Sound Energy',
                 'description': 'Daily electricity totals and monthly natural gas statements from PSE.',
                 'kwh': (13, 90), 'therms': (18, 300)},
     'transit': {'label': 'ORCA card',
                 'description': 'Tap-ons at Bellevue 2 Line stations; no alighting or distance inferred.',
                 'agency': 'Sound Transit', 'line': '2 Line', 'fare_cents': LINK_FARE_CENTS,
                 'am': ('Bellevue Downtown station',), 'pm': ('Wilburton station',)},
     'vehicle': {'label': 'Connected EV telemetry',
                 'description': 'Optional read-only Smartcar-style odometer (km) and EV battery (%) snapshots; no GPS coordinates or vehicle commands.',
                 'optional': True, 'readOnly': True, 'units': ('km', '%'),
                 'base_km': 18420.0, 'weekday_km': (12, 230), 'weekend_km': (4, 160),
                 'soc': (46, 42), 'range_km': 420},
     'merchants': (('Synthetic Bellevue Market', 5640), ('Synthetic Roastery', 695),
                   ('Synthetic Home Goods', 2890), ('Synthetic Apothecary', 1625),
                   ('Synthetic Bistro', 3450))},
    {'id': 'sammamish', 'uid': 'sammamish-demo', 'name': 'Fir Household', 'city': 'Sammamish',
     'region': 'Sammamish, WA (NWPP)',
     'scenario': 'Detached house with PSE electricity and gas; commutes on King County Metro Route 269; optional read-only EV telemetry and supporting home charger sessions.',
     'sources': ('utility', 'orca', 'bank', 'vehicle', 'charger'),
     'utility': {'label': 'Puget Sound Energy',
                 'description': 'Daily electricity totals and monthly natural gas statements from PSE.',
                 'kwh': (22, 140), 'therms': (45, 500)},
     'transit': {'label': 'ORCA card',
                 'description': 'Tap-ons on King County Metro Route 269; no alighting or distance inferred.',
                 'agency': 'King County Metro', 'line': 'Route 269', 'fare_cents': METRO_FARE_CENTS,
                 'am': ('South Sammamish Park & Ride',), 'pm': ('Marymoor Village Station bus bay',)},
     'vehicle': {'label': 'Connected EV telemetry',
                 'description': 'Optional read-only Smartcar-style odometer (km) and EV battery (%) snapshots; no GPS coordinates or vehicle commands.',
                 'optional': True, 'readOnly': True, 'units': ('km', '%'),
                 'base_km': 31250.0, 'weekday_km': (28, 370), 'weekend_km': (10, 300),
                 'soc': (42, 46), 'range_km': 460},
     'charger': {'label': 'Home EV charger',
                 'description': 'Optional read-only Enode-style home charging sessions (kWh). Supporting detail only; overlaps the PSE electricity meter and is never added to totals.',
                 'optional': True, 'readOnly': True, 'supporting': True,
                 'overlaps': 'utility', 'addsToTotals': False, 'units': ('kWh',),
                 'kwh': (6, 125), 'kw': 7.2},
     'merchants': (('Synthetic Plateau Grocer', 7420), ('Synthetic Garden Supply', 3680),
                   ('Synthetic Coffee Stand', 625), ('Synthetic Pharmacy', 1840),
                   ('Synthetic Bakery', 1290))},
    {'id': 'seattle', 'uid': 'seattle-demo', 'name': 'Madrona Household', 'city': 'Seattle',
     'region': 'Seattle, WA (NWPP)',
     'scenario': 'All-electric Capitol Hill apartment on Seattle City Light; rides the 1 Line to Westlake.',
     'sources': LEGACY_SOURCES,
     'utility': {'label': 'Seattle City Light',
                 'description': 'Daily electricity totals from Seattle City Light; all-electric apartment, no gas service.',
                 'kwh': (8, 60), 'therms': None},
     'transit': {'label': 'ORCA card',
                 'description': 'Tap-ons at 1 Line stations; no alighting or distance inferred.',
                 'agency': 'Sound Transit', 'line': '1 Line', 'fare_cents': LINK_FARE_CENTS,
                 'am': ('Capitol Hill station',), 'pm': ('Westlake station',)},
     'merchants': (('Synthetic Corner Co-op', 3915), ('Synthetic Espresso Bar', 585),
                   ('Synthetic Bookshop', 1995), ('Synthetic Noodle Shop', 1750),
                   ('Synthetic Pharmacy', 1245))},
    {'id': 'renton', 'uid': 'renton-demo', 'name': 'Spruce Household', 'city': 'Renton',
     'region': 'Renton, WA (NWPP)',
     'scenario': 'Duplex with PSE electricity and gas; takes the RapidRide F Line between Renton and Tukwila.',
     'sources': LEGACY_SOURCES,
     'utility': {'label': 'Puget Sound Energy',
                 'description': 'Daily electricity totals and monthly natural gas statements from PSE.',
                 'kwh': (17, 110), 'therms': (30, 400)},
     'transit': {'label': 'ORCA card',
                 'description': 'Tap-ons on the King County Metro RapidRide F Line; no alighting or distance inferred.',
                 'agency': 'King County Metro', 'line': 'RapidRide F Line', 'fare_cents': METRO_FARE_CENTS,
                 'am': ('Renton Transit Center',), 'pm': ('Tukwila Sounder Station',)},
     'merchants': (('Synthetic Valley Market', 5180), ('Synthetic Hardware', 2495),
                   ('Synthetic Diner', 1860), ('Synthetic Bakery', 940),
                   ('Synthetic Pharmacy', 1410))},
    {'id': 'tacoma', 'uid': 'tacoma-demo', 'name': 'Hemlock Household', 'city': 'Tacoma',
     'region': 'Tacoma, WA (NWPP)',
     'scenario': 'Bungalow with Tacoma Power electricity and a separate PSE natural gas source; rides the T Line downtown.',
     'sources': ('utility', 'gas', 'orca', 'bank'),
     'utility': {'label': 'Tacoma Power',
                 'description': 'Daily electricity totals from Tacoma Power (electricity only; PSE natural gas is authorized separately).',
                 'kwh': (15, 100), 'therms': None},
     'gas': {'label': 'Puget Sound Energy gas',
             'description': 'Monthly natural gas statements from PSE, authorized and managed separately from Tacoma Power electricity.',
             'therms': (35, 450)},
     'transit': {'label': 'ORCA card',
                 'description': 'Tap-ons on the Sound Transit T Line; no alighting or distance inferred.',
                 'agency': 'Sound Transit', 'line': 'T Line', 'fare_cents': T_LINE_FARE_CENTS,
                 'am': ('Tacoma Dome Station',), 'pm': ('Union Station T Line stop',)},
     'merchants': (('Synthetic Harbor Grocer', 4460), ('Synthetic Hardware', 2040),
                   ('Synthetic Coffee House', 540), ('Synthetic Bakery', 895),
                   ('Synthetic Corner Mart', 1175))},
)

BY_ID = {p['id']: p for p in PROFILES}
BY_UID = {p['uid']: p for p in PROFILES}

_SOURCE_META_FIELDS = ('optional', 'readOnly', 'supporting', 'overlaps', 'addsToTotals', 'units')


def source_meta(profile, source_id):
    """Public metadata for one source on a household profile."""
    raw = {'utility': profile['utility'], 'gas': profile.get('gas'), 'orca': profile['transit'],
           'bank': profile.get('bank', BANK), 'vehicle': profile.get('vehicle'),
           'charger': profile.get('charger')}.get(source_id)
    if not raw:
        raise KeyError(source_id)
    meta = {'label': raw['label'], 'description': raw['description']}
    for field in _SOURCE_META_FIELDS:
        if field in raw:
            value = raw[field]
            meta[field] = list(value) if isinstance(value, tuple) else value
    return meta


def summary(profile):
    return {'id': profile['id'], 'name': profile['name'], 'city': profile['city'],
            'scenario': profile['scenario'], 'sources': list(profile['sources'])}
