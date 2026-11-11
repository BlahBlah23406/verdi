// Overview: Tests for institutional map feature and factor analysis visualization.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi/features/institution_map_view.dart';
import 'package:verdi/features/factor_analysis_view.dart';

void main() {
  group('Institutional Geospatial Map Tests', () {
    testWidgets('renders map header, metrics, corridors, and hotspots', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InstitutionMapView(organizationName: 'Cascadia University'),
            ),
          ),
        ),
      );

      // Verify title & eyebrow
      expect(find.text('Carbon Map: Routes & Hotspots'), findsOneWidget);
      expect(find.textContaining('GEOSPATIAL CARBON INTELLIGENCE'), findsOneWidget);

      // Verify KPIs
      expect(find.text('Corridor Emissions'), findsOneWidget);
      expect(find.text('Facility Hotspots'), findsOneWidget);
      expect(find.text('Mitigation Potential'), findsOneWidget);

      // Verify filter chips
      expect(find.textContaining('All Routes & Places'), findsOneWidget);
      expect(find.text('High Carbon Only (≥22t)'), findsOneWidget);

      // Verify map canvas is present
      expect(find.byType(CustomPaint), findsWidgets);

      // Verify default inspector
      expect(find.text('North Campus District Cogeneration Plant'), findsWidgets);
      expect(find.textContaining('Natural gas heating boilers'), findsWidgets);

      // Tap a corridor card to select route inspector
      final corridorCard = find.text('I-5 North Gateway Commute Corridor');
      expect(corridorCard, findsOneWidget);
      await tester.ensureVisible(corridorCard);
      await tester.tap(corridorCard);
      await tester.pumpAndSettle();

      // Verify corridor inspector details
      expect(find.textContaining('Modal Profile:'), findsOneWidget);
      expect(find.text('COR-01'), findsWidgets);
    });
  });

  group('Institutional Factor Sensitivity Tests', () {
    testWidgets('renders factor waterfall chart, interactive sliders, and scenario simulator', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FactorAnalysisView(totalBaselineTonnes: 263.7),
            ),
          ),
        ),
      );

      // Verify header & title
      expect(find.text('Which Factors Affect Carbon Most?'), findsOneWidget);
      expect(find.textContaining('Ranked Factor Impact Breakdown'), findsOneWidget);

      // Verify top determinants are listed
      expect(find.text('Commute Transport Mode Choice'), findsOneWidget);
      expect(find.text('Commute Distance & In-Office Frequency'), findsOneWidget);
      expect(find.text('Grid Electricity Marginal Carbon Intensity'), findsOneWidget);

      // Verify simulator card and baseline comparison
      expect(find.text('Baseline Footprint'), findsOneWidget);
      expect(find.text('Simulated Footprint'), findsOneWidget);
      expect(find.textContaining('reduction vs. 263.7t baseline'), findsOneWidget);

      // Verify interactive sliders
      expect(find.byType(Slider), findsNWidgets(4));

      // Drag the mode shift slider
      final firstSlider = find.byType(Slider).first;
      await tester.ensureVisible(firstSlider);
      await tester.drag(firstSlider, const Offset(50, 0));
      await tester.pumpAndSettle();

      // Verify key takeaways
      expect(find.text('Mode Shift Outperforms All Vehicle Upgrades'), findsOneWidget);
      expect(find.textContaining('Remote Collaboration Days Deliver Immediate'), findsOneWidget);
    });
  });
}
