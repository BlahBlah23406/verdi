import 'package:flutter_test/flutter_test.dart';
import 'package:verdi/domain/footprint_ledger.dart';

// Synthetic factors verify accounting rules, not real provider intensities.
void main() {
  const generation = (
    boundary: 'generation',
    gwp: 'AR5-100',
    method: 'location',
  );
  const lifecycle = (boundary: 'lifecycle', gwp: 'AR5-100', method: 'location');
  final start = DateTime.utc(2026, 10);
  final end = DateTime.utc(2026, 11);
  FootprintFactor factor({
    String unit = 'kWh',
    String boundary = 'generation',
    double value = 0.4,
    String version = 'fixture-v1',
    String gwp = 'AR5-100',
    String method = 'location',
  }) => FootprintFactor(
    id: 'synthetic',
    version: version,
    sector: FootprintSector.electricity,
    unit: unit,
    boundary: boundary,
    geography: 'test only',
    dataYear: 2025,
    sourceUrl: 'https://example.org/synthetic',
    gwpVersion: gwp,
    accountingMethod: method,
    kgCo2ePerUnit: value,
  );
  FootprintEvidence evidence({
    String id = 'meter',
    String source = 'utility',
    String key = 'home-october-generation',
    double quantity = 100,
    String unit = 'kWh',
    String boundary = 'generation',
    EvidenceQuality quality = EvidenceQuality.measuredQuantity,
    bool reviewed = true,
    FootprintFactor? selected,
    bool missingFactor = false,
    double share = 1,
    DateTime? from,
    DateTime? to,
  }) => FootprintEvidence(
    id: id,
    source: source,
    coverageKey: key,
    sector: FootprintSector.electricity,
    start: from ?? start,
    end: to ?? end,
    boundary: boundary,
    unit: unit,
    quantity: quantity,
    quality: quality,
    reviewed: reviewed,
    factor: missingFactor ? null : selected ?? factor(),
    personalShare: share,
  );
  FootprintReport report(List<FootprintEvidence> input) =>
      const FootprintLedger().reconcile(
        input,
        start: start,
        end: end,
        expectedSectors: {FootprintSector.electricity, FootprintSector.food},
      );

  test(
    'meter replaces matched utility bank spend; household share applied once',
    () {
      final r = report([
        evidence(share: 0.5),
        evidence(
          id: 'bank',
          source: 'bank',
          unit: 'USD-2022',
          quantity: 50,
          quality: EvidenceQuality.spendEstimate,
          selected: factor(unit: 'USD-2022', value: 2),
        ),
      ]);
      expect(r.kgCo2eByBasis, {generation: 20});
      expect(r.suppressed.single.id, 'bank');
      expect(r.missingSectors, {FootprintSector.food});
    },
  );
  test('input order cannot change the chosen estimate', () {
    final records = [evidence(id: 'a'), evidence(id: 'b')];
    expect(report(records).included.single.id, 'a');
    expect(report(records.reversed.toList()).included.single.id, 'a');
    expect(
      report(records).kgCo2eByBasis,
      report(records.reversed.toList()).kgCo2eByBasis,
    );
  });
  test(
    'conflicting equal quality quantities require review rather than summing',
    () {
      final r = report([evidence(), evidence(id: 'second', quantity: 120)]);
      expect(r.included, isEmpty);
      expect(r.issues.single.reason, contains('equal quality'));
      expect(r.missingSectors, contains(FootprintSector.electricity));
    },
  );
  test('duplicate source identities cannot be remapped to count twice', () {
    final r = report([evidence(), evidence(key: 'another-home')]);
    expect(r.included, isEmpty);
    expect(r.issues, hasLength(2));
  });
  test('conflicting revision cannot hide behind a lower quality', () {
    final r = report([
      evidence(),
      evidence(quantity: 20, quality: EvidenceQuality.confirmedQuantity),
    ]);
    expect(r.included, isEmpty);
    expect(r.issues.single.reason, contains('identity'));
  });
  test('exact replay is idempotent', () {
    final r = report([evidence(), evidence()]);
    expect(r.kgCo2eByBasis[generation], 40);
    expect(r.included, hasLength(1));
    expect(r.suppressed, hasLength(1));
  });
  test(
    'missing factor on measured input cannot silently fall back to spend',
    () {
      final r = report([
        evidence(missingFactor: true),
        evidence(id: 'bank', quality: EvidenceQuality.spendEstimate),
      ]);
      expect(r.included, isEmpty);
      expect(r.issues.single.reason, contains('no spend fallback'));
    },
  );
  test('rejects incompatible factor units and boundaries', () {
    for (final f in [factor(unit: 'MWh'), factor(boundary: 'lifecycle')]) {
      final r = report([evidence(selected: f)]);
      expect(r.included, isEmpty);
      expect(r.issues, hasLength(1));
    }
  });
  test('unreviewed equal or stronger evidence prevents a weaker fallback', () {
    for (final quality in [
      EvidenceQuality.spendEstimate,
      EvidenceQuality.measuredQuantity,
    ]) {
      final r = report([
        evidence(reviewed: false, quality: quality),
        evidence(id: 'bank', quality: EvidenceQuality.spendEstimate),
      ]);
      expect(r.included, isEmpty);
      expect(r.issues.single.reason, contains('no weaker fallback'));
    }
    final accepted = report([
      evidence(),
      evidence(
        id: 'unreviewed-bank',
        reviewed: false,
        quality: EvidenceQuality.spendEstimate,
      ),
    ]);
    expect(accepted.included.single.id, 'meter');
  });
  test('does not combine lifecycle and operational into a headline number', () {
    final r = report([
      evidence(),
      evidence(
        id: 'food-energy',
        key: 'other-component',
        boundary: 'lifecycle',
        selected: factor(boundary: 'lifecycle', value: 0.6),
      ),
    ]);
    expect(r.kgCo2eByBasis, {generation: 40, lifecycle: 60});
  });
  test('partial reporting intervals are held, outside records excluded', () {
    final r = report([
      evidence(from: start.subtract(const Duration(days: 1))),
      evidence(
        id: 'old',
        from: DateTime.utc(2026, 8),
        to: DateTime.utc(2026, 9),
      ),
    ]);
    expect(r.included, isEmpty);
    expect(r.issues, hasLength(1));
    expect(r.issues.single.reason, contains('Split'));
  });
  test('canonical key cannot conflate a daily interval and a monthly bill', () {
    final r = report([
      evidence(),
      evidence(id: 'day', to: start.add(const Duration(days: 1))),
    ]);
    expect(r.included, isEmpty);
    expect(r.issues.single.reason, contains('intervals'));
  });
  test(
    'unreviewed evidence produces a gap; measured zero is valid evidence',
    () {
      expect(report([evidence(reviewed: false)]).included, isEmpty);
      final zero = report([evidence(quantity: 0)]);
      expect(zero.kgCo2eByBasis[generation], 0);
      expect(zero.missingSectors, isNot(contains(FootprintSector.electricity)));
    },
  );
  test('factor revisions conflict and provenance is preserved', () {
    final f = factor();
    expect(report([evidence(selected: f)]).included.single.factor, same(f));
    expect(
      report([
        evidence(),
        evidence(
          id: 'new',
          selected: factor(version: 'v2'),
        ),
      ]).included,
      isEmpty,
    );
  });
  test('different GWP sets and electricity methods have separate totals', () {
    final r = report([
      evidence(),
      evidence(
        id: 'other',
        key: 'other-event',
        selected: factor(gwp: 'AR6-100'),
      ),
      evidence(
        id: 'supplier',
        key: 'supplier-view',
        selected: factor(method: 'supplier'),
      ),
    ]);
    expect(r.kgCo2eByBasis, hasLength(3));
    expect(r.kgCo2eByBasis[generation], 40);
  });
  test('same-quality observations with different GWP basis require review', () {
    expect(
      report([
        evidence(),
        evidence(
          id: 'other',
          selected: factor(gwp: 'AR6-100'),
        ),
      ]).included,
      isEmpty,
    );
  });

  test('weaker reviewed observation with incompatible GWP or method is held', () {
    for (final altFactor in [
      factor(unit: 'USD-2022', gwp: 'AR6-100', value: 2),
      factor(unit: 'USD-2022', method: 'supplier', value: 2),
    ]) {
      final r = report([
        evidence(),
        evidence(
          id: 'bank',
          source: 'bank',
          unit: 'USD-2022',
          quantity: 20,
          quality: EvidenceQuality.spendEstimate,
          selected: altFactor,
        ),
      ]);
      expect(r.included, isEmpty);
      expect(
        r.issues.single.reason,
        contains('incompatible GWP sets or accounting methods'),
      );
    }
  });

  test('cross-period duplicate identity conflict is held in reporting window', () {
    final r = report([
      evidence(id: 'shared-id', key: 'october-component'),
      evidence(
        id: 'shared-id',
        key: 'november-component',
        quantity: 250,
        from: DateTime.utc(2026, 11),
        to: DateTime.utc(2026, 12),
      ),
    ]);
    expect(r.included, isEmpty);
    expect(r.issues.single.reason, contains('identity'));
  });

  test('tie-breaker compares source and ID tuples without colon ambiguity', () {
    final a = evidence(source: 'a:b', id: 'c');
    final b = evidence(source: 'a', id: 'b:c');
    expect(report([a, b]).included.single.source, 'a');
    expect(report([b, a]).included.single.source, 'a');
  });

  test('independent arithmetic and serialization roundtrip for factor and evidence', () {
    // 375.5 kWh * 0.35163206270192 kg/kWh * 0.25 share = 33.00945988614274 kg CO2e
    const rate = (771.5 + 0.057 * 28 + 0.008 * 265) * 0.45359237 / 1000;
    final f = factor(value: rate);
    final e = evidence(quantity: 375.5, share: 0.25, selected: f);
    final restored = FootprintEvidence.fromJson(e.toJson());
    expect(restored.factor!.sameValue(f), isTrue);
    expect(restored.kgCo2e, closeTo(33.00945988614274, 1e-12));
    final r = report([restored]);
    expect(r.kgCo2eByBasis[generation], closeTo(33.00945988614274, 1e-12));
  });

  test('invalid and overflowing values cannot enter totals', () {
    for (final q in [-1.0, double.nan, double.infinity]) {
      expect(() => evidence(quantity: q), throwsArgumentError);
    }
    for (final share in [0.0, -1.0, 1.1, double.nan]) {
      expect(() => evidence(share: share), throwsArgumentError);
    }
    expect(() => factor(value: -0.1), throwsArgumentError);
    expect(
      report([evidence(quantity: 1e308, selected: factor(value: 1e308))])
          .included,
      isEmpty,
    );
    expect(
      () => FootprintReport(
        [
          evidence(
            key: 'a',
            quantity: 1e308,
            selected: factor(value: 1),
          ),
          evidence(
            id: 'meter-2',
            key: 'b',
            quantity: 1e308,
            selected: factor(value: 1),
          ),
        ],
        const [],
        const [],
        const {},
      ).kgCo2eByBasis,
      throwsStateError,
    );
  });
}
