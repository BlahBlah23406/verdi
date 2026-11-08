// Verifies HTTP client errors, auth headers and both live entry-point layouts.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:verdi/product/platform_app.dart';

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
  for (final institution in [false, true]) {
    testWidgets(
      'live ${institution ? 'institution' : 'consumer'} starts with sign in on small screens',
      (tester) async {
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
