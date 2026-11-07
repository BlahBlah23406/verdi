// Overview: Unified ingestion orchestrator coordinating fetching, normalization, reconciliation, deduplication, and review queuing.
import '../../data/activity_store.dart';
import '../../data/automation_store.dart';
import '../../domain/automation.dart';
import 'reconciliation_engine.dart';
import 'source_registry.dart';

/// Result summary of an ingestion run.
class IngestionResult {
  const IngestionResult({
    required this.totalFetched,
    required this.reconciledCount,
    required this.duplicatesSkipped,
    required this.queuedCount,
    required this.queuedCandidates,
  });

  final int totalFetched;
  final int reconciledCount;
  final int duplicatesSkipped;
  final int queuedCount;
  final List<ActivityCandidate> queuedCandidates;

  Map<String, dynamic> toJson() => {
    'totalFetched': totalFetched,
    'reconciledCount': reconciledCount,
    'duplicatesSkipped': duplicatesSkipped,
    'queuedCount': queuedCount,
  };
}

/// Unified ingestion orchestrator that coordinates adapters, runs multi-source
/// reconciliation, filters out known/dismissed activities, and updates the review queue.
class IngestionOrchestrator {
  IngestionOrchestrator({
    required this.registry,
    required this.automationStore,
    required this.activityStore,
    ReconciliationEngine? reconciliationEngine,
  }) : engine = reconciliationEngine ?? const ReconciliationEngine();

  final MultiSourceRegistry registry;
  final AutomationStore automationStore;
  final ActivityStore activityStore;
  final ReconciliationEngine engine;

  /// Ingests from all registered adapters, reconciles overlapping signals,
  /// deduplicates against journal and dismissed records, and saves to the review queue.
  Future<IngestionResult> ingest({DateTime? since}) async {
    // 1. Fetch from all adapters
    final allFetched = <ActivityCandidate>[];
    for (final adapter in registry.listAdapters()) {
      try {
        final candidates = await adapter.fetchCandidates(since: since);
        allFetched.addAll(candidates);
      } catch (_) {
        // Continue on adapter failure
      }
    }

    // 2. Normalize and filter invalid candidates
    final valid = allFetched.where((c) {
      return c.id.isNotEmpty &&
          c.quantity.isFinite &&
          c.quantity > 0 &&
          !c.end.isBefore(c.start);
    }).toList();

    // 3. Reconcile overlapping signals across sources
    final reconciled = engine.reconcile(valid);
    final reconciledCount = valid.length - reconciled.length;

    // 4. Deduplicate against existing activities, pending candidates, and dismissed IDs
    final currentState = automationStore.load();
    final existingActivities = activityStore.load();

    final knownIds = <String>{
      ...currentState.dismissed,
      ...currentState.pending.map((c) => c.id),
      ...existingActivities.map((a) => a.id),
      ...existingActivities.map((a) => a.sourceId).whereType<String>(),
    };

    // Also check if any candidate's merged component IDs were already processed
    for (final c in currentState.pending) {
      if (c.metadata['mergedCandidateIds'] is List) {
        knownIds.addAll(
          (c.metadata['mergedCandidateIds'] as List).cast<String>(),
        );
      }
    }
    for (final a in existingActivities) {
      if (a.factorMetadata['mergedCandidateIds'] is List) {
        knownIds.addAll(
          (a.factorMetadata['mergedCandidateIds'] as List).cast<String>(),
        );
      }
    }

    final newCandidates = <ActivityCandidate>[];
    var duplicatesSkipped = 0;

    for (final candidate in reconciled) {
      // Check primary ID
      if (knownIds.contains(candidate.id)) {
        duplicatesSkipped++;
        continue;
      }

      // Check if candidate is a reconciled composite whose components are all known
      if (candidate.metadata['mergedCandidateIds'] is List) {
        final merged = (candidate.metadata['mergedCandidateIds'] as List).cast<String>();
        if (merged.any((id) => knownIds.contains(id))) {
          duplicatesSkipped++;
          continue;
        }
      }

      // Check for direct overlap with already confirmed activities
      final hasConfirmedOverlap = existingActivities.any(
        (a) => overlaps(candidate, a),
      );
      if (hasConfirmedOverlap) {
        duplicatesSkipped++;
        continue;
      }

      newCandidates.add(candidate);
      knownIds.add(candidate.id);
    }

    // 5. Enqueue new candidates
    if (newCandidates.isNotEmpty) {
      final updatedPending = [...currentState.pending, ...newCandidates];
      await automationStore.save(
        AutomationState(updatedPending, currentState.dismissed),
      );
    }

    return IngestionResult(
      totalFetched: allFetched.length,
      reconciledCount: reconciledCount,
      duplicatesSkipped: duplicatesSkipped,
      queuedCount: newCandidates.length,
      queuedCandidates: newCandidates,
    );
  }
}
