// Overview: Reconciliation engine combining multi-source signals (phone GPS, bank inference, transport API, utility readings).
import 'dart:math' as math;
import 'dart:convert';

import '../../domain/automation.dart';
import '../../domain/carbon.dart';

/// Strategy applied during reconciliation arbitration.
enum ReconciliationStrategy {
  chosenMostAccurate('chosen_most_accurate'),
  averagedWithinTolerance('averaged_within_tolerance'),
  singleSource('single_source'),
  conflictPrioritized('conflict_prioritized');

  const ReconciliationStrategy(this.code);
  final String code;
}

/// Result of reconciling a cluster of candidate signals.
class ReconciledSignal {
  const ReconciledSignal({
    required this.candidate,
    required this.strategy,
    required this.contributingSources,
    required this.confidenceImprovement,
    required this.toleranceAgreed,
  });

  final ActivityCandidate candidate;
  final ReconciliationStrategy strategy;
  final List<String> contributingSources;
  final double confidenceImprovement;
  final bool toleranceAgreed;
}

/// Engine that analyzes multi-source candidates, detects overlapping signals,
/// checks agreement against configurable tolerances, and reconciles them into
/// high-confidence candidates.
class ReconciliationEngine {
  const ReconciliationEngine({
    this.distanceToleranceRatio =
        0.25, // 25% acceptable discrepancy between sensors/inferences
    this.absoluteDistanceToleranceKm = 1.8,
    this.timeToleranceMinutes = 30,
  });

  final double distanceToleranceRatio;
  final double absoluteDistanceToleranceKm;
  final int timeToleranceMinutes;

  /// Main entry point: reconciles a heterogeneous list of activity candidates.
  List<ActivityCandidate> reconcile(List<ActivityCandidate> candidates) {
    if (candidates.length <= 1) return List.of(candidates);

    // Group candidates into overlapping clusters
    final clusters = _clusterOverlappingCandidates(candidates);
    final results = <ActivityCandidate>[];

    for (final cluster in clusters) {
      if (cluster.length == 1) {
        results.add(cluster.first);
      } else {
        final reconciled = _combineCluster(cluster);
        results.add(reconciled.candidate);
      }
    }

    return results;
  }

  /// Groups candidates into connected components of overlapping signals.
  List<List<ActivityCandidate>> _clusterOverlappingCandidates(
    List<ActivityCandidate> candidates,
  ) {
    final visited = <ActivityCandidate>{};
    final clusters = <List<ActivityCandidate>>[];

    for (final candidate in candidates) {
      if (visited.contains(candidate)) continue;
      final currentCluster = <ActivityCandidate>[];
      final queue = <ActivityCandidate>[candidate];
      visited.add(candidate);

      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        currentCluster.add(current);

        for (final other in candidates) {
          if (!visited.contains(other) &&
              _signalsOverlap(current, other) &&
              currentCluster.every(
                (member) => _signalsOverlap(member, other),
              )) {
            visited.add(other);
            queue.add(other);
          }
        }
      }

      clusters.add(currentCluster);
    }

    return clusters;
  }

  /// Evaluates whether two candidates represent overlapping activity signals.
  bool _signalsOverlap(ActivityCandidate a, ActivityCandidate b) {
    if (a.source == b.source) return false;
    final aHome = a.kind == ActivityKind.electricity;
    final bHome = b.kind == ActivityKind.electricity;
    if (aHome || bHome) {
      // Whole-home and appliance meters are nested boundaries, not corroboration.
      return aHome &&
          bHome &&
          a.metadata['meterId'] != null &&
          a.metadata['meterId'] == b.metadata['meterId'] &&
          a.start == b.start &&
          a.end == b.end;
    }
    const ground = {
      ActivityKind.car,
      ActivityKind.bus,
      ActivityKind.train,
      ActivityKind.bicycle,
      null,
    };
    if (!ground.contains(a.kind) || !ground.contains(b.kind)) return false;
    if (a.kind != null && b.kind != null && a.kind != b.kind) return false;
    final aAccount = a.metadata['accountId'];
    final bAccount = b.metadata['accountId'];
    if (aAccount != null && bAccount != null && aAccount != bAccount) {
      return false;
    }
    return a.start.isBefore(b.end) &&
        b.start.isBefore(a.end) &&
        a.start.difference(b.start).abs().inMinutes <= timeToleranceMinutes;
  }

  /// Combines a cluster of overlapping candidates into a single reconciled candidate.
  ReconciledSignal _combineCluster(List<ActivityCandidate> cluster) {
    // Collect source types and fidelities
    final sourceFidelities = <ActivityCandidate, double>{};
    for (final c in cluster) {
      final baseConf = c.confidence ?? _inferDefaultFidelity(c.source);
      sourceFidelities[c] = baseConf;
    }

    // Determine category and travel mode
    // If any source identifies a specific travel mode (e.g. train, bus), prioritize it over phone null kind
    final typed = cluster.where((c) => c.kind != null).toList()
      ..sort((a, b) => sourceFidelities[b]!.compareTo(sourceFidelities[a]!));
    final resolvedKind = typed.isEmpty ? null : typed.first.kind;

    // Check tolerance agreement across quantities
    final quantities = cluster.map((c) => c.quantity).toList();
    final minQ = quantities.reduce(math.min);
    final maxQ = quantities.reduce(math.max);
    final diff = maxQ - minQ;
    final relDiff = maxQ > 0 ? diff / maxQ : 0.0;

    final agreedWithinTolerance =
        relDiff <= distanceToleranceRatio ||
        diff <= absoluteDistanceToleranceKm;

    // Determine quantity and strategy
    double reconciledQuantity;
    ReconciliationStrategy strategy;

    // Find the candidate with highest fidelity
    final sortedByFidelity = List.of(cluster)
      ..sort((a, b) => (sourceFidelities[b]!).compareTo(sourceFidelities[a]!));
    final highestFidelityCandidate = sortedByFidelity.first;
    final highestFidelity = sourceFidelities[highestFidelityCandidate]!;
    final secondHighestFidelity = sortedByFidelity.length > 1
        ? sourceFidelities[sortedByFidelity[1]]!
        : 0.0;

    if (agreedWithinTolerance) {
      // If one candidate is significantly more accurate (e.g. transport API 0.95 vs bank 0.75), choose it
      if (highestFidelity - secondHighestFidelity >= 0.10) {
        reconciledQuantity = highestFidelityCandidate.quantity;
        strategy = ReconciliationStrategy.chosenMostAccurate;
      } else {
        // Otherwise, compute weighted average across corroborating signals
        var weightedSum = 0.0;
        var totalWeight = 0.0;
        for (final c in cluster) {
          final w = sourceFidelities[c]!;
          weightedSum += c.quantity * w;
          totalWeight += w;
        }
        reconciledQuantity = totalWeight > 0 ? weightedSum / totalWeight : minQ;
        reconciledQuantity = double.parse(
          reconciledQuantity.toStringAsFixed(2),
        );
        strategy = ReconciliationStrategy.averagedWithinTolerance;
      }
    } else {
      // Beyond tolerance: prioritize highest-fidelity verified hardware/API source
      reconciledQuantity = highestFidelityCandidate.quantity;
      strategy = ReconciliationStrategy.conflictPrioritized;
    }

    // Sources may be correlated. This score is a heuristic, not calibrated probability.
    final combinedConfidence = agreedWithinTolerance
        ? highestFidelity
        : highestFidelity * 0.8;
    const confidenceImprovement = 0.0;

    // Form composite timestamps
    final earliestStart = cluster
        .map((c) => c.start)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final latestEnd = cluster
        .map((c) => c.end)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    // Form composite description
    final sourceNames = cluster.map((c) => c.source).toSet().toList();
    final sourceSummary = cluster
        .map((c) => '${c.source} (${c.quantity.toStringAsFixed(1)})')
        .join(', ');
    final note = agreedWithinTolerance
        ? 'Reconciled from ${cluster.length} sources: $sourceSummary. Multi-source agreement within ${(relDiff * 100).toStringAsFixed(1)}%.'
        : 'Conflicting evidence requires review; selected higher-ranked source from ${cluster.length} signals: $sourceSummary.';

    final candidateIds = cluster.map((c) => c.id).toList()..sort();
    final reconciledId =
        'reconciled:${base64Url.encode(utf8.encode(jsonEncode(candidateIds)))}';

    final reconciledCandidate = ActivityCandidate(
      id: reconciledId,
      source: 'multi-source-reconciled',
      start: earliestStart,
      end: latestEnd,
      quantity: reconciledQuantity,
      kind: resolvedKind,
      confidence: double.parse(combinedConfidence.toStringAsFixed(2)),
      description: note,
      metadata: {
        'reconciled': true,
        'strategy': strategy.code,
        'toleranceAgreed': agreedWithinTolerance,
        'relativeDiscrepancy': double.parse(relDiff.toStringAsFixed(3)),
        'confidenceImprovement': confidenceImprovement,
        'confidenceType': 'uncalibrated heuristic',
        'requiresReview': true,
        'mergedCandidateIds': candidateIds,
        'contributingSources': sourceNames,
        'sourceQuantities': {for (final c in cluster) c.source: c.quantity},
        'chosenQuantity': reconciledQuantity,
      },
    );

    return ReconciledSignal(
      candidate: reconciledCandidate,
      strategy: strategy,
      contributingSources: sourceNames,
      confidenceImprovement: confidenceImprovement,
      toleranceAgreed: agreedWithinTolerance,
    );
  }

  double _inferDefaultFidelity(String source) {
    if (source.contains('transport')) return 0.95;
    if (source.contains('utility')) return 0.98;
    if (source.contains('iot')) return 0.92;
    if (source.contains('phone')) return 0.80;
    if (source.contains('bank')) return 0.75;
    return 0.70;
  }
}
