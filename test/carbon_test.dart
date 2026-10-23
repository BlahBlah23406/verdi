// Overview: Checks emissions calculations, historical factors, reporting periods, and activity persistence.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:verdi/data/activity_store.dart';
import 'package:verdi/domain/carbon.dart';

void main() {
  const engine = CarbonEngine();
  Activity entry(String id, DateTime date, {double quantity = 10}) =>
      Activity(id: id, kind: ActivityKind.car, quantity: quantity, date: date);

  test('quantity and factor produce reproducible estimates', () {
    final activity = entry('a', DateTime(2026, 10, 1));
    expect(activity.emissions, closeTo(1.855226104549431, 1e-12));
    final restored = Activity.fromJson(activity.toJson());
    expect(restored.emissions, closeTo(1.855226104549431, 1e-12));
    expect(restored.factorVersion, 'us-epa-2025-v1');
    final historical = Activity(
      id: 'old',
      kind: ActivityKind.car,
      quantity: 10,
      date: DateTime(2025),
      factor: 0.5,
      factorVersion: 'old',
    );
    expect(Activity.fromJson(historical.toJson()).emissions, 5);
  });
  test('rejects invalid quantities and factors', () {
    for (final n in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => entry('a', DateTime(2026), quantity: n),
        throwsArgumentError,
      );
    }
    expect(
      () => Activity(
        id: 'a',
        kind: ActivityKind.car,
        quantity: 1,
        date: DateTime(2026),
        factor: -1,
      ),
      throwsArgumentError,
    );
  });
  test('monthly windows exclude other months and duplicate IDs', () {
    final start = DateTime(2026, 10);
    final end = DateTime(2026, 11);
    final items = [
      entry('before', DateTime(2026, 9, 30)),
      entry('a', start),
      entry('a', start),
      entry('b', DateTime(2026, 10, 31)),
      entry('after', end),
    ];
    final period = engine.inPeriod(items, start, end);
    expect(period.map((a) => a.id), ['a', 'b']);
    expect(engine.total(period), closeTo(3.710452209098862, 1e-12));
    expect(
      engine.breakdown(period)['Travel'],
      closeTo(3.710452209098862, 1e-12),
    );
    expect(engine.total([]), 0);
    expect(() => engine.inPeriod([], end, start), throwsArgumentError);
  });
  test('travel scenarios and reward previews are deterministic', () {
    expect(
      engine.potentialTravelSaving(20, ActivityKind.train),
      closeTo(2.045388680108168, 1e-10),
    );
    expect(engine.previewPoints(3.29), 32);
    expect(engine.previewPoints(0), 0);
    expect(() => engine.previewPoints(-1), throwsArgumentError);
    expect(
      () => engine.potentialTravelSaving(20, ActivityKind.food),
      throwsArgumentError,
    );
  });
  test('local activities survive a new store instance and deletion', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = ActivityStore(prefs);
    expect(store.load(), isEmpty);
    await store.save([entry('a', DateTime(2026, 10, 1))]);
    expect(
      ActivityStore(prefs).load().single.emissions,
      closeTo(1.855226104549431, 1e-12),
    );
    await store.save([]);
    expect(ActivityStore(prefs).load(), isEmpty);
  });
  test('corrupted data is reported without overwriting it', () async {
    SharedPreferences.setMockInitialValues({ActivityStore.key: 'broken'});
    final prefs = await SharedPreferences.getInstance();
    expect(() => ActivityStore(prefs).load(), throwsFormatException);
    expect(prefs.getString(ActivityStore.key), 'broken');
  });
}
