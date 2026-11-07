// Overview: Unit and widget tests for the institutional aggregation dashboard and reporting calculations.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi/features/institutional_dashboard.dart';

void main() {
  group('Institutional Dashboard Domain Calculations', () {
    test('Calculates total emissions, tonnes, per-capita and category roll-ups accurately', () {
      final org = demoOrganizations.firstWhere((o) => o.id == 'cascadia-uni');

      expect(org.name, 'Cascadia University');
      expect(org.totalMembers, 1420);

      // Verify category roll-up sum
      final expectedSum = 48200.0 + 39500.0 + 14300.0 + 9000.0;
      expect(org.totalEmissionsKg, expectedSum);
      expect(org.totalEmissionsTonnes, expectedSum / 1000.0);

      // Verify per-capita
      expect(org.perCapitaKgCo2e, closeTo(expectedSum / 1420, 0.01));

      // Verify month-over-month change
      expect(org.latestMomChangePercent, -6.4);
    });

    test('generateReportJson outputs complete, audit-compliant JSON structure', () {
      final org = demoOrganizations.firstWhere((o) => o.id == 'acme-cleantech');
      final report = org.generateReportJson();

      expect(report['reportId'], contains('ACME-CLEANTECH'));
      expect(report['organization']['name'], 'Acme CleanTech Corp');
      expect(report['organization']['totalMembers'], 350);

      final summary = report['summary'] as Map<String, dynamic>;
      expect(summary['totalEmissionsMetricTonnes'], org.totalEmissionsTonnes);
      expect(summary['monthOverMonthChangePercent'], -5.4);

      final categoryRollup = report['categoryRollup'] as Map<String, dynamic>;
      expect(categoryRollup.keys, containsAll(['Travel', 'Home & Facilities', 'Products', 'Waste']));

      // Percentages sum to 100%
      var totalPct = 0.0;
      for (final cat in categoryRollup.values) {
        totalPct += (cat as Map)['percentageOfTotal'] as double;
      }
      expect(totalPct, closeTo(100.0, 0.5));

      final topContributors = report['topContributors'] as List;
      expect(topContributors, isNotEmpty);
      expect(topContributors.first['name'], 'Software Engineering');

      final monthlyTrend = report['monthlyTrend'] as List;
      expect(monthlyTrend, hasLength(6));
    });
  });

  group('Institutional Dashboard Widget Tests', () {
    testWidgets('Renders organization profile, metrics, category roll-ups and opens report dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InstitutionalDashboard(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header and primary metrics
      expect(find.text('Organization Emissions View'), findsOneWidget);
      expect(find.text('1420 Active Members'), findsOneWidget);
      expect(find.text('111.0 tonnes'), findsOneWidget);
      expect(find.text('Per-Category Emissions Roll-Up'), findsOneWidget);
      expect(find.text('College of the Environment'), findsOneWidget);

      // Verify download report action
      final downloadBtn = find.text('Download Report (JSON Export)');
      expect(downloadBtn, findsOneWidget);

      await tester.tap(downloadBtn);
      await tester.pumpAndSettle();

      // Verify report modal dialog opens
      expect(find.text('Report: Cascadia University'), findsOneWidget);
      expect(find.text('Copy JSON Report'), findsOneWidget);

      // Tap Copy JSON Report
      await tester.tap(find.text('Copy JSON Report'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify dialog dismissed and snackbar shown
      expect(find.text('Report JSON for Cascadia University copied to clipboard!'), findsOneWidget);
    });

    testWidgets('Switches organizations via dropdown selector and updates metrics', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InstitutionalDashboard(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dropdown selector
      await tester.tap(find.text('Cascadia University (Higher Education Institution)'));
      await tester.pumpAndSettle();

      // Select Acme CleanTech Corp
      await tester.tap(find.text('Acme CleanTech Corp (Enterprise Technology)').last);
      await tester.pumpAndSettle();

      // Verify state updated
      expect(find.text('350 Active Members'), findsOneWidget);
      expect(find.text('44.0 tonnes'), findsOneWidget);
      expect(find.text('Software Engineering'), findsOneWidget);
    });
  });
}
