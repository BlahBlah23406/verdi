// Overview: Saves reviewed electricity previews into the experimental evidence archive.
import 'dart:math';

import '../domain/evidence_archive.dart';
import '../domain/utility_review.dart';
import 'evidence_archive_store.dart';
import 'utility_review_store.dart';

/// Coordinates the archive and its meter/provenance records. It never writes
/// journal activities or dashboard data.
class UtilityReviewService {
  UtilityReviewService({required this.archive, required this.reviews});
  final EvidenceArchiveStore archive;
  final UtilityReviewStore reviews;

  /// A new random pseudonymous namespace; never derived from account data.
  static UtilityMeter newMeter({
    required String label,
    required String zoneId,
    required DateTime now,
    Random? random,
  }) {
    final r = random ?? Random.secure();
    final id = List.generate(
      8,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return UtilityMeter(
      namespace: '${utilityNamespacePrefix}meter-$id',
      label: label.trim(),
      zoneId: zoneId,
      createdAt: now,
    );
  }

  static String newBatchId([Random? random]) {
    final r = random ?? Random.secure();
    return List.generate(
      12,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  /// Saves [plan]. Ensures the meter is registered, then commits the archive
  /// revisions and [plan.batch] receipt atomically in a single preferences
  /// write to [EvidenceArchiveStore.key]. A changed archive raises
  /// [StaleEvidenceException].
  Future<EvidenceArchive> save(UtilityImportPlan plan) async {
    if (plan.hasUnconfirmedCorrections) {
      throw StateError('Confirm or remove corrections before saving.');
    }
    final changes = plan.changes;
    if (changes.isEmpty) {
      throw StateError('No new or corrected readings to save.');
    }
    // Fail closed before touching either store if persisted data is corrupt.
    archive.load();
    reviews.load();
    final legacy = reviews.legacyBatches();
    await reviews.update((s) {
      final byLabel = s.meterByLabel(plan.meter.label);
      if (byLabel != null && byLabel.namespace != plan.meter.namespace) {
        throw StateError('Another meter already uses this nickname.');
      }
      return s.withMeter(plan.meter);
    });
    return archive.appendUtility(
      adapter: plan.adapter,
      changes: changes,
      baseline: plan.baseline,
      batch: plan.batch,
      migratedBatches: legacy,
    );
  }
}
