// Shared responsive Flutter UI for consumer rewards and institution analytics.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
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
      'Authorization': 'Bearer $token',
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
  const PlatformApp({super.key, this.demo = false, this.institutional = false});
  final bool demo, institutional;
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
    home: PlatformHome(demo: demo, institutional: institutional),
  );
}

class PlatformHome extends StatefulWidget {
  const PlatformHome({
    super.key,
    required this.demo,
    required this.institutional,
  });
  final bool demo, institutional;
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
  bool pickingFile = false;
  bool bankSyncAttempted = false;

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
        bankSyncAttempted = false;
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

  bool bankSyncAvailable(Map<String, dynamic> snapshot) =>
      (snapshot['connections'] as List).any(
        (source) =>
            source['provider'] == 'bank' &&
            source['connected'] == 1 &&
            (source['mode'] == 'plaid-production' ||
                source['mode'] == 'plaid-sandbox'),
      );

  Future<void> syncBankOnOpen(Map<String, dynamic> snapshot) async {
    if (!bankSyncAvailable(snapshot)) {
      bankSyncAttempted = false;
      return;
    }
    if (bankSyncAttempted) return;
    bankSyncAttempted = true;
    try {
      await api!.request('sync', {});
      final latest = await api!.request('me');
      if (mounted) setState(() => data = latest);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Bank sync did not finish. Try Sync bank transactions in Connections.',
        );
      }
    }
  }

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
      api = PlatformApi(
        widget.institutional ? 'verdi-demo-analyst' : 'verdi-demo-consumer',
      );
      refresh();
    } else if (nativeConsumer) {
      unawaited(restoreSession());
    }
  }

  @override
  void dispose() {
    phone?.dispose();
    api?.dispose();
    tokenController.dispose();
    super.dispose();
  }

  Future<void> refresh({bool remember = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await api!.request(
        widget.institutional ? 'institution' : 'me',
      );
      if (!mounted) return;
      setState(() => data = result);
      if (remember && nativeConsumer) {
        try {
          await secureStorage.write(key: sessionKey, value: api!.token);
        } catch (_) {
          if (mounted) {
            setState(
              () => error = 'Could not remember this sign-in on your phone.',
            );
          }
        }
      }
      if (mounted && nativeConsumer) {
        try {
          await configurePhone(result);
        } catch (_) {
          if (mounted) {
            setState(() => error = 'Could not load phone trip settings.');
          }
        }
      }
      if (mounted && !widget.demo && !widget.institutional) {
        await syncBankOnOpen(result);
      }
    } catch (e) {
      if (e is PlatformRequestError && e.status == 401 && !widget.demo) {
        await signOut();
        if (mounted && api == null) {
          setState(
            () => error = 'That pilot session is invalid or has expired.',
          );
        }
        return;
      }
      if (mounted) {
        setState(
          () => error =
              'Could not load Verdi. Check the API connection. ${e.toString().replaceFirst('Bad state: ', '')}',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> act(String action, Map<String, dynamic> body) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await api!.request(action, body);
      if (!mounted) return false;
      if (action == 'connection' &&
          body['provider'] == 'transport' &&
          body['enabled'] == false) {
        await phone?.setConsent(false);
      }
      if (!mounted) return false;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(switch (action) {
              'sync' when !widget.demo =>
                '${response['added']} bank records updated, ${response['removed']} removed',
              'sync' || 'import' || 'import-phone-trip' =>
                '${response['added']} new records, ${response['duplicates']} duplicates skipped',
              'import-green-button' =>
                '${response['added']} days ready for review, ${response['duplicates']} duplicates, ${response['incompleteDays']} incomplete days skipped',
              _ => 'Saved${widget.demo ? ' to the synthetic demo' : ''}',
            }),
          ),
        );
        await refresh();
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
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
    onPressed: busy || phoneBusy || pickingFile ? null : onTap,
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
        if (api != null)
          IconButton(
            tooltip: 'Refresh data',
            onPressed: busy || phoneBusy || pickingFile ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
        if (api != null && !widget.demo)
          IconButton(
            tooltip: 'Sign out',
            onPressed: busy || phoneBusy || pickingFile ? null : signOut,
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
            child: const Text(
              'SYNTHETIC DEMO  ·  Fictional accounts and providers. Rewards and contributions are simulations.',
              style: TextStyle(color: ink),
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
                  ].join('|'),
                ),
                padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 600 ? 18 : 36,
                ),
                children: [
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
                  if (api == null)
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
                : const [
                    NavigationDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      label: 'Today',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.hub_outlined),
                      label: 'Connections',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.redeem_outlined),
                      label: 'Rewards',
                    ),
                    NavigationDestination(
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
              const Text('Start with home electricity or travel.'),
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

  Future<void> importElectricity({required bool xml}) async {
    if (busy || phoneBusy || pickingFile) return;
    setState(() => pickingFile = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [xml ? 'xml' : 'csv'],
        withData: true,
      );
      if (picked == null || !mounted) return;
      final bytes = picked.files.single.bytes;
      if (bytes == null) {
        throw const FormatException('Could not read that file.');
      }
      if (bytes.length > (xml ? 5000000 : 1000000)) {
        throw FormatException('Choose a file smaller than ${xml ? 5 : 1} MB.');
      }
      final input = utf8.decode(bytes);
      if (xml) {
        if (!await enableUtility()) return;
        if (!mounted) return;
        if (await act('import-green-button', {'xml': input}) && mounted) {
          setState(() => tab = 0);
        }
        return;
      }
      final candidates = parseUtilityCsv(
        input,
        (data!['user'] as Map)['id'] as String,
      );
      if (!await enableUtility() || !mounted) return;
      if (await act('import', {
            'provider': 'utility',
            'records': candidates
                .map(
                  (c) => {
                    'id': c.id,
                    'day': c.start.toIso8601String().substring(0, 10),
                    'kind': 'electricity',
                    'quantity': c.quantity,
                    'description': 'Imported utility reading',
                  },
                )
                .toList(),
          }) &&
          mounted) {
        setState(() => tab = 0);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => pickingFile = false);
    }
  }

  Future<bool> enableUtility() async {
    if (sourceEnabled(data!, 'utility')) return true;
    return act('connection', {'provider': 'utility', 'enabled': true});
  }

  Future<void> withPhone(Future<void> Function() action) async {
    if (phoneBusy || busy || pickingFile) return;
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

  List<Widget> connections() {
    final sources = (data!['connections'] as List).cast<Map>();
    final bankEnabled = bankSyncAvailable(data!);
    final utilityEnabled = sourceEnabled(data!, 'utility');
    final travelEnabled = sourceEnabled(data!, 'transport');
    final meterTimeZone = data!['meterTimeZone'];
    return [
      title('Connections'),
      if (!widget.demo) ...[
        title('Home electricity'),
        if (meterTimeZone != null) ...[
          const Text(
            'In myPSE, open My usage → Green Button. If XML is available, export one '
            'electric meter. Verdi imports complete days in your meter time zone.',
          ),
          Text('Meter time zone · $meterTimeZone'),
          button(
            'Upload Green Button XML',
            () => importElectricity(xml: true),
            icon: Icons.upload_file,
          ),
        ],
        const Text(
          'You can also upload a CSV with record_id, date and kwh. Uploading '
          'enables Home energy and queues readings for review. Upload again '
          'when you have new readings.',
        ),
        button(
          'Upload electricity CSV',
          () => importElectricity(xml: false),
          icon: Icons.upload_file,
        ),
        if (phone case final capture?) phoneSetup(capture, travelEnabled),
        button('Log a trip', logTrip, icon: Icons.directions_transit),
        title('Manage sources'),
      ],
      const Text(
        'Disconnect a source to stop new imports and keep confirmed history.',
      ),
      const SizedBox(height: 18),
      ...sources.map(
        (e) => box(
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              {
                'bank': 'Bank transactions',
                'utility': 'Home energy',
                'transport': 'Travel',
                'iot': 'Smart devices',
              }[e['provider']]!,
            ),
            subtitle: Text(
              widget.demo
                  ? 'Fictional provider · SQLite demo records'
                  : switch (e['mode']) {
                      'plaid-production' => 'Plaid · syncs when you open Verdi',
                      'plaid-sandbox' =>
                        'Plaid Sandbox · syncs test transactions on open',
                      'file-import' => 'Upload a utility export',
                      'manual' =>
                        'Log trips using your travel mode and distance',
                      'supporting' => 'Device readings through the pilot API',
                      _ => 'Requires a Plaid account provisioned by the pilot administrator',
                    },
            ),
            value: e['connected'] == 1,
            onChanged:
                busy ||
                    phoneBusy ||
                    (e['mode'] == 'unavailable' && e['connected'] != 1)
                ? null
                : (v) => act('connection', {
                    'provider': e['provider'],
                    'enabled': v,
                  }),
          ),
        ),
      ),
      if (widget.demo || bankEnabled)
        button(
          widget.demo ? 'Sync connected sources' : 'Sync bank transactions',
          () => act('sync', {}),
          icon: Icons.sync,
        ),
      if (widget.demo && utilityEnabled)
        button(
          'Choose electricity CSV',
          () => importElectricity(xml: false),
          icon: Icons.upload_file,
        ),
    ];
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
