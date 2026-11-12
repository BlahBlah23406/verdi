import 'carbon.dart';

/// An individual's reviewed journal and explicit organization sharing grant.
/// The personal journal stays local; reports contain category totals only.
class ConsentedJournal {
  const ConsentedJournal({
    required this.memberId,
    required this.organizationId,
    required this.activities,
    this.consentedAt,
    this.revokedAt,
  });

  final String memberId, organizationId;
  final List<Activity> activities;
  final DateTime? consentedAt, revokedAt;
}

class InstitutionalRollup {
  const InstitutionalRollup(this.members, this.categoriesKg);
  final int members;
  final Map<String, double> categoriesKg;
  double get totalKg => categoriesKg.values.fold(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
    'consentingMembers': members,
    'categoryEmissionsKg': categoriesKg,
    'totalEmissionsKg': totalKg,
    'basis': 'Reviewed personal activity estimates; sample data, not audited',
  };
}

class InstitutionalAggregator {
  const InstitutionalAggregator();

  InstitutionalRollup aggregate({
    required String organizationId,
    required Iterable<ConsentedJournal> journals,
    required DateTime start,
    required DateTime end,
    required DateTime asOf,
  }) {
    if (!end.isAfter(start)) throw ArgumentError('Invalid reporting period');
    final categories = <String, double>{};
    final members = <String>{};
    final seen = <(String, String)>{};
    for (final journal in journals) {
      final consent = journal.consentedAt;
      if (journal.organizationId != organizationId ||
          consent == null ||
          consent.isAfter(asOf) ||
          (journal.revokedAt != null && !journal.revokedAt!.isAfter(asOf))) {
        continue;
      }
      members.add(journal.memberId);
      for (final activity in const CarbonEngine().inPeriod(
        journal.activities,
        start,
        end,
      )) {
        if (!activity.isPilotEstimate ||
            !seen.add((journal.memberId, activity.id))) {
          continue;
        }
        categories.update(
          activity.kind.category,
          (v) => v + activity.emissions,
          ifAbsent: () => activity.emissions,
        );
      }
    }
    return InstitutionalRollup(members.length, Map.unmodifiable(categories));
  }
}
