// Overview: Starts the Flutter app and builds the overview, journal, comparison, tracking, and settings navigation.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/activity_store.dart';
import 'data/settings_store.dart';
import 'domain/carbon.dart';
import 'domain/data_source.dart';
import 'domain/incentive_service.dart';
import 'features/automation_screen.dart';
import 'features/onboarding_screen.dart';
import 'features/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final prefs = await SharedPreferences.getInstance();
    final store = ActivityStore(prefs);
    final settingsStore = SettingsStore(prefs);
    runApp(VerdiApp(store: store, settingsStore: settingsStore));
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Verdi could not open local storage. Please restart the app.',
            ),
          ),
        ),
      ),
    );
  }
}

const forest = Color(0xFF174C38);
const cream = Color(0xFFF6F7F2);

class VerdiApp extends StatelessWidget {
  const VerdiApp({super.key, required this.store, required this.settingsStore});
  final ActivityStore store;
  final SettingsStore settingsStore;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Verdi',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(seedColor: forest),
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: forest,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      cardTheme: const CardThemeData(elevation: 0, color: Colors.white),
    ),
    home: VerdiRoot(store: store, settingsStore: settingsStore),
  );
}

class VerdiRoot extends StatefulWidget {
  const VerdiRoot({super.key, required this.store, required this.settingsStore});
  final ActivityStore store;
  final SettingsStore settingsStore;

  @override
  State<VerdiRoot> createState() => _VerdiRootState();
}

class _VerdiRootState extends State<VerdiRoot> {
  UserSettings? settings;

  @override
  void initState() {
    super.initState();
    settings = widget.settingsStore.load();
  }

  void _onSettingsChanged() {
    setState(() => settings = widget.settingsStore.load());
  }

  @override
  Widget build(BuildContext context) {
    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!settings!.onboarded) {
      return OnboardingScreen(
        settingsStore: widget.settingsStore,
        onComplete: _onSettingsChanged,
      );
    }
    return Home(
      store: widget.store,
      settingsStore: widget.settingsStore,
      settings: settings!,
      onSettingsChanged: _onSettingsChanged,
    );
  }
}

class Home extends StatefulWidget {
  const Home({
    super.key,
    required this.store,
    required this.settingsStore,
    required this.settings,
    required this.onSettingsChanged,
  });
  final ActivityStore store;
  final SettingsStore settingsStore;
  final UserSettings settings;
  final VoidCallback onSettingsChanged;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final engine = const CarbonEngine();
  List<Activity> activities = [];
  int tab = 0;
  bool busy = false;
  String? loadError;
  double distance = 20;
  ActivityKind alternative = ActivityKind.train;
  bool demoMode = false;

  @override
  void initState() {
    super.initState();
    try {
      activities = widget.store.load();
    } catch (_) {
      loadError =
          'Saved activities could not be read. Your data has been kept. Restart after restoring a valid backup.';
    }
  }

  /// Load sample activities for VC demo — populates the app with realistic data.
  Future<void> loadDemoData() async {
    final now = DateTime.now();
    final sample = [
      Activity(id: 'demo-1', kind: ActivityKind.car, quantity: 15, date: DateTime(now.year, now.month, now.day - 1, 8, 30), note: 'Commute to campus'),
      Activity(id: 'demo-2', kind: ActivityKind.car, quantity: 15, date: DateTime(now.year, now.month, now.day - 2, 17, 0), note: 'Drive home'),
      Activity(id: 'demo-3', kind: ActivityKind.electricity, quantity: 120, date: DateTime(now.year, now.month, now.day - 3), note: 'Daily electricity'),
      Activity(id: 'demo-4', kind: ActivityKind.bus, quantity: 8, date: DateTime(now.year, now.month, now.day - 4, 9, 0), note: 'Bus to downtown'),
      Activity(id: 'demo-5', kind: ActivityKind.car, quantity: 22, date: DateTime(now.year, now.month, now.day - 5, 14, 0), note: 'Weekend errands'),
      Activity(id: 'demo-6', kind: ActivityKind.train, quantity: 30, date: DateTime(now.year, now.month, now.day - 7, 7, 0), note: 'Train to Seattle'),
      Activity(id: 'demo-7', kind: ActivityKind.electricity, quantity: 95, date: DateTime(now.year, now.month, now.day - 8), note: 'Daily electricity'),
      Activity(id: 'demo-8', kind: ActivityKind.car, quantity: 12, date: DateTime(now.year, now.month, now.day - 10, 18, 0), note: 'Evening drive'),
    ];
    setState(() => busy = true);
    try {
      await widget.store.save(sample);
      if (mounted) {
        setState(() {
          activities = sample;
          demoMode = true;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load demo data.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Clear demo data and return to empty state.
  Future<void> clearDemoData() async {
    setState(() => busy = true);
    try {
      await widget.store.save([]);
      if (mounted) {
        setState(() {
          activities = [];
          demoMode = false;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not clear demo data.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> persist(List<Activity> next) async {
    setState(() => busy = true);
    try {
      await widget.store.save(next);
      if (mounted) setState(() => activities = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<Activity> get monthly {
    final now = DateTime.now();
    return engine.inPeriod(
      activities.where((a) => a.isPilotEstimate),
      DateTime(now.year, now.month),
      DateTime(now.year, now.month + 1),
    );
  }

  Future<void> addActivity() async {
    final result = await showModalBottomSheet<Activity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const ActivityForm(),
    );
    if (result != null && mounted) await persist([...activities, result]);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      dashboard(),
      journal(),
      explore(),
      rewardsPage(),
      AutomationScreen(
        activities: widget.store,
        onChanged: () {
          if (mounted) setState(() => activities = widget.store.load());
        },
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'verdi',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(
                    title: const Text('Settings'),
                    backgroundColor: cream,
                    foregroundColor: forest,
                  ),
                  body: SettingsScreen(
                    settingsStore: widget.settingsStore,
                    onChanged: widget.onSettingsChanged,
                  ),
                ),
              ),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'About these estimates',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('An honest starting point'),
                content: const Text(
                  'US pilot: EPA 2025 factors for average passenger cars, buses, commuter rail and US-average electricity (eGRID 2023). Extended factors for flights, products, and waste are research-sourced placeholders (DEFRA, EPA WARM, EIO-LCA). Results estimate operational emissions, not a full lifecycle footprint. Cars assume one occupant; bicycle zero excludes food and manufacturing. Electricity uses your selected regional factor or the national fallback. Legacy demo logs stay in Activities but are excluded from totals. Rewards remain hypothetical.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Got it'),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.info_outline),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: loadError != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(loadError!),
                )
              : IndexedStack(index: tab, children: pages),
        ),
      ),
      floatingActionButton: loadError != null || tab >= 4
          ? null
          : FloatingActionButton.extended(
              onPressed: busy ? null : addActivity,
              backgroundColor: forest,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Log activity'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab.clamp(0, 4),
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Activities',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            label: 'Reduce',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            label: 'Rewards',
          ),
          NavigationDestination(icon: Icon(Icons.sensors), label: 'Auto track'),
        ],
      ),
    );
  }

  Widget heading(String eyebrow, String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: const TextStyle(
          color: forest,
          letterSpacing: 2,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        title,
        style: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
        softWrap: true,
      ),
      const SizedBox(height: 12),
      Text(
        subtitle,
        style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
        softWrap: true,
      ),
      const SizedBox(height: 28),
    ],
  );

  Widget dashboard() {
    final entries = monthly;
    final total = engine.total(entries);
    final categories = engine.breakdown(entries).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final region = widget.settings.region;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        heading(
          'SMALL STEPS. LASTING CHANGE.',
          'Your impact, made visible.',
          'Auto-track travel, utilities, purchases, flights, and waste — correlated into one clear footprint.',
        ),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: forest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'THIS MONTH · US PILOT ESTIMATE',
                style: TextStyle(color: Color(0xFFC7E0CB), letterSpacing: 1.5),
              ),
              const SizedBox(height: 20),
              Text(
                '${total.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  fontSize: 52,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'CO₂e across ${entries.length} logged activities',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                'A picture of what you log, not your whole footprint.',
                style: TextStyle(color: Color(0xFFC7E0CB)),
              ),
            ],
          ),
        ),
        // Demo mode toggle
        if (entries.isEmpty && !demoMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: FilledButton.tonalIcon(
              onPressed: busy ? null : loadDemoData,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Load demo data'),
            ),
          ),
        if (demoMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                const Icon(Icons.science_outlined, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Demo mode — sample data loaded',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: busy ? null : clearDemoData,
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 28),
        // Settings summary card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune, color: forest, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Your profile',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _profileRow('Vehicle', VehicleTypeOption.byId(widget.settings.vehicleType).label),
                _profileRow('Occupancy', '${widget.settings.occupancy} ${widget.settings.occupancy == 1 ? "person (solo)" : "people"}'),
                _profileRow('Electricity region', region.label),
                _profileRow('Electricity factor', '${region.kgCo2ePerKwh.toStringAsPrecision(4)} kg CO₂e/kWh'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Where it comes from',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          panel(
            Icons.spa_outlined,
            'Start with multi-front tracking',
            'Open Auto track to detect phone journeys, import utility readings, or connect data sources. Manual logging is also available.',
          ),
        for (final category in categories)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(category.key)),
                      Text('${category.value.toStringAsFixed(1)} kg CO₂e'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: total == 0 ? 0 : category.value / total,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(10),
                    color: forest,
                  ),
                ],
              ),
            ),
          ),
        // Before vs After carbon impact visualization
        if (entries.isNotEmpty) ...[
          const SizedBox(height: 28),
          const Text(
            'Your impact: before vs after',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'See how small changes to your travel habits could reduce your monthly footprint.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          _beforeAfterViz(entries, total),
        ],
        const SizedBox(height: 20),
        panel(
          Icons.lightbulb_outline,
          'Your next step',
          categories.isEmpty
              ? 'Try the Reduce tab to compare travel choices.'
              : '${categories.first.key} is your largest logged contributor this month. ${tip(categories.first.key)}',
        ),
        const SizedBox(height: 12),
        Text(
          'US pilot • EPA 2025 factors • Region: ${region.label} • Legacy demo logs excluded',
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    );
  }

  Widget _profileRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Flexible(child: Text(label, style: const TextStyle(color: Colors.black54))),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w500),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      );

  /// Before/after carbon impact visualization showing current footprint
  /// vs potential reduction if car trips were replaced with public transit.
  Widget _beforeAfterViz(List<Activity> entries, double total) {
    // Calculate potential savings: replace all car trips with train
    final carActivities = entries.where((a) => a.kind == ActivityKind.car).toList();
    double potentialSaving = 0;
    for (final a in carActivities) {
      potentialSaving += a.quantity * (ActivityKind.car.factor - ActivityKind.train.factor);
    }
    final reducedTotal = total - potentialSaving;
    final savingPct = total > 0 ? (potentialSaving / total * 100) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Before bar
            const Text(
              'Current footprint',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: total.round().clamp(1, 100),
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: forest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${total.toStringAsFixed(1)} kg CO₂e',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // After bar
            const Text(
              'With public transit swaps',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: reducedTotal.round().clamp(1, 100),
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${reducedTotal.toStringAsFixed(1)} kg CO₂e',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Savings summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_down, color: Color(0xFF2E7D32), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${potentialSaving.toStringAsFixed(1)} kg CO₂e potential reduction',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2E7D32)),
                        ),
                        Text(
                          "That's ${savingPct.toStringAsFixed(0)}% of your monthly footprint — "
                          'equivalent to ${engine.previewPoints(potentialSaving)} eco-points',
                          style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (carActivities.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'No car trips logged yet. Add a car journey to see your reduction potential.',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String tip(String category) => switch (category) {
    'Travel' => 'Compare a car journey with public transport in Reduce.',
    'Home' => 'Log meter readings consistently to understand electricity use.',
    'Food' =>
      'Detailed food quantities will improve on spending-based estimates.',
    'Shopping' => 'Consider repairing or reusing before buying something new.',
    _ => 'Track waste weight consistently to see changes over time.',
  };

  Widget panel(IconData icon, String title, String body) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: forest),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 8),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget rewardsPage() {
    final incentiveService = const IncentiveService();
    final now = DateTime.now();
    final currentMonth = engine.inPeriod(
      activities.where((a) => a.isPilotEstimate),
      DateTime(now.year, now.month),
      DateTime(now.year, now.month + 1),
    );
    final previousMonth = engine.inPeriod(
      activities.where((a) => a.isPilotEstimate),
      DateTime(now.year, now.month - 1),
      DateTime(now.year, now.month),
    );
    final monthlyReward = incentiveService.computeMonthlyReward(
      currentMonth: currentMonth,
      previousMonth: previousMonth,
      now: now,
    );
    final registry = DataSourceRegistry();
    final fronts = registry.byFront;
    registry.dispose();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        heading(
          'REDUCE. GET REWARDED.',
          'Incentives for lower emissions.',
          'Earn eco-points when your footprint shrinks month over month. Rewards are preview-only — no real redemption yet.',
        ),
        // Monthly reward card
        if (monthlyReward != null)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: forest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'THIS MONTH · REWARD PREVIEW',
                  style: TextStyle(color: Color(0xFFC7E0CB), letterSpacing: 1.5),
                ),
                const SizedBox(height: 20),
                Text(
                  '+${monthlyReward.points} eco-points',
                  style: const TextStyle(
                    fontSize: 52,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  monthlyReward.description,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.emoji_events_outlined, color: forest, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'No reward yet this month',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Reduce your emissions below last month to earn eco-points. '
                    'Log activities across multiple fronts to build a complete picture.',
                    style: TextStyle(color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 28),
        // Multi-front tracking vision
        const Text(
          'Tracking fronts',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Verdi correlates data from multiple sources to build a granular, '
          'down-to-user emissions picture. Here is what is available and what is on the roadmap.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),
        for (final entry in fronts.entries) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_frontIcon(entry.key), color: forest, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.key.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.key.description,
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  for (final source in entry.value)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          _statusDot(source.status),
                          const SizedBox(width: 8),
                          Expanded(child: Text(source.displayName)),
                          Text(
                            source.status.label,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Show which sources are implemented vs roadmap
                  if (entry.key == TrackingFront.travel)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '✓ Phone GPS trip detection and utility CSV import are implemented. '
                        'Flight data is a roadmap item.',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    )
                  else if (entry.key == TrackingFront.home)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '✓ Utility CSV import is implemented. Live provider connections are a roadmap item.',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Roadmap: ${entry.key.label.toLowerCase()} data sources will connect with user consent in future phases.',
                        style: const TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 20),
        panel(
          Icons.lightbulb_outline,
          'How rewards work',
          'Compare this month to last month. If your emissions dropped, earn 10 eco-points per kg of reduction. '
          'This is a preview system — no points are redeemable or transferable yet. A verified reward ledger '
          'requires a backend and trusted baselines (see docs/ROADMAP.md, Phase 4).',
        ),
        const SizedBox(height: 12),
        Text(
          'Current month: ${engine.total(currentMonth).toStringAsFixed(1)} kg CO₂e · '
          'Previous month: ${engine.total(previousMonth).toStringAsFixed(1)} kg CO₂e',
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    );
  }

  IconData _frontIcon(TrackingFront front) => switch (front) {
    TrackingFront.travel => Icons.directions_car_outlined,
    TrackingFront.home => Icons.home_outlined,
    TrackingFront.products => Icons.shopping_bag_outlined,
    TrackingFront.waste => Icons.delete_outline,
    TrackingFront.food => Icons.restaurant_outlined,
  };

  Widget _statusDot(DataSourceStatus status) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: switch (status) {
            DataSourceStatus.connected => const Color(0xFF4CAF50),
            DataSourceStatus.pending => Colors.orange,
            DataSourceStatus.error => Colors.red,
            DataSourceStatus.notConnected => Colors.grey.shade400,
          },
        ),
      );

  Widget journal() {
    final sorted = [...activities]..sort((a, b) => b.date.compareTo(a.date));
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        heading(
          'YOUR EVERYDAY FOOTPRINT',
          'One activity at a time.',
          'All your entries, saved locally. Delete an entry to correct it.',
        ),
        if (sorted.isEmpty)
          panel(
            Icons.edit_note,
            'Your journal starts here',
            'Tap Log activity to add your first entry.',
          ),
        for (final a in sorted)
          Card(
            child: ListTile(
              isThreeLine: true,
              title: Text(a.kind.label),
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Calculation details'),
                  content: SingleChildScrollView(
                    child: SelectableText(
                      '${a.quantity} ${a.kind.unit} × ${a.factor.toStringAsPrecision(8)} kg CO₂e/${a.kind.unit}\n'
                      'Version: ${a.factorVersion}\nSource: ${a.source}\nRecord: ${a.sourceId ?? a.id}\n'
                      '${a.factorMetadata.entries.map((e) => '${e.key}: ${e.value}').join('\n')}',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
              subtitle: Text(
                '${a.quantity} ${a.kind.unit} · ${a.date.toLocal().toString().substring(0, 10)}\n${a.isPilotEstimate ? 'US pilot estimate' : 'Legacy demo · excluded from totals'}${a.note.isEmpty ? '' : ' · ${a.note}'}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${a.emissions.toStringAsFixed(1)} kg'),
                  IconButton(
                    tooltip: 'Delete activity',
                    onPressed: busy
                        ? null
                        : () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete this activity?'),
                                content: Text(a.kind.label),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && mounted) {
                              await persist(
                                activities
                                    .where((item) => item.id != a.id)
                                    .toList(),
                              );
                            }
                          },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget explore() {
    final saving = engine.potentialTravelSaving(distance, alternative);
    final perPerson = engine.adjustedCarEmissions(distance, widget.settings.occupancy);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        heading(
          'MAKE ROOM FOR BETTER',
          'A different way to get there.',
          'Explore the potential impact of replacing a solo car journey.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Journey distance · ${distance.round()} km',
                  style: const TextStyle(fontSize: 18),
                ),
                Slider(
                  value: distance,
                  min: 1,
                  max: 100,
                  divisions: 99,
                  label: '${distance.round()} km',
                  onChanged: (v) => setState(() => distance = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ActivityKind>(
                  initialValue: alternative,
                  decoration: const InputDecoration(
                    labelText: 'Try this instead',
                  ),
                  items:
                      [
                            ActivityKind.bus,
                            ActivityKind.train,
                            ActivityKind.bicycle,
                          ]
                          .map(
                            (kind) => DropdownMenuItem(
                              value: kind,
                              child: Text(kind.label),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => alternative = value!),
                ),
                const SizedBox(height: 16),
                // Occupancy-adjusted comparison
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cream,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'With ${widget.settings.occupancy} ${widget.settings.occupancy == 1 ? "occupant" : "occupants"}: '
                        '${perPerson.toStringAsFixed(1)} kg CO₂e per person',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        softWrap: true,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Total car emissions ÷ occupants = your personal share.',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  '${saving.toStringAsFixed(1)} kg CO₂e',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: forest,
                  ),
                ),
                const Text(
                  'potential reduction for this journey · US average estimate',
                ),
                const Divider(height: 40),
                Text(
                  '${engine.previewPoints(saving)} eco-points',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Rewards preview only. No points are earned or redeemable. The demo rule is 10 points per kg of potential reduction.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        panel(
          Icons.science_outlined,
          'How this works',
          'Distance × (car factor − alternative factor). Uses EPA 2025 operational travel averages; rail means commuter rail. This is a comparison of attributed emissions, not a measured reduction from changing one trip.',
        ),
      ],
    );
  }
}

class ActivityForm extends StatefulWidget {
  const ActivityForm({super.key});
  @override
  State<ActivityForm> createState() => _ActivityFormState();
}

class _ActivityFormState extends State<ActivityForm> {
  final form = GlobalKey<FormState>();
  final quantity = TextEditingController();
  final note = TextEditingController();
  ActivityKind kind = ActivityKind.car;
  DateTime date = DateTime.now();
  @override
  void dispose() {
    quantity.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Log an activity',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<ActivityKind>(
            initialValue: kind,
            decoration: const InputDecoration(labelText: 'Activity'),
            items: ActivityKind.allLoggable
                .map((k) => DropdownMenuItem(value: k, child: Text(k.label)))
                .toList(),
            onChanged: (value) => setState(() {
              kind = value!;
              quantity.clear();
            }),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Amount (${kind.unit})'),
            validator: (value) {
              final n = double.tryParse(value?.trim() ?? '');
              return n == null || !n.isFinite || n <= 0 || n > 1000000
                  ? 'Enter a number greater than 0, up to 1,000,000.'
                  : null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: note,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(date.toString().substring(0, 10)),
            onPressed: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (selected != null && mounted) setState(() => date = selected);
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              Navigator.pop(
                context,
                Activity(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  kind: kind,
                  quantity: double.parse(quantity.text.trim()),
                  date: date,
                  note: note.text.trim(),
                ),
              );
            },
            child: const Text('Save activity'),
          ),
          const SizedBox(height: 12),
          const Text(
            'US average estimates. Cars assume solo travel. Electricity uses your selected regional factor. Saved only on this device.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
