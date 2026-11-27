// Verifies HTTP client errors, auth headers and both live entry-point layouts.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:verdi/product/platform_app.dart';
import 'package:verdi/services/phone_tracking.dart';

void main() {
  test('client authenticates and returns server errors without treating them as success', () async {
    final api = PlatformApi(
      'test-session',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-session');
        expect(request.url.path, '/api/redeem');
        expect(jsonDecode(request.body)['key'], 'stable');
        return http.Response('{"error":"Insufficient points."}', 409);
      }),
    );
    await expectLater(
      api.request('redeem', {'key': 'stable'}),
      throwsStateError,
    );
    api.dispose();
  });
  testWidgets('mobile onboarding remembers sign-in and capture opt-in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final messenger = tester.binding.defaultBinaryMessenger;
    final channel = MethodChannel(PhoneTracking.channel.name);
    final locationCalls = <Object?>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'listen') locationCalls.add(call.arguments);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var travel = false;
    var bank = false;
    final requests = <String>[];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const PlatformApp());
        await tester.pumpAndSettle();
        expect(locationCalls, isEmpty);
        await tester.enterText(find.byType(TextField), 'qa-pilot');
        await tester.tap(find.text('Sign in'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Set up your sources'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set up your sources'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Upload'), findsNothing);
        expect(find.text('Sync bank transactions'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('Enable trip detection'),
          200,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Enable trip detection')),
          alignment: 0.4,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Enable trip detection'));
        await tester.pumpAndSettle();
        expect(travel, isTrue);
        expect(locationCalls, [true]);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        bank = true;
        await tester.pumpWidget(const PlatformApp());
        await tester.pumpAndSettle();
        expect(find.text('Sign in'), findsNothing);
        expect(locationCalls, [true, false]);
        await tester.tap(find.byTooltip('Refresh data'));
        await tester.pumpAndSettle();
        expect(requests, isNot(contains('/api/sync')));
        await tester.tap(find.text('Connections').last);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Automatically synced'), 200);
        expect(find.text('Automatically synced'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Electricity and natural gas'),
          200,
        );
        expect(find.text('Electricity and natural gas'), findsOneWidget);
        expect(
          requests.where((path) => path == '/api/connection'),
          hasLength(1),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        travel = false;
        await tester.pumpWidget(const PlatformApp());
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Sign out'));
        await tester.pumpAndSettle();
        expect(find.text('Sign in'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(const PlatformApp());
        await tester.pumpAndSettle();
        expect(find.text('Sign in'), findsOneWidget);
      },
      () => MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer qa-pilot');
        requests.add(request.url.path);
        switch (request.url.path) {
          case '/api/connection':
            expect(jsonDecode(request.body), {
              'provider': 'transport',
              'enabled': true,
            });
            travel = true;
            return http.Response('{}', 200);
          case '/api/me':
            return http.Response(
              jsonEncode({
                'user': {'id': 'qa', 'name': 'QA'},
                'connections': [
                  {
                    'provider': 'utility',
                    'connected': 0,
                    'mode': 'unavailable',
                  },
                  {
                    'provider': 'transport',
                    'connected': travel ? 1 : 0,
                    'mode': 'manual',
                  },
                  {
                    'provider': 'bank',
                    'connected': bank ? 1 : 0,
                    'mode': 'plaid-sandbox',
                    'syncStatus': bank ? 'ok' : 'disconnected',
                    'automaticSyncEnabled': true,
                  },
                ],
                'meterTimeZone': 'America/Los_Angeles',
                'categories': {},
                'period': 'November 2026',
                'activities': [],
                'points': 0,
                'pledgedCents': 0,
                'boundary': 'Pilot estimates.',
              }),
              200,
            );
        }
        fail('Unexpected request ${request.url.path}');
      }),
    );
  });

  for (final institution in [false, true]) {
    testWidgets(
      'live ${institution ? 'institution' : 'consumer'} starts with sign in on small screens',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(PlatformApp(institutional: institution));
        await tester.pumpAndSettle();
        expect(find.text('Sign in'), findsOneWidget);
        expect(find.textContaining('SYNTHETIC DEMO'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
