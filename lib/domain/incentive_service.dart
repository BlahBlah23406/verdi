// Overview: Tracks emission reductions and computes rule-based rewards.
// No backend required — all state is derived from the activity journal.
import 'carbon.dart';

/// A single reward entry earned by reducing emissions relative to a baseline.
class RewardEntry {
  const RewardEntry({
    required this.id,
    required this.date,
    required this.kgReduced,
    required this.points,
    required this.description,
  });

  final String id;
  final DateTime date;
  final double kgReduced;
  final int points;
  final String description;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'kgReduced': kgReduced,
    'points': points,
    'description': description,
  };
}

/// Tracks month-over-month emission reductions and issues preview rewards.
///
/// The incentive model is intentionally simple and rule-based:
/// - Compare the current month's total to the previous month's total.
/// - If emissions decreased, award 10 points per kg of reduction.
/// - If emissions increased, no points are awarded (but no penalty either).
///
/// This is a preview system. No points are redeemable or transferable yet.
/// A server-owned ledger and verified reduction baselines are required
/// before real rewards can be issued (see docs/ROADMAP.md, Phase 4).
class IncentiveService {
  const IncentiveService({this.pointsPerKg = 10});

  final int pointsPerKg;

  /// Compute the reward for the current month relative to the previous month.
  ///
  /// Returns null if there is no previous month to compare against, or if
  /// both months have zero emissions (nothing to reward).
  RewardEntry? computeMonthlyReward({
    required List<Activity> currentMonth,
    required List<Activity> previousMonth,
    required DateTime now,
  }) {
    final current = CarbonEngine().total(
      currentMonth.where((a) => a.isPilotEstimate),
    );
    final previous = CarbonEngine().total(
      previousMonth.where((a) => a.isPilotEstimate),
    );

    if (previous <= 0 && current <= 0) return null;

    final reduction = previous - current;
    if (reduction <= 0) return null;

    final points = (reduction * pointsPerKg).floor();

    return RewardEntry(
      id: 'reward:${now.year}-${now.month}',
      date: now,
      kgReduced: reduction,
      points: points,
      description: 'Reduced emissions by ${reduction.toStringAsFixed(1)} kg CO₂e '
          'compared to last month.',
    );
  }

  /// Compute a preview reward for a potential travel-mode swap.
  ///
  /// This mirrors CarbonEngine.previewPoints but returns a structured
  /// RewardEntry so the UI can display it consistently.
  RewardEntry previewTravelReward({
    required double potentialSavingKg,
    required DateTime date,
  }) {
    if (potentialSavingKg < 0) {
      throw ArgumentError('Potential saving must be non-negative.');
    }
    return RewardEntry(
      id: 'preview:${date.microsecondsSinceEpoch}',
      date: date,
      kgReduced: potentialSavingKg,
      points: (potentialSavingKg * pointsPerKg).floor(),
      description: 'Preview: swap a car journey for a lower-emission alternative.',
    );
  }

  /// Compute the total points from a list of reward entries.
  int totalPoints(List<RewardEntry> entries) =>
      entries.fold(0, (sum, e) => sum + e.points);

  /// Compute the total kg reduced from a list of reward entries.
  double totalKgReduced(List<RewardEntry> entries) =>
      entries.fold(0.0, (sum, e) => sum + e.kgReduced);
}
