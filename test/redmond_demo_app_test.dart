import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:verdi/product/platform_app.dart';

Future<void> _show(
  WidgetTester tester,
  Finder finder, {
  double delta = 200,
}) async {
  await tester.scrollUntilVisible(finder, delta);
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.4);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(
  WidgetTester tester,
  Finder finder, {
  double delta = 200,
}) async {
  await _show(tester, finder, delta: delta);
  await tester.tap(finder);
}

void main() {
  const households = [
    {
      'id': 'redmond',
      'name': 'Cedar Household',
      'city': 'Redmond, WA',
      'scenario':
          'Eastside household with PSE electricity, gas, and 2 Line transit.',
    },
    {
      'id': 'bellevue',
      'name': 'Maple Household',
      'city': 'Bellevue, WA',
      'scenario': 'Downtown Bellevue commuter household on the 2 Line.',
    },
    {
      'id': 'seattle',
      'name': 'Alder Household',
      'city': 'Seattle, WA',
      'scenario': 'All-electric Seattle City Light renter near the 1 Line.',
    },
  ];

  testWidgets(
    'Cedar Household opens by default, consents per-source and polls without sync',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final writes = <String>[];
      final sessionQueries = <String>[];
      var status = 'disconnected';

      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const PlatformApp(demo: true, redmondDemo: true),
          );
          await tester.pumpAndSettle();
          expect(sessionQueries, ['/api/demo/session']);
          expect(find.text('Cedar Household'), findsOneWidget);
          expect(find.text('Demo household & city'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('demo-household-redmond')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('demo-household-bellevue')),
            findsOneWidget,
          );
          expect(
            find.text('0 of 1 sources syncing automatically'),
            findsOneWidget,
          );

          await _tapVisible(tester, find.text('Set up your sources'));
          await tester.pumpAndSettle();
          await _tapVisible(
            tester,
            find.text('Connect PSE electricity and gas'),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(writes, isEmpty);

          await _tapVisible(
            tester,
            find.text('Connect PSE electricity and gas'),
          );
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
          await _show(tester, find.text('Electricity statement'));
          expect(find.text('Syncing automatically'), findsOneWidget);
          expect(find.text('Electricity statement'), findsOneWidget);
          expect(writes, ['/api/demo-authorize']);
          expect(find.textContaining('Upload'), findsNothing);
          expect(find.text('Rewards'), findsNothing);

          await _tapVisible(
            tester,
            find.text('Simulate expired access · PSE electricity and gas'),
          );
          await tester.pumpAndSettle();
          await _show(tester, find.text('Reconnect PSE electricity and gas'));
          expect(
            find.text('Reconnect PSE electricity and gas'),
            findsOneWidget,
          );
          expect(find.text('Electricity statement'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          if (request.url.path == '/api/demo/households') {
            return http.Response(jsonEncode({'households': households}), 200);
          }
          if (request.url.path == '/api/demo/session') {
            sessionQueries.add(
              request.url.toString().replaceFirst(
                RegExp(r'^https?://[^/]+'),
                '',
              ),
            );
            return http.Response(jsonEncode({'token': 'token-redmond'}), 200);
          }
          expect(request.headers['Authorization'], 'Bearer token-redmond');
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
              'demoHousehold': households.first,
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

  testWidgets(
    'grouped authorization selects eligible sources once and honors custom source metadata',
    (tester) async {
      tester.view.physicalSize = const Size(480, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authorizePayloads = <Map<String, dynamic>>[];
      final statuses = <String, String>{
        'utility': 'disconnected',
        'orca': 'auth_required',
        'bank': 'ok',
      };

      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const PlatformApp(demo: true, redmondDemo: true),
          );
          await tester.pumpAndSettle();

          // Switch to Seattle household to test custom labels/descriptions + grouped consent.
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('demo-household-seattle')),
          );
          await tester.pumpAndSettle();
          expect(find.text('Alder Household'), findsOneWidget);
          expect(
            find.text(
              'All-electric Seattle City Light renter near the 1 Line.',
            ),
            findsOneWidget,
          );

          await _tapVisible(tester, find.text('Set up your sources'));
          await tester.pumpAndSettle();

          await _show(tester, find.text('Seattle City Light electricity'));
          expect(find.text('Seattle City Light electricity'), findsOneWidget);
          expect(
            find.text('Daily all-electric meter readings without gas'),
            findsOneWidget,
          );
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('demo-source-select-utility')),
          );
          await tester.pumpAndSettle();

          // Scroll down to verify ORCA custom metadata & select it.
          await _show(tester, find.text('ORCA 1 Line transit taps'));
          expect(find.text('ORCA 1 Line transit taps'), findsOneWidget);
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('demo-source-select-orca')),
          );
          await tester.pumpAndSettle();

          // Ineligible ('ok') source renders without a selection checkbox.
          await _show(tester, find.text('Bank transactions'));
          expect(
            find.byKey(const ValueKey('demo-source-select-bank')),
            findsNothing,
          );
          expect(
            find.text('Simulate expired access · Bank transactions'),
            findsOneWidget,
          );

          // Scroll back up to grouped authorization bar.
          await _show(tester, find.text('Authorize selected (2)'), delta: -200);
          expect(find.text('2 of 2 eligible sources selected'), findsOneWidget);

          // Cancel grouped dialog: no request should be sent.
          await tester.tap(find.text('Authorize selected (2)'));
          await tester.pumpAndSettle();
          expect(find.text('Authorize 2 simulated sources'), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(authorizePayloads, isEmpty);

          // Confirm grouped dialog: single POST /api/demo-authorize with sources list.
          await tester.tap(find.text('Authorize selected (2)'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Allow demo access'));
          await tester.pumpAndSettle();

          expect(authorizePayloads, [
            {
              'sources': ['utility', 'orca'],
            },
          ]);
          expect(find.text('Authorize sources together'), findsNothing);
          await _show(
            tester,
            find.text('Disconnect Seattle City Light electricity'),
          );
          expect(
            find.text('Authorized · waiting for first sync'),
            findsAtLeastNWidgets(1),
          );
          // Per-source controls remain intact after grouped authorization.
          expect(
            find.text('Disconnect Seattle City Light electricity'),
            findsOneWidget,
          );
          await _show(
            tester,
            find.text('Simulate expired access · Bank transactions'),
          );
          expect(
            find.text('Simulate expired access · Bank transactions'),
            findsOneWidget,
          );

          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          if (request.url.path == '/api/demo/households') {
            return http.Response(jsonEncode({'households': households}), 200);
          }
          if (request.url.path == '/api/demo/session') {
            final id = request.url.queryParameters['household'] ?? 'redmond';
            return http.Response(jsonEncode({'token': 'token-$id'}), 200);
          }
          if (request.headers['Authorization'] == 'Bearer token-redmond') {
            return http.Response(
              jsonEncode({
                'redmondDemo': true,
                'demoHousehold': households[0],
                'demoSources': [
                  {
                    'id': 'utility',
                    'status': 'disconnected',
                    'lastSyncedAt': null,
                    'records': [],
                  },
                ],
              }),
              200,
            );
          }
          expect(request.headers['Authorization'], 'Bearer token-seattle');
          if (request.method == 'POST' &&
              request.url.path == '/api/demo-authorize') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            authorizePayloads.add(body);
            final ids = (body['sources'] as List).cast<String>();
            for (final id in ids) {
              statuses[id] = 'waiting';
            }
            return http.Response('{}', 200);
          }
          expect(request.url.path, '/api/me');
          return http.Response(
            jsonEncode({
              'redmondDemo': true,
              'demoHousehold': households[2],
              'demoSources': [
                {
                  'id': 'utility',
                  'label': 'Seattle City Light electricity',
                  'description':
                      'Daily all-electric meter readings without gas',
                  'status': statuses['utility'],
                  'lastSyncedAt': null,
                  'records': [],
                },
                {
                  'id': 'orca',
                  'label': 'ORCA 1 Line transit taps',
                  'description': 'Tap-on events along Sound Transit 1 Line',
                  'status': statuses['orca'],
                  'lastSyncedAt': null,
                  'records': [
                    {
                      'label': 'Tap at Capitol Hill station',
                      'detail': 'Synthetic ORCA tap; 1 Line',
                    },
                  ],
                },
                {
                  'id': 'bank',
                  'status': statuses['bank'],
                  'lastSyncedAt': '2026-11-03T12:00:00Z',
                  'records': [
                    {
                      'label': 'Synthetic Grocer \$48.23',
                      'detail': 'Synthetic Plaid transaction; posted',
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }),
      );
    },
  );

  testWidgets(
    'switching households clears old data immediately and ignores slower refresh, mutation, and switch responses',
    (tester) async {
      tester.view.physicalSize = const Size(480, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final slowCedarRefresh = Completer<http.Response>();
      final slowCedarMutation = Completer<http.Response>();
      final bellevueMeGate = Completer<http.Response>();
      final slowBellevueSwitch = Completer<http.Response>();
      var cedarMeCount = 0;
      var bellevueSessionCount = 0;
      var slowCedarRefreshStarted = false;
      var slowCedarMutationStarted = false;

      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const PlatformApp(demo: true, redmondDemo: true),
          );
          await tester.pumpAndSettle();

          // Navigate to Connections on Cedar so evidence & controls are visible.
          await _tapVisible(tester, find.text('Set up your sources'));
          await tester.pumpAndSettle();
          expect(find.text('Cedar Household connections'), findsOneWidget);
          expect(find.text('Cedar Electricity 22.4 kWh'), findsOneWidget);

          // Select an eligible Cedar source checkbox before switching.
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('demo-source-select-orca')),
          );
          await tester.pumpAndSettle();
          await _show(
            tester,
            find.byKey(const ValueKey('demo-household-bellevue')),
            delta: -200,
          );
          expect(find.text('1 of 1 eligible sources selected'), findsOneWidget);

          // Trigger a slow manual refresh on Cedar (remains in flight).
          await tester.tap(find.byTooltip('Refresh data'));
          await tester.pump();
          expect(slowCedarRefreshStarted, isTrue);

          // Switch to Bellevue while Cedar's slow refresh is still in flight.
          await tester.tap(
            find.byKey(const ValueKey('demo-household-bellevue')),
          );
          await tester.pump();

          // Old Cedar account data must disappear immediately while Bellevue loads.
          expect(find.text('Cedar Household connections'), findsNothing);
          expect(find.text('Cedar Electricity 22.4 kWh'), findsNothing);
          expect(find.text('Sign in'), findsNothing);
          expect(
            find.textContaining('Loading Maple Household'),
            findsOneWidget,
          );

          // Complete Bellevue's /api/me response.
          bellevueMeGate.complete(
            http.Response(
              jsonEncode({
                'redmondDemo': true,
                'demoHousehold': households[1],
                'demoSources': [
                  {
                    'id': 'orca',
                    'label': 'Bellevue 2 Line ORCA',
                    'description': 'Bellevue Downtown station tap events',
                    'status': 'ok',
                    'lastSyncedAt': '2026-11-04T08:00:00Z',
                    'records': [
                      {
                        'label': 'Tap at Bellevue Downtown station',
                        'detail': 'Synthetic Bellevue ORCA tap',
                      },
                    ],
                  },
                ],
              }),
              200,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Maple Household connections'), findsOneWidget);
          expect(find.text('Tap at Bellevue Downtown station'), findsOneWidget);
          expect(find.text('Cedar Electricity 22.4 kWh'), findsNothing);

          // Resolve the stale slower Cedar refresh with distinct Cedar data.
          slowCedarRefresh.complete(
            http.Response(
              jsonEncode({
                'redmondDemo': true,
                'demoHousehold': households[0],
                'demoSources': [
                  {
                    'id': 'utility',
                    'status': 'ok',
                    'lastSyncedAt': '2026-11-05T08:00:00Z',
                    'records': [
                      {
                        'label': 'STALE CEDAR REFRESH RECORD',
                        'detail': 'Should never overwrite Bellevue',
                      },
                    ],
                  },
                ],
              }),
              200,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Maple Household connections'), findsOneWidget);
          expect(find.text('Tap at Bellevue Downtown station'), findsOneWidget);
          expect(find.text('STALE CEDAR REFRESH RECORD'), findsNothing);

          // Switch back to Cedar and start a slow mutation (demo-expire), then switch away.
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('demo-household-redmond')),
            delta: -200,
          );
          await tester.pumpAndSettle();
          expect(find.text('Cedar Household connections'), findsOneWidget);
          // Prior Cedar checkbox selection must have been cleared on switch.
          expect(find.text('0 of 1 eligible sources selected'), findsOneWidget);

          await _tapVisible(
            tester,
            find.text('Simulate expired access · PSE electricity and gas'),
          );
          await tester.pump();
          expect(slowCedarMutationStarted, isTrue);

          // Switch to Bellevue (slow session) and then rapidly to Seattle (fast).
          await _show(
            tester,
            find.byKey(const ValueKey('demo-household-bellevue')),
            delta: -200,
          );
          await tester.tap(
            find.byKey(const ValueKey('demo-household-bellevue')),
          );
          await tester.pump();
          expect(find.text('Cedar Household connections'), findsNothing);

          await tester.tap(
            find.byKey(const ValueKey('demo-household-seattle')),
          );
          await tester.pumpAndSettle();
          expect(find.text('Alder Household connections'), findsOneWidget);
          expect(find.text('Seattle City Light 14.2 kWh'), findsOneWidget);

          // Complete BOTH the stale Cedar mutation AND the stale Bellevue session switch.
          slowCedarMutation.complete(http.Response('{}', 200));
          slowBellevueSwitch.complete(
            http.Response(jsonEncode({'token': 'token-bellevue-stale'}), 200),
          );
          await tester.pumpAndSettle();

          // Seattle must remain active with zero overwrite from Cedar or Bellevue.
          expect(find.text('Alder Household connections'), findsOneWidget);
          expect(find.text('Seattle City Light 14.2 kWh'), findsOneWidget);
          expect(find.text('Cedar Household connections'), findsNothing);
          expect(find.text('Maple Household connections'), findsNothing);

          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          if (request.url.path == '/api/demo/households') {
            return http.Response(jsonEncode({'households': households}), 200);
          }
          if (request.url.path == '/api/demo/session') {
            final id = request.url.queryParameters['household'] ?? 'redmond';
            if (id == 'bellevue') {
              bellevueSessionCount++;
              if (bellevueSessionCount == 2) {
                return slowBellevueSwitch.future;
              }
            }
            return http.Response(jsonEncode({'token': 'token-$id'}), 200);
          }

          final auth = request.headers['Authorization'];
          if (auth == 'Bearer token-redmond') {
            if (request.method == 'POST' &&
                request.url.path == '/api/demo-expire') {
              slowCedarMutationStarted = true;
              return slowCedarMutation.future;
            }
            cedarMeCount++;
            if (cedarMeCount == 2) {
              slowCedarRefreshStarted = true;
              return slowCedarRefresh.future;
            }
            return http.Response(
              jsonEncode({
                'redmondDemo': true,
                'demoHousehold': households[0],
                'demoSources': [
                  {
                    'id': 'utility',
                    'status': 'ok',
                    'lastSyncedAt': '2026-11-04T08:00:00Z',
                    'records': [
                      {
                        'label': 'Cedar Electricity 22.4 kWh',
                        'detail': 'Synthetic Redmond daily total',
                      },
                    ],
                  },
                  {
                    'id': 'orca',
                    'status': 'disconnected',
                    'lastSyncedAt': null,
                    'records': [],
                  },
                ],
              }),
              200,
            );
          }

          if (auth == 'Bearer token-bellevue') {
            return bellevueMeGate.future;
          }

          if (auth == 'Bearer token-bellevue-stale') {
            fail(
              'Stale Bellevue switch should never issue /api/me after epoch changed',
            );
          }

          if (auth == 'Bearer token-seattle') {
            return http.Response(
              jsonEncode({
                'redmondDemo': true,
                'demoHousehold': households[2],
                'demoSources': [
                  {
                    'id': 'utility',
                    'label': 'Seattle City Light electricity',
                    'description': 'All-electric daily kWh',
                    'status': 'ok',
                    'lastSyncedAt': '2026-11-04T08:00:00Z',
                    'records': [
                      {
                        'label': 'Seattle City Light 14.2 kWh',
                        'detail': 'Synthetic Seattle daily total',
                      },
                    ],
                  },
                ],
              }),
              200,
            );
          }

          fail('Unexpected request ${request.method} ${request.url} ($auth)');
        }),
      );
    },
  );
}
