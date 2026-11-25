// Overview: Shows useful regional connection routes and honest implementation status.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/connection_setup_store.dart';
import '../domain/connection_catalog.dart';

/// [electricityReview] asks the caller to open the existing utility review.
enum ConnectionsAction { electricityImport, electricityReview }

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key, this.setupStore});

  /// Defaults to the app's SharedPreferences; tests may inject one.
  final ConnectionSetupStore? setupStore;

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  ConnectionRegion region = ConnectionRegion.redmond;
  ConnectionSetupStore? store;
  Map<String, ConnectionChoice> choices = {};
  String? storeProblem;

  @override
  void initState() {
    super.initState();
    store = widget.setupStore;
    if (store == null) {
      SharedPreferences.getInstance().then(
        (p) => attach(ConnectionSetupStore(p)),
        onError: (_) =>
            showProblem('Choices cannot be remembered on this device.'),
      );
    } else {
      attach(store!);
    }
  }

  void attach(ConnectionSetupStore s) {
    try {
      final loaded = s.load();
      if (!mounted) return;
      setState(() {
        store = s;
        choices = loaded;
      });
    } catch (e) {
      showProblem(
        'Saved choices could not be read; new choices will not be saved.',
      );
    }
  }

  void showProblem(String message) {
    if (mounted) setState(() => storeProblem = message);
  }

  Future<void> choose(String id, ConnectionChoice? choice) async {
    final previous = choices[id];
    setState(() {
      if (choice == null) {
        choices.remove(id);
      } else {
        choices[id] = choice;
      }
    });
    try {
      await store?.set(id, choice);
      if (store == null) {
        showProblem('Choices are kept only until you leave this screen.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (previous == null) {
          choices.remove(id);
        } else {
          choices[id] = previous;
        }
        storeProblem = 'That choice could not be saved.';
      });
    }
  }

  String choiceLabel(ConnectionChoice? c) => switch (c) {
    ConnectionChoice.planned => 'You chose this',
    ConnectionChoice.deferred => 'Saved for later',
    null => '',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Connections')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            Text(
              'Build a fuller picture.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            const Text(
              'Start with the sources that describe your life. No provider accounts are live-connected here. Expand a source to see what it can add and what is available today.',
            ),
            if (storeProblem != null) ...[
              const SizedBox(height: 10),
              Text(storeProblem!, key: const ValueKey('setup-problem')),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final choice in ConnectionRegion.values)
                  ChoiceChip(
                    label: Text(choice.label),
                    selected: region == choice,
                    onSelected: (_) => setState(() => region = choice),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              region == ConnectionRegion.redmond
                  ? 'Redmond first. Check your actual service address and account.'
                  : '${region.label} adds sources to the earlier regions. These are rollout groups, not guaranteed service areas.',
            ),
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coverage comes from your data',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This directory does not measure your footprint. Food, goods, services, heating, water, waste, flights and lodging remain unmeasured in app totals. Missing data is not zero emissions.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Shared homes, energy included in rent, cash purchases and employer-paid trips may need extra records. Share only the files and fields needed; never give Verdi account passwords.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final option in connectionsThrough(region))
              connectionCard(option),
            const SizedBox(height: 16),
            const Text(
              'Sources checked November 18, 2026 Pacific. Documented access is different from a tested import or a connected account. No native provider samples were tested in this research.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    ),
  );

  Widget connectionCard(ConnectionOption option) => Card(
    key: ValueKey('connection-${option.id}'),
    child: ExpansionTile(
      key: ValueKey(option.id),
      title: Text(option.name),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          '${option.category} · ${option.readiness.label}'
          '${choices[option.id] == null ? '' : ' · ${choiceLabel(choices[option.id])}'}',
        ),
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      children: [
        detail('What it adds', option.benefit),
        detail('Useful evidence', option.evidence),
        detail('Access and consent', option.access),
        detail('Current limits', option.limit),
        if (option.id == 'pse-electricity') pseSteps(),
        setupControls(option),
        const Text(
          'Official source',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        SelectableText(option.sourceUrl),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: option.sourceUrl));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Source link copied.')),
            );
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copy source link'),
        ),
      ],
    ),
  );

  Widget pseSteps() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PSE electricity setup (manual file upload)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text(
          '1. Download your own daily usage from myPSE and convert it to record_id,date,kwh CSV.\n'
          '2. Import the file in Auto track.\n'
          '3. Check the imported readings in utility review before they count.\n'
          'Verdi never signs in to PSE; each file is something you upload yourself.',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(context)
                      .pop(ConnectionsAction.electricityImport),
              icon: const Icon(Icons.upload_file),
              label: const Text('Go to electricity import'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(context)
                      .pop(ConnectionsAction.electricityReview),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Go to utility review'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget setupControls(ConnectionOption option) {
    final current = choices[option.id];
    final importable = option.readiness == ConnectionReadiness.normalizedImport;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (current == null) ...[
            FilledButton(
              key: ValueKey('choose-${option.id}'),
              onPressed: () => choose(option.id, ConnectionChoice.planned),
              child: Text(importable ? 'Set this up' : 'Plan to use this'),
            ),
            TextButton(
              key: ValueKey('defer-${option.id}'),
              onPressed: () => choose(option.id, ConnectionChoice.deferred),
              child: const Text('Later'),
            ),
          ] else ...[
            Text(
              '${choiceLabel(current)}. ${importable ? 'Uploads are manual; nothing is connected.' : 'Nothing is connected or importable yet.'}',
            ),
            if (current == ConnectionChoice.deferred)
              TextButton(
                key: ValueKey('choose-${option.id}'),
                onPressed: () => choose(option.id, ConnectionChoice.planned),
                child: const Text('Set up now'),
              ),
            TextButton(
              key: ValueKey('clear-${option.id}'),
              onPressed: () => choose(option.id, null),
              child: const Text('Clear'),
            ),
          ],
        ],
      ),
    );
  }

  Widget detail(String label, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        Text(body),
      ],
    ),
  );
}
