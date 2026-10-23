import 'dart:convert';
import 'dart:math' as math;

import 'carbon.dart';

class LocationSample {
  const LocationSample(this.latitude, this.longitude, this.accuracy, this.time);
  final double latitude, longitude, accuracy;
  final DateTime time;
  bool get usable =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180 &&
      accuracy.isFinite &&
      accuracy >= 0 &&
      accuracy <= 50;
  double distanceTo(LocationSample other) {
    double rad(double degrees) => degrees * math.pi / 180;
    final a =
        math.pow(math.sin(rad(other.latitude - latitude) / 2), 2) +
        math.cos(rad(latitude)) *
            math.cos(rad(other.latitude)) *
            math.pow(math.sin(rad(other.longitude - longitude) / 2), 2);
    return 6371000 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }
}

/// A summary only: raw coordinates are deliberately not persisted.
class ActivityCandidate {
  const ActivityCandidate({
    required this.id,
    required this.source,
    required this.start,
    required this.end,
    required this.quantity,
    required this.description,
    this.kind,
  });
  final String id, source, description;
  final DateTime start, end;
  final double quantity;
  final ActivityKind? kind;
  Activity confirm(ActivityKind selected) {
    if (kind == ActivityKind.electricity && selected != kind ||
        kind == null && selected.category != 'Travel') {
      throw ArgumentError('Choose a compatible activity type.');
    }
    return Activity(
      id: id,
      kind: selected,
      quantity: quantity,
      date: start,
      endDate: end,
      source: source,
      sourceId: id,
      note: 'Reviewed: $description',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'quantity': quantity,
    'description': description,
    'kind': kind?.name,
  };
  factory ActivityCandidate.fromJson(Map<String, dynamic> j) {
    final result = ActivityCandidate(
      id: j['id'] as String,
      source: j['source'] as String,
      start: DateTime.parse(j['start'] as String),
      end: DateTime.parse(j['end'] as String),
      quantity: (j['quantity'] as num).toDouble(),
      description: j['description'] as String,
      kind: j['kind'] == null
          ? null
          : ActivityKind.values.byName(j['kind'] as String),
    );
    if (!result.quantity.isFinite ||
        result.quantity <= 0 ||
        result.end.isBefore(result.start)) {
      throw const FormatException('Invalid saved candidate.');
    }
    return result;
  }
}

/// Heuristic segmentation, not a trained classifier. Never guesses car vs transit.
class TripDetector {
  LocationSample? _anchor, _start, _lastMovement;
  DateTime? _lastSeen;
  double _metres = 0;
  int rejected = 0;
  double get kilometres => _metres / 1000;
  ActivityCandidate? add(LocationSample sample) {
    if (!sample.usable ||
        (_lastSeen != null && !sample.time.isAfter(_lastSeen!))) {
      rejected++;
      return null;
    }
    ActivityCandidate? completed;
    if (_lastSeen != null &&
        sample.time.difference(_lastSeen!).inSeconds > 120) {
      completed = finish('Location gap; partial journey');
    }
    _lastSeen = sample.time;
    final anchor = _anchor;
    if (anchor == null) {
      _anchor = sample;
      return completed;
    }
    final seconds = sample.time.difference(anchor.time).inMilliseconds / 1000;
    final metres = anchor.distanceTo(sample);
    if (metres / seconds > 70) {
      rejected++;
      return completed;
    }
    final movementThreshold = math.max(
      10.0,
      math.max(anchor.accuracy, sample.accuracy),
    );
    if (metres < movementThreshold) {
      if (_lastMovement != null &&
          sample.time.difference(_lastMovement!.time).inSeconds >= 120) {
        completed ??= finish('Stopped for at least two minutes');
        _anchor = sample;
        _lastSeen = sample.time;
      }
      return completed;
    }
    _start ??= anchor;
    _lastMovement = sample;
    _metres += metres;
    _anchor = sample;
    return completed;
  }

  ActivityCandidate? finish([
    String reason = 'Tracking stopped; partial journey',
  ]) {
    final start = _start, end = _lastMovement;
    ActivityCandidate? result;
    if (start != null &&
        end != null &&
        _metres >= 100 &&
        end.time.difference(start.time).inSeconds >= 60) {
      final speed = _metres / end.time.difference(start.time).inSeconds * 3.6;
      result = ActivityCandidate(
        id: 'phone:${start.time.microsecondsSinceEpoch}:${end.time.microsecondsSinceEpoch}',
        source: 'phone-location',
        start: start.time,
        end: end.time,
        quantity: _metres / 1000,
        description:
            '$reason. Average ${speed.toStringAsFixed(1)} km/h. Confirm travel mode; speed alone cannot identify it.',
      );
    }
    _anchor = null;
    _start = null;
    _lastMovement = null;
    _lastSeen = null;
    _metres = 0;
    return result;
  }
}

/// Normalized utility export format. Rejects the entire import on invalid rows.
List<ActivityCandidate> parseUtilityCsv(String input, String account) {
  account = account.trim();
  if (account.isEmpty || account.length > 80) {
    throw const FormatException('Enter an account nickname (1–80 characters).');
  }
  if (input.length > 1000000) throw const FormatException('File exceeds 1 MB.');
  final lines = input
      .replaceFirst('\uFEFF', '')
      .split(RegExp(r'\r?\n'))
      .where((s) => s.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty || lines.first.trim() != 'record_id,date,kwh') {
    throw const FormatException('Expected header: record_id,date,kwh');
  }
  if (lines.length > 1001) {
    throw const FormatException('Import at most 1,000 readings at a time.');
  }
  final records = <String, ActivityCandidate>{};
  for (var i = 1; i < lines.length; i++) {
    final cells = lines[i].split(',').map((s) => s.trim()).toList();
    if (cells.length != 3 ||
        cells[0].isEmpty ||
        cells[0].length > 120 ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(cells[1])) {
      throw FormatException(
        'Invalid row ${i + 1}. Use record_id,YYYY-MM-DD,kwh. Quoted fields are not supported.',
      );
    }
    final date = DateTime.tryParse(cells[1]);
    final value = double.tryParse(cells[2]);
    if (date == null ||
        date.toIso8601String().substring(0, 10) != cells[1] ||
        value == null ||
        !value.isFinite ||
        value <= 0 ||
        value > 1000000 ||
        date.isAfter(DateTime.now())) {
      throw FormatException('Invalid date or kWh on row ${i + 1}.');
    }
    final id =
        'utility:${base64Url.encode(utf8.encode(jsonEncode([account, cells[0]])))}';
    final candidate = ActivityCandidate(
      id: id,
      source: 'utility-csv',
      start: date,
      end: DateTime(date.year, date.month, date.day + 1),
      quantity: value,
      description: '$account · ${cells[0]} · electricity reading',
      kind: ActivityKind.electricity,
    );
    final old = records[id];
    if (old != null && (old.quantity != value || old.start != date)) {
      throw FormatException('Conflicting record ID on row ${i + 1}.');
    }
    records[id] = candidate;
  }
  if (records.isEmpty) throw const FormatException('The file has no readings.');
  return records.values.toList();
}

bool overlaps(ActivityCandidate candidate, Activity activity) {
  final sameCategory = candidate.kind == ActivityKind.electricity
      ? activity.kind == ActivityKind.electricity
      : activity.kind.category == 'Travel';
  if (!sameCategory) return false;
  final end = activity.endDate ?? activity.date.add(const Duration(seconds: 1));
  return candidate.start.isBefore(end) && activity.date.isBefore(candidate.end);
}
