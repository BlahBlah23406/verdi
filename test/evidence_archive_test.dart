// Overview: Exercises revision persistence and cross-source/contained evidence accounting.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:verdi/data/evidence_archive_store.dart';
import 'package:verdi/domain/evidence_archive.dart';
import 'package:verdi/domain/footprint_ledger.dart';

class FailingPreferencesStore extends InMemorySharedPreferencesStore {
  FailingPreferencesStore() : super.empty();
  bool fail = false;
  bool throwsOnWrite = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (fail) {
      if (throwsOnWrite) throw StateError('Simulated disk failure.');
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  final start = DateTime.utc(2026, 10), end = DateTime.utc(2026, 11);
  FootprintEvidence evidence(
    String id, {
    double quantity = 100,
    String unit = 'kWh',
    String? key,
    DateTime? from,
    DateTime? to,
    double share = 1,
    bool reviewed = true,
    String method = 'location',
    EvidenceQuality quality = EvidenceQuality.measuredQuantity,
    FootprintSector sector = FootprintSector.electricity,
  }) => FootprintEvidence(
    id: id,
    source: 'test-account',
    coverageKey: key ?? id,
    sector: sector,
    start: from ?? start,
    end: to ?? end,
    boundary: 'generation',
    unit: unit,
    quantity: quantity,
    reviewed: reviewed,
    personalShare: share,
    quality: quality,
    factor: FootprintFactor(
      id: 'fixture',
      version: 'v1',
      sector: sector,
      unit: unit,
      boundary: 'generation',
      geography: 'test',
      dataYear: 2025,
      sourceUrl: 'https://example.org/fixture',
      gwpVersion: 'AR5-100yr',
      accountingMethod: method,
      kgCo2ePerUnit: 0.4,
    ),
  );
  EvidenceRevision revision(FootprintEvidence e, [int n = 1]) =>
      EvidenceRevision(
        ref: EvidenceRef(e.source, e.id, n),
        receivedAt: end,
        evidence: e,
      );
  EvidenceRelation link(
    EvidenceRevision a,
    EvidenceRevision b, {
    EvidenceRelationKind kind = EvidenceRelationKind.sameComponent,
    String id = 'match',
    int n = 1,
    bool reviewed = true,
  }) => EvidenceRelation(
    id: id,
    revision: n,
    from: a.ref,
    to: b.ref,
    kind: kind,
    reviewed: reviewed,
    reason: 'Synthetic reviewed reference fixture.',
  );
  FootprintReport report(EvidenceArchive a) => a.reconcile(
    start: start,
    end: end,
    expectedSectors: FootprintSector.values.toSet(),
  );
  double total(FootprintReport r) =>
      r.kgCo2eByBasis.values.fold(0, (a, b) => a + b);
  EvidenceArchive archive(
    List<EvidenceRevision> records, [
    List<EvidenceRelation> links = const [],
  ]) => EvidenceArchive().append(revisions: records, relations: links);

  test('factor and evidence snapshots roundtrip, corrected head retains prior revision', () {
    final old = revision(evidence('meter'));
    final correction = revision(evidence('meter', quantity: 120), 2);
    final a = archive([correction, old]);
    final restored = EvidenceArchive.fromJson(
      jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>,
    );
    expect(restored.revisions, hasLength(2));
    expect(restored.heads.values.single.ref.revision, 2);
    expect(total(report(restored)), 48);
    expect(restored.revisions.last.evidence!.quantity, 100);
    expect(() => restored.revisions.clear(), throwsUnsupportedError);
  });
  test(
    'replaying identical revision is idempotent; conflict rejects whole append',
    () {
      final r = revision(evidence('meter'));
      final a = archive([r, r]);
      expect(a.revisions, hasLength(1));
      expect(
        () => a.append(
          revisions: [
            revision(evidence('new')),
            revision(evidence('meter', quantity: 1)),
          ],
        ),
        throwsStateError,
      );
      expect(a.revisions, hasLength(1));
    },
  );
  test(
    'withdrawal removes only latest consumption, never adds negative emissions',
    () {
      final r = revision(evidence('meter'));
      final a = archive([
        r,
        EvidenceRevision(
          ref: EvidenceRef(r.ref.source, r.ref.id, 2),
          receivedAt: end,
        ),
      ]);
      expect(a.revisions, hasLength(2));
      expect(report(a).included, isEmpty);
      expect(report(a).missingSectors, contains(FootprintSector.electricity));
    },
  );
  test('reviewed cross-source match counts physical consumption once', () {
    final meter = revision(evidence('meter'));
    final bank = revision(
      evidence(
        'bank',
        quantity: 80,
        unit: 'USD-2022',
        quality: EvidenceQuality.spendEstimate,
      ),
    );
    final a = archive(
      [bank, meter],
      [link(bank, meter, kind: EvidenceRelationKind.supports)],
    );
    final r = report(a);
    expect(total(r), 40);
    expect(r.included.single.id, 'meter');
    expect(r.suppressed.single.id, 'bank');
    expect(r.issues, isEmpty);
  });
  test('disjoint matched periods cannot count the same component in different months', () {
    for (final kind in [
      EvidenceRelationKind.supports,
      EvidenceRelationKind.sameComponent,
    ]) {
      final meter = revision(evidence('meter'));
      final bank = revision(
        evidence(
          'bank',
          unit: 'USD',
          quality: EvidenceQuality.spendEstimate,
          from: DateTime.utc(2026, 11, 3),
          to: DateTime.utc(2026, 11, 4),
        ),
      );
      final a = archive([meter, bank], [link(bank, meter, kind: kind)]);
      for (final period in [start, end]) {
        final r = a.reconcile(
          start: period,
          end: DateTime.utc(period.year, period.month + 1),
        );
        expect(r.included, isEmpty);
        expect(
          r.issues.single.reason,
          contains('different sectors, boundaries or intervals'),
        );
      }
    }
  });
  test(
    'same-component alias cannot bypass review of stronger physical evidence',
    () {
      final meter = revision(evidence('meter', reviewed: false));
      final bank = revision(
        evidence('bank', unit: 'USD', quality: EvidenceQuality.spendEstimate),
      );
      final r = report(archive([meter, bank], [link(meter, bank)]));
      expect(r.included, isEmpty);
      expect(r.issues.single.reason, contains('no weaker fallback'));
    },
  );
  test('unreviewed matches stay unresolved; decision revision can approve', () {
    final a = revision(evidence('a')), b = revision(evidence('b'));
    final pending = archive([a, b], [link(a, b, reviewed: false)]);
    expect(report(pending).included, isEmpty);
    final approved = pending.append(relations: [link(a, b, n: 2)]);
    expect(approved.relations, hasLength(2));
    expect(total(report(approved)), 40);
  });
  test('source correction invalidates matching until re-reviewed against new revision', () {
    final a = revision(evidence('a')), b = revision(evidence('b'));
    final corrected = revision(evidence('a', quantity: 110), 2);
    final oldMatch = archive(
      [a, b],
      [link(a, b)],
    ).append(revisions: [corrected]);
    expect(report(oldMatch).included, isEmpty);
    final reviewed = oldMatch.append(relations: [link(corrected, b, n: 2)]);
    // Both sources are equally strong but now disagree: review cannot erase it.
    expect(report(reviewed).included, isEmpty);
    expect(report(reviewed).issues.single.reason, contains('equal quality'));
  });
  test(
    'related withdrawal does not silently count leftover supporting money',
    () {
      final meter = revision(evidence('meter'));
      final bank = revision(
        evidence('bank', unit: 'USD', quality: EvidenceQuality.spendEstimate),
      );
      final a =
          archive(
            [meter, bank],
            [link(bank, meter, kind: EvidenceRelationKind.supports)],
          ).append(
            revisions: [
              EvidenceRevision(
                ref: EvidenceRef(meter.ref.source, meter.ref.id, 2),
                receivedAt: end,
              ),
            ],
          );
      expect(report(a).included, isEmpty);
      expect(report(a).issues.single.reason, contains('revised or withdrawn'));
    },
  );
  test(
    'contained aliases cannot re-enter totals through another source record',
    () {
      final p = revision(evidence('home'));
      final c = revision(evidence('charging-record', quantity: 20));
      final alias = revision(evidence('vehicle-record', quantity: 20));
      final r = report(
        archive(
          [p, c, alias],
          [
            link(c, alias, id: 'aliases'),
            link(c, p, id: 'contains', kind: EvidenceRelationKind.containedIn),
          ],
        ),
      );
      expect(total(r), 40);
      expect(r.included.single.id, 'home');
      expect(
        r.suppressed.map((e) => e.id),
        containsAll(['charging-record', 'vehicle-record']),
      );
    },
  );
  test(
    'relationship revisions cannot silently replace a different source pair',
    () {
      final a = revision(evidence('a')),
          b = revision(evidence('b')),
          c = revision(evidence('c'));
      final original = archive([a, b, c], [link(a, b)]);
      expect(
        () => original.append(relations: [link(a, c, n: 2)]),
        throwsArgumentError,
      );
    },
  );
  test('conflicting or stronger oversized child alias cannot bypass containment validation', () {
    final p = revision(evidence('home'));
    final c = revision(
      evidence(
        'charging',
        quantity: 20,
        quality: EvidenceQuality.confirmedQuantity,
      ),
    );
    for (final quality in [
      EvidenceQuality.confirmedQuantity,
      EvidenceQuality.measuredQuantity,
    ]) {
      final alias = revision(
        evidence('vehicle', quantity: 200, quality: quality),
      );
      final r = report(
        archive(
          [p, c, alias],
          [
            link(c, alias, id: 'aliases'),
            link(c, p, id: 'contains', kind: EvidenceRelationKind.containedIn),
          ],
        ),
      );
      expect(r.included, isEmpty);
      expect(r.issues, isNotEmpty);
    }
  });
  test('containment and separation cannot contradict through an alias', () {
    final p = revision(evidence('home'));
    final c = revision(evidence('charging', quantity: 20));
    final alias = revision(evidence('vehicle', quantity: 20));
    final r = report(
      archive(
        [p, c, alias],
        [
          link(c, alias, id: 'aliases'),
          link(c, p, id: 'contains', kind: EvidenceRelationKind.containedIn),
          link(
            alias,
            p,
            id: 'distinct',
            kind: EvidenceRelationKind.separateComponent,
          ),
        ],
      ),
    );
    expect(r.included, isEmpty);
    expect(r.issues.any((e) => e.reason.contains('contradicts')), isTrue);
  });
  test('children aggregate against canonical parent across parent aliases', () {
    final p = revision(evidence('home-a')), q = revision(evidence('home-b'));
    final c = revision(
      evidence(
        'charging-a',
        quantity: 60,
        to: start.add(const Duration(days: 1)),
      ),
    );
    final d = revision(
      evidence(
        'charging-b',
        quantity: 60,
        from: start.add(const Duration(days: 1)),
      ),
    );
    final r = report(
      archive(
        [p, q, c, d],
        [
          link(p, q, id: 'aliases'),
          link(c, p, id: 'contains-a', kind: EvidenceRelationKind.containedIn),
          link(d, q, id: 'contains-b', kind: EvidenceRelationKind.containedIn),
        ],
      ),
    );
    expect(r.included, isEmpty);
    expect(r.issues.any((e) => e.reason.contains('exceed')), isTrue);
  });
  test('contained home EV electricity is retained for attribution, not added twice', () {
    final parent = revision(evidence('home'));
    final child = revision(
      evidence(
        'ev',
        sector: FootprintSector.travel,
        quantity: 20,
        from: start.add(const Duration(days: 1)),
        to: start.add(const Duration(days: 2)),
      ),
    );
    final external = revision(
      evidence('public-charging', sector: FootprintSector.travel, quantity: 10),
    );
    final r = report(
      archive(
        [child, parent, external],
        [link(child, parent, kind: EvidenceRelationKind.containedIn)],
      ),
    );
    expect(total(r), 44); // 100 household kWh + 10 external kWh, NOT 130.
    expect(
      r.included.map((e) => e.id),
      containsAll(['home', 'public-charging']),
    );
    expect(r.suppressed.single.id, 'ev');
    expect(r.issues, isEmpty);
  });
  test('incompatible containment share or accounting method is held', () {
    final parent = revision(evidence('home'));
    for (final e in [
      evidence('ev', quantity: 20, share: 0.5),
      evidence('ev', quantity: 20, method: 'supplier'),
    ]) {
      final child = revision(e);
      final r = report(
        archive(
          [parent, child],
          [link(child, parent, kind: EvidenceRelationKind.containedIn)],
        ),
      );
      expect(r.included, isEmpty);
      expect(r.issues, isNotEmpty);
    }
  });
  test('sum of nonoverlapping children cannot exceed parent', () {
    final parent = revision(evidence('home'));
    final a = revision(
      evidence('ev-a', quantity: 60, to: start.add(const Duration(days: 1))),
    );
    final b = revision(
      evidence('ev-b', quantity: 60, from: start.add(const Duration(days: 1))),
    );
    final r = report(
      archive(
        [parent, a, b],
        [
          link(a, parent, kind: EvidenceRelationKind.containedIn, id: 'a'),
          link(b, parent, kind: EvidenceRelationKind.containedIn, id: 'b'),
        ],
      ),
    );
    expect(r.included, isEmpty);
    expect(r.issues.any((e) => e.reason.contains('exceed')), isTrue);
  });
  test('overlapping child sessions are held even below parent quantity', () {
    final parent = revision(evidence('home'));
    final a = revision(evidence('ev-a', quantity: 20)),
        b = revision(evidence('ev-b', quantity: 20));
    final r = report(
      archive(
        [parent, a, b],
        [
          link(a, parent, kind: EvidenceRelationKind.containedIn, id: 'a'),
          link(b, parent, kind: EvidenceRelationKind.containedIn, id: 'b'),
        ],
      ),
    );
    expect(r.included, isEmpty);
    expect(r.issues.any((e) => e.reason.contains('overlap')), isTrue);
  });
  test(
    'competing parents hold the whole relationship regardless of input order',
    () {
      final a = revision(evidence('home-a')), b = revision(evidence('home-b'));
      final c = revision(evidence('ev', quantity: 20));
      final links = [
        link(c, a, kind: EvidenceRelationKind.containedIn, id: 'a'),
        link(c, b, kind: EvidenceRelationKind.containedIn, id: 'b'),
      ];
      for (final edges in [links, links.reversed.toList()]) {
        expect(report(archive([a, b, c], edges)).included, isEmpty);
      }
    },
  );
  test('a partial-period parent is not prorated or replaced by its child', () {
    final p = revision(
      evidence('home', from: start.subtract(const Duration(days: 1))),
    );
    final c = revision(evidence('ev', quantity: 20));
    final r = report(
      archive([p, c], [link(c, p, kind: EvidenceRelationKind.containedIn)]),
    );
    expect(r.included, isEmpty);
    expect(
      r.issues.any((e) => e.reason.contains('child is not counted')),
      isTrue,
    );
  });
  test(
    'same component rejects unequal intervals and contradictory separation',
    () {
      final a = revision(evidence('a')),
          b = revision(evidence('b', to: start.add(const Duration(days: 1))));
      expect(report(archive([a, b], [link(a, b)])).included, isEmpty);
      expect(
        report(
          archive(
            [a, b],
            [
              link(a, b),
              link(
                a,
                b,
                id: 'separate',
                kind: EvidenceRelationKind.separateComponent,
              ),
            ],
          ),
        ).included,
        isEmpty,
      );
    },
  );
  test(
    'unrelated reporting period does not report historical matching problems',
    () {
      final a = revision(evidence('a')), b = revision(evidence('b'));
      final r = archive(
        [a, b],
        [link(a, b, reviewed: false)],
      ).reconcile(start: DateTime.utc(2027), end: DateTime.utc(2027, 2));
      expect(r.issues, isEmpty);
    },
  );
  test('reconcile validates UTC reporting window', () {
    final a = archive([revision(evidence('a'))]);
    expect(
      () => a.reconcile(start: DateTime(2026, 10), end: end),
      throwsArgumentError,
    );
    expect(
      () => a.reconcile(start: end, end: start),
      throwsArgumentError,
    );
  });
  test('inverted supports direction where supporting outranks primary is held', () {
    final meter = revision(evidence('meter'));
    final bank = revision(
      evidence(
        'bank',
        quantity: 80,
        unit: 'USD-2022',
        quality: EvidenceQuality.spendEstimate,
      ),
    );
    // meter -> bank with kind supports is inverted (measured supporting spend).
    final r = report(
      archive(
        [meter, bank],
        [link(meter, bank, kind: EvidenceRelationKind.supports)],
      ),
    );
    expect(r.included, isEmpty);
    expect(
      r.issues.single.reason,
      contains('Supporting evidence cannot outrank its primary evidence'),
    );
  });
  test('containment across child aliases and parent aliases succeeds without false conflict', () {
    final p1 = revision(evidence('home-meter', quantity: 100));
    final p2 = revision(
      evidence(
        'home-bill',
        quantity: 100,
        quality: EvidenceQuality.confirmedQuantity,
      ),
    );
    final c1 = revision(evidence('ev-charger', quantity: 25));
    final c2 = revision(
      evidence(
        'ev-vehicle',
        quantity: 25,
        quality: EvidenceQuality.confirmedQuantity,
      ),
    );
    final r = report(
      archive(
        [p1, p2, c1, c2],
        [
          link(p1, p2, id: 'parent-match'),
          link(c1, c2, id: 'child-match'),
          link(c1, p1, id: 'contains-1', kind: EvidenceRelationKind.containedIn),
          link(c2, p2, id: 'contains-2', kind: EvidenceRelationKind.containedIn),
        ],
      ),
    );
    expect(r.issues, isEmpty);
    expect(r.included.single.id, 'home-meter');
    expect(total(r), 40);
    expect(
      r.suppressed.map((e) => e.id).toSet(),
      {'home-bill', 'ev-charger', 'ev-vehicle'},
    );
  });
  test('blocked child or parent in containment is not classified as suppressed', () {
    final p = revision(evidence('home', quantity: 100));
    final c = revision(evidence('ev', quantity: 20));
    final alias = revision(evidence('ev-alias', quantity: 20));
    final r = report(
      archive(
        [p, c, alias],
        [
          link(c, alias, id: 'aliases'),
          link(c, p, id: 'contains', kind: EvidenceRelationKind.containedIn),
          link(alias, p, id: 'contradict', kind: EvidenceRelationKind.separateComponent),
        ],
      ),
    );
    expect(r.included, isEmpty);
    expect(r.suppressed, isEmpty);
    expect(r.issues.map((i) => i.coverageKey).toSet(), {'home', 'ev'});
  });
  test('canonical issues are deduplicated under canonical coverage keys', () {
    final a = revision(evidence('a'));
    final b = revision(evidence('b'));
    final c = revision(evidence('c'));
    final r = report(
      archive(
        [a, b, c],
        [
          link(a, b, id: 'ab'),
          link(b, c, id: 'bc'),
          link(a, c, id: 'separate', kind: EvidenceRelationKind.separateComponent),
        ],
      ),
    );
    expect(r.included, isEmpty);
    expect(r.issues, hasLength(1));
    expect(r.issues.single.coverageKey, 'a');
  });
  test(
    'append validates references and source identities before changing archive',
    () {
      final a = revision(evidence('a')), b = revision(evidence('b'));
      expect(() => archive([a], [link(a, b)]), throwsArgumentError);
      expect(
        () =>
            EvidenceRevision(ref: a.ref, receivedAt: end, evidence: b.evidence),
        throwsArgumentError,
      );
      expect(
        () => EvidenceArchive.fromJson({'schema': 2}),
        throwsFormatException,
      );
    },
  );
  test('queued local appends preserve revisions, links and factor snapshots on reload', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = EvidenceArchiveStore(prefs);
    final a = revision(evidence('a')), b = revision(evidence('b'));
    await Future.wait([
      store.append(revisions: [a]),
      store.append(revisions: [b]),
    ]);
    await store.append(relations: [link(a, b)]);
    final reloaded = EvidenceArchiveStore(prefs).load();
    expect(reloaded.revisions, hasLength(2));
    expect(total(report(reloaded)), 40);
    expect(
      reloaded.relations.single.reason,
      'Synthetic reviewed reference fixture.',
    );
  });
  test('corrupt local state cannot be overwritten by append', () async {
    SharedPreferences.setMockInitialValues({
      EvidenceArchiveStore.key: 'broken',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = EvidenceArchiveStore(prefs);
    expect(store.load, throwsFormatException);
    await expectLater(
      store.append(revisions: [revision(evidence('a'))]),
      throwsFormatException,
    );
    expect(prefs.getString(EvidenceArchiveStore.key), 'broken');
    // A failed queued append does not poison a later retry after explicit repair.
    await prefs.setString(
      EvidenceArchiveStore.key,
      jsonEncode(EvidenceArchive().toJson()),
    );
    await store.append(revisions: [revision(evidence('a'))]);
    expect(store.load().revisions, hasLength(1));
  });
  test(
    'failed physical writes restore durable cache and permit corrected retries',
    () async {
      for (final throwFailure in [false, true]) {
        SharedPreferences.setMockInitialValues({});
        final backend = FailingPreferencesStore();
        SharedPreferencesStorePlatform.instance = backend;
        final prefs = await SharedPreferences.getInstance();
        final store = EvidenceArchiveStore(prefs);
        await store.append(revisions: [revision(evidence('original'))]);
        backend.fail = true;
        backend.throwsOnWrite = throwFailure;
        await expectLater(
          store.append(revisions: [revision(evidence('retry', quantity: 10))]),
          throwsStateError,
        );
        expect(store.load().revisions.single.ref.id, 'original');
        backend.fail = false;
        await store.append(
          revisions: [revision(evidence('retry', quantity: 20))],
        );
        expect(
          store.load().heads[('test-account', 'retry')]!.evidence!.quantity,
          20,
        );
        await prefs.reload();
        expect(store.load().revisions, hasLength(2));
      }
    },
  );
}
