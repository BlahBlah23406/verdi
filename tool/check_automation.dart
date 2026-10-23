import 'dart:io';

import 'package:verdi/domain/automation.dart';
import 'package:verdi/domain/carbon.dart';

void main() {
  var checks = 0;
  void check(bool result, String label) {
    if (!result) throw StateError(label);
    checks++;
  }

  void rejects(void Function() action, String label) {
    try {
      action();
    } on FormatException {
      checks++;
      return;
    }
    throw StateError(label);
  }

  final base = DateTime(2026, 1, 1, 12);
  LocationSample fix(int seconds, double lat, {double accuracy = 5}) =>
      LocationSample(lat, -122, accuracy, base.add(Duration(seconds: seconds)));
  final detector = TripDetector();
  detector.add(fix(0, 47));
  detector.add(fix(30, 47.001));
  detector.add(fix(60, 47.002));
  detector.add(fix(90, 47.003));
  final trip = detector.add(fix(210, 47.003));
  check(trip != null, 'Stationary stop closes trip');
  check(
    (trip!.quantity - 0.33358478).abs() < 0.00001,
    'Haversine distance reference',
  );
  check(trip.kind == null, 'Transport mode must not be invented');
  check(detector.kilometres == 0, 'Detector resets after completed trip');
  final accepted = trip.confirm(ActivityKind.bus);
  check(
    accepted.source == 'phone-location' &&
        accepted.endDate == base.add(const Duration(seconds: 90)),
    'Source and timing retained',
  );
  check(
    Activity.fromJson(accepted.toJson()).sourceId == trip.id,
    'Source identity survives activity persistence',
  );
  check(
    !trip.toJson().containsKey('latitude') &&
        !trip.toJson().containsKey('longitude'),
    'Summary has no coordinates',
  );
  check(
    ActivityCandidate.fromJson(trip.toJson()).quantity == trip.quantity,
    'Candidate roundtrip',
  );
  check(overlaps(trip, accepted), 'Overlapping trips flagged');
  check(
    !overlaps(
      trip,
      Activity(
        id: 'electricity',
        kind: ActivityKind.electricity,
        quantity: 1,
        date: base,
      ),
    ),
    'Different categories do not overlap',
  );
  final noisy = TripDetector();
  noisy.add(fix(0, 47));
  noisy.add(fix(60, 47.00001));
  noisy.add(fix(120, 47));
  check(noisy.finish() == null, 'Stationary jitter does not create trip');
  final invalid = TripDetector();
  invalid.add(fix(0, 47, accuracy: 100));
  invalid.add(fix(0, double.nan));
  check(invalid.rejected == 2, 'Reject inaccurate and invalid points');
  invalid.add(fix(0, 47));
  invalid.add(fix(0, 47.01));
  invalid.add(fix(1, 48));
  check(
    invalid.rejected == 4,
    'Reject duplicate timestamp and impossible jumps',
  );
  check(invalid.finish() == null, 'Bad samples do not create activity');
  final gaps = TripDetector();
  gaps.add(fix(0, 47));
  gaps.add(fix(60, 47.002));
  final partial = gaps.add(fix(240, 48));
  check(
    partial != null && partial.quantity < 0.3,
    'Signal gaps are not bridged',
  );
  check(gaps.finish() == null, 'Gap resets accumulation');
  final short = TripDetector();
  short.add(fix(0, 47));
  short.add(fix(10, 47.001));
  check(short.finish() == null, 'Short segments require minimum duration');

  const csv = 'record_id,date,kwh\nr1,2026-01-01,12.5\nr2,2026-01-02,10';
  final readings = parseUtilityCsv(csv, 'Home');
  check(
    readings.length == 2 && readings.first.quantity == 12.5,
    'Utility rows imported',
  );
  check(
    readings.first.id == parseUtilityCsv(csv, 'Home').first.id,
    'Stable reimport identity',
  );
  check(
    readings.first.id != parseUtilityCsv(csv, 'Office').first.id,
    'Distinct accounts isolated',
  );
  check(
    readings.first.confirm(ActivityKind.electricity).emissions > 0,
    'Imported reading flows into engine',
  );
  check(
    parseUtilityCsv('$csv\nr1,2026-01-01,12.5', 'Home').length == 2,
    'Duplicate rows deduplicated',
  );
  rejects(
    () => parseUtilityCsv('$csv\nr1,2026-01-01,13', 'Home'),
    'Conflicting duplicate rejected',
  );
  rejects(
    () => parseUtilityCsv('date,kwh\n2026-01-01,1', 'Home'),
    'Header validated',
  );
  rejects(() => parseUtilityCsv(csv, ''), 'Account required');
  for (final value in ['NaN', 'Infinity', '0', '-5', '1000001']) {
    rejects(
      () => parseUtilityCsv('record_id,date,kwh\nr,2026-01-01,$value', 'Home'),
      'Reject invalid kWh',
    );
  }
  rejects(
    () => parseUtilityCsv('record_id,date,kwh\nr,2026-02-30,1', 'Home'),
    'Invalid calendar date',
  );
  rejects(
    () => parseUtilityCsv('record_id,date,kwh\nr,2099-01-01,1', 'Home'),
    'Future reading rejected',
  );
  check(
    parseUtilityCsv(
          '\uFEFFrecord_id,date,kwh\r\nr,2026-01-01,1\r\n',
          'Home',
        ).length ==
        1,
    'BOM and CRLF accepted',
  );
  final historical = Activity.fromJson({
    'id': 'old',
    'kind': 'car',
    'quantity': 1,
    'date': base.toIso8601String(),
    'note': '',
    'factor': 0.2,
    'factorVersion': 'illustrative-v1',
  });
  check(
    historical.source == 'manual' && historical.endDate == null,
    'Older records remain compatible',
  );
  stdout.writeln('$checks automation checks passed.');
}
