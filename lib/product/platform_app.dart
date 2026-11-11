// Shared responsive Flutter UI for consumer rewards and institution analytics.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

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
      base =
          base ??
          const String.fromEnvironment(
            'VERDI_API',
            defaultValue: 'http://127.0.0.1:8787',
          );
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
    final result = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    if (response.statusCode >= 400) {
      throw StateError(result['error'] as String? ?? 'Request failed.');
    }
    return result;
  }

  void dispose() => client.close();
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
  @override
  void initState() {
    super.initState();
    if (widget.demo) {
      api = PlatformApi(
        widget.institutional ? 'verdi-demo-analyst' : 'verdi-demo-consumer',
      );
      refresh();
    }
  }

  @override
  void dispose() {
    api?.dispose();
    tokenController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await api!.request(
        widget.institutional ? 'institution' : 'me',
      );
      if (mounted) setState(() => data = result);
    } catch (e) {
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

  Future<void> act(String action, Map<String, dynamic> body) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await api!.request(action, body);
      if (!mounted) return;
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
            content: Text(
              action == 'sync'
                  ? '${response['added']} new records, ${response['duplicates']} duplicates skipped'
                  : 'Saved${widget.demo ? ' to the synthetic demo' : ''}',
            ),
          ),
        );
        await refresh();
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
      }
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
    VoidCallback onTap, {
    IconData icon = Icons.arrow_forward,
  }) => FilledButton.icon(
    onPressed: busy ? null : onTap,
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
            onPressed: busy ? null : refresh,
            icon: const Icon(Icons.refresh),
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
    const Text(
      'Sign in with a session issued by your Verdi pilot administrator. The live app starts empty.',
    ),
    const SizedBox(height: 24),
    TextField(
      controller: tokenController,
      obscureText: true,
      decoration: const InputDecoration(labelText: 'Pilot session token'),
    ),
    const SizedBox(height: 20),
    button('Sign in', () {
      api?.dispose();
      api = PlatformApi(tokenController.text.trim());
      tokenController.clear();
      refresh();
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
      title('Review new evidence (${pending.length})'),
      if (pending.isEmpty)
        const Text(
          'You’re up to date. Sync a connection to check for new records.',
        ),
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

  List<Widget> connections() => [
    title('Your connected world'),
    const Text(
      'You control each connection. Disconnecting stops new imports and keeps your confirmed history.',
    ),
    const SizedBox(height: 18),
    ...(data!['connections'] as List).map(
      (e) => box(
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            {
              'bank': 'Bank transactions',
              'utility': 'Home energy',
              'transport': 'Travel receipts',
              'iot': 'Smart devices',
            }[e['provider']]!,
          ),
          subtitle: Text(
            widget.demo
                ? 'Fictional provider · SQLite demo records'
                : 'Authorized import connection',
          ),
          value: e['connected'] == 1,
          onChanged: busy
              ? null
              : (v) => act('connection', {
                  'provider': e['provider'],
                  'enabled': v,
                }),
        ),
      ),
    ),
    button('Sync connected sources', () => act('sync', {}), icon: Icons.sync),
    title('Import your electricity readings'),
    const Text(
      'Use your utility export with columns record_id, date and kwh. Review the readings before they enter your footprint.',
    ),
    const SizedBox(height: 16),
    button('Choose electricity CSV', () async {
      try {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['csv'],
          withData: true,
        );
        if (picked == null || !mounted) return;
        final bytes = picked.files.single.bytes;
        if (bytes == null) {
          throw const FormatException('Could not read that file.');
        }
        final candidates = parseUtilityCsv(
          utf8.decode(bytes),
          (data!['user'] as Map)['id'] as String,
        );
        await act('import', {
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
        });
      } catch (e) {
        if (mounted) setState(() => error = e.toString());
      }
    }, icon: Icons.upload_file),
  ];

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
      return [
        InstitutionMapView(
          organizationName: '${(data!['organization'] as String?)?.toUpperCase() ?? 'CASCADIA'} UNIVERSITY',
        ),
      ];
    }

    if (institutionTab == 2) {
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
                        child: const Icon(Icons.map_outlined, color: forest, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Carbon Map & Corridors',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ink),
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
                          color: const Color(0xFFD34528).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.insights_outlined, color: Color(0xFFD34528), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Factor Sensitivity & Drivers',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Analyze mode choice, distance, and grid determinants with an interactive policy simulator.',
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
