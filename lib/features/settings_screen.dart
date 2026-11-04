// Overview: Settings screen for vehicle type, occupancy, and electricity region selection.
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../domain/regional_factors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settingsStore,
    required this.onChanged,
  });
  final SettingsStore settingsStore;
  final VoidCallback onChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late UserSettings settings;
  bool busy = false;

  static const forest = Color(0xFF174C38);

  @override
  void initState() {
    super.initState();
    settings = widget.settingsStore.load();
  }

  Future<void> _save(UserSettings next) async {
    setState(() => busy = true);
    try {
      await widget.settingsStore.save(next);
      if (mounted) setState(() => settings = next);
      widget.onChanged();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save settings. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: forest),
        ),
        const SizedBox(height: 8),
        const Text(
          'Personalise your emission estimates.',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
        const SizedBox(height: 32),

        // Vehicle type section
        const Text(
          'Vehicle type',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: forest),
        ),
        const SizedBox(height: 12),
        ...VehicleTypeOption.all.map(
          (v) => Card(
            child: RadioListTile<String>(
              value: v.id,
              groupValue: settings.vehicleType,
              activeColor: forest,
              title: Text(v.label, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(v.description),
              onChanged: busy ? null : (val) {
                if (val != null) _save(settings.copyWith(vehicleType: val));
              },
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Occupancy section
        const Text(
          'Vehicle occupancy',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: forest),
        ),
        const SizedBox(height: 8),
        const Text(
          'Used to adjust per-person car emissions (total ÷ occupants).',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('1 (solo)')),
            ButtonSegment(value: 2, label: Text('2')),
            ButtonSegment(value: 3, label: Text('3')),
            ButtonSegment(value: 4, label: Text('4+')),
          ],
          selected: {settings.occupancy},
          onSelectionChanged: busy ? null : (s) => _save(settings.copyWith(occupancy: s.first)),
        ),
        const SizedBox(height: 28),

        // Region section
        const Text(
          'Electricity region',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: forest),
        ),
        const SizedBox(height: 8),
        const Text(
          'Regional factors from EPA eGRID 2023. Affects electricity emission calculations.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        ...RegionalFactor.all.map(
          (r) => Card(
            child: RadioListTile<String>(
              value: r.id,
              groupValue: settings.regionId,
              activeColor: forest,
              title: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${r.kgCo2ePerKwh.toStringAsPrecision(4)} kg CO₂e/kWh\n${r.subregions}',
              ),
              onChanged: busy ? null : (val) {
                if (val != null) _save(settings.copyWith(regionId: val));
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: forest),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your current electricity factor: '
                        '${settings.region.kgCo2ePerKwh.toStringAsPrecision(4)} kg CO₂e/kWh',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  settings.regionId == 'us'
                      ? 'Using the US national average. Select a region for more accurate estimates.'
                      : 'Using ${settings.region.label} regional factor.',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
