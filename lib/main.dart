import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/activity_store.dart';
import 'domain/carbon.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final store = ActivityStore(await SharedPreferences.getInstance());
    runApp(VerdiApp(store: store));
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
  const VerdiApp({super.key, required this.store});
  final ActivityStore store;
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
    home: Home(store: store),
  );
}

class Home extends StatefulWidget {
  const Home({super.key, required this.store});
  final ActivityStore store;
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
  @override
  void initState() {
    super.initState();
    try {
      activities = widget.store.load();
    } catch (_) {
      loadError = 'Saved activities could not be read. Your data has been kept. Restart after restoring a valid backup.';
    }
  }

  Future<void> persist(List<Activity> next) async {
    setState(() => busy = true);
    try {
      await widget.store.save(next);
      if (mounted) setState(() => activities = next);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<Activity> get monthly {
    final now = DateTime.now();
    return engine.inPeriod(
      activities,
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
    final pages = [dashboard(), journal(), explore()];
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.eco_outlined),
            SizedBox(width: 8),
            Text(
              'verdi',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'About these estimates',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('An honest starting point'),
                content: const Text(
                  'This prototype uses illustrative emission factors. All results are demo estimates, not a complete or verified carbon footprint. Travel is modeled per person, assuming solo car travel. Purchase estimates use USD. Bicycle travel excludes manufacturing and food. Your entries stay on this device. Rewards are previews with no cash value.',
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
              : pages[tab],
        ),
      ),
      floatingActionButton: loadError != null || tab == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: busy ? null : addActivity,
              backgroundColor: forest,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Log activity'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
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
      ),
      const SizedBox(height: 12),
      Text(
        subtitle,
        style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
      ),
      const SizedBox(height: 28),
    ],
  );
  Widget dashboard() {
    final entries = monthly;
    final total = engine.total(entries);
    final categories = engine.breakdown(entries).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        heading(
          'SMALL STEPS. LASTING CHANGE.',
          'Your impact, made visible.',
          'Understand your everyday choices. Find your next better one.',
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
                'THIS MONTH · DEMO ESTIMATE',
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
        const SizedBox(height: 28),
        const Text(
          'Where it comes from',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          panel(
            Icons.spa_outlined,
            'Start with one everyday choice',
            'Log a journey, electricity use, a purchase, or waste to build your picture.',
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
        const SizedBox(height: 20),
        panel(
          Icons.lightbulb_outline,
          'Your next step',
          categories.isEmpty
              ? 'Try the Reduce tab to compare travel choices.'
              : '${categories.first.key} is your largest logged contributor this month. ${tip(categories.first.key)}',
        ),
        const SizedBox(height: 12),
        const Text(
          'Prototype • Illustrative factors • Saved on this device',
          style: TextStyle(color: Colors.black54),
        ),
      ],
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
              subtitle: Text(
                '${a.quantity} ${a.kind.unit} · ${a.date.toLocal().toString().substring(0, 10)}\n${a.note.isEmpty ? 'Manual entry' : a.note}',
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
                            if (confirmed == true && mounted)
                              await persist(
                                activities
                                    .where((item) => item.id != a.id)
                                    .toList(),
                              );
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
                  'potential reduction for this journey · demo estimate',
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
          'Distance × (car factor − alternative factor). These sample factors help test the experience; real estimates need regional data and validated assumptions.',
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
            items: ActivityKind.values
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
            'Uses illustrative emission factors. Saved only on this device.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
