// Parses real, user-exported Green Button Download My Data without uploading XML.
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

import '../../domain/automation.dart';
import '../../domain/carbon.dart';
import '../../domain/data_source.dart';
import 'multi_source_adapter.dart';

const _atom = 'http://www.w3.org/2005/Atom';
const _espi = 'http://naesb.org/espi';

/// Real utility adapter. Connection means a file was supplied, not a live API.
/// Only incremental forward electricity energy intervals are supported.
class GreenButtonUtilityAdapter implements MultiSourceAdapter {
  GreenButtonUtilityAdapter({String? xml, String account = '', DateTime? now})
    : _readings = xml == null
          ? const []
          : parseGreenButtonXml(xml, account: account, now: now);

  final List<ActivityCandidate> _readings;
  @override
  String get sourceId => 'utility-green-button';
  @override
  String get displayName => 'Green Button utility file';
  @override
  String get sourceType => 'utility_green_button';
  @override
  TrackingFront get front => TrackingFront.home;
  @override
  String get description =>
      'Import a Green Button XML export from your utility. Parsed on this device.';
  @override
  bool get isConnected => _readings.isNotEmpty;
  // Arbitration priority only; this is not a measured accuracy claim.
  @override
  double get baseFidelity => 0.8;
  @override
  Future<List<ActivityCandidate>> fetchCandidates({DateTime? since}) async =>
      List.unmodifiable(
        _readings.where((r) => since == null || r.end.isAfter(since)),
      );
}

List<ActivityCandidate> parseGreenButtonXml(
  String input, {
  required String account,
  DateTime? now,
}) {
  account = account.trim();
  if (account.isEmpty || account.length > 80) {
    throw const FormatException('Enter an account nickname (1–80 characters).');
  }
  if (utf8.encode(input).length > 1000000) {
    throw const FormatException('Choose Green Button XML smaller than 1 MB.');
  }
  // No DTDs, entities, external requests, customer/account resources or raw XML
  // are retained. Namespace URIs, rather than vendor-specific prefixes, match.
  if (RegExp(r'<!\s*(DOCTYPE|ENTITY)', caseSensitive: false).hasMatch(input)) {
    throw const FormatException(
      'XML declarations with DTD/entities are unsupported.',
    );
  }
  final XmlDocument document;
  try {
    document = XmlDocument.parse(input);
  } on XmlException {
    throw const FormatException('Invalid Green Button XML.');
  }
  final entries = document.descendants
      .whereType<XmlElement>()
      .where((e) => e.name.local == 'entry' && e.namespaceUri == _atom)
      .toList();
  if (entries.isEmpty || entries.length > 10000) {
    throw const FormatException(
      'Expected an Atom feed with Green Button entries.',
    );
  }
  final types = <String, XmlElement>{};
  final meterTypes = <String, String>{};
  for (final entry in entries) {
    final type = _resource(entry, 'ReadingType');
    final meter = _resource(entry, 'MeterReading');
    if (type != null) {
      final self = _link(entry, 'self');
      if (self == null || types.containsKey(self)) {
        throw const FormatException(
          'ReadingType must have a unique self link.',
        );
      }
      types[self] = type;
    }
    if (meter != null) {
      final self = _link(entry, 'self');
      final related = _relatedReadingType(entry);
      if (self == null || related == null || meterTypes.containsKey(self)) {
        throw const FormatException(
          'MeterReading must link to one ReadingType.',
        );
      }
      meterTypes[self] = related;
    }
  }
  final records = <String, ActivityCandidate>{};
  var readingCount = 0;
  final deadline = (now ?? DateTime.now()).toUtc().add(
    const Duration(minutes: 5),
  );
  for (final entry in entries) {
    final block = _resource(entry, 'IntervalBlock');
    if (block == null) continue;
    // Linkage prevents applying the wrong multiplier/unit in multi-meter files.
    final meter = _link(entry, 'up');
    final type = types[meterTypes[meter]];
    if (meter == null || type == null) {
      throw const FormatException(
        'IntervalBlock has an unresolved MeterReading/ReadingType link.',
      );
    }
    if (_number(type, 'commodity') != 1 ||
        _number(type, 'kind') != 12 ||
        _number(type, 'uom') != 72 ||
        _number(type, 'flowDirection') != 1 ||
        _number(type, 'accumulationBehaviour') != 4) {
      throw const FormatException(
        'Only incremental forward electricity energy in Wh is supported. Cumulative, export, gas, power and reactive-energy readings are rejected.',
      );
    }
    final multiplier = _number(type, 'powerOfTenMultiplier');
    if (multiplier < -12 || multiplier > 12) {
      throw const FormatException('Unsupported energy multiplier.');
    }
    final meterHash = sha256.convert(utf8.encode(meter)).toString();
    for (final reading in _children(block, 'IntervalReading')) {
      if (++readingCount > 10000) {
        throw const FormatException('Import at most 10,000 intervals at once.');
      }
      final periods = _children(reading, 'timePeriod').toList();
      if (periods.length != 1) {
        throw const FormatException('Each reading requires one timePeriod.');
      }
      final seconds = _number(periods.single, 'start');
      final duration = _number(periods.single, 'duration');
      final value = _number(reading, 'value');
      if (seconds < 0 ||
          seconds > 253402300799 ||
          duration <= 0 ||
          duration > 2678400 ||
          value < 0) {
        throw const FormatException(
          'Invalid interval timestamp, duration or consumption.',
        );
      }
      final start = DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      );
      final end = start.add(Duration(seconds: duration));
      final kwh = value * math.pow(10, multiplier) / 1000;
      if (!kwh.isFinite || kwh > 1000000 || end.isAfter(deadline)) {
        throw const FormatException(
          'Invalid, future or excessive electricity reading.',
        );
      }
      if (kwh == 0) continue; // Zero usage produces no emissions activity.
      final id = 'green-button:$meterHash:$seconds:$duration';
      final qualities = _children(reading, 'ReadingQuality')
          .expand((q) => _children(q, 'quality'))
          .map((q) => q.innerText.trim())
          .toList();
      final candidate = ActivityCandidate(
        id: id,
        source: 'utility-green-button',
        start: start,
        end: end,
        quantity: kwh.toDouble(),
        kind: ActivityKind.electricity,
        description:
            '$account · Green Button electricity interval (review required)',
        metadata: {
          'sourceType': 'utility_green_button',
          'meterHash': meterHash,
          'importMethod': 'local_xml',
          'readingQuality': qualities,
          if (_children(type, 'defaultQuality').isNotEmpty)
            'defaultQuality': _children(
              type,
              'defaultQuality',
            ).single.innerText.trim(),
          'accuracyVerified': false,
        },
      );
      final old = records[id];
      if (old != null && old.quantity != candidate.quantity) {
        throw const FormatException(
          'Conflicting values for the same meter interval.',
        );
      }
      records[id] = candidate;
    }
  }
  if (readingCount == 0) {
    throw const FormatException(
      'No supported Green Button IntervalReading found.',
    );
  }
  final sorted = records.values.toList()
    ..sort((a, b) {
      final meters = (a.metadata['meterHash'] as String).compareTo(
        b.metadata['meterHash'] as String,
      );
      return meters == 0 ? a.start.compareTo(b.start) : meters;
    });
  for (var i = 1; i < sorted.length; i++) {
    final a = sorted[i - 1], b = sorted[i];
    if (a.metadata['meterHash'] == b.metadata['meterHash'] &&
        b.start.isBefore(a.end)) {
      throw const FormatException(
        'Overlapping meter intervals are unsupported (possible tariff/phase double count).',
      );
    }
  }
  return List.unmodifiable(sorted);
}

Iterable<XmlElement> _children(XmlElement parent, String name) => parent
    .childElements
    .where((e) => e.name.local == name && e.namespaceUri == _espi);

XmlElement? _resource(XmlElement entry, String name) {
  final contents = entry.childElements.where(
    (e) => e.name.local == 'content' && e.namespaceUri == _atom,
  );
  final resources = contents.expand((c) => _children(c, name)).toList();
  if (resources.length > 1) {
    throw const FormatException('Duplicate ESPI resource.');
  }
  return resources.firstOrNull;
}

String? _link(XmlElement entry, String relation) {
  final links = entry.childElements
      .where(
        (e) =>
            e.name.local == 'link' &&
            e.namespaceUri == _atom &&
            e.getAttribute('rel') == relation,
      )
      .map(_resourceHref)
      .toList();
  if (links.length > 1) {
    throw const FormatException('Ambiguous Atom resource linkage.');
  }
  return links.firstOrNull;
}

String? _relatedReadingType(XmlElement entry) {
  final links = entry.childElements
      .where(
        (e) =>
            e.name.local == 'link' &&
            e.namespaceUri == _atom &&
            e.getAttribute('rel') == 'related',
      )
      .map(_resourceHref)
      .where(
        (s) => RegExp(r'(^|/)ReadingType/[^/]+/?$').hasMatch(Uri.parse(s).path),
      )
      .toList();
  if (links.length > 1) {
    throw const FormatException('Ambiguous ReadingType linkage.');
  }
  return links.firstOrNull;
}

String _resourceHref(XmlElement link) {
  Uri? base;
  final lineage = [
    ...link.ancestors.whereType<XmlElement>().toList().reversed,
    link,
  ];
  for (final element in lineage) {
    // xml is a reserved prefix and need not have an explicit xmlns declaration.
    final value =
        element.getAttribute('xml:base') ??
        element.getAttribute(
          'base',
          namespace: 'http://www.w3.org/XML/1998/namespace',
        );
    if (value != null) {
      base = base == null ? Uri.parse(value) : base.resolve(value);
    }
  }
  final href = link.getAttribute('href');
  if (href == null || href.isEmpty) {
    throw const FormatException('Missing Atom link href.');
  }
  final uri = (base == null ? Uri.parse(href) : base.resolve(href))
      .normalizePath();
  if (!['https', 'http'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException(
      'Resource links require an absolute HTTP(S) URI or xml:base. Links are never fetched.',
    );
  }
  return uri.replace(fragment: '').toString();
}

int _number(XmlElement parent, String name) {
  final elements = _children(parent, name).toList();
  final value = elements.length == 1
      ? int.tryParse(elements.single.innerText.trim())
      : null;
  if (value == null) throw FormatException('Missing or invalid integer $name.');
  return value;
}
