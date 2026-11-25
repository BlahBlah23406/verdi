import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:verdi/product/platform_app.dart';

void main() {
  testWidgets(
    'Cedar Household consents and polls without sending a sync request',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final writes = <String>[];
      var status = 'disconnected';

      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const PlatformApp(demo: true, redmondDemo: true),
          );
          await tester.pumpAndSettle();
          expect(find.text('Cedar Household'), findsOneWidget);
          expect(
            find.text('0 of 1 sources syncing automatically'),
            findsOneWidget,
          );

          await tester.tap(find.text('Set up your sources'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Connect PSE electricity and gas'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(writes, isEmpty);

          await tester.tap(find.text('Connect PSE electricity and gas'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Allow demo access'));
          await tester.pumpAndSettle();
          expect(writes, ['/api/demo-authorize']);
          expect(
            find.text('Authorized · waiting for first sync'),
            findsOneWidget,
          );

          status = 'ok';
          await tester.pump(const Duration(seconds: 2));
          await tester.pumpAndSettle();
          expect(find.text('Syncing automatically'), findsOneWidget);
          expect(find.text('Electricity statement'), findsOneWidget);
          expect(writes, ['/api/demo-authorize']);
          expect(find.textContaining('Upload'), findsNothing);
          expect(find.text('Rewards'), findsNothing);

          await tester.tap(
            find.text('Simulate expired access · PSE electricity and gas'),
          );
          await tester.pumpAndSettle();
          expect(
            find.text('Reconnect PSE electricity and gas'),
            findsOneWidget,
          );
          expect(find.text('Electricity statement'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer verdi-redmond-demo');
          if (request.method == 'POST') {
            writes.add(request.url.path);
            expect(jsonDecode(request.body), {'source': 'utility'});
            status = request.url.path == '/api/demo-authorize'
                ? 'waiting'
                : 'auth_required';
            return http.Response('{}', 200);
          }
          expect(request.url.path, '/api/me');
          return http.Response(
            jsonEncode({
              'redmondDemo': true,
              'demoSources': [
                {
                  'id': 'utility',
                  'status': status,
                  'lastSyncedAt': null,
                  'records': status == 'ok' || status == 'auth_required'
                      ? [
                          {
                            'label': 'Electricity statement',
                            'detail': '450 kWh',
                          },
                        ]
                      : [],
                },
              ],
            }),
            200,
          );
        }),
      );
    },
  );
}
