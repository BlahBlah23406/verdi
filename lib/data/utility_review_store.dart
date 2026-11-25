// Overview: Persists pseudonymous utility meters and reviewer provenance beside the evidence archive.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/utility_review.dart';
import 'evidence_archive_store.dart';

/// Separate key for the local meter registry. Authoritative batch receipts are
/// committed atomically inside [EvidenceArchiveStore.key]; any historical
/// batches stored under [key] are retained and surfaced by [load].
class UtilityReviewStore {
  UtilityReviewStore(this.preferences);
  final SharedPreferences preferences;
  static const key = 'verdi.utility-review.v1';
  Future<void> _writes = Future.value();
  bool _needsReload = false;

  UtilityReviewState _loadOwn() {
    if (_needsReload) {
      throw StateError(
        'Saved review data must be reloaded after a failed write.',
      );
    }
    final raw = preferences.getString(key);
    if (raw == null) return UtilityReviewState(const [], const []);
    try {
      return UtilityReviewState.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      throw const FormatException(
        'Saved meter and review records are invalid; they have not been overwritten.',
      );
    }
  }

  /// Legacy batches stored in [key] before receipts moved into the archive.
  List<UtilityReviewBatch> legacyBatches() => _loadOwn().batches;

  /// Loads meters from [key] and merges any legacy batches in [key] with the
  /// authoritative batch receipts committed in [EvidenceArchiveStore.key].
  UtilityReviewState load() {
    final own = _loadOwn();
    final archiveBatches = EvidenceArchiveStore(preferences).loadBatches();
    if (archiveBatches.isEmpty) return own;
    final merged = [...own.batches];
    for (final batch in archiveBatches) {
      final same = merged.where((b) => b.id == batch.id);
      if (same.isNotEmpty) {
        if (jsonEncode(same.single.toJson()) != jsonEncode(batch.toJson())) {
          throw const FormatException(
            'Saved meter and review records are invalid; they have not been overwritten.',
          );
        }
      } else {
        merged.add(batch);
      }
    }
    return UtilityReviewState(own.meters, merged);
  }

  /// Queued like `EvidenceArchiveStore.append`: reloads before writing and
  /// restores durable state after a failed write.
  Future<UtilityReviewState> update(
    UtilityReviewState Function(UtilityReviewState current) mutate,
  ) {
    final operation = _writes.then((_) async {
      if (_needsReload) {
        await preferences.reload();
        _needsReload = false;
      }
      final current = _loadOwn();
      final next = mutate(current);
      if (identical(next, current)) return current;
      try {
        if (!await preferences.setString(key, jsonEncode(next.toJson()))) {
          throw StateError('Could not save review records.');
        }
      } catch (_) {
        _needsReload = true;
        try {
          await preferences.reload();
          _needsReload = false;
        } catch (_) {
          // Keep reads blocked until a later update can reload safely.
        }
        rethrow;
      }
      return next;
    });
    _writes = operation.then((_) {}, onError: (Object _) {});
    return operation;
  }
}
