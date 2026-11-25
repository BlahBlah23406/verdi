// Overview: Checks automatic ingestion, review-queue persistence, and confirmation into the activity journal.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:verdi/features/automation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:verdi/data/activity_store.dart';
import 'package:verdi/data/automation_store.dart';
import 'package:verdi/domain/automation.dart';
import 'package:verdi/domain/carbon.dart';
import 'package:verdi/main.dart';

import '../tool/check_automation.dart' as checks;

void main() {
  testWidgets(
    'connection directory returns to the existing electricity import',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(VerdiApp(store: ActivityStore(prefs)));
      await tester.tap(find.text('Auto track'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Browse connections'));
      await tester.pumpAndSettle();
      expect(find.text('Build a fuller picture.'), findsOneWidget);
      await tester.ensureVisible(find.text('PSE electricity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PSE electricity'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Go to electricity import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go to electricity import'));
      await tester.pumpAndSettle();
      expect(find.text('Choose utility CSV').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'trip detection, utility parsing and reconciliation reference cases',
    checks.main,
  );
  test('review queue and discarded identities survive restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final candidates = parseUtilityCsv(
      'record_id,date,kwh\nr1,2026-01-01,12.5',
      'Home',
    );
    await AutomationStore(prefs)
        .save(AutomationState(candidates, {'discarded-id'}));
    final restored = AutomationStore(prefs).load();
    expect(restored.pending.single.id, candidates.single.id);
    expect(restored.dismissed, contains('discarded-id'));
  });
  test('corrupted queue is reported without overwriting it', () async {
    SharedPreferences.setMockInitialValues({AutomationStore.key: 'broken'});
    final prefs = await SharedPreferences.getInstance();
    expect(() => AutomationStore(prefs).load(), throwsFormatException);
    expect(prefs.getString(AutomationStore.key), 'broken');
  });
  testWidgets('import review confirmation enters journal once', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final candidates = parseUtilityCsv(
      'record_id,date,kwh\nr1,2026-01-01,12.5',
      'Home',
    );
    await AutomationStore(prefs).save(AutomationState(candidates, {}));
    final activityStore = ActivityStore(prefs);
    await tester.pumpWidget(VerdiApp(store: activityStore));
    await tester.tap(find.text('Auto track'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Confirm activity').hitTestable(),
      300,
      scrollable: find
          .descendant(
            of: find.byType(AutomationScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Confirm activity'));
    await tester.pumpAndSettle();
    expect(activityStore.load(), hasLength(1));
    expect(activityStore.load().single.kind, ActivityKind.electricity);
    expect(activityStore.load().single.source, 'utility-csv');
    expect(AutomationStore(prefs).load().pending, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
