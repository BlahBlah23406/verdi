// Overview: Runs standalone calculation checks without the Flutter test runner.
// Direct checks for environments where Flutter test cannot open a local socket.
import 'dart:io';

import 'package:verdi/domain/carbon.dart';

void main() {
  var checks = 0;
  void check(bool valid, String description) {
    if (!valid) throw StateError(description);
    checks++;
  }

  void rejects(void Function() action, String description) {
    try {
      action();
    } on ArgumentError {
      checks++;
      return;
    }
    throw StateError(description);
  }

  const engine = CarbonEngine();
  final start = DateTime(2026, 10);
  final end = DateTime(2026, 11);
  Activity entry(String id, DateTime date, {double quantity = 10}) =>
      Activity(id: id, kind: ActivityKind.car, quantity: quantity, date: date);
  final a = entry('a', start);
  check((a.emissions - 1.855226104549431).abs() < 1e-12, '10 km car estimate');
  check(
    (Activity.fromJson(a.toJson()).emissions - 1.855226104549431).abs() < 1e-12,
    'JSON round trip',
  );
  final old = Activity(
    id: 'old',
    kind: ActivityKind.car,
    quantity: 10,
    date: start,
    factor: 0.5,
    factorVersion: 'historical',
  );
  final restored = Activity.fromJson(old.toJson());
  check(
    restored.emissions == 5 && restored.factorVersion == 'historical',
    'Historical factor retention',
  );
  for (final value in [0.0, -1.0, double.nan, double.infinity]) {
    rejects(() => entry('invalid', start, quantity: value), 'Invalid quantity');
  }
  final period = engine.inPeriod(
    [
      entry('before', DateTime(2026, 9, 30)),
      a,
      a,
      entry('b', DateTime(2026, 10, 31)),
      entry('after', end),
    ],
    start,
    end,
  );
  check(period.length == 2, 'Month boundaries and duplicate IDs');
  check(
    (engine.total(period) - 3.710452209098862).abs() < 1e-12,
    'Aggregation',
  );
  check(
    (engine.breakdown(period)['Travel']! - 3.710452209098862).abs() < 1e-12,
    'Category breakdown',
  );
  check(engine.total([]) == 0, 'Empty data');
  rejects(() => engine.inPeriod([], end, start), 'Invalid period');
  check(
    (engine.potentialTravelSaving(20, ActivityKind.train) - 2.045388680108168)
            .abs() <
        1e-9,
    'Travel comparison',
  );
  check(engine.previewPoints(3.29) == 32, 'Reward rounding');
  check(engine.previewPoints(0) == 0, 'Zero reward');
  rejects(() => engine.previewPoints(-1), 'Negative reward');
  rejects(
    () => engine.potentialTravelSaving(2, ActivityKind.food),
    'Invalid alternative',
  );
  final legacy = Activity.fromJson({
    'id': 'legacy',
    'kind': 'car',
    'quantity': 10,
    'date': start.toIso8601String(),
    'note': '',
    'factor': 0.2,
    'factorVersion': 'illustrative-v1',
  });
  check(
    legacy.emissions == 2 && !legacy.isPilotEstimate,
    'Legacy values preserved and excluded',
  );
  check(
    Activity.fromJson(a.toJson()).factorMetadata['sourceTable'] == '10, 11',
    'Factor provenance survives persistence',
  );
  check(
    (ActivityKind.electricity.factor - 0.35163206270192).abs() < 1e-12,
    'Electricity pounds/MWh to kg/kWh and AR5 conversion',
  );
  check(
    (ActivityKind.bus.factor * 1.609344 - 0.0666323).abs() < 1e-12,
    'Bus passenger-mile reference vector',
  );
  check(ActivityKind.bicycle.factor == 0, 'Bicycle operational boundary');
  check(
    !ActivityKind.supported.contains(ActivityKind.food),
    'Unsupported spending excluded from catalog',
  );
  try {
    ActivityKind.food.factor;
    throw StateError('Unsupported factor must fail');
  } on UnsupportedError {
    checks++;
  }
  stdout.writeln('$checks algorithm checks passed.');
}
