// Overview: Checks reviewed utility readings become stable, replayable archive revisions.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:verdi/domain/automation.dart';
import 'package:verdi/domain/carbon.dart';
import 'package:verdi/domain/evidence_archive.dart';
import 'package:verdi/domain/footprint_ledger.dart';
import 'package:verdi/domain/utility_evidence_adapter.dart';

void main() {
  const pdt = Duration(hours: -7), pst = Duration(hours: -8);
  final october = (DateTime.utc(2026, 10), DateTime.utc(2026, 11));
  final received = DateTime.utc(2026, 11, 2, 12);
  FootprintFactor factor({
    String unit = 'kWh',
    String boundary = 'generation',
    FootprintSector sector = FootprintSector.electricity,
    double value = 0.4,
    String version = 'v1',
  }) => FootprintFactor(
    id: 'fixture-grid',
    version: version,
    sector: sector,
    unit: unit,
    boundary: boundary,
    geography: 'test',
    dataYear: 2025,
    sourceUrl: 'https://example.org/fixture',
    gwpVersion: 'AR5-100yr',
    accountingMethod: 'location',
    kgCo2ePerUnit: value,
  );
  final home = UtilityEvidenceAdapter(
    sourceNamespace: 'synthetic-meter:home-a',
    accountNickname: 'Home',
  );
  UtilityReadingReview review(
    int day, {
    int revision = 1,
    int? supersedes,
    String? key,
    UtilityReviewDecision decision = UtilityReviewDecision.approved,
    FootprintFactor? selected,
    double share = 0.5,
    int month = 10,
    Duration start = pdt,
    Duration end = pdt,
  }) {
    final (from, to) = civilDayInUtc(
      2026,
      month,
      day,
      offsetAtStart: start,
      offsetAtEnd: end,
    );
    return UtilityReadingReview(
      revision: revision,
      supersedes: supersedes,
      receivedAt: received,
      decision: decision,
      coverageKey: key ?? 'home-a:electricity:2026-$month-$day',
      serviceStart: from,
      serviceEnd: to,
      boundary: 'generation',
      quality: EvidenceQuality.measuredQuantity,
      factor: selected ?? factor(),
      personalShare: share,
    );
  }

  final rows = parseUtilityCsv(
    'record_id,date,kwh\nr-14,2026-10-14,10\nr-15,2026-10-15,12.5\n',
    'Home',
  );

  test('parsed rows become archive revisions with explicit choices', () {
    final change = home.reading(rows[1], review(15));
    final r = change.revision;
    expect(r.ref.source, 'synthetic-meter:home-a');
    expect(r.ref.id, 'r-15');
    expect(r.ref.revision, 1);
    expect(change.supersedes, isNull);
    final e = r.evidence!;
    expect(e.sector, FootprintSector.electricity);
    expect(e.unit, 'kWh');
    expect(e.quantity, 12.5);
    expect(e.personalShare, 0.5);
    expect(e.reviewed, isTrue);
    expect(e.coverageKey, 'home-a:electricity:2026-10-15');
    expect(e.factor!.toJson(), factor().toJson());
    expect(e.kgCo2e, closeTo(12.5 * 0.4 * 0.5, 1e-12));
  });

  test('identity is the namespace plus raw record ID, never the nickname', () {
    final renamed = parseUtilityCsv(
      'record_id,date,kwh\nr-15,2026-10-15,12.5\n',
      'Home, renamed',
    );
    final sameMeter = UtilityEvidenceAdapter(
      sourceNamespace: 'synthetic-meter:home-a',
      accountNickname: 'Home, renamed',
    );
    expect(
      sameMeter.reading(renamed.single, review(15)).revision.ref.key,
      home.reading(rows[1], review(15)).revision.ref.key,
    );
    // Re-parsing is deterministic.
    final again = parseUtilityCsv(
      'record_id,date,kwh\nr-15,2026-10-15,12.5\nr-14,2026-10-14,10\n',
      'Home',
    );
    expect(home.recordIdOf(again.first), 'r-15');

    // A candidate from another account cannot enter this namespace.
    final cabin = parseUtilityCsv(
      'record_id,date,kwh\nr-15,2026-10-15,3\n',
      'Cabin',
    );
    expect(() => home.reading(cabin.single, review(15)), throwsArgumentError);

    // The same raw ID under separate meters stays separate.
    final cabinAdapter = UtilityEvidenceAdapter(
      sourceNamespace: 'synthetic-meter:cabin-b',
      accountNickname: 'Cabin',
    );
    final archive = EvidenceArchive()
        .append(revisions: [home.reading(rows[1], review(15)).revision])
        .append(
          revisions: [
            cabinAdapter
                .reading(cabin.single, review(15, key: 'cabin-b:2026-10-15'))
                .revision,
          ],
        );
    expect(archive.heads.length, 2);
    expect(() => home.append(archive, []), returnsNormally);
    expect(
      () => home.append(EvidenceArchive(), [
        cabinAdapter.reading(cabin.single, review(15)),
      ]),
      throwsArgumentError,
    );
  });

  test('description text is ignored for identity', () {
    final row = rows[1];
    final misleading = ActivityCandidate(
      id: row.id,
      source: row.source,
      start: row.start,
      end: row.end,
      quantity: row.quantity,
      description: 'Cabin · r-99 · electricity reading',
      kind: row.kind,
    );
    expect(home.recordIdOf(misleading), 'r-15');
  });

  test('service interval is chosen explicitly in UTC', () {
    final e = home.reading(rows[1], review(15)).revision.evidence!;
    expect(e.start, DateTime.utc(2026, 10, 15, 7));
    expect(e.end, DateTime.utc(2026, 10, 16, 7));

    // A daylight-saving day has 25 hours with explicit offsets.
    final dst = parseUtilityCsv('record_id,date,kwh\nd,2026-11-01,9\n', 'Home');
    final fallBack = home
        .reading(dst.single, review(1, month: 11, end: pst))
        .revision
        .evidence!;
    expect(fallBack.end.difference(fallBack.start), const Duration(hours: 25));

    UtilityReadingReview interval(DateTime from, DateTime to) =>
        UtilityReadingReview(
          revision: 1,
          receivedAt: received,
          decision: UtilityReviewDecision.approved,
          coverageKey: 'k',
          serviceStart: from,
          serviceEnd: to,
          boundary: 'generation',
          quality: EvidenceQuality.measuredQuantity,
          factor: factor(),
          personalShare: 1,
        );
    // Local instants are refused even when they denote the same moment.
    expect(
      () => interval(
        DateTime.utc(2026, 10, 15, 7).toLocal(),
        DateTime.utc(2026, 10, 16, 7),
      ),
      throwsArgumentError,
    );
    // Wrong civil day, too long, or an impossible offset.
    for (final (from, to) in [
      (DateTime.utc(2026, 10, 14, 7), DateTime.utc(2026, 10, 15, 7)),
      (DateTime.utc(2026, 10, 15, 7), DateTime.utc(2026, 10, 17, 7)),
      (DateTime.utc(2026, 10, 15, 13), DateTime.utc(2026, 10, 16, 13)),
    ]) {
      expect(
        () => home.reading(rows[1], interval(from, to)),
        throwsArgumentError,
      );
    }
    expect(
      () => civilDayInUtc(
        2026,
        10,
        15,
        offsetAtStart: const Duration(hours: 15),
        offsetAtEnd: pdt,
      ),
      throwsArgumentError,
    );
    expect(
      () => civilDayInUtc(2026, 2, 30, offsetAtStart: pdt, offsetAtEnd: pdt),
      throwsArgumentError,
    );

    // A local day crossing a UTC month boundary is held, not prorated.
    final lastDay = parseUtilityCsv(
      'record_id,date,kwh\nend,2026-10-31,8\n',
      'Home',
    );
    final archive = home.append(EvidenceArchive(), [
      home.reading(lastDay.single, review(31)),
    ]);
    final report = archive.reconcile(start: october.$1, end: october.$2);
    expect(report.included, isEmpty);
    expect(report.issues.single.reason, contains('Split the evidence'));
  });

  test('incompatible factors fail closed', () {
    expect(
      () => review(15, selected: factor(unit: 'therm')),
      throwsArgumentError,
    );
    expect(
      () => review(15, selected: factor(sector: FootprintSector.heating)),
      throwsArgumentError,
    );
    expect(
      () => review(15, selected: factor(boundary: 'lifecycle')),
      throwsArgumentError,
    );
  });

  test('invalid or unnormalized inputs are rejected', () {
    final row = rows[1];
    ActivityCandidate variant({
      String? id,
      String? source,
      DateTime? start,
      DateTime? end,
      double? quantity,
      ActivityKind? kind = ActivityKind.electricity,
    }) => ActivityCandidate(
      id: id ?? row.id,
      source: source ?? row.source,
      start: start ?? row.start,
      end: end ?? row.end,
      quantity: quantity ?? row.quantity,
      description: row.description,
      kind: kind,
    );
    final bad = [
      variant(source: 'phone-location'),
      variant(kind: null),
      variant(kind: ActivityKind.car),
      variant(quantity: 0),
      variant(quantity: -1),
      variant(quantity: double.nan),
      variant(quantity: double.infinity),
      variant(
        start: DateTime.utc(2026, 10, 15),
        end: DateTime.utc(2026, 10, 16),
      ),
      variant(start: DateTime(2026, 10, 15, 1)),
      variant(end: DateTime(2026, 10, 17)),
      variant(id: 'phone:1:2'),
      variant(id: 'utility:not-base64!'),
      variant(id: 'utility:${base64Url.encode(utf8.encode('["Home"]'))}'),
      variant(
        id: 'utility:${base64Url.encode(utf8.encode('[ "Home","r-15"]'))}',
      ),
    ];
    for (final candidate in bad) {
      expect(
        () => home.reading(candidate, review(15)),
        throwsArgumentError,
        reason: candidate.id,
      );
    }
    for (final make in <void Function()>[
      () => review(15, revision: 0),
      () => review(15, revision: 2, supersedes: 2),
      () => review(15, share: 0),
      () => review(15, share: 1.5),
      () => review(15, share: double.nan),
      () => review(15, key: ' '),
      () => UtilityReadingReview(
        revision: 1,
        receivedAt: DateTime(2026, 11, 2),
        decision: UtilityReviewDecision.approved,
        coverageKey: 'k',
        serviceStart: DateTime.utc(2026, 10, 15, 7),
        serviceEnd: DateTime.utc(2026, 10, 16, 7),
        boundary: 'generation',
        quality: EvidenceQuality.measuredQuantity,
        factor: factor(),
        personalShare: 1,
      ),
      () => UtilityReadingReview(
        revision: 1,
        receivedAt: received,
        decision: UtilityReviewDecision.approved,
        coverageKey: 'k',
        serviceStart: DateTime.utc(2026, 10, 15, 7),
        serviceEnd: DateTime.utc(2026, 10, 16, 7),
        boundary: 'generation',
        quality: EvidenceQuality.spendEstimate,
        factor: factor(),
        personalShare: 1,
      ),
      () => UtilityEvidenceAdapter(
        sourceNamespace: 'utility-csv',
        accountNickname: 'Home',
      ),
      () => UtilityEvidenceAdapter(sourceNamespace: ' ', accountNickname: 'x'),
      () => UtilityEvidenceAdapter(sourceNamespace: 'm', accountNickname: ' '),
      () => home.withdrawal(
        recordId: 'r-15',
        revision: 1,
        supersedes: 1,
        receivedAt: received,
      ),
    ]) {
      expect(make, throwsArgumentError);
    }
  });

  test('unreviewed readings are archived but never counted', () {
    final pending = home.append(EvidenceArchive(), [
      home.reading(
        rows[1],
        review(15, decision: UtilityReviewDecision.pendingReview),
      ),
    ]);
    final report = pending.reconcile(start: october.$1, end: october.$2);
    expect(report.included, isEmpty);
    expect(report.issues.single.reason, 'Evidence requires review.');
    expect(report.kgCo2eByBasis, isEmpty);
  });

  test('archive JSON round trip preserves adapter output', () {
    final archive = home.append(EvidenceArchive(), [
      for (final (i, row) in rows.indexed) home.reading(row, review(14 + i)),
    ]);
    final restored = EvidenceArchive.fromJson(
      jsonDecode(jsonEncode(archive.toJson())) as Map<String, dynamic>,
    );
    expect(jsonEncode(restored.toJson()), jsonEncode(archive.toJson()));
    final a = archive.reconcile(start: october.$1, end: october.$2);
    final b = restored.reconcile(start: october.$1, end: october.$2);
    expect(b.kgCo2eByBasis, a.kgCo2eByBasis);
  });

  test('replay is idempotent; conflicting same revision fails atomically', () {
    final first = home.append(EvidenceArchive(), [
      home.reading(rows[1], review(15)),
    ]);
    final replay = home.append(first, [home.reading(rows[1], review(15))]);
    expect(replay.revisions.length, 1);
    // Different factor under the same revision number is a conflict.
    expect(
      () => home.append(first, [
        home.reading(rows[0], review(14)),
        home.reading(rows[1], review(15, selected: factor(value: 0.5))),
      ]),
      throwsStateError,
    );
    expect(first.revisions.length, 1);
    // A second first-observation for an existing record needs a predecessor.
    expect(
      () =>
          home.append(first, [home.reading(rows[1], review(15, revision: 2))]),
      throwsStateError,
    );
  });

  test('corrections need explicit current predecessors; links go stale', () {
    final bill = EvidenceRevision(
      ref: EvidenceRef('synthetic-bill:home-a', 'oct-15', 1),
      receivedAt: received,
      evidence: FootprintEvidence(
        id: 'oct-15',
        source: 'synthetic-bill:home-a',
        coverageKey: 'bill:2026-10-15',
        sector: FootprintSector.electricity,
        start: DateTime.utc(2026, 10, 15, 7),
        end: DateTime.utc(2026, 10, 16, 7),
        boundary: 'generation',
        unit: 'kWh',
        quantity: 12.5,
        quality: EvidenceQuality.confirmedQuantity,
        reviewed: true,
        factor: factor(),
        personalShare: 0.5,
      ),
    );
    var archive = home.append(EvidenceArchive(), [
      home.reading(rows[1], review(15)),
    ]);
    final meter = archive.heads.values.single;
    archive = archive.append(
      revisions: [bill],
      relations: [
        EvidenceRelation(
          id: 'meter-bill',
          from: meter.ref,
          to: bill.ref,
          kind: EvidenceRelationKind.sameComponent,
          reviewed: true,
          reason: 'Synthetic reviewed match.',
        ),
      ],
    );
    var report = archive.reconcile(start: october.$1, end: october.$2);
    expect(report.included.single.source, 'synthetic-meter:home-a');
    expect(report.suppressed.single.source, 'synthetic-bill:home-a');

    final corrected = parseUtilityCsv(
      'record_id,date,kwh\nr-15,2026-10-15,13\n',
      'Home',
    );
    // Revision 3 claiming to supersede a revision that never existed.
    expect(
      () => home.append(archive, [
        home.reading(corrected.single, review(15, revision: 3, supersedes: 2)),
      ]),
      throwsStateError,
    );
    archive = home.append(archive, [
      home.reading(corrected.single, review(15, revision: 2, supersedes: 1)),
    ]);
    expect(archive.heads[('synthetic-meter:home-a', 'r-15')]!.ref.revision, 2);
    expect(archive.revisions.where((r) => r.ref.id == 'r-15').length, 2);
    // Stale correction against revision 1 is refused.
    expect(
      () => home.append(archive, [
        home.reading(corrected.single, review(15, revision: 3, supersedes: 1)),
      ]),
      throwsStateError,
    );
    // Replaying revision 1 later does not change the head.
    archive = home.append(archive, [home.reading(rows[1], review(15))]);
    expect(archive.heads[('synthetic-meter:home-a', 'r-15')]!.ref.revision, 2);

    report = archive.reconcile(start: october.$1, end: october.$2);
    expect(report.included, isEmpty);
    expect(
      report.issues.map((i) => i.reason),
      contains(contains('revised or withdrawn')),
    );
  });

  test('withdrawal is explicit, not zero, and can be reinstated', () {
    var archive = home.append(EvidenceArchive(), [
      home.reading(rows[1], review(15)),
    ]);
    expect(
      () => home.append(archive, [
        home.withdrawal(
          recordId: 'missing',
          revision: 2,
          supersedes: 1,
          receivedAt: received,
        ),
      ]),
      throwsStateError,
    );
    final withdraw = home.withdrawal(
      recordId: home.recordIdOf(rows[1]),
      revision: 2,
      supersedes: 1,
      receivedAt: received,
    );
    expect(withdraw.isWithdrawal, isTrue);
    archive = home.append(archive, [withdraw]);
    var report = archive.reconcile(
      start: october.$1,
      end: october.$2,
      expectedSectors: {FootprintSector.electricity},
    );
    expect(report.included, isEmpty);
    expect(report.issues, isEmpty);
    expect(report.missingSectors, {FootprintSector.electricity});
    expect(archive.revisions.length, 2);
    expect(
      () => home.append(archive, [
        home.withdrawal(
          recordId: 'r-15',
          revision: 3,
          supersedes: 2,
          receivedAt: received,
        ),
      ]),
      throwsStateError,
    );
    archive = home.append(archive, [
      home.reading(rows[1], review(15, revision: 3, supersedes: 2)),
    ]);
    report = archive.reconcile(start: october.$1, end: october.$2);
    expect(report.included.single.id, 'r-15');
  });

  test('report attributes reviewed readings to their meter and factor', () {
    final archive = home.append(EvidenceArchive(), [
      for (final (i, row) in rows.indexed) home.reading(row, review(14 + i)),
    ]);
    final report = archive.reconcile(start: october.$1, end: october.$2);
    expect(report.issues, isEmpty);
    expect(report.included.map((e) => (e.source, e.id)).toSet(), {
      ('synthetic-meter:home-a', 'r-14'),
      ('synthetic-meter:home-a', 'r-15'),
    });
    expect(report.included.map((e) => e.factor!.id).toSet(), {'fixture-grid'});
    final totals = report.kgCo2eByBasis;
    expect(totals.keys.single, (
      boundary: 'generation',
      gwp: 'AR5-100yr',
      method: 'location',
    ));
    expect(totals.values.single, closeTo((10 + 12.5) * 0.4 * 0.5, 1e-12));
  });
}
