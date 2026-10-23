// Overview: Presents tracking consent, utility imports, and the candidate review queue.
import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/activity_store.dart';
import '../data/automation_store.dart';
import '../domain/automation.dart';
import '../domain/carbon.dart';
import '../services/phone_tracking.dart';

class AutomationScreen extends StatefulWidget {
  const AutomationScreen({
    super.key,
    required this.activities,
    required this.onChanged,
  });
  final ActivityStore activities;
  final VoidCallback onChanged;
  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen>
    with WidgetsBindingObserver {
  late final AutomationStore store;
  final detector = TripDetector();
  final account = TextEditingController();
  final selections = <String, ActivityKind>{};
  List<ActivityCandidate> pending = [];
  Set<String> dismissed = {};
  StreamSubscription<LocationSample>? subscription;
  Future<void> writes = Future.value();
  bool tracking = false, busy = false, saveFailed = false;
  String? fatalError;
  String status = 'Tracking is off.';
  bool get phoneAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store = AutomationStore(widget.activities.preferences);
    try {
      final data = store.load();
      pending = data.pending;
      dismissed = data.dismissed;
    } catch (_) {
      fatalError =
          'The saved review queue cannot be read. It has not been overwritten.';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(
        stop('App left the foreground; partial journey saved for review.'),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(subscription?.cancel());
    account.dispose();
    super.dispose();
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> saveQueue() {
    final snapshot = AutomationState(List.of(pending), Set.of(dismissed));
    writes = writes.then((_) async {
      try {
        await store.save(snapshot);
        if (mounted) setState(() => saveFailed = false);
      } catch (_) {
        if (mounted) setState(() => saveFailed = true);
      }
    });
    return writes;
  }

  Future<void> enqueue(List<ActivityCandidate> candidates) async {
    final known = {
      ...pending.map((c) => c.id),
      ...dismissed,
      ...widget.activities.load().map((a) => a.id),
    };
    final added = candidates.where((c) => known.add(c.id)).toList();
    if (mounted) setState(() => pending.addAll(added));
    await saveQueue();
  }

  Future<void> start() async {
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use location to detect trips?'),
        content: const Text(
          'While Verdi is open, location samples estimate journey distance. Only trip summaries are saved on this device; raw coordinates are not saved or uploaded. You review the travel mode before emissions are added. Tracking stops when you leave the app. You can stop at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable tracking'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) return;
    setState(() {
      tracking = true;
      status = 'Requesting permission; waiting for accurate location…';
    });
    subscription = PhoneTracking().samples().listen(
      (sample) {
        if (!tracking) return;
        // Reject stale/cached or future OS fixes before segmentation.
        final age = DateTime.now().difference(sample.time).inSeconds;
        if (age > 30 || age < -5) return;
        final candidate = detector.add(sample);
        if (candidate != null) unawaited(enqueue([candidate]));
        if (mounted) {
          setState(
            () => status =
                'Listening · ${detector.kilometres.toStringAsFixed(2)} km in current segment · ${detector.rejected} filtered samples',
          );
        }
      },
      onError: (Object error) {
        final detail = error is PlatformException
            ? error.message ?? error.code
            : 'Location is unavailable.';
        unawaited(stop(detail));
      },
      onDone: () => unawaited(stop('Location stream ended.')),
    );
  }

  Future<void> stop([String reason = 'Tracking stopped.']) async {
    if (!tracking) return;
    final current = subscription;
    subscription = null;
    if (mounted) {
      setState(() {
        tracking = false;
        status = reason;
      });
    }
    final candidate = detector.finish(reason);
    if (candidate != null) await enqueue([candidate]);
    await current?.cancel();
  }

  Future<void> importUtility() async {
    if (account.text.trim().isEmpty) {
      message('Enter an account nickname first.');
      return;
    }
    setState(() => busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || !mounted) return;
      final file = result.files.single;
      if (file.size > 1000000 || file.bytes == null) {
        throw const FormatException('Choose a readable CSV smaller than 1 MB.');
      }
      final candidates = parseUtilityCsv(
        utf8.decode(file.bytes!),
        account.text,
      );
      final before = pending.length;
      await enqueue(candidates);
      message(
        '${pending.length - before} new readings ready for review. Previously seen records were skipped.',
      );
    } catch (error) {
      message(
        error is FormatException
            ? error.message.toString()
            : 'Import failed. Your existing data is unchanged.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> dismiss(ActivityCandidate candidate) async {
    setState(() {
      busy = true;
      pending.removeWhere((c) => c.id == candidate.id);
      dismissed.add(candidate.id);
    });
    await saveQueue();
    if (mounted) setState(() => busy = false);
  }

  Future<void> accept(ActivityCandidate candidate, ActivityKind kind) async {
    setState(() => busy = true);
    try {
      final existing = widget.activities.load();
      if (!existing.any((a) => a.id == candidate.id)) {
        if (existing.any((a) => overlaps(candidate, a))) {
          message(
            'This overlaps a logged activity. Check the journal and discard the duplicate or remove the old entry first.',
          );
          return;
        }
        await widget.activities.save([...existing, candidate.confirm(kind)]);
      }
      // Save activity first: retry after interruption cannot create a duplicate.
      if (mounted) {
        setState(() => pending.removeWhere((c) => c.id == candidate.id));
      }
      await saveQueue();
      widget.onChanged();
    } catch (_) {
      message('Could not confirm this activity. Please retry.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (fatalError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(fatalError!),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: [
        const Text(
          'Let your day tell the story.',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const Text(
          'Detect journeys from your phone and import electricity readings. Review what we find before it changes your footprint.',
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Phone trip detection',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  phoneAvailable ? status : 'Phone detection is available in the Android and iOS apps. File imports work here too.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Keep the app open. Trips of at least 100 m and 60 seconds are queued after a two-minute stop. Car, bus, train and cycling must be confirmed; discard walking or unsupported journeys.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: tracking
                      ? () => stop()
                      : (phoneAvailable && !busy && !saveFailed ? start : null),
                  icon: Icon(tracking ? Icons.stop : Icons.my_location),
                  label: Text(
                    tracking ? 'Stop tracking' : 'Enable phone tracking',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Import electricity data',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use daily readings exported from your utility, normalized to the format below. This is a file import, not a live utility connection. Reuse the same account nickname on future imports.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: account,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Utility account nickname',
                  ),
                ),
                const SelectableText(
                  'record_id,date,kwh\nreading-001,2026-01-01,12.5',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: busy || saveFailed ? null : importUtility,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Choose utility CSV'),
                ),
              ],
            ),
          ),
        ),
        if (saveFailed)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'The review queue has not been saved. Keep the app open and retry.',
                  ),
                  TextButton(
                    onPressed: saveQueue,
                    child: const Text('Retry saving queue'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        Text(
          'Review queue · ${pending.length}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        if (pending.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Detected trips and new utility readings will appear here.',
            ),
          ),
        for (final candidate in pending) candidateCard(candidate),
        const SizedBox(height: 16),
        const Text(
          'Bank transactions, travel accounts, smart-home connections, always-on background tracking and real reward redemption are not connected yet.',
        ),
      ],
    );
  }

  Widget candidateCard(ActivityCandidate c) {
    final selected = c.kind ?? selections[c.id];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              c.kind == ActivityKind.electricity
                  ? '${c.quantity.toStringAsFixed(2)} kWh electricity'
                  : '${c.quantity.toStringAsFixed(2)} km detected journey',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            Text(c.start.toLocal().toString().substring(0, 16)),
            const SizedBox(height: 8),
            Text(c.description),
            if (c.kind == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: DropdownButtonFormField<ActivityKind>(
                  key: ValueKey(c.id),
                  initialValue: selected,
                  decoration: const InputDecoration(
                    labelText: 'Confirm travel mode',
                  ),
                  items: ActivityKind.supported
                      .where((k) => k.category == 'Travel')
                      .map(
                        (k) => DropdownMenuItem(value: k, child: Text(k.label)),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (kind) => setState(() => selections[c.id] = kind!),
                ),
              ),
            if (selected != null)
              Text(
                '${(c.quantity * selected.factor).toStringAsFixed(2)} kg CO₂e estimate',
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                FilledButton(
                  onPressed: busy || saveFailed || selected == null
                      ? null
                      : () => accept(c, selected),
                  child: const Text('Confirm activity'),
                ),
                TextButton(
                  onPressed: busy || saveFailed ? null : () => dismiss(c),
                  child: const Text('Discard'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
