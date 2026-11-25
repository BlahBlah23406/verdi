// Overview: Checks region staging, truthful connection details and mobile layout.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:verdi/data/connection_setup_store.dart';
import 'package:verdi/domain/connection_catalog.dart';
import 'package:verdi/features/connections_screen.dart';

Future<void> reveal(WidgetTester tester, Finder finder, double delta) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find
        .descendant(
          of: find.byType(ConnectionsScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  test('regional expansion preserves earlier connections', () {
    final redmond = connectionsThrough(ConnectionRegion.redmond)
        .map((c) => c.id)
        .toSet();
    final seattle = connectionsThrough(ConnectionRegion.greaterSeattle)
        .map((c) => c.id)
        .toSet();
    final washington = connectionsThrough(ConnectionRegion.washington)
        .map((c) => c.id)
        .toSet();
    expect(
      redmond,
      containsAll([
        'pse-electricity',
        'pse-gas',
        'orca',
        'receipts',
        'banking',
      ]),
    );
    expect(seattle, containsAll(redmond));
    expect(seattle, containsAll(['city-light', 'snopud', 'chargepoint']));
    expect(washington, containsAll(seattle));
    expect(washington, contains('ferries'));
    expect(
      connectionCatalog.map((c) => c.id).toSet(),
      hasLength(connectionCatalog.length),
    );
  });

  testWidgets(
    'default source details explain normalized import and no live sync',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ConnectionsScreen()));
      expect(find.text('Redmond'), findsOneWidget);
      expect(
        find.textContaining('No provider accounts are live-connected'),
        findsOneWidget,
      );
      await reveal(tester, find.text('PSE electricity'), 250);
      await tester.tap(find.text('PSE electricity'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'only daily data converted to record_id,date,kwh CSV',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('No live PSE sync is connected'),
        findsOneWidget,
      );
      expect(find.text('Go to electricity import'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('region filter adds Seattle and Washington sources', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ConnectionsScreen()));
    await tester.tap(find.text('Greater Seattle'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Seattle City Light'), 450);
    expect(find.text('Seattle City Light'), findsOneWidget);
    await reveal(tester, find.text('Greater Seattle'), -500);
    await tester.tap(find.text('Washington'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Washington State Ferries'), 500);
    expect(find.text('Washington State Ferries'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'small phone and enlarged text keep details within the viewport',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: ConnectionsScreen(),
          ),
        ),
      );
      await reveal(tester, find.text('PSE electricity'), 250);
      await tester.tap(find.text('PSE electricity'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Copy source link'), 300);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('electricity action returns an explicit import request', (
    tester,
  ) async {
    ConnectionsAction? action;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                action = await Navigator.of(context).push<ConnectionsAction>(
                  MaterialPageRoute(builder: (_) => const ConnectionsScreen()),
                );
              },
              child: const Text('Open directory'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open directory'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('PSE electricity'), 250);
    await tester.tap(find.text('PSE electricity'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Go to electricity import'), 300);
    await tester.tap(find.text('Go to electricity import'));
    await tester.pumpAndSettle();
    expect(action, ConnectionsAction.electricityImport);
    expect(find.text('Open directory'), findsOneWidget);
  });

  testWidgets('choices persist, show honest status and can be cleared', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Future<void> open() async {
      await tester.pumpWidget(
        MaterialApp(
          home: ConnectionsScreen(setupStore: ConnectionSetupStore(prefs)),
        ),
      );
      await reveal(tester, find.text('PSE electricity'), 250);
      await tester.tap(find.text('PSE electricity'));
      await tester.pumpAndSettle();
    }

    await open();
    expect(find.text('Go to utility review'), findsOneWidget);
    expect(find.textContaining('Verdi never signs in to PSE'), findsOneWidget);
    await reveal(
      tester,
      find.byKey(const ValueKey('defer-pse-electricity')),
      300,
    );
    await tester.tap(find.byKey(const ValueKey('defer-pse-electricity')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved for later'), findsWidgets);
    expect(find.textContaining('nothing is connected'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await open();
    expect(find.textContaining('Saved for later'), findsWidgets);
    await reveal(
      tester,
      find.byKey(const ValueKey('clear-pse-electricity')),
      300,
    );
    await tester.tap(find.byKey(const ValueKey('clear-pse-electricity')));
    await tester.pumpAndSettle();
    expect(ConnectionSetupStore(prefs).load(), isEmpty);
  });

  testWidgets('utility review action is returned to the caller', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ConnectionsAction? action;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => action = await Navigator.of(context)
                .push<ConnectionsAction>(
                  MaterialPageRoute(
                    builder: (_) => ConnectionsScreen(
                      setupStore: ConnectionSetupStore(prefs),
                    ),
                  ),
                ),
            child: const Text('Open directory'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open directory'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('PSE electricity'), 250);
    await tester.tap(find.text('PSE electricity'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Go to utility review'), 300);
    await tester.tap(find.text('Go to utility review'));
    await tester.pumpAndSettle();
    expect(action, ConnectionsAction.electricityReview);
  });
}
