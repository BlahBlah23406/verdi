// Overview: Checks archive inspection, period holds, history and safe load failures.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:verdi/data/activity_store.dart';
import 'package:verdi/data/evidence_archive_store.dart';
import 'package:verdi/domain/evidence_archive.dart';
import 'package:verdi/domain/footprint_ledger.dart';
import 'package:verdi/features/automation_screen.dart';
import 'package:verdi/features/evidence_archive_screen.dart';

void main() {
  final start = DateTime.utc(2026, 10), end = DateTime.utc(2026, 11);
  EvidenceRevision meter(int revision, double quantity) => EvidenceRevision(
    ref: EvidenceRef('home', 'meter', revision),
    receivedAt: end,
    evidence: FootprintEvidence(
      id: 'meter',
      source: 'home',
      coverageKey: 'october-energy',
      sector: FootprintSector.electricity,
      start: start,
      end: end,
      boundary: 'generation',
      unit: 'kWh',
      quantity: quantity,
      quality: EvidenceQuality.measuredQuantity,
      reviewed: true,
      factor: FootprintFactor(
        id: 'synthetic',
        version: 'v1',
        sector: FootprintSector.electricity,
        unit: 'kWh',
        boundary: 'generation',
        geography: 'fixture',
        dataYear: 2025,
        sourceUrl: 'https://example.org/factor',
        gwpVersion: 'AR5',
        accountingMethod: 'location',
        kgCo2ePerUnit: 0.4,
      ),
    ),
  );
  Future<void> open(WidgetTester tester, EvidenceArchive archive) async {
    SharedPreferences.setMockInitialValues({
      EvidenceArchiveStore.key: jsonEncode(archive.toJson()),
    });
    final store = EvidenceArchiveStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      MaterialApp(
        home: EvidenceArchiveScreen(store: store, initialMonth: start),
      ),
    );
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tracking opens empty archive without inserting sample data', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AutomationScreen(
            activities: ActivityStore(prefs),
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Inspect evidence history'));
    await tester.pumpAndSettle();
    expect(find.text('Evidence history'), findsOneWidget);
    expect(find.textContaining('No evidence saved.'), findsOneWidget);
    expect(find.textContaining('0.00 kg'), findsNothing);
    expect(prefs.getString(EvidenceArchiveStore.key), isNull);
  });

  testWidgets(
    'corrected quantity, factor provenance and historical source revision are visible',
    (tester) async {
      await open(
        tester,
        EvidenceArchive().append(revisions: [meter(1, 100), meter(2, 120)]),
      );
      expect(
        find.text('48.00 kg CO₂e\ngeneration · AR5 · location'),
        findsOneWidget,
      );
      expect(
        find.textContaining('No accepted evidence: heating'),
        findsOneWidget,
      );
      await reveal(tester, find.text('home / meter'));
      expect(find.text('Included · current revision 2'), findsOneWidget);
      await tester.tap(find.text('home / meter'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('100.0 kWh · personal share 1.0'));
      expect(find.text('120.0 kWh · personal share 1.0'), findsOneWidget);
      expect(find.text('https://example.org/factor'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'month navigation holds a cross-month bill and returns to original report',
    (tester) async {
      final r = meter(1, 100);
      final j = r.toJson();
      (j['evidence'] as Map<String, dynamic>)['end'] = DateTime.utc(
        2026,
        11,
        2,
      ).toIso8601String();
      await open(
        tester,
        EvidenceArchive().append(revisions: [EvidenceRevision.fromJson(j)]),
      );
      expect(find.text('No accepted estimate for this month.'), findsOneWidget);
      await reveal(tester, find.textContaining('Split the evidence'));
      expect(find.textContaining('Split the evidence'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byTooltip('Next month'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2026-11-01 to 2026-12-01'), findsOneWidget);
      expect(find.text('No accepted estimate for this month.'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2026-10-01 to 2026-11-01'), findsOneWidget);
    },
  );

  testWidgets(
    'corrupt archive is preserved and reload recovers after external repair',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        EvidenceArchiveStore.key: '{broken',
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: EvidenceArchiveScreen(
            store: EvidenceArchiveStore(prefs),
            initialMonth: start,
          ),
        ),
      );
      expect(
        find.textContaining('Saved evidence could not be read.'),
        findsOneWidget,
      );
      expect(prefs.getString(EvidenceArchiveStore.key), '{broken');
      await prefs.setString(
        EvidenceArchiveStore.key,
        jsonEncode(EvidenceArchive().toJson()),
      );
      await tester.tap(find.byTooltip('Reload evidence'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Saved evidence could not be read.'),
        findsNothing,
      );
      expect(find.textContaining('No evidence saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'withdrawals and stale relationship decisions fit a narrow enlarged-text view',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final a = meter(1, 100);
      final b = EvidenceRevision.fromJson({
        ...a.toJson(),
        'ref': EvidenceRef('home', 'backup', 1).toJson(),
        'evidence': {...a.evidence!.toJson(), 'id': 'backup'},
      });
      final archive = EvidenceArchive().append(
        revisions: [
          a,
          b,
          EvidenceRevision(
            ref: EvidenceRef('home', 'meter', 2),
            receivedAt: end,
          ),
        ],
        relations: [
          EvidenceRelation(
            id: 'bill-match',
            from: a.ref,
            to: b.ref,
            kind: EvidenceRelationKind.sameComponent,
            reviewed: true,
            reason: 'Reviewed synthetic match.',
          ),
        ],
      );
      SharedPreferences.setMockInitialValues({
        EvidenceArchiveStore.key: jsonEncode(archive.toJson()),
      });
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: EvidenceArchiveScreen(
              store: EvidenceArchiveStore(
                await SharedPreferences.getInstance(),
              ),
              initialMonth: start,
            ),
          ),
        ),
      );
      await reveal(tester, find.text('Withdrawn · current revision 2'));
      await reveal(tester, find.text('bill-match · revision 1'));
      await tester.tap(find.text('bill-match · revision 1'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Reviewed synthetic match.'));
      expect(
        find.textContaining('source revised or withdrawn'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
