import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:verdi/data/activity_store.dart';
import 'package:verdi/main.dart';

void main() {
  testWidgets('log, reload and delete activity; compare travel', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = ActivityStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(VerdiApp(store: store));
    expect(find.text('0.0 kg'), findsOneWidget);
    await tester.tap(find.text('Log activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save activity'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a number greater than 0, up to 1,000,000.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField).first, '10');
    await tester.tap(find.text('Save activity'));
    await tester.pumpAndSettle();
    expect(find.text('2.0 kg'), findsOneWidget);
    expect(store.load(), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(VerdiApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('2.0 kg'), findsOneWidget);
    await tester.tap(find.text('Activities'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(store.load(), isEmpty);
    await tester.tap(find.text('Reduce'));
    await tester.pumpAndSettle();
    expect(find.text('3.2 kg CO₂e'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('small phone layout renders without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      VerdiApp(store: ActivityStore(await SharedPreferences.getInstance())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Reduce'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
