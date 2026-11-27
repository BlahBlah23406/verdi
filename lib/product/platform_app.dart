// Shared responsive Flutter UI for consumer rewards and institution analytics.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pilot_phone_capture.dart';

import '../domain/automation.dart';
import '../features/institution_map_view.dart'
    hide ink, paper, lime, forest, cream, amber, coral, sage;
import '../features/factor_analysis_view.dart'
    hide ink, paper, lime, forest, cream, amber, coral, sage;

const ink = Color(0xFF163D32);
const forest = Color(0xFF174C38);
const paper = Color(0xFFF4F5EE);
const lime = Color(0xFFD6EC92);

class PlatformApi {
  PlatformApi(this.token, {http.Client? client, String? base})
    : client = client ?? http.Client(),
      base = (base ?? _defaultBase()).replaceFirst(RegExp(r'/+$'), '');

  static String _defaultBase() {
    const configured = String.fromEnvironment('VERDI_API');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb && Uri.base.scheme == 'https') return Uri.base.origin;
    return 'http://127.0.0.1:8787';
  }

  final String token, base;
  final http.Client client;
  Future<Map<String, dynamic>> request(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final uri = Uri.parse('$base/api/$path');
    final headers = {
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final response =
        await (body == null
                ? client.get(uri, headers: headers)
                : client.post(uri, headers: headers, body: jsonEncode(body)))
            .timeout(const Duration(seconds: 35));
    final Object? payload;
    try {
      payload = jsonDecode(response.body);
    } on FormatException {
      throw StateError(
        'The API returned an unexpected response (HTTP ${response.statusCode}).',
      );
    }
    if (payload is! Map<String, dynamic>) {
      throw StateError('The API returned an unexpected response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PlatformRequestError(
        response.statusCode,
        payload['error'] as String? ?? 'Request failed.',
      );
    }
    return payload;
  }

  void dispose() => client.close();
}

class PlatformRequestError extends StateError {
  PlatformRequestError(this.status, super.message);
  final int status;
}

class PlatformApp extends StatelessWidget {
  const PlatformApp({
    super.key,
    this.demo = false,
    this.institutional = false,
    this.redmondDemo = false,
  });
  final bool demo, institutional, redmondDemo;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: institutional ? 'Verdi for institutions' : 'Verdi',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        primary: ink,
        secondary: lime,
      ),
      cardTheme: const CardThemeData(elevation: 0, color: Colors.white),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: PlatformHome(
      demo: demo,
      institutional: institutional,
      redmondDemo: redmondDemo,
    ),
  );
}

class PlatformHome extends StatefulWidget {
  const PlatformHome({
    super.key,
    required this.demo,
    required this.institutional,
    this.redmondDemo = false,
  });
  final bool demo, institutional, redmondDemo;
  @override
  State<PlatformHome> createState() => _PlatformHomeState();
}

class _PlatformHomeState extends State<PlatformHome> {
  PlatformApi? api;
  Map<String, dynamic>? data;
  String? error;
  bool busy = false;
  int tab = 0;
  int institutionTab = 0;
  String period = '2026-10';
  final tokenController = TextEditingController();
  static const secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  PilotPhoneCapture? phone;
  bool phoneBusy = false;
  Timer? demoPoll;
  int? demoReadingEpoch;
  int sessionEpoch = 0;
  PlatformApi? demoCatalogApi;
  List<Map<String, dynamic>> demoHouseholds = const [];
  String? selectedHouseholdId;
  bool switchingHousehold = false;
  final Set<String> selectedDemoSources = <String>{};

  String? get _redmondBase =>
      widget.redmondDemo && kIsWeb ? Uri.base.origin : null;

  bool get nativeConsumer =>
      !widget.demo &&
      !widget.institutional &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  String get sessionKey =>
      'verdi.pilot.session.v1.${PlatformApi._defaultBase()}';

  Future<void> restoreSession() async {
    setState(() => busy = true);
    try {
      final token = await secureStorage.read(key: sessionKey);
      if (!mounted || token == null) return;
      api = PlatformApi(token);
      await refresh();
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not restore your pilot sign-in.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> signOut() async {
    sessionEpoch++;
    setState(() => busy = true);
    try {
      if (nativeConsumer) await secureStorage.delete(key: sessionKey);
      if (!mounted) return;
      String? signOutNotice;
      try {
        await phone?.setConsent(false);
      } catch (_) {
        signOutNotice = 'Could not save the last phone trip.';
      }
      if (!mounted) return;
      phone?.dispose();
      phone = null;
      api?.dispose();
      setState(() {
        api = null;
        data = null;
        tab = 0;
        institutionTab = 0;
        error = signOutNotice;
      });
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not finish signing out. Try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool sourceEnabled(Map<String, dynamic> snapshot, String provider) =>
      (snapshot['connections'] as List).any(
        (source) => source['provider'] == provider && source['connected'] == 1,
      );

  Future<void> configurePhone(Map<String, dynamic> snapshot) async {
    final base = api!.base;
    final user = (snapshot['user'] as Map)['id'];
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final capture = phone ??= PilotPhoneCapture(
      prefs,
      jsonEncode([base, user]),
    );
    await capture.setConsent(sourceEnabled(snapshot, 'transport'));
  }

  @override
  void initState() {
    super.initState();
    if (widget.demo) {
      if (widget.redmondDemo) {
        demoCatalogApi = PlatformApi('', base: _redmondBase);
        unawaited(_initRedmondDemo());
        demoPoll = Timer.periodic(
          const Duration(seconds: 2),
          (_) => pollDemo(),
        );
      } else {
        api = PlatformApi(
          widget.institutional ? 'verdi-demo-analyst' : 'verdi-demo-consumer',
        );
        refresh();
      }
    } else if (nativeConsumer) {
      unawaited(restoreSession());
    }
  }

  @override
  void dispose() {
    sessionEpoch++;
    demoPoll?.cancel();
    phone?.dispose();
    api?.dispose();
    demoCatalogApi?.dispose();
    tokenController.dispose();
    super.dispose();
  }

  Future<void> _initRedmondDemo() async {
    unawaited(_loadDemoHouseholds());
    await switchDemoHousehold(null, force: true);
  }

  Future<void> _loadDemoHouseholds() async {
    final catalogApi = demoCatalogApi;
    if (catalogApi == null) return;
    try {
      final response = await catalogApi.request('demo/households');
      if (!mounted) return;
      final raw = response['households'];
      if (raw is List) {
        final parsed = raw
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .where((entry) => entry['id'] is String)
            .toList();
        if (parsed.isNotEmpty) {
          setState(() => demoHouseholds = parsed);
        }
      }
    } catch (_) {
      // Keep working with the active household snapshot if catalog is unavailable.
    }
  }

  Future<void> switchDemoHousehold(
    String? householdId, {
    bool force = false,
  }) async {
    if (!widget.redmondDemo) return;
    if (householdId != null &&
        !force &&
        householdId == selectedHouseholdId &&
        data != null &&
        api != null &&
        error == null) {
      return;
    }
    final catalogApi = demoCatalogApi ??= PlatformApi('', base: _redmondBase);
    final epoch = ++sessionEpoch;
    final oldApi = api;
    setState(() {
      api = null;
      data = null;
      error = null;
      busy = true;
      switchingHousehold = true;
      selectedDemoSources.clear();
      if (householdId != null) {
        selectedHouseholdId = householdId;
      }
    });
    oldApi?.dispose();

    PlatformApi? nextApi;
    try {
      final sessionPath = householdId == null
          ? 'demo/session'
          : 'demo/session?household=${Uri.encodeQueryComponent(householdId)}';
      String token;
      try {
        final session = await catalogApi.request(sessionPath);
        final rawToken = session['token'];
        if (rawToken is! String || rawToken.isEmpty) {
          throw StateError('The API returned an invalid demo session.');
        }
        token = rawToken;
      } on PlatformRequestError catch (e) {
        if (e.status == 404 && householdId == null) {
          token = 'verdi-redmond-demo';
        } else {
          rethrow;
        }
      }
      if (!mounted || epoch != sessionEpoch) return;
      nextApi = PlatformApi(token, base: _redmondBase);
      final result = await nextApi.request('me');
      if (!mounted || epoch != sessionEpoch) {
        nextApi.dispose();
        return;
      }
      final household = result['demoHousehold'];
      final resolvedId = household is Map && household['id'] is String
          ? household['id'] as String
          : (householdId ?? 'redmond');
      setState(() {
        api = nextApi;
        data = result;
        selectedHouseholdId = resolvedId;
        selectedDemoSources.clear();
        busy = false;
        switchingHousehold = false;
        error = null;
      });
      nextApi = null;
    } catch (e) {
      nextApi?.dispose();
      if (!mounted || epoch != sessionEpoch) return;
      setState(() {
        busy = false;
        switchingHousehold = false;
        error =
            'Could not load Verdi. Check the API connection. ${e.toString().replaceFirst('Bad state: ', '')}';
      });
    }
  }

  Future<void> pollDemo() async {
    final currentApi = api;
    final epoch = sessionEpoch;
    if (busy ||
        switchingHousehold ||
        demoReadingEpoch == epoch ||
        data == null ||
        currentApi == null) {
      return;
    }
    final before = data;
    demoReadingEpoch = epoch;
    try {
      final latest = await currentApi.request('me');
      if (mounted &&
          !busy &&
          !switchingHousehold &&
          epoch == sessionEpoch &&
          identical(api, currentApi) &&
          identical(before, data)) {
        setState(() {
          data = latest;
          _pruneSelectedDemoSources(latest);
        });
      }
    } on PlatformRequestError catch (e) {
      if (e.status == 401 && mounted && !busy && epoch == sessionEpoch) {
        await switchDemoHousehold(selectedHouseholdId, force: true);
      }
    } catch (_) {
      // Keep the last fetched state available. Refresh can surface connection errors.
    } finally {
      if (demoReadingEpoch == epoch) {
        demoReadingEpoch = null;
      }
    }
  }

  Future<void> refresh({bool remember = false}) async {
    if (widget.redmondDemo && demoHouseholds.isEmpty) {
      unawaited(_loadDemoHouseholds());
    }
    final currentApi = api;
    if (currentApi == null) {
      if (widget.redmondDemo) {
        await switchDemoHousehold(selectedHouseholdId, force: true);
      }
      return;
    }
    final epoch = sessionEpoch;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await currentApi.request(
        widget.institutional ? 'institution' : 'me',
      );
      if (!mounted || epoch != sessionEpoch || !identical(api, currentApi)) {
        return;
      }
      setState(() {
        data = result;
        _pruneSelectedDemoSources(result);
      });
      if (remember && nativeConsumer) {
        try {
          await secureStorage.write(key: sessionKey, value: currentApi.token);
        } catch (_) {
          if (mounted && epoch == sessionEpoch && identical(api, currentApi)) {
            setState(
              () => error = 'Could not remember this sign-in on your phone.',
            );
          }
        }
      }
      if (mounted &&
          nativeConsumer &&
          epoch == sessionEpoch &&
          identical(api, currentApi)) {
        try {
          await configurePhone(result);
        } catch (_) {
          if (mounted && epoch == sessionEpoch && identical(api, currentApi)) {
            setState(() => error = 'Could not load phone trip settings.');
          }
        }
      }
    } catch (e) {
      if (!mounted || epoch != sessionEpoch || !identical(api, currentApi)) {
        return;
      }
      if (e is PlatformRequestError && e.status == 401) {
        if (widget.redmondDemo) {
          await switchDemoHousehold(selectedHouseholdId, force: true);
          return;
        }
        if (!widget.demo) {
          await signOut();
          if (mounted && api == null) {
            setState(
              () => error = 'That pilot session is invalid or has expired.',
            );
          }
          return;
        }
      }
      if (mounted) {
        setState(
          () => error =
              'Could not load Verdi. Check the API connection. ${e.toString().replaceFirst('Bad state: ', '')}',
        );
      }
    } finally {
      if (mounted && epoch == sessionEpoch && identical(api, currentApi)) {
        setState(() => busy = false);
      }
    }
  }

  Future<bool> act(String action, Map<String, dynamic> body) async {
    final currentApi = api;
    if (currentApi == null) return false;
    final epoch = sessionEpoch;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await currentApi.request(action, body);
      if (!mounted || epoch != sessionEpoch || !identical(api, currentApi)) {
        return false;
      }
      if (action == 'connection' &&
          body['provider'] == 'transport' &&
          body['enabled'] == false) {
        await phone?.setConsent(false);
      }
      if (!mounted || epoch != sessionEpoch || !identical(api, currentApi)) {
        return false;
      }
      if (action == 'coach') {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(response['mode'] as String),
            content: SingleChildScrollView(
              child: SelectableText(
                '${response['text']}\n\nScenario facts: ${jsonEncode(response['facts'])}',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
      if (mounted && epoch == sessionEpoch && identical(api, currentApi)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(switch (action) {
              'sync' when !widget.demo =>
                '${response['added']} bank records updated, ${response['removed']} removed',
              'sync' || 'import' || 'import-phone-trip' =>
                '${response['added']} new records, ${response['duplicates']} duplicates skipped',
              _ => 'Saved${widget.demo ? ' to the synthetic demo' : ''}',
            }),
          ),
        );
        await refresh();
      }
      return epoch == sessionEpoch && identical(api, currentApi);
    } catch (e) {
      if (mounted && epoch == sessionEpoch && identical(api, currentApi)) {
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
      }
      return false;
    } finally {
      if (mounted && epoch == sessionEpoch && identical(api, currentApi)) {
        setState(() => busy = false);
      }
    }
  }

  Widget title(String text) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 14),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 25,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    ),
  );
  Widget box(Widget child) => Card(
    child: Padding(padding: const EdgeInsets.all(22), child: child),
  );
  Widget metric(String label, String value, String detail) => SizedBox(
    width: 280,
    child: box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          Text(detail, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    ),
  );
  Widget button(
    String text,
    VoidCallback? onTap, {
    IconData icon = Icons.arrow_forward,
  }) => FilledButton.icon(
    onPressed: busy || phoneBusy ? null : onTap,
    icon: Icon(icon, size: 18),
    label: Text(text),
  );
  List<Map<String, dynamic>> get activities =>
      (data?['activities'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: paper,
      title: Row(
        children: [
          const Icon(Icons.spa_outlined, color: ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.institutional ? 'verdi / institutions' : 'verdi',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
            ),
          ),
        ],
      ),
      actions: [
        if (api != null || widget.redmondDemo)
          IconButton(
            tooltip: 'Refresh data',
            onPressed: busy || phoneBusy ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
        if (api != null && !widget.demo)
          IconButton(
            tooltip: 'Sign out',
            onPressed: busy || phoneBusy ? null : signOut,
            icon: const Icon(Icons.logout),
          ),
        const SizedBox(width: 12),
      ],
    ),
    body: Column(
      children: [
        if (widget.demo)
          Container(
            width: double.infinity,
            color: lime,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Text(
              widget.redmondDemo ? _redmondBannerText() : 'SYNTHETIC DEMO · Fictional accounts and providers. Rewards and contributions are simulations.',
              style: const TextStyle(color: ink),
            ),
          ),
        if (busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: ListView(
                key: ValueKey(
                  [
                    data == null,
                    widget.institutional ? institutionTab : tab,
                    if (widget.redmondDemo) selectedHouseholdId,
                  ].join('|'),
                ),
                padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 600 ? 18 : 36,
                ),
                children: [
                  if (widget.redmondDemo) _demoHouseholdSwitcher(),
                  if (error != null)
                    box(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            error!,
                            style: TextStyle(color: Colors.red.shade800),
                          ),
                          TextButton(
                            onPressed: busy ? null : refresh,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  if (widget.redmondDemo) ...[
                    if (data != null)
                      ...redmondHousehold()
                    else if (error == null)
                      _redmondLoadingCard(),
                  ] else if (api == null)
                    ...login()
                  else if (data != null)
                    ...(widget.institutional ? institution() : consumer()),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
    bottomNavigationBar: data != null
        ? NavigationBar(
            selectedIndex: widget.institutional ? institutionTab : tab,
            onDestinationSelected: (value) => setState(() {
              if (widget.institutional) {
                institutionTab = value;
              } else {
                tab = value;
              }
            }),
            destinations: widget.institutional
                ? const [
                    NavigationDestination(
                      icon: Icon(Icons.analytics_outlined),
                      label: 'Overview',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.map_outlined),
                      label: 'Carbon Map',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.insights_outlined),
                      label: 'Factor Analysis',
                    ),
                  ]
                : [
                    const NavigationDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      label: 'Today',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.hub_outlined),
                      label: 'Connections',
                    ),
                    if (!widget.redmondDemo)
                      const NavigationDestination(
                        icon: Icon(Icons.redeem_outlined),
                        label: 'Rewards',
                      ),
                    if (!widget.redmondDemo)
                      const NavigationDestination(
                        icon: Icon(Icons.manage_accounts_outlined),
                        label: 'Your data',
                      ),
                  ],
          )
        : null,
  );

  List<Widget> login() => [
    title(
      widget.institutional
          ? 'Understand your sustainability program'
          : 'Make lower-impact choices rewarding',
    ),
    const Text('Enter the session token from your Verdi pilot invitation.'),
    const SizedBox(height: 24),
    TextField(
      controller: tokenController,
      obscureText: true,
      decoration: const InputDecoration(labelText: 'Pilot session token'),
    ),
    const SizedBox(height: 20),
    button('Sign in', () async {
      final token = tokenController.text.trim();
      if (token.isEmpty) {
        setState(() => error = 'Enter your pilot session token.');
        return;
      }
      api = PlatformApi(token);
      tokenController.clear();
      await refresh(remember: true);
    }),
  ];

  List<Widget> consumer() {
    if (widget.redmondDemo) return redmondHousehold();
    switch (tab) {
      case 1:
        return connections();
      case 2:
        return rewards();
      case 3:
        return privacy();
    }
    final cats = Map<String, dynamic>.from(data!['categories'] as Map);
    final total = cats.values.fold<double>(
      0,
      (sum, e) => sum + (e as num).toDouble(),
    );
    final pending = activities.where((e) => e['status'] == 'pending').toList();
    return [
      const SizedBox(height: 12),
      Text(
        'Good choices add up, ${(data!['user'] as Map)['name']}.',
        style: const TextStyle(
          fontSize: 36,
          height: 1.15,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      if (!widget.demo &&
          !(data!['connections'] as List).any((s) => s['connected'] == 1))
        box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'See which sources are available for your pilot account.',
              ),
              button(
                'Set up your sources',
                () => setState(() => tab = 1),
                icon: Icons.hub_outlined,
              ),
            ],
          ),
        ),
      const SizedBox(height: 16),
      const Text(
        'Connect your everyday activity. See where to act. Earn rewards when comparable evidence supports a reduction.',
        style: TextStyle(fontSize: 17),
      ),
      const SizedBox(height: 26),
      Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          metric(
            'Observed operational emissions',
            '${total.toStringAsFixed(1)} kg',
            data!['period'] as String,
          ),
          metric(
            'Reward balance',
            '${data!['points']} pts',
            widget.demo ? 'Simulated partner rewards' : 'Eligible rewards only',
          ),
          metric(
            'Round-up contributions',
            '\$${((data!['pledgedCents'] as num) / 100).toStringAsFixed(2)}',
            'Pledged, no funds collected',
          ),
        ],
      ),
      title('Your next action'),
      box(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Could a bus replace part of your commute?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const Text(
              'Compare a specific journey using the same sourced factors. Your coach can explain the estimate and its limits.',
            ),
            const SizedBox(height: 16),
            button(
              'Explore my plan',
              () => act('coach', {}),
              icon: Icons.auto_awesome_outlined,
            ),
          ],
        ),
      ),
      title('Where activity comes from'),
      ...cats.entries.map(
        (e) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              SizedBox(width: 90, child: Text(e.key)),
              Expanded(
                child: LinearProgressIndicator(
                  value: total > 0 ? (e.value as num) / total : 0,
                  minHeight: 12,
                  backgroundColor: Colors.white,
                  color: ink,
                ),
              ),
              const SizedBox(width: 14),
              Text('${(e.value as num).toStringAsFixed(1)} kg'),
            ],
          ),
        ),
      ),
      if (phone case final capture?)
        ListenableBuilder(
          listenable: capture,
          builder: (context, _) => capture.pending.isEmpty
              ? const SizedBox.shrink()
              : TextButton(
                  onPressed: () => setState(() => tab = 1),
                  child: Text(
                    'Review ${capture.pending.length} trips on this phone',
                  ),
                ),
        ),
      title('Review new evidence (${pending.length})'),
      if (pending.isEmpty)
        const Text('You’re up to date. New imports will appear here.'),
      ...pending.map(
        (r) => box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r['description'] as String,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${r['day']} · ${r['quantity']} ${r['unit']} · ${(r['kg'] as num).toStringAsFixed(2)} kg CO₂e',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  button(
                    'Confirm',
                    () => act('review', {'id': r['id'], 'status': 'confirmed'}),
                    icon: Icons.check,
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => act('review', {
                            'id': r['id'],
                            'status': 'dismissed',
                          }),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      if (!widget.demo)
        TextButton.icon(
          onPressed: busy || phoneBusy ? null : logTrip,
          icon: const Icon(Icons.add),
          label: const Text('Log a trip manually'),
        ),
      title('Activity journal'),
      ...activities
          .where((e) => e['status'] == 'confirmed')
          .take(12)
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                r['kind'] == 'electricity'
                    ? Icons.bolt_outlined
                    : Icons.directions_transit,
                color: ink,
              ),
              title: Text(r['description'] as String),
              subtitle: Text(
                '${r['day']} · ${r['quantity']} ${r['unit']} · ${r['version']}',
              ),
              trailing: Text('${(r['kg'] as num).toStringAsFixed(2)} kg'),
            ),
          ),
      const SizedBox(height: 24),
      Text(
        data!['boundary'] as String,
        style: const TextStyle(color: Colors.black54),
      ),
    ];
  }

  Future<void> withPhone(Future<void> Function() action) async {
    if (phoneBusy || busy) return;
    setState(() => phoneBusy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not update phone trips. Try again.');
      }
    } finally {
      if (mounted) setState(() => phoneBusy = false);
    }
  }

  Future<void> sendPhoneTrip(
    PilotPhoneCapture capture,
    ActivityCandidate candidate,
  ) async {
    final mode = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('How did you travel?'),
        children: [
          for (final entry in const {
            'car': 'Car',
            'bus': 'Bus',
            'train': 'Commuter rail',
            'bicycle': 'Bicycle',
          }.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, entry.key),
              child: Text(entry.value),
            ),
        ],
      ),
    );
    if (!mounted || mode == null) return;
    final sent = await act('import-phone-trip', {
      'id': candidate.id,
      'day': candidate.start.toLocal().toIso8601String().substring(0, 10),
      'kind': mode,
      'quantity': candidate.quantity,
    });
    if (sent && mounted) {
      await capture.remove(candidate.id);
      if (mounted) setState(() => tab = 0);
    }
  }

  Widget phoneSetup(
    PilotPhoneCapture capture,
    bool travelEnabled,
  ) => ListenableBuilder(
    listenable: capture,
    builder: (context, _) => box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phone trip detection',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'While Verdi is open, precise location estimates trip distance. '
            'Routes stay in memory. You choose which trip summaries to send.',
          ),
          if (capture.storageError != null)
            Text(capture.storageError!)
          else if (capture.error != null && travelEnabled && capture.enabled)
            Text(capture.error!)
          else if (travelEnabled && capture.enabled)
            Text(
              capture.listening
                  ? 'Detecting trips'
                  : 'Detection resumes when Verdi opens',
            ),
          Wrap(
            spacing: 12,
            children: [
              button(
                travelEnabled && capture.enabled
                    ? 'Turn off detection'
                    : 'Enable trip detection',
                phoneBusy
                    ? null
                    : () => withPhone(() async {
                        if (!travelEnabled &&
                            !await act('connection', {
                              'provider': 'transport',
                              'enabled': true,
                            })) {
                          return;
                        }
                        if (mounted) {
                          await capture.setEnabled(
                            !travelEnabled || !capture.enabled,
                          );
                        }
                      }),
                icon: Icons.location_on_outlined,
              ),
              if (travelEnabled && capture.enabled && capture.error != null)
                TextButton(
                  onPressed: busy || phoneBusy
                      ? null
                      : () => withPhone(() => capture.setEnabled(true)),
                  child: const Text('Retry location'),
                ),
            ],
          ),
          for (final trip in capture.pending)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${(trip.quantity / 1.609344).toStringAsFixed(1)} mi detected',
              ),
              subtitle: Text(
                MaterialLocalizations.of(context)
                    .formatMediumDate(trip.start.toLocal()),
              ),
              leading: IconButton(
                tooltip: 'Discard trip',
                onPressed: busy || phoneBusy
                    ? null
                    : () => withPhone(() => capture.remove(trip.id)),
                icon: const Icon(Icons.delete_outline),
              ),
              trailing: TextButton(
                onPressed: busy || phoneBusy || !travelEnabled
                    ? null
                    : () => withPhone(() => sendPhoneTrip(capture, trip)),
                child: const Text('Choose mode'),
              ),
            ),
        ],
      ),
    ),
  );

  Future<void> logTrip() async {
    var mode = 'car';
    final now = DateTime.now();
    var day = now;
    var distance = '';
    final form = GlobalKey<FormState>();
    final record = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Log a trip'),
          content: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: mode,
                    decoration: const InputDecoration(labelText: 'Travel mode'),
                    items: const [
                      DropdownMenuItem(value: 'car', child: Text('Car')),
                      DropdownMenuItem(value: 'bus', child: Text('Bus')),
                      DropdownMenuItem(
                        value: 'train',
                        child: Text('Commuter rail'),
                      ),
                      DropdownMenuItem(
                        value: 'bicycle',
                        child: Text('Bicycle'),
                      ),
                    ],
                    onChanged: (value) => mode = value!,
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: day,
                        firstDate: DateTime(2000),
                        lastDate: now,
                      );
                      if (picked != null && context.mounted) {
                        setDialogState(() => day = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      MaterialLocalizations.of(context).formatMediumDate(day),
                    ),
                  ),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Distance (miles)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) => distance = value,
                    validator: (value) {
                      final miles = double.tryParse(value ?? '');
                      return miles == null ||
                              !miles.isFinite ||
                              miles <= 0 ||
                              miles > 1000
                          ? 'Enter a distance from 0 to 1,000 miles.'
                          : null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                Navigator.pop(context, {
                  'id': 'manual:${now.microsecondsSinceEpoch}',
                  'day': day.toIso8601String().substring(0, 10),
                  'kind': mode,
                  'quantity': double.parse(distance) * 1.609344,
                  'description': 'Self-reported $mode trip',
                });
              },
              child: const Text('Send to review'),
            ),
          ],
        ),
      ),
    );
    if (record != null && mounted) {
      if (!sourceEnabled(data!, 'transport') &&
          !await act('connection', {
            'provider': 'transport',
            'enabled': true,
          })) {
        return;
      }
      if (!mounted) return;
      await act('import', {
        'provider': 'transport',
        'records': [record],
      });
    }
  }

  String _redmondBannerText() {
    final city = (_activeDemoHousehold()['city'] as String? ?? '').trim();
    if (data != null && city.isNotEmpty) {
      return 'REGIONAL DEMO · $city · Fictional household and simulated provider data';
    }
    return 'REGIONAL DEMO · Fictional households and simulated provider data';
  }

  Map<String, dynamic>? _catalogHouseholdById(String? id) {
    if (id == null) return null;
    for (final household in demoHouseholds) {
      if (household['id'] == id) return household;
    }
    return null;
  }

  Map<String, dynamic> _activeDemoHousehold() {
    final fromSnapshot = data?['demoHousehold'];
    if (fromSnapshot is Map) {
      return Map<String, dynamic>.from(fromSnapshot);
    }
    final fromCatalog = _catalogHouseholdById(selectedHouseholdId);
    if (fromCatalog != null) return fromCatalog;
    final user = data?['user'];
    return {
      'id': selectedHouseholdId ?? 'redmond',
      'name': user is Map && user['name'] is String
          ? user['name'] as String
          : 'Cedar Household',
      'city': user is Map && user['region'] is String
          ? user['region'] as String
          : 'Redmond, Washington',
      'scenario': 'A fictional household in Redmond, Washington.',
    };
  }

  String _householdChipLabel(Map<String, dynamic> household) {
    final name = (household['name'] as String? ?? '').trim();
    final city = (household['city'] as String? ?? '').trim();
    if (name.isEmpty) {
      return city.isEmpty ? (household['id'] as String? ?? 'Household') : city;
    }
    if (city.isEmpty) return name;
    return '$name · $city';
  }

  bool _isDemoSourceEligible(Map source) {
    final status = source['status'];
    return status == 'disconnected' || status == 'auth_required';
  }

  void _pruneSelectedDemoSources(Map<String, dynamic> snapshot) {
    if (!widget.redmondDemo || selectedDemoSources.isEmpty) return;
    final eligibleIds = (snapshot['demoSources'] as List? ?? const [])
        .whereType<Map>()
        .where(_isDemoSourceEligible)
        .map((source) => source['id'])
        .whereType<String>()
        .toSet();
    selectedDemoSources.retainAll(eligibleIds);
  }

  String _demoSourceLabel(Map source) {
    final label = source['label'];
    if (label is String && label.trim().isNotEmpty) return label.trim();
    final id = source['id'] as String;
    return switch (id) {
      'utility' => 'PSE electricity and gas',
      'orca' => 'ORCA transit activity',
      'bank' => 'Bank transactions',
      _ => id,
    };
  }

  String _demoSourceDescription(Map source) {
    final description = source['description'];
    if (description is String && description.trim().isNotEmpty) {
      return description.trim();
    }
    final id = source['id'] as String;
    return switch (id) {
      'utility' => 'Daily electricity use and natural gas statements',
      'orca' => 'Card tap time, location, agency and fare',
      _ => 'Transaction dates, amounts and pending or posted status',
    };
  }

  Widget _demoHouseholdSwitcher() {
    if (demoHouseholds.isEmpty) return const SizedBox.shrink();
    final activeId =
        selectedHouseholdId ??
        (data?['demoHousehold'] is Map
            ? data!['demoHousehold']['id'] as String?
            : null) ??
        'redmond';
    return Semantics(
      container: true,
      label: 'Demo household and city switcher',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Demo household & city',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600, color: ink),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final household in demoHouseholds)
                    ChoiceChip(
                      key: ValueKey('demo-household-${household['id']}'),
                      label: Text(_householdChipLabel(household)),
                      selected: household['id'] == activeId,
                      onSelected: (_) {
                        final id = household['id'] as String;
                        if (id != activeId || error != null) {
                          unawaited(switchDemoHousehold(id));
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _redmondLoadingCard() {
    final target = _catalogHouseholdById(selectedHouseholdId);
    final label = target != null ? _householdChipLabel(target) : 'household';
    return box(
      Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Loading $label…')),
        ],
      ),
    );
  }

  List<Widget> redmondHousehold() {
    final household = _activeDemoHousehold();
    final householdName = (household['name'] as String? ?? 'Cedar Household')
        .trim();
    final city = (household['city'] as String? ?? '').trim();
    final scenario = (household['scenario'] as String? ?? '').trim();
    final sources = (data!['demoSources'] as List? ?? const []).cast<Map>();
    if (tab == 0) {
      final active = sources.where((source) => source['status'] == 'ok').length;
      return [
        title(householdName),
        if (city.isNotEmpty)
          Text(
            '$city · Fictional demo household',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: Colors.black54),
          ),
        if (scenario.isNotEmpty) ...[const SizedBox(height: 6), Text(scenario)],
        const SizedBox(height: 16),
        box(Text('$active of ${sources.length} sources syncing automatically')),
        const SizedBox(height: 16),
        button(
          'Set up your sources',
          () => setState(() => tab = 1),
          icon: Icons.hub_outlined,
        ),
      ];
    }
    final eligibleSources = sources.where(_isDemoSourceEligible).toList();
    final selectedEligible = eligibleSources
        .where((source) => selectedDemoSources.contains(source['id']))
        .toList();
    final allEligibleSelected =
        eligibleSources.isNotEmpty &&
        selectedEligible.length == eligibleSources.length;
    return [
      title('$householdName connections'),
      if (city.isNotEmpty || scenario.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            [city, scenario].where((part) => part.isNotEmpty).join(' · '),
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      const Text(
        'Select eligible simulated sources to authorize together once, or authorize each source individually. The server keeps collecting while this page is closed.',
      ),
      const SizedBox(height: 12),
      if (eligibleSources.isNotEmpty)
        box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Authorize sources together',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600, color: ink),
              ),
              const SizedBox(height: 4),
              Text(
                '${selectedEligible.length} of ${eligibleSources.length} eligible sources selected',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  button(
                    selectedEligible.isEmpty
                        ? 'Authorize selected'
                        : 'Authorize selected (${selectedEligible.length})',
                    selectedEligible.isEmpty
                        ? null
                        : () => authorizeDemoSources(selectedEligible),
                    icon: Icons.done_all,
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            if (allEligibleSelected) {
                              selectedDemoSources.clear();
                            } else {
                              selectedDemoSources
                                ..clear()
                                ..addAll(
                                  eligibleSources.map(
                                    (source) => source['id'] as String,
                                  ),
                                );
                            }
                          }),
                    child: Text(
                      allEligibleSelected
                          ? 'Clear selection'
                          : 'Select all eligible',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      for (final source in sources) redmondSource(source),
    ];
  }

  Widget redmondSource(Map source) {
    final id = source['id'] as String;
    final name = _demoSourceLabel(source);
    final permission = _demoSourceDescription(source);
    final status = source['status'];
    final eligible = _isDemoSourceEligible(source);
    final selected = eligible && selectedDemoSources.contains(id);
    final lastSynced = source['lastSyncedAt'];
    final records = (source['records'] as List? ?? const []).cast<Map>();
    return box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eligible)
            CheckboxListTile(
              key: ValueKey('demo-source-select-$id'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(name, style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text(permission),
              value: selected,
              onChanged: busy
                  ? null
                  : (checked) => setState(() {
                      if (checked == true) {
                        selectedDemoSources.add(id);
                      } else {
                        selectedDemoSources.remove(id);
                      }
                    }),
            )
          else ...[
            Text(name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(permission, style: const TextStyle(color: Colors.black54)),
          ],
          const SizedBox(height: 6),
          Text(switch (status) {
            'ok' => 'Syncing automatically',
            'waiting' => 'Authorized · waiting for first sync',
            'auth_required' => 'Authorization expired · reconnect to continue',
            _ => 'Ready to authorize',
          }),
          if (lastSynced is String) Text('Last simulated sync · $lastSynced'),
          const SizedBox(height: 12),
          for (final record in records.take(3))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(record['label'] as String),
              subtitle: Text(record['detail'] as String),
            ),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              if (eligible)
                button(
                  status == 'auth_required'
                      ? 'Reconnect $name'
                      : 'Connect $name',
                  () => authorizeDemoSource(id, name, permission),
                  icon: Icons.link,
                ),
              if (status == 'ok' || status == 'waiting')
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => act('demo-expire', {'source': id}),
                  child: Text('Simulate expired access · $name'),
                ),
              if (status != 'disconnected')
                TextButton(
                  onPressed: busy
                      ? null
                      : () => act('demo-disconnect', {'source': id}),
                  child: Text('Disconnect $name'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> authorizeDemoSources(List<Map> selectedSources) async {
    if (selectedSources.isEmpty) return;
    final epoch = sessionEpoch;
    final ids = selectedSources
        .map((source) => source['id'] as String)
        .toList();
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Authorize ${selectedSources.length} simulated '
          '${selectedSources.length == 1 ? 'source' : 'sources'}',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final source in selectedSources)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _demoSourceLabel(source),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(_demoSourceDescription(source)),
                    ],
                  ),
                ),
              const Text(
                'This demo uses fictional records and never asks for a password.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow demo access'),
          ),
        ],
      ),
    );
    if (allowed == true && mounted && epoch == sessionEpoch) {
      final ok = await act('demo-authorize', {'sources': ids});
      if (ok && mounted && epoch == sessionEpoch) {
        setState(() => selectedDemoSources.removeAll(ids));
      }
    }
  }

  Future<void> authorizeDemoSource(
    String id,
    String name,
    String permission,
  ) async {
    final epoch = sessionEpoch;
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Authorize $name'),
        content: Text(
          '$permission\n\nThis demo uses fictional records and never asks for a password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow demo access'),
          ),
        ],
      ),
    );
    if (allowed == true && mounted && epoch == sessionEpoch) {
      await act('demo-authorize', {'source': id});
    }
  }

  List<Widget> connections() {
    final sources = (data!['connections'] as List).cast<Map>();
    if (widget.demo) {
      return [
        title('Connections'),
        for (final source in sources)
          box(
            SwitchListTile(
              title: Text(switch (source['provider']) {
                'bank' => 'Bank transactions',
                'utility' => 'Home energy',
                'transport' => 'Travel',
                _ => 'Smart devices',
              }),
              subtitle: const Text('Fictional provider · SQLite demo records'),
              value: source['connected'] == 1,
              onChanged: busy
                  ? null
                  : (enabled) => act('connection', {
                      'provider': source['provider'],
                      'enabled': enabled,
                    }),
            ),
          ),
        button('Sync demo data', () => act('sync', {}), icon: Icons.sync),
      ];
    }

    final travelEnabled = sourceEnabled(data!, 'transport');
    final bank = sources.cast<Map?>().firstWhere(
      (source) => source?['provider'] == 'bank',
      orElse: () => null,
    );
    final canConnectBank =
        bank?['automaticSyncEnabled'] == true &&
        (bank?['mode'] == 'plaid-production' ||
            bank?['mode'] == 'plaid-sandbox');
    final bankConnected = bank?['connected'] == 1;
    return [
      title('Connections'),
      if (phone case final capture?) phoneSetup(capture, travelEnabled),
      box(
        SwitchListTile(
          title: Text(
            bank?['mode'] == 'plaid-sandbox'
                ? 'Bank transactions (Sandbox)'
                : 'Bank transactions',
          ),
          subtitle: Text(bankStatus(bank, canConnectBank)),
          contentPadding: EdgeInsets.zero,
          value: bankConnected,
          onChanged: busy || phoneBusy || (!canConnectBank && !bankConnected)
              ? null
              : (enabled) =>
                    act('connection', {'provider': 'bank', 'enabled': enabled}),
        ),
      ),
      title('Provider access pending'),
      box(
        const ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Electricity and natural gas'),
          subtitle: Text(
            'Automatic residential access is pending. Availability depends on your service address and account.',
          ),
        ),
      ),
      box(
        const ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('ORCA'),
          subtitle: Text(
            'Automatic access to personal card activity is pending.',
          ),
        ),
      ),
      if (travelEnabled)
        TextButton(
          onPressed: busy || phoneBusy
              ? null
              : () => act('connection', {
                  'provider': 'transport',
                  'enabled': false,
                }),
          child: const Text('Disconnect travel'),
        ),
    ];
  }

  String bankStatus(Map? bank, bool canConnect) {
    if (!canConnect) {
      return 'Automatic bank access is unavailable for this pilot account.';
    }
    if (bank?['connected'] != 1) {
      return 'Enable automatic syncing with your authorized Plaid account.';
    }
    final timestamp = bank?['lastSyncedAt'];
    final lastSync = timestamp is String ? DateTime.tryParse(timestamp) : null;
    return switch (bank?['syncStatus']) {
      'ok' when lastSync != null =>
        'Automatically synced · ${MaterialLocalizations.of(context).formatMediumDate(lastSync.toLocal())}',
      'ok' => 'Automatically synced',
      'retrying' => 'Sync delayed. Verdi will retry automatically.',
      'auth_required' =>
        'Bank authorization needs attention. Contact your pilot administrator.',
      _ => 'Waiting for automatic sync',
    };
  }

  List<Widget> rewards() => [
    title('Lower impact. Tangible benefits.'),
    Wrap(
      spacing: 14,
      children: [
        metric('Available', '${data!['points']} points', 'Ledger balance'),
        metric(
          'Contributions',
          '\$${((data!['pledgedCents'] as num) / 100).toStringAsFixed(2)}',
          'Round-up pledges',
        ),
      ],
    ),
    title('Rewards for comparable reductions'),
    const Text(
      'Completed months need daily utility and travel evidence in both periods. A missing connection cannot earn points. Points use a capped program rule, not a carbon credit.',
    ),
    const SizedBox(height: 16),
    button(
      'Check completed month',
      () => act('reward', {
        'month': widget.demo
            ? '2026-10'
            : DateTime(
                DateTime.now().year,
                DateTime.now().month - 1,
              ).toIso8601String().substring(0, 7),
      }),
      icon: Icons.verified_outlined,
    ),
    title('Partner offers'),
    ...(data!['rewards'] as List).map(
      (r) => box(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r['title'] as String, style: const TextStyle(fontSize: 22)),
            Text(
              '${r['points']} points${widget.demo ? ' · Demo offer' : ' · Partner availability required'}',
            ),
            const SizedBox(height: 14),
            button(
              'Redeem',
              () => act('redeem', {
                'reward': r['id'],
                'key': '${r['id']}-${DateTime.now().microsecondsSinceEpoch}',
              }),
              icon: Icons.redeem,
            ),
          ],
        ),
      ),
    ),
    title('Optional round-ups'),
    const Text(
      'Round posted purchases to the next dollar, capped at \$5 for the month. Whole-dollar purchases, pending transactions and refunds contribute zero. This pilot records pledges and does not charge an account.',
    ),
    const SizedBox(height: 16),
    button(
      'Enable \$5 monthly cap',
      () => act('roundups', {'capCents': 500}),
      icon: Icons.favorite_border,
    ),
    title('Reward ledger'),
    ...(data!['ledger'] as List).map(
      (r) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(r['description'] as String),
        trailing: Text('${r['points']} pts'),
      ),
    ),
  ];

  List<Widget> privacy() => [
    title('Your data, your choice'),
    box(
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Share program aggregates'),
        subtitle: const Text(
          'Your institution sees fixed reports only when at least 10 consenting participants contribute. It cannot see your journal or transactions.',
        ),
        value: (data!['user'] as Map)['consent'] == 1,
        onChanged: busy ? null : (v) => act('consent', {'enabled': v}),
      ),
    ),
    const SizedBox(height: 16),
    button('Copy my data export', () async {
      await Clipboard.setData(
        ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Export copied.')));
      }
    }, icon: Icons.download_outlined),
    title('Calculation boundaries'),
    Text(data!['boundary'] as String),
    const SizedBox(height: 12),
    const Text(
      'Sources use pinned EPA 2025 operational factors. National electricity is a labeled fallback across the US. This version does not claim full lifestyle coverage, measured causality, verified offsets, or automatic tax deductions.',
    ),
  ];

  List<Widget> institution() {
    if (data!['suppressed'] == true) {
      return [title('Program privacy'), Text(data!['reason'] as String)];
    }
    final rows = (data!['rows'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final periods = rows.map((r) => r['month'] as String).toSet().toList()
      ..sort();
    if (!periods.contains(period) && periods.isNotEmpty) period = periods.last;
    final current = rows.where((r) => r['month'] == period).toList();
    final total = current.fold<double>(
      0,
      (s, r) => s + (r['kg'] as num).toDouble(),
    );
    final members = data!['consentingParticipants'] as int;

    if (institutionTab == 1) {
      if (!widget.demo) {
        return [
          title('Carbon Map'),
          const Text(
            'Route and location reporting requires consented route data. The pilot currently reports emissions by activity type.',
          ),
        ];
      }
      return [
        InstitutionMapView(
          organizationName:
              '${(data!['organization'] as String?)?.toUpperCase() ?? 'CASCADIA'} UNIVERSITY',
        ),
      ];
    }

    if (institutionTab == 2) {
      if (!widget.demo) {
        final sources = [...current]
          ..sort((a, b) => (b['kg'] as num).compareTo(a['kg'] as num));
        return [
          title('Reported emissions by activity'),
          if (sources.isEmpty)
            const Text(
              'Activity totals appear when the reporting cohort is large enough.',
            ),
          for (final source in sources)
            ListTile(
              title: Text(source['kind'] as String),
              subtitle: LinearProgressIndicator(
                value: total > 0 ? (source['kg'] as num).toDouble() / total : 0,
              ),
              trailing: Text(
                '${(source['kg'] as num).toStringAsFixed(1)} kg CO₂e',
              ),
            ),
        ];
      }
      return [
        FactorAnalysisView(
          totalBaselineTonnes: (total / 1000.0) > 0 ? (total / 1000.0) : 263.7,
        ),
      ];
    }

    return [
      title('A clearer view of your program'),
      Text(
        '${data!['organization']} · Participant activity analytics',
        style: const TextStyle(fontSize: 18),
      ),
      const SizedBox(height: 24),
      Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          metric(
            'Consenting participants',
            '$members',
            'Minimum published cohort: 10',
          ),
          metric(
            'Reported activity',
            '${(total / 1000).toStringAsFixed(2)} t CO₂e',
            period,
          ),
          metric(
            'Per consenting participant',
            '${(total / members).toStringAsFixed(1)} kg',
            'Observed activities only',
          ),
        ],
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          SizedBox(
            width: 360,
            child: box(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: forest.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.map_outlined,
                          color: forest,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Carbon Map & Corridors',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Visualize commuter routes and specific physical campus nodes with high carbon output.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 14),
                  button(
                    'Explore Routes & Map',
                    () => setState(() => institutionTab = 1),
                    icon: Icons.explore_outlined,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 360,
            child: box(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD34528)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.insights_outlined,
                          color: Color(0xFFD34528),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Factor Sensitivity & Drivers',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.demo
                        ? 'Analyze mode choice, distance, and grid determinants with an interactive policy simulator.'
                        : 'Compare reported emissions by activity type for the selected period.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 14),
                  button(
                    'Analyze Factor Drivers',
                    () => setState(() => institutionTab = 2),
                    icon: Icons.tune_outlined,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      title('Reporting period'),
      DropdownButtonFormField<String>(
        initialValue: period,
        items: periods
            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
            .toList(),
        onChanged: (v) => setState(() => period = v!),
      ),
      title('Emission sources'),
      ...current.map(
        (r) => box(
          Row(
            children: [
              Expanded(
                child: Text(
                  r['kind'] as String,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              Text(
                '${(r['kg'] as num).toStringAsFixed(1)} kg\n${r['people']} participants',
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
      ),
      title('Monthly activity trend'),
      ...periods.map((p) {
        final value = rows
            .where((r) => r['month'] == p)
            .fold<double>(0, (s, r) => s + (r['kg'] as num).toDouble());
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(p),
          trailing: Text('${(value / 1000).toStringAsFixed(2)} t CO₂e'),
        );
      }),
      title('Program decisions'),
      const Text(
        'Compare source coverage before comparing emissions. Use the commute breakdown to evaluate transit incentives. Changes describe participating accounts and do not prove that a program caused a reduction.',
      ),
      const SizedBox(height: 20),
      button('Copy program report', () async {
        await Clipboard.setData(
          ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)),
        );
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Report copied.')));
        }
      }, icon: Icons.download_outlined),
      title('Methodology'),
      Text(data!['methodology'] as String),
    ];
  }
}
