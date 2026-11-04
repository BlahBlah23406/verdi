// Overview: Three-step onboarding flow — welcome, vehicle setup, region selection.
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../domain/regional_factors.dart';

/// Multi-step onboarding shown on first launch (or when user hasn't completed setup).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.settingsStore,
    required this.onComplete,
  });
  final SettingsStore settingsStore;
  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;
  String vehicleType = 'gasoline';
  int occupancy = 1;
  String regionId = 'us';

  static const forest = Color(0xFF174C38);
  static const cream = Color(0xFFF6F7F2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _progressDots(),
                const SizedBox(height: 32),
                Expanded(child: _stepContent()),
                const SizedBox(height: 24),
                _navButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressDots() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == step ? forest : forest.withValues(alpha: 0.2),
            ),
          );
        }),
      );

  Widget _stepContent() {
    switch (step) {
      case 0:
        return _welcomeStep();
      case 1:
        return _vehicleStep();
      case 2:
        return _regionStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _welcomeStep() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.eco, size: 80, color: forest),
          const SizedBox(height: 24),
          const Text(
            'Welcome to Verdi',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: forest,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Understand your everyday carbon footprint.\n'
            'Track travel and electricity, see your impact,\n'
            'and discover ways to reduce emissions.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          Card(
            color: Colors.white,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _featureRow(Icons.sensors, 'Automatic tracking',
                      'Detect journeys and import utility readings'),
                  _featureRow(Icons.receipt_long, 'Activity journal',
                      'Every logged activity with traceable calculations'),
                  _featureRow(Icons.auto_awesome, 'Reduce',
                      'Compare travel options and see potential savings'),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _featureRow(IconData icon, String title, String subtitle) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: forest, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                  Text(subtitle,
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _vehicleStep() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'What do you drive?',
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w700, color: forest),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'We use this to personalise your travel estimates.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          ...VehicleTypeOption.all.map(
            (v) => Card(
              color: Colors.white,
              elevation: 0,
              child: RadioListTile<String>(
                value: v.id,
                groupValue: vehicleType,
                activeColor: forest,
                title: Text(v.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(v.description),
                onChanged: (val) => setState(() => vehicleType = val!),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'How many people typically ride with you?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1 (solo)')),
              ButtonSegment(value: 2, label: Text('2')),
              ButtonSegment(value: 3, label: Text('3')),
              ButtonSegment(value: 4, label: Text('4+')),
            ],
            selected: {occupancy},
            onSelectionChanged: (s) => setState(() => occupancy = s.first),
          ),
        ],
      );

  Widget _regionStep() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Where do you live?',
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w700, color: forest),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Electricity emissions vary by region. Select yours for accurate estimates.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          ...RegionalFactor.all.map(
            (r) => Card(
              color: Colors.white,
              elevation: 0,
              child: RadioListTile<String>(
                value: r.id,
                groupValue: regionId,
                activeColor: forest,
                title: Text(r.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${r.kgCo2ePerKwh.toStringAsPrecision(4)} kg CO₂e/kWh · ${r.subregions}',
                ),
                onChanged: (val) => setState(() => regionId = val!),
              ),
            ),
          ),
        ],
      );

  Widget _navButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (step > 0)
            TextButton(
              onPressed: () => setState(() => step--),
              child: const Text('Back'),
            )
          else
            const SizedBox(width: 60),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: forest),
            onPressed: () async {
              if (step < 2) {
                setState(() => step++);
              } else {
                await widget.settingsStore.save(
                  widget.settingsStore.load().copyWith(
                        onboarded: true,
                        vehicleType: vehicleType,
                        occupancy: occupancy,
                        regionId: regionId,
                      ),
                );
                widget.onComplete();
              }
            },
            child: Text(step < 2 ? 'Continue' : 'Get started'),
          ),
        ],
      );
}
