// Overview: Serializes experimental evidence archives locally without storing credentials.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/evidence_archive.dart';
import '../domain/utility_evidence_adapter.dart';
import '../domain/utility_review.dart';

/// The archive changed after a preview was built; nothing was written.
class StaleEvidenceException implements Exception {
  const StaleEvidenceException();
  @override
  String toString() =>
      'Saved evidence changed after this preview. Preview again before saving.';
}

class EvidenceArchiveStore {
  EvidenceArchiveStore(this.preferences);
  final SharedPreferences preferences;
  static const key = 'verdi.evidence-archive.v1';
  Future<void> _writes = Future.value();
  bool _needsReload = false;

  ({EvidenceArchive archive, List<UtilityReviewBatch> batches})
  _readEnvelope() {
    if (_needsReload) {
      throw StateError('Saved evidence must be reloaded after a failed write.');
    }
    final raw = preferences.getString(key);
    if (raw == null) {
      return (archive: EvidenceArchive(), batches: const []);
    }
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final archive = EvidenceArchive.fromJson(map);
      final rawBatches = map['batches'];
      if (rawBatches == null) {
        return (archive: archive, batches: const []);
      }
      final batches = (rawBatches as List)
          .map(
            (e) => UtilityReviewBatch.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
      final ids = <String>{};
      final byKey = {for (final r in archive.revisions) r.ref.key: r};
      for (final batch in batches) {
        if (!ids.add(batch.id)) {
          throw const FormatException('Duplicate utility review batch ID.');
        }
        for (final revisionKey in batch.revisionKeys) {
          final revision = byKey[revisionKey];
          if (revision == null || revision.ref.source != batch.namespace) {
            throw const FormatException(
              'Review batch references missing archive revisions.',
            );
          }
        }
      }
      return (
        archive: archive,
        batches: List<UtilityReviewBatch>.unmodifiable(batches),
      );
    } catch (_) {
      throw const FormatException(
        'Saved evidence archive is invalid; it has not been overwritten.',
      );
    }
  }

  EvidenceArchive load() => _readEnvelope().archive;

  /// Authoritative utility review receipts committed atomically with archive
  /// revisions inside [key].
  List<UtilityReviewBatch> loadBatches() => _readEnvelope().batches;

  /// Queues mutations per store; every append reloads before writing, so replay
  /// and interrupted retries cannot discard prior revisions. Not a cloud store.
  ///
  /// Reviewed utility namespaces are rejected here: they must go through
  /// [appendUtility], which validates predecessors.
  Future<void> append({
    Iterable<EvidenceRevision> revisions = const [],
    Iterable<EvidenceRelation> relations = const [],
  }) {
    final records = List<EvidenceRevision>.of(revisions);
    final links = List<EvidenceRelation>.of(relations);
    if (records.any((r) => r.ref.source.startsWith(utilityNamespacePrefix))) {
      return Future.error(
        ArgumentError('Reviewed utility evidence must use appendUtility.'),
      );
    }
    return _enqueue(
      (current) => (
        archive: current.archive.append(revisions: records, relations: links),
        batches: current.batches,
      ),
    );
  }

  /// Applies reviewed utility changes and their optional [batch] receipt
  /// atomically in one preferences write against freshly loaded state. Throws
  /// [StaleEvidenceException] unless the meter's archived revisions, apart from
  /// this batch's own (a retried save), still equal [baseline]. The adapter
  /// then enforces exact predecessors.
  Future<EvidenceArchive> appendUtility({
    required UtilityEvidenceAdapter adapter,
    required List<UtilityRevisionChange> changes,
    required Set<String> baseline,
    UtilityReviewBatch? batch,
    Iterable<UtilityReviewBatch> migratedBatches = const [],
  }) {
    if (!adapter.sourceNamespace.startsWith(utilityNamespacePrefix)) {
      return Future.error(
        ArgumentError('Reviewed utility meters use a reserved namespace.'),
      );
    }
    final planned = {for (final c in changes) c.revision.ref.key};
    if (batch != null) {
      if (batch.namespace != adapter.sourceNamespace ||
          batch.revisionKeys.length != changes.length ||
          !batch.revisionKeys.every(planned.contains)) {
        return Future.error(
          ArgumentError('Review batch must match the planned utility changes.'),
        );
      }
    }
    final migrated = List<UtilityReviewBatch>.of(migratedBatches);
    return _enqueue((current) {
      final now = namespaceKeys(current.archive, adapter.sourceNamespace);
      final expected = baseline.difference(planned);
      final actual = now.difference(planned);
      if (actual.length != expected.length || !actual.containsAll(expected)) {
        throw const StaleEvidenceException();
      }
      final isBatchReplay =
          batch == null || current.batches.any((b) => b.id == batch.id);
      // A planned revision already present is tolerated only as this batch's
      // own earlier save (identical payload); anything else changed meanwhile.
      final saved = {for (final r in current.archive.revisions) r.ref.key: r};
      for (final c in changes) {
        final old = saved[c.revision.ref.key];
        if (old != null && !baseline.contains(c.revision.ref.key)) {
          if (!isBatchReplay ||
              jsonEncode(old.evidence?.toJson()) !=
                  jsonEncode(c.revision.evidence?.toJson())) {
            throw const StaleEvidenceException();
          }
        }
      }
      final nextArchive = adapter.append(current.archive, changes);
      final nextByKey = {for (final r in nextArchive.revisions) r.ref.key: r};
      final nextBatches = [...current.batches];
      void addBatch(UtilityReviewBatch candidate) {
        final existing = nextBatches.where((b) => b.id == candidate.id);
        if (existing.isNotEmpty) {
          if (jsonEncode(existing.single.toJson()) !=
              jsonEncode(candidate.toJson())) {
            throw StateError('Review batch ${candidate.id} already differs.');
          }
          return;
        }
        nextBatches.add(candidate);
      }

      for (final legacy in migrated) {
        final inArchive = legacy.revisionKeys.every(
          (k) => nextByKey[k]?.ref.source == legacy.namespace,
        );
        if (inArchive) addBatch(legacy);
      }
      if (batch != null) addBatch(batch);
      return (
        archive: nextArchive,
        batches: List<UtilityReviewBatch>.unmodifiable(nextBatches),
      );
    });
  }

  Future<EvidenceArchive> _enqueue(
    ({EvidenceArchive archive, List<UtilityReviewBatch> batches}) Function(
      ({EvidenceArchive archive, List<UtilityReviewBatch> batches}) current,
    )
    mutate,
  ) {
    final operation = _writes.then((_) async {
      if (_needsReload) {
        await preferences.reload();
        _needsReload = false;
      }
      final next = mutate(_readEnvelope());
      final encoded = jsonEncode({
        ...next.archive.toJson(),
        if (next.batches.isNotEmpty)
          'batches': next.batches.map((b) => b.toJson()).toList(),
      });
      try {
        if (!await preferences.setString(key, encoded)) {
          throw StateError('Could not save evidence archive.');
        }
      } catch (_) {
        // SharedPreferences updates its cache before awaiting the disk write.
        // Reload durable state so a failed append cannot appear to have saved.
        _needsReload = true;
        try {
          await preferences.reload();
          _needsReload = false;
        } catch (_) {
          // Keep reads blocked until a subsequent append can reload safely.
        }
        rethrow;
      }
      return next.archive;
    });
    _writes = operation.then((_) {}, onError: (Object _) {});
    return operation;
  }
}
