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
  check(a.emissions == 2, '10 km car estimate');
  check(Activity.fromJson(a.toJson()).emissions == 2, 'JSON round trip');
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
  check(engine.total(period) == 4, 'Aggregation');
  check(engine.breakdown(period)['Travel'] == 4, 'Category breakdown');
  check(engine.total([]) == 0, 'Empty data');
  rejects(() => engine.inPeriod([], end, start), 'Invalid period');
  check(
    (engine.potentialTravelSaving(20, ActivityKind.train) - 3.2).abs() < 1e-9,
    'Travel comparison',
  );
  check(engine.previewPoints(3.29) == 32, 'Reward rounding');
  check(engine.previewPoints(0) == 0, 'Zero reward');
  rejects(() => engine.previewPoints(-1), 'Negative reward');
  rejects(
    () => engine.potentialTravelSaving(2, ActivityKind.food),
    'Invalid alternative',
  );
  stdout.writeln('$checks algorithm checks passed.');
}
