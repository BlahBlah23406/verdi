"""Convert a Green Button Download My Data XML file into daily electricity evidence."""
from collections import defaultdict
from datetime import datetime, time, timedelta
from decimal import Decimal
import re
from xml.etree import ElementTree
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

NS = {'a': 'http://www.w3.org/2005/Atom', 'e': 'http://naesb.org/espi'}


def link(entry, rel):
    return next(
        (node.get('href', '').rstrip('/') for node in entry.findall('a:link', NS)
         if node.get('rel') == rel), '')


def daily_readings(document, timezone):
    """Accept one electric consumption meter and retain complete local days only."""
    if not isinstance(document, str) or re.search(r'<!\s*(?:DOCTYPE|ENTITY)', document, re.I):
        raise ValueError('Use a Green Button XML export without a document type.')
    try:
        zone = ZoneInfo(timezone)
        root = ElementTree.fromstring(document)
    except (ElementTree.ParseError, ZoneInfoNotFoundError, ValueError, TypeError):
        raise ValueError('Use a valid Green Button XML file and meter time zone.') from None
    if root.tag != f"{{{NS['a']}}}feed":
        raise ValueError('Expected a Green Button Atom XML feed.')

    entries = root.findall('a:entry', NS)
    meters = []
    reading_types = {}
    blocks = []
    for entry in entries:
        if entry.find('a:content/e:MeterReading', NS) is not None:
            meters.append(entry)
        reading_type = entry.find('a:content/e:ReadingType', NS)
        if reading_type is not None:
            reading_types[link(entry, 'self')] = reading_type
        block = entry.find('a:content/e:IntervalBlock', NS)
        if block is not None:
            blocks.append((entry, block))
    eligible = {}
    for entry in meters:
        related = [node.get('href', '').rstrip('/') for node in entry.findall('a:link', NS)
                   if node.get('rel') == 'related']
        for path in related:
            reading_type = reading_types.get(path)
            if reading_type is None:
                continue
            fields = {key: reading_type.findtext(f'e:{key}', namespaces=NS)
                      for key in ('uom', 'flowDirection', 'accumulationBehaviour')}
            if fields == {'uom': '72', 'flowDirection': '1', 'accumulationBehaviour': '4'}:
                meter_path = link(entry, 'self')
                if not meter_path or meter_path in eligible:
                    raise ValueError('The electricity meter must have one unambiguous reading type.')
                eligible[meter_path] = reading_type
    if len(eligible) != 1:
        raise ValueError('Export one electricity consumption meter with interval Wh readings.')
    meter_path, reading_type = next(iter(eligible.items()))
    try:
        exponent = int(reading_type.findtext('e:powerOfTenMultiplier', '0', NS))
        if not -12 <= exponent <= 12:
            raise ValueError
        scale = Decimal(10) ** (exponent - 3)
        by_day = defaultdict(dict)
        for entry, block in blocks:
            if link(entry, 'up') != f'{meter_path}/IntervalBlock':
                continue
            for reading in block.findall('e:IntervalReading', NS):
                start = int(reading.findtext('e:timePeriod/e:start', namespaces=NS))
                duration = int(reading.findtext('e:timePeriod/e:duration', namespaces=NS))
                value = int(reading.findtext('e:value', namespaces=NS))
                if not 0 < duration <= 90000 or not 0 <= value <= 10**15:
                    raise ValueError
                day = datetime.fromtimestamp(start, zone).date()
                intervals = by_day[day]
                interval = (duration, value)
                if start in intervals and intervals[start] != interval:
                    raise ValueError
                intervals[start] = interval
    except (TypeError, ValueError, OverflowError, OSError):
        raise ValueError('The file has invalid or conflicting electricity intervals.') from None

    records = []
    for day, intervals in sorted(by_day.items()):
        cursor = int(datetime.combine(day, time.min, zone).timestamp())
        try:
            end = int(datetime.combine(day + timedelta(days=1), time.min, zone).timestamp())
        except OverflowError:
            raise ValueError('The file contains an unsupported electricity reading date.') from None
        complete = True
        for start, (duration, _) in sorted(intervals.items()):
            if start < cursor or start + duration > end:
                raise ValueError('Electricity intervals overlap or cross a meter-day boundary.')
            complete = complete and start == cursor
            cursor = start + duration
        if complete and cursor == end:
            kwh = float(sum(value for _, value in intervals.values()) * scale)
            records.append({'id': f'green-button:{day}', 'day': day.isoformat(),
                            'kind': 'electricity', 'quantity': kwh,
                            'description': 'Green Button daily electricity'})
    if not records:
        raise ValueError('No complete electricity days found. Check the meter time zone and export range.')
    return records, len(by_day) - len(records)
