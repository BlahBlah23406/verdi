import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi/domain/carbon.dart';
import 'package:verdi/domain/institutional_aggregation.dart';
import 'package:verdi/features/consent_rollup_card.dart';

void main() {
  final start = DateTime(2026, 11);
  final end = DateTime(2026, 12);
  final asOf = DateTime(2026, 11, 6);
  final activity = Activity(
    id: 'a',
    kind: ActivityKind.train,
    quantity: 10,
    date: start,
  );
  ConsentedJournal journal(
    String member, {
    String org = 'org',
    DateTime? consent,
    DateTime? revoked,
    List<Activity>? activities,
  }) => ConsentedJournal(
    memberId: member,
    organizationId: org,
    activities: activities ?? [activity],
    consentedAt: consent,
    revokedAt: revoked,
  );
  InstitutionalRollup aggregate(List<ConsentedJournal> journals) =>
      const InstitutionalAggregator().aggregate(
        organizationId: 'org',
        journals: journals,
        start: start,
        end: end,
        asOf: asOf,
      );

  test('Requires current explicit consent for the target organization', () {
    final result = aggregate([
      journal('yes', consent: start),
      journal('no'),
      journal('revoked', consent: start, revoked: asOf),
      journal('future', consent: end),
      journal('other', org: 'elsewhere', consent: start),
    ]);
    expect(result.members, 1);
    expect(result.totalKg, activity.emissions);
    expect(result.toJson().toString(), isNot(contains('memberId')));
  });
  test(
    'Deduplicates within a member but preserves different members records',
    () {
      final result = aggregate([
        journal('one', consent: start),
        journal('one', consent: start),
        journal('two', consent: start),
      ]);
      expect(result.members, 2);
      expect(result.totalKg, 2 * activity.emissions);
    },
  );
  test('Uses half-open reporting dates and excludes legacy estimates', () {
    final result = aggregate([
      journal(
        'one',
        consent: start,
        activities: [
          activity,
          Activity(id: 'end', kind: ActivityKind.car, quantity: 10, date: end),
          Activity(
            id: 'before',
            kind: ActivityKind.car,
            quantity: 10,
            date: start.subtract(const Duration(seconds: 1)),
          ),
          Activity(
            id: 'legacy',
            kind: ActivityKind.car,
            quantity: 10,
            date: start,
            factorVersion: 'legacy',
          ),
        ],
      ),
    ]);
    expect(result.totalKg, activity.emissions);
    expect(aggregate([]).totalKg, 0);
  });
  testWidgets('Opt-in adds a journal and withdrawal removes it', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConsentRollupCard(organizationId: 'org'),
          ),
        ),
      ),
    );
    expect(find.textContaining('2 of 4 members sharing'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.textContaining('3 of 4 members sharing'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.textContaining('2 of 4 members sharing'), findsOneWidget);
  });
}
