// Regression cases for unrelated sensors, confidence, identity and provenance.
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi/domain/automation.dart';
import 'package:verdi/domain/carbon.dart';
import 'package:verdi/domain/incentive_service.dart';
import 'package:verdi/services/multi_source/reconciliation_engine.dart';

ActivityCandidate candidate(
  String id,
  String source,
  ActivityKind? kind, {
  int offset = 0,
  Map<String, dynamic> metadata = const {},
}) => ActivityCandidate(
  id: id,
  source: source,
  start: DateTime(2026, 10, 1, 8, offset),
  end: DateTime(2026, 10, 1, 8, offset + 20),
  quantity: 10,
  description: 'evidence',
  kind: kind,
  confidence: .8,
  metadata: metadata,
);

void main() {
  const engine = ReconciliationEngine();
  test(
    'nested electricity meters cannot overwrite the whole-home boundary',
    () {
      expect(
        engine.reconcile([
          candidate('meter', 'utility', ActivityKind.electricity),
          candidate('charger', 'iot', ActivityKind.electricity),
        ]),
        hasLength(2),
      );
    },
  );
  test('separate records from one provider cannot merge', () {
    expect(
      engine.reconcile([
        candidate('a', 'transport', ActivityKind.bus),
        candidate('b', 'transport', ActivityKind.bus),
      ]),
      hasLength(2),
    );
  });
  test('flight and ground travel cannot merge', () {
    expect(
      engine.reconcile([
        candidate('a', 'transport', ActivityKind.flight),
        candidate('b', 'phone', ActivityKind.car),
      ]),
      hasLength(2),
    );
  });
  test('repeated correlated sources cannot fabricate high confidence', () {
    final a = candidate('a', 'phone', null),
        b = candidate('b', 'transport', ActivityKind.bus);
    final result = engine.reconcile([a, b]).single;
    expect(result.confidence, .8);
    expect(engine.reconcile([b, a]).single.id, result.id);
    final confirmed = result.confirm(ActivityKind.bus);
    expect(
      confirmed.factorMetadata['mergedCandidateIds'],
      containsAll(['a', 'b']),
    );
  });
  test('transitive time chain cannot collapse unrelated journeys', () {
    expect(
      engine.reconcile([
        candidate('a', 'phone', null),
        candidate('b', 'bank', ActivityKind.car, offset: 15),
        candidate('c', 'transport', ActivityKind.bus, offset: 30),
      ]),
      hasLength(2),
    );
  });
  test('missing current journal cannot create monthly reward', () {
    expect(
      const IncentiveService().computeMonthlyReward(
        currentMonth: [],
        previousMonth: [
          Activity(
            id: 'a',
            kind: ActivityKind.car,
            quantity: 100,
            date: DateTime(2026, 9, 1),
          ),
        ],
        now: DateTime(2026, 10, 8),
      ),
      isNull,
    );
    expect(
      () => const IncentiveService().previewTravelReward(
        potentialSavingKg: double.nan,
        date: DateTime(2026),
      ),
      throwsArgumentError,
    );
  });
  test('source metadata cannot overwrite the selected factor provenance', () {
    final entry = candidate(
      'a',
      'transport',
      ActivityKind.bus,
      metadata: {'kgCo2ePerUnit': 999, 'version': 'forged'},
    ).confirm(ActivityKind.bus);
    expect(entry.factorMetadata['kgCo2ePerUnit'], ActivityKind.bus.factor);
    expect(entry.factorMetadata['version'], ActivityKind.factorVersion);
  });
}
