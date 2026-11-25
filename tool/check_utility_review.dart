// Independent normalized electricity acceptance checks; runnable without Flutter sockets.
import 'dart:io';

import 'package:verdi/domain/evidence_archive.dart';
import 'package:verdi/domain/footprint_ledger.dart';
import 'package:verdi/domain/service_zone.dart';
import 'package:verdi/domain/utility_evidence_adapter.dart';
import 'package:verdi/domain/utility_review.dart';

void main() {
  var checks = 0;
  void check(bool condition, String label) {
    if (!condition) throw StateError(label);
    checks++;
  }

  final now = DateTime.utc(2026, 11, 20);
  final meter = UtilityMeter(
    namespace: 'verdi-utility:independent-fixture',
    label: 'Acceptance home',
    zoneId: 'America/Los_Angeles',
    createdAt: now,
  );
  UtilityReviewChoices choices({
    bool confirm = false,
    EvidenceQuality quality = EvidenceQuality.confirmedQuantity,
  }) => UtilityReviewChoices(
    zone: ServiceZone.losAngeles,
    factor: utilityFactorChoices.single,
    quality: quality,
    personalShare: 0.5,
    decision: UtilityReviewDecision.approved,
    reviewer: 'Independent check',
    reason: 'Compare full-month reference arithmetic',
    consentAcknowledged: true,
    confirmCorrections: confirm,
  );
  String csv({double day15 = 10}) {
    final rows = List.generate(
      31,
      (i) =>
          'day-${i + 1},2026-10-${(i + 1).toString().padLeft(2, '0')},${i == 14 ? day15 : 10}',
    ).join('\n');
    return 'record_id,date,kwh\n$rows';
  }
  UtilityImportPlan plan(
    EvidenceArchive archive, {
    double day15 = 10,
    bool confirm = false,
    EvidenceQuality quality = EvidenceQuality.confirmedQuantity,
  }) => planUtilityImport(
    csv: csv(day15: day15),
    meter: meter,
    choices: choices(confirm: confirm, quality: quality),
    archive: archive,
    now: now,
    batchId: 'reference-$day15-$confirm-${quality.name}',
  );
  final initial = plan(EvidenceArchive());
  check(initial.changes.length == 31, '31 daily records retained');
  check(
    initial.batch.quality == EvidenceQuality.confirmedQuantity,
    'Explicit evidence quality snapshotted in batch provenance',
  );
  final archive = initial.adapter.append(EvidenceArchive(), initial.changes);
  final report = archive.reconcile(
    start: DateTime.utc(2026, 10),
    end: DateTime.utc(2026, 11),
  );
  check(
    report.included.length == 30 && report.issues.length == 1,
    '30 included, October 31 crossing held',
  );
  check(
    (report.kgCo2eByBasis.values.single - 52.744809405288).abs() < 1e-9,
    'Independent 300 kWh x 0.5 share x 0.35163206270192 factor',
  );
  check(plan(archive).changes.isEmpty, 'Replay adds nothing');
  final qualityUpgrade = plan(
    archive,
    quality: EvidenceQuality.measuredQuantity,
  );
  check(
    qualityUpgrade.count(UtilityRowStatus.correction) == 31 &&
        qualityUpgrade.hasUnconfirmedCorrections,
    'Quality change requires explicit correction confirmation',
  );
  final correction = plan(archive, day15: 12, confirm: true);
  check(
    correction.changes.length == 1 && correction.changes.single.supersedes == 1,
    'Correction affects exactly one predecessor',
  );
  final corrected = correction.adapter.append(archive, correction.changes);
  final correctedReport = corrected.reconcile(
    start: DateTime.utc(2026, 10),
    end: DateTime.utc(2026, 11),
  );
  check(
    corrected.revisions.length == 32 && correctedReport.included.length == 30,
    'Correction keeps history without increasing counted records',
  );
  check(
    (correctedReport.kgCo2eByBasis.values.single - 53.09644146798992).abs() <
        1e-9,
    'Corrected expected value',
  );
  final zone = ServiceZone.losAngeles;
  final spring = zone.civilDay(2026, 3, 8), fall = zone.civilDay(2026, 11, 1);
  check(
    spring.$2.difference(spring.$1).inHours == 23 &&
        fall.$2.difference(fall.$1).inHours == 25,
    'DST lengths',
  );
  stdout.writeln('$checks independent monthly pipeline checks passed.');
}
