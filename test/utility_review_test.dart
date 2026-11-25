// Overview: Checks reviewed utility planning, guarded archive appends, provenance and safe retries.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:verdi/data/evidence_archive_store.dart';
import 'package:verdi/data/utility_review_service.dart';
import 'package:verdi/data/utility_review_store.dart';
import 'package:verdi/domain/automation.dart';
import 'package:verdi/domain/evidence_archive.dart';
import 'package:verdi/domain/footprint_ledger.dart';
import 'package:verdi/domain/service_zone.dart';
import 'package:verdi/domain/utility_evidence_adapter.dart';
import 'package:verdi/domain/utility_review.dart';

/// Fails writes for keys ending in [failKey] while [fail] is set.
class KeyFailingStore extends InMemorySharedPreferencesStore {
  KeyFailingStore() : super.empty();
  bool fail = false, throws = false;
  String failKey = '';

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (fail && key.endsWith(failKey)) {
      if (throws) throw StateError('Simulated disk failure.');
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  final now = DateTime.utc(2026, 11, 3, 18);
  const csv =
      'record_id,date,kwh\nr-31,2026-10-31,9\nr-14,2026-10-14,10\n'
      'r-15,2026-10-15,12.5\n';
  final meter = UtilityReviewService.newMeter(
    label: 'Home',
    zoneId: ServiceZone.losAngeles.id,
    now: now,
    random: Random(1),
  );
  UtilityReviewChoices choices({
    double share = 0.5,
    EvidenceQuality quality = EvidenceQuality.confirmedQuantity,
    UtilityReviewDecision decision = UtilityReviewDecision.approved,
    bool confirm = false,
  }) => UtilityReviewChoices(
    zone: ServiceZone.losAngeles,
    factor: utilityFactorChoices.single,
    quality: quality,
    personalShare: share,
    decision: decision,
    reviewer: 'SH',
    reason: 'October bill check',
    consentAcknowledged: true,
    confirmCorrections: confirm,
  );
  UtilityImportPlan plan(
    EvidenceArchive archive, {
    String text = csv,
    UtilityReviewChoices? with_,
    String batch = 'batch-1',
  }) => planUtilityImport(
    csv: text,
    meter: meter,
    choices: with_ ?? choices(),
    archive: archive,
    now: now,
    batchId: batch,
  );
  Future<(SharedPreferences, UtilityReviewService)> open([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    return (
      prefs,
      UtilityReviewService(
        archive: EvidenceArchiveStore(prefs),
        reviews: UtilityReviewStore(prefs),
      ),
    );
  }

  test('meter identity is random, pseudonymous and validated', () {
    expect(meter.namespace, startsWith(utilityNamespacePrefix));
    expect(meter.namespace, isNot(contains('Home')));
    final other = UtilityReviewService.newMeter(
      label: 'Home',
      zoneId: ServiceZone.losAngeles.id,
      now: now,
    );
    expect(other.namespace, isNot(meter.namespace));
    expect(validateMeterLabel('PSE 1234 5678'), isNotNull);
    expect(validateMeterLabel('Apartment 4B'), isNull);
    expect(
      () => UtilityReviewService.newMeter(
        label: 'Home',
        zoneId: 'Europe/Paris',
        now: now,
      ),
      throwsArgumentError,
    );
    expect(
      () => UtilityReviewState([meter, other], const []),
      throwsArgumentError,
      reason: 'One identity per nickname',
    );
  });

  test(
    'review choices require explicit non-spend quality, consent, reviewer, reason and a valid share',
    () {
      UtilityReviewChoices make({
        bool consent = true,
        String reviewer = 'SH',
        String reason = 'r',
        double share = 1,
        EvidenceQuality quality = EvidenceQuality.confirmedQuantity,
      }) => UtilityReviewChoices(
        zone: ServiceZone.losAngeles,
        factor: utilityFactorChoices.single,
        quality: quality,
        personalShare: share,
        decision: UtilityReviewDecision.approved,
        reviewer: reviewer,
        reason: reason,
        consentAcknowledged: consent,
      );
      expect(() => make(consent: false), throwsArgumentError);
      expect(() => make(reviewer: ' '), throwsArgumentError);
      expect(() => make(reason: ''), throwsArgumentError);
      expect(() => make(share: 0), throwsArgumentError);
      expect(() => make(share: 1.01), throwsArgumentError);
      expect(
        () => make(quality: EvidenceQuality.spendEstimate),
        throwsArgumentError,
      );
      for (final q in utilityQualityChoices) {
        expect(make(quality: q).quality, q);
      }
      expect(make().personalShare, 1);
    },
  );

  test('preview resolves named-zone intervals and projects month accounting', () {
    final p = plan(EvidenceArchive());
    expect(p.count(UtilityRowStatus.added), 3);
    final oct15 = p.rows.firstWhere((r) => r.recordId == 'r-15').evidence!;
    expect(oct15.start, DateTime.utc(2026, 10, 15, 7));
    expect(oct15.end, DateTime.utc(2026, 10, 16, 7));
    expect(oct15.source, meter.namespace);
    expect(oct15.personalShare, 0.5);
    expect(p.baseline, isEmpty);
    // Oct 31 Pacific ends at 07:00Z Nov 1: crosses a UTC month, so it is held.
    expect(p.months, [DateTime.utc(2026, 10), DateTime.utc(2026, 11)]);
    final report = p.projected.reconcile(
      start: DateTime.utc(2026, 10),
      end: DateTime.utc(2026, 11),
    );
    expect(report.included, hasLength(2));
    expect(report.issues, hasLength(1));
    final kg = report.kgCo2eByBasis.values.single;
    expect(
      kg,
      closeTo(22.5 * 0.5 * utilityFactorChoices.single.kgCo2ePerUnit, 1e-9),
    );
    expect(p.batch.revisionKeys, hasLength(3));
  });

  test('unsupported dates are rejected per row, not guessed', () {
    final p = plan(
      EvidenceArchive(),
      text: 'record_id,date,kwh\nold,2006-06-01,4\nok,2026-10-14,10\n',
    );
    expect(p.count(UtilityRowStatus.rejected), 1);
    expect(
      p.rows.firstWhere((r) => r.recordId == 'old').problem,
      contains('supported only'),
    );
    expect(p.changes, hasLength(1));
  });

  test(
    'saving persists meter, provenance and archive atomically; reload, legacy batches and duplicates',
    () async {
      final (prefs, service) = await open();
      await service.save(plan(EvidenceArchive()));
      final reviews = UtilityReviewStore(prefs).load();
      expect(reviews.meters.single.namespace, meter.namespace);
      final batch = reviews.batches.single;
      expect(batch.reviewer, 'SH');
      expect(batch.consentVersion, utilityConsentVersion);
      expect(batch.zoneId, 'America/Los_Angeles');
      expect(batch.quality, EvidenceQuality.confirmedQuantity);
      expect(
        EvidenceArchiveStore(prefs).loadBatches().single.toJson(),
        batch.toJson(),
      );
      expect(prefs.getString(UtilityReviewStore.key), isNot(contains('Home ')));
      final archive = EvidenceArchiveStore(prefs).load();
      expect(archive.revisions, hasLength(3));
      expect(
        archive.revisions.map((r) => r.ref.key),
        unorderedEquals(batch.revisionKeys),
      );
      // Old persisted batches without a quality snapshot remain readable.
      final legacyBatchJson = Map<String, dynamic>.of(batch.toJson())
        ..remove('quality');
      final legacyBatch = UtilityReviewBatch.fromJson(legacyBatchJson);
      expect(legacyBatch.quality, isNull);
      // Same file again: everything already archived, nothing to save.
      final again = plan(archive, batch: 'batch-2');
      expect(again.count(UtilityRowStatus.unchanged), 3);
      expect(again.changes, isEmpty);
      await expectLater(service.save(again), throwsStateError);
      expect(UtilityReviewStore(prefs).load().batches, hasLength(1));
    },
  );

  test('corrections need confirmation and become new revisions, including quality changes', () async {
    final (prefs, service) = await open();
    await service.save(
      plan(
        EvidenceArchive(),
        with_: choices(quality: EvidenceQuality.modelEstimate),
      ),
    );
    final corrected =
        'record_id,date,kwh\nr-14,2026-10-14,11\nr-15,2026-10-15,12.5\n';
    final held = plan(
      EvidenceArchiveStore(prefs).load(),
      text: corrected,
      with_: choices(quality: EvidenceQuality.modelEstimate),
      batch: 'b2',
    );
    expect(held.count(UtilityRowStatus.correction), 1);
    expect(held.hasUnconfirmedCorrections, isTrue);
    expect(held.changes, isEmpty);
    await expectLater(service.save(held), throwsStateError);
    final confirmed = plan(
      EvidenceArchiveStore(prefs).load(),
      text: corrected,
      with_: choices(quality: EvidenceQuality.modelEstimate, confirm: true),
      batch: 'b2',
    );
    await service.save(confirmed);
    final archive = EvidenceArchiveStore(prefs).load();
    final head = archive.heads[(meter.namespace, 'r-14')]!;
    expect(head.ref.revision, 2);
    expect(head.evidence!.quantity, 11);
    expect(head.evidence!.quality, EvidenceQuality.modelEstimate);
    expect(archive.revisions.where((r) => r.ref.id == 'r-14'), hasLength(2));
    // A changed share or evidence quality is also a correction, never silent.
    final reshared = plan(
      archive,
      with_: choices(share: 1, quality: EvidenceQuality.modelEstimate),
      batch: 'b3',
    );
    expect(reshared.count(UtilityRowStatus.correction), 3);
    final upgradedQuality = plan(
      archive,
      with_: choices(
        quality: EvidenceQuality.measuredQuantity,
        confirm: true,
      ),
      batch: 'b4',
    );
    expect(upgradedQuality.count(UtilityRowStatus.correction), 3);
    await service.save(upgradedQuality);
    final afterUpgrade = EvidenceArchiveStore(prefs).load();
    expect(
      afterUpgrade.heads[(meter.namespace, 'r-15')]!.evidence!.quality,
      EvidenceQuality.measuredQuantity,
    );
    expect(
      EvidenceArchiveStore(prefs).loadBatches().last.quality,
      EvidenceQuality.measuredQuantity,
    );
  });

  test(
    'sameComponent normalized confirmedQuantity vs differing confirmed bill holds; explicit measured outranks weaker only when asserted',
    () {
      const singleDayCsv = 'record_id,date,kwh\nr-15,2026-10-15,10\n';
      final confirmedImport = plan(
        EvidenceArchive(),
        text: singleDayCsv,
        with_: choices(quality: EvidenceQuality.confirmedQuantity),
        batch: 'confirmed-import',
      );
      final importedRev = confirmedImport.changes.single.revision;
      final differingConfirmedBill = EvidenceRevision(
        ref: EvidenceRef('reviewed-bill:home', 'oct-15-bill', 1),
        receivedAt: now,
        evidence: FootprintEvidence(
          id: 'oct-15-bill',
          source: 'reviewed-bill:home',
          coverageKey: 'reviewed-bill:home:2026-10-15',
          sector: FootprintSector.electricity,
          start: importedRev.evidence!.start,
          end: importedRev.evidence!.end,
          boundary: utilityFactorChoices.single.boundary,
          unit: 'kWh',
          quantity: 12.5,
          quality: EvidenceQuality.confirmedQuantity,
          reviewed: true,
          factor: utilityFactorChoices.single,
          personalShare: 0.5,
        ),
      );
      final tiedArchive = confirmedImport.projected.append(
        revisions: [differingConfirmedBill],
        relations: [
          EvidenceRelation(
            id: 'csv-vs-bill',
            from: importedRev.ref,
            to: differingConfirmedBill.ref,
            kind: EvidenceRelationKind.sameComponent,
            reviewed: true,
            reason: 'Same service day on utility export and bill.',
          ),
        ],
      );
      final tiedReport = tiedArchive.reconcile(
        start: DateTime.utc(2026, 10),
        end: DateTime.utc(2026, 11),
      );
      expect(tiedReport.included, isEmpty);
      expect(
        tiedReport.issues.single.reason,
        contains('Conflicting evidence of equal quality; review required.'),
      );

      // Only when the reviewer explicitly asserts measuredQuantity (and re-links
      // the new revision) does the actual meter reading outrank the confirmed bill.
      final measuredCorrection = plan(
        tiedArchive,
        text: singleDayCsv,
        with_: choices(
          quality: EvidenceQuality.measuredQuantity,
          confirm: true,
        ),
        batch: 'measured-upgrade',
      );
      final measuredRev = measuredCorrection.changes.single.revision;
      final measuredArchive = measuredCorrection.projected.append(
        relations: [
          EvidenceRelation(
            id: 'csv-vs-bill',
            revision: 2,
            from: measuredRev.ref,
            to: differingConfirmedBill.ref,
            kind: EvidenceRelationKind.sameComponent,
            reviewed: true,
            reason: 'Confirmed CSV row is an actual meter reading.',
          ),
        ],
      );
      final measuredReport = measuredArchive.reconcile(
        start: DateTime.utc(2026, 10),
        end: DateTime.utc(2026, 11),
      );
      expect(measuredReport.issues, isEmpty);
      expect(measuredReport.included.single.source, meter.namespace);
      expect(measuredReport.included.single.quantity, 10);
      expect(measuredReport.suppressed.single.source, 'reviewed-bill:home');
    },
  );

  test(
    'stale preview fails when the meter head changes concurrently',
    () async {
      final (prefs, service) = await open();
      final base = EvidenceArchive();
      final first = plan(base, batch: 'a');
      final second = plan(
        base,
        text: 'record_id,date,kwh\nr-14,2026-10-14,10.5\n',
        batch: 'b',
      );
      await service.save(first);
      await expectLater(
        service.save(second),
        throwsA(isA<StaleEvidenceException>()),
      );
      expect(EvidenceArchiveStore(prefs).load().revisions, hasLength(3));
      expect(UtilityReviewStore(prefs).load().batches.map((b) => b.id), ['a']);
      // Concurrent saves from one store: exactly one baseline survives.
      final (prefs2, service2) = await open();
      Future<Object> attempt(UtilityImportPlan p) => service2
          .save(p)
          .then<Object>((_) => p.batchId, onError: (Object e) => e);
      final results = await Future.wait([
        attempt(plan(EvidenceArchive(), batch: 'x')),
        attempt(
          plan(
            EvidenceArchive(),
            text: 'record_id,date,kwh\nr-1,2026-10-01,3\n',
            batch: 'y',
          ),
        ),
      ]);
      expect(results.whereType<StaleEvidenceException>(), hasLength(1));
      final winner = results.whereType<String>().single;
      expect(
        EvidenceArchiveStore(prefs2).load().revisions,
        hasLength(winner == 'x' ? 3 : 1),
      );
      expect(UtilityReviewStore(prefs2).load().batches.single.id, winner);
    },
  );

  test(
    'appendUtility enforces predecessors even with a fresh baseline',
    () async {
      final (prefs, _) = await open();
      final store = EvidenceArchiveStore(prefs);
      final p = plan(EvidenceArchive());
      await store.appendUtility(
        adapter: p.adapter,
        changes: p.changes,
        baseline: p.baseline,
      );
      final current = store.load();
      // Forged change claiming a first observation of an existing record.
      final forged = p.adapter.reading(
        parseUtilityCsv(
          'record_id,date,kwh\nr-14,2026-10-14,99\n',
          'Home',
        ).single,
        UtilityReadingReview(
          revision: 2,
          receivedAt: now,
          decision: UtilityReviewDecision.approved,
          coverageKey: 'k',
          serviceStart: DateTime.utc(2026, 10, 14, 7),
          serviceEnd: DateTime.utc(2026, 10, 15, 7),
          boundary: utilityFactorChoices.single.boundary,
          quality: EvidenceQuality.measuredQuantity,
          factor: utilityFactorChoices.single,
          personalShare: 1,
        ),
      );
      await expectLater(
        store.appendUtility(
          adapter: p.adapter,
          changes: [forged],
          baseline: namespaceKeys(current, meter.namespace),
        ),
        throwsStateError,
      );
      expect(store.load().revisions, hasLength(3));
    },
  );

  test('raw revision append cannot bypass the reviewed utility path', () async {
    final (prefs, _) = await open();
    final store = EvidenceArchiveStore(prefs);
    final p = plan(EvidenceArchive());
    await expectLater(
      store.append(revisions: [p.changes.first.revision]),
      throwsArgumentError,
    );
    expect(prefs.getString(EvidenceArchiveStore.key), isNull);
    final outside = UtilityEvidenceAdapter(
      sourceNamespace: 'synthetic-meter:home-a',
      accountNickname: 'Home',
    );
    await expectLater(
      store.appendUtility(
        adapter: outside,
        changes: const [],
        baseline: const {},
      ),
      throwsArgumentError,
    );
  });

  test('corrupt archive, review records or batch receipts are never overwritten', () async {
    for (final key in [EvidenceArchiveStore.key, UtilityReviewStore.key]) {
      final (prefs, service) = await open({key: 'broken'});
      await expectLater(
        service.save(plan(EvidenceArchive())),
        throwsFormatException,
      );
      expect(prefs.getString(key), 'broken');
      if (key == EvidenceArchiveStore.key) {
        expect(prefs.getString(UtilityReviewStore.key), isNull);
        expect(EvidenceArchiveStore(prefs).loadBatches, throwsFormatException);
        expect(UtilityReviewStore(prefs).load, throwsFormatException);
      } else {
        expect(prefs.getString(EvidenceArchiveStore.key), isNull);
      }
    }
    // A corrupt receipt embedded inside the archive envelope is also preserved.
    final initial = plan(EvidenceArchive());
    final corruptEnvelope = jsonEncode({
      ...initial.projected.toJson(),
      'batches': [
        {
          ...initial.batch.toJson(),
          'revisionKeys': ['["verdi-utility:unknown","missing",1]'],
        },
      ],
    });
    final (prefs, service) = await open({
      EvidenceArchiveStore.key: corruptEnvelope,
    });
    expect(EvidenceArchiveStore(prefs).load, throwsFormatException);
    expect(EvidenceArchiveStore(prefs).loadBatches, throwsFormatException);
    expect(UtilityReviewStore(prefs).load, throwsFormatException);
    await expectLater(
      service.save(plan(EvidenceArchive(), batch: 'next')),
      throwsFormatException,
    );
    await expectLater(
      EvidenceArchiveStore(prefs).append(
        revisions: [
          EvidenceRevision(
            ref: EvidenceRef('external-source', 'rec-1', 1),
            receivedAt: now,
          ),
        ],
      ),
      throwsFormatException,
    );
    expect(prefs.getString(EvidenceArchiveStore.key), corruptEnvelope);
  });

  test(
    'failed writes are atomic across restart with fresh services and rebuilt plans',
    () async {
      for (final failing in [EvidenceArchiveStore.key, UtilityReviewStore.key]) {
        for (final throws in [false, true]) {
          SharedPreferences.setMockInitialValues({});
          final backend = KeyFailingStore()
            ..failKey = failing
            ..throws = throws;
          SharedPreferencesStorePlatform.instance = backend;
          final prefs = await SharedPreferences.getInstance();
          final service = UtilityReviewService(
            archive: EvidenceArchiveStore(prefs),
            reviews: UtilityReviewStore(prefs),
          );
          final p = plan(EvidenceArchive());
          backend.fail = true;
          await expectLater(service.save(p), throwsStateError);
          await prefs.reload();
          // Neither revisions nor batch receipts were committed.
          expect(EvidenceArchiveStore(prefs).load().revisions, isEmpty);
          expect(EvidenceArchiveStore(prefs).loadBatches(), isEmpty);
          expect(UtilityReviewStore(prefs).load().batches, isEmpty);

          // Simulate a full process restart with fresh stores/services and a
          // freshly rebuilt plan (new batch ID) after storage recovers.
          backend.fail = false;
          final restartedArchive = EvidenceArchiveStore(prefs);
          final restartedReviews = UtilityReviewStore(prefs);
          final restartedService = UtilityReviewService(
            archive: restartedArchive,
            reviews: restartedReviews,
          );
          final rebuilt = plan(restartedArchive.load(), batch: 'rebuilt-batch');
          expect(rebuilt.count(UtilityRowStatus.added), 3);
          await restartedService.save(rebuilt);
          await prefs.reload();
          expect(EvidenceArchiveStore(prefs).load().revisions, hasLength(3));
          expect(
            EvidenceArchiveStore(prefs).loadBatches().single.id,
            'rebuilt-batch',
          );
          expect(
            UtilityReviewStore(prefs).load().batches.single.id,
            'rebuilt-batch',
          );
          expect(
            jsonDecode(prefs.getString(UtilityReviewStore.key)!)['meters'],
            hasLength(1),
          );
        }
      }
    },
  );

  test(
    'ordinary raw archive appends preserve receipts and existing meters do not require review-store writes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final backend = KeyFailingStore()
        ..failKey = UtilityReviewStore.key
        ..throws = true;
      SharedPreferencesStorePlatform.instance = backend;
      final prefs = await SharedPreferences.getInstance();
      final archiveStore = EvidenceArchiveStore(prefs);
      final reviewStore = UtilityReviewStore(prefs);
      final service = UtilityReviewService(
        archive: archiveStore,
        reviews: reviewStore,
      );
      // Seed meter and a legacy batch in UtilityReviewStore.key before migration.
      final p1 = plan(
        EvidenceArchive(),
        text: 'record_id,date,kwh\nr-14,2026-10-14,10\n',
        batch: 'legacy-b1',
      );
      await archiveStore.appendUtility(
        adapter: p1.adapter,
        changes: p1.changes,
        baseline: p1.baseline,
      );
      await reviewStore.update((s) => s.withMeter(meter).withBatch(p1.batch));
      expect(reviewStore.load().batches.map((b) => b.id), ['legacy-b1']);

      // Now fail any write to UtilityReviewStore.key: saving a new batch for the
      // already-registered meter still succeeds because the authoritative
      // transaction writes only EvidenceArchiveStore.key and migrates legacy-b1.
      backend.fail = true;
      final p2 = plan(
        archiveStore.load(),
        text: 'record_id,date,kwh\nr-15,2026-10-15,12.5\n',
        batch: 'atomic-b2',
      );
      await service.save(p2);
      await prefs.reload();
      expect(
        archiveStore.loadBatches().map((b) => b.id),
        ['legacy-b1', 'atomic-b2'],
      );
      expect(
        reviewStore.load().batches.map((b) => b.id),
        ['legacy-b1', 'atomic-b2'],
      );

      // Ordinary raw append (non-utility revision and relation) preserves receipts.
      final importedEvidence = p2.changes.single.revision.evidence!;
      final validExternal = EvidenceRevision(
        ref: EvidenceRef('manual-bill', 'oct-15', 1),
        receivedAt: now,
        evidence: FootprintEvidence(
          id: 'oct-15',
          source: 'manual-bill',
          coverageKey: 'manual-bill:oct-15',
          sector: FootprintSector.electricity,
          start: importedEvidence.start,
          end: importedEvidence.end,
          boundary: importedEvidence.boundary,
          unit: 'kWh',
          quantity: 12.5,
          quality: EvidenceQuality.confirmedQuantity,
          reviewed: true,
          factor: utilityFactorChoices.single,
          personalShare: 0.5,
        ),
      );
      await archiveStore.append(
        revisions: [validExternal],
        relations: [
          EvidenceRelation(
            id: 'rel-1',
            from: p2.changes.single.revision.ref,
            to: validExternal.ref,
            kind: EvidenceRelationKind.sameComponent,
            reviewed: true,
            reason: 'Matched external bill.',
          ),
        ],
      );
      await prefs.reload();
      expect(archiveStore.load().revisions, hasLength(3));
      expect(archiveStore.load().relations, hasLength(1));
      expect(
        archiveStore.loadBatches().map((b) => b.id),
        ['legacy-b1', 'atomic-b2'],
      );
      expect(
        reviewStore.load().batches.map((b) => b.id),
        ['legacy-b1', 'atomic-b2'],
      );
    },
  );
}
