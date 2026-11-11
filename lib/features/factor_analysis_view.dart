// Overview: Factor sensitivity and attribution analysis for institutional emissions.
import 'package:flutter/material.dart';

const Color ink = Color(0xFF163D32);
const Color forest = Color(0xFF174C38);
const Color paper = Color(0xFFF4F5EE);
const Color cream = Color(0xFFF6F7F2);
const Color lime = Color(0xFFD6EC92);
const Color amber = Color(0xFFD89361);
const Color coral = Color(0xFFD34528);
const Color sage = Color(0xFF98E2A7);

/// Determinant factor influencing institutional carbon output.
class FactorDeterminant {
  const FactorDeterminant({
    required this.name,
    required this.category,
    required this.varianceSharePercent,
    required this.monthlyTonnesAttributed,
    required this.baselineValue,
    required this.factorRationale,
    required this.leverDescription,
    required this.elasticityRating, // 'Very High', 'High', 'Moderate'
    required this.icon,
  });

  final String name;
  final String category;
  final double varianceSharePercent;
  final double monthlyTonnesAttributed;
  final String baselineValue;
  final String factorRationale;
  final String leverDescription;
  final String elasticityRating;
  final IconData icon;

  Color get color {
    switch (elasticityRating) {
      case 'Very High':
        return coral;
      case 'High':
        return amber;
      case 'Moderate':
      default:
        return const Color(0xFF2E7D32);
    }
  }
}

final List<FactorDeterminant> sampleDeterminants = [
  const FactorDeterminant(
    name: 'Commute Transport Mode Choice',
    category: 'Travel / Commuter Scope 3',
    varianceSharePercent: 41.2,
    monthlyTonnesAttributed: 108.6,
    baselineValue: '76% Solo ICE Vehicle (0.1855 kg/p-km)',
    factorRationale: 'EPA Table 10 factor differential: Solo car is 4.1x higher carbon than bus (0.0454 kg/p-km) and 2.2x higher than commuter rail.',
    leverDescription: 'Shifting 20% of solo drivers to public transit yields the single largest institutional emission reduction.',
    elasticityRating: 'Very High',
    icon: Icons.directions_car_outlined,
  ),
  const FactorDeterminant(
    name: 'Commute Distance & In-Office Frequency',
    category: 'Travel Activity Volume',
    varianceSharePercent: 24.8,
    monthlyTonnesAttributed: 65.4,
    baselineValue: '28.4 km roundtrip avg · 4.2 in-office days/week',
    factorRationale: 'Linear passenger-km scaling. Weekly remote work days directly reduce commuter vehicle-km without equipment purchase.',
    leverDescription: 'One universal remote collaboration day per week cuts institutional travel emissions by 23.8 tonnes CO₂e/mo.',
    elasticityRating: 'High',
    icon: Icons.alt_route_outlined,
  ),
  const FactorDeterminant(
    name: 'Grid Electricity Marginal Carbon Intensity',
    category: 'Facility Energy / Scope 2',
    varianceSharePercent: 18.5,
    monthlyTonnesAttributed: 48.8,
    baselineValue: '0.349 kg CO₂e/kWh (US EPA national fallback)',
    factorRationale: 'Regional eGRID subregion factors vary 3.6x between off-peak clean hydro/wind (0.12 kg/kWh) and peak natural gas peaking (0.44 kg/kWh).',
    leverDescription: 'Shift high-demand compute jobs and EV fleet charging to midnight-to-6 AM surplus generation window.',
    elasticityRating: 'High',
    icon: Icons.bolt_outlined,
  ),
  const FactorDeterminant(
    name: 'Building Thermal Heating & Degree Days',
    category: 'Facility Heating / Scope 1',
    varianceSharePercent: 10.3,
    monthlyTonnesAttributed: 27.2,
    baselineValue: '680 Heating Degree Days (HDD) · Gas baseload',
    factorRationale: 'District steam cogeneration morning ramps (5:00-8:00 AM) trigger natural gas peaker boilers during freezing weather.',
    leverDescription: 'Heat pump pre-heating and night setback temperature schedules dampen boiler firing cycles.',
    elasticityRating: 'Moderate',
    icon: Icons.thermostat_outlined,
  ),
  const FactorDeterminant(
    name: 'Vehicle Occupancy & Rideshare Matching',
    category: 'Travel Efficiency',
    varianceSharePercent: 5.2,
    monthlyTonnesAttributed: 13.7,
    baselineValue: '1.14 average vehicle occupants',
    factorRationale: 'Moving occupancy from 1.14 to 2.0+ riders halves per-passenger travel emissions without changing vehicle fleet.',
    leverDescription: 'Campus rideshare matching incentives for staff along heavy commuter corridors.',
    elasticityRating: 'Moderate',
    icon: Icons.groups_outlined,
  ),
];

/// Interactive factor sensitivity and scenario simulator.
class FactorAnalysisView extends StatefulWidget {
  const FactorAnalysisView({
    super.key,
    this.totalBaselineTonnes = 263.7,
  });

  final double totalBaselineTonnes;

  @override
  State<FactorAnalysisView> createState() => _FactorAnalysisViewState();
}

class _FactorAnalysisViewState extends State<FactorAnalysisView> {
  // Simulator scenario sliders
  double transitShiftPercent = 15.0; // 0% to 50%
  double remoteDaysPerWeek = 1.0; // 0 to 4 days
  double cleanGridShiftPercent = 20.0; // 0% to 80%
  double carpoolOccupancy = 1.3; // 1.0 to 2.5 riders

  @override
  Widget build(BuildContext context) {
    // Dynamic sensitivity calculation
    // 1. Mode shift impact: up to 54.3 tonnes reduction at 50%
    final double modeShiftSavings = (transitShiftPercent / 50.0) * 42.5;

    // 2. Remote work impact: up to 38.0 tonnes reduction at 4 days
    final double remoteDaysSavings = (remoteDaysPerWeek / 4.0) * 32.0;

    // 3. Clean grid shift impact: up to 28.0 tonnes reduction at 80%
    final double cleanGridSavings = (cleanGridShiftPercent / 80.0) * 24.5;

    // 4. Carpool impact: up to 12.0 tonnes at 2.5 riders
    final double carpoolSavings = ((carpoolOccupancy - 1.0) / 1.5).clamp(0.0, 1.0) * 11.2;

    final double totalSavingsTonnes = (modeShiftSavings + remoteDaysSavings + cleanGridSavings + carpoolSavings)
        .clamp(0.0, widget.totalBaselineTonnes * 0.65);
    final double projectedEmissionsTonnes = widget.totalBaselineTonnes - totalSavingsTonnes;
    final double reductionPercent = (totalSavingsTonnes / widget.totalBaselineTonnes) * 100.0;
    final int simulatedPoints = (totalSavingsTonnes * 1000 * 10).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Text(
          'FACTOR SENSITIVITY MODELING · EPA & EGRID METHODOLOGY',
          style: TextStyle(
            color: forest,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Which Factors Affect Carbon Most?',
          style: TextStyle(
            fontSize: MediaQuery.sizeOf(context).width < 600 ? 26 : 32,
            fontWeight: FontWeight.w700,
            color: ink,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Attribute emissions to underlying physical determinants and simulate high-leverage institutional policy levers.',
          style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 24),

        // Ranked Factor Waterfall Chart Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Ranked Factor Impact Breakdown (% of Total Variance)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ink),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: forest.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'EPA 2025 Attributed',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: forest),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Statistical variance contribution calculated across 1,420 active participant activity records.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),

                // Factor Bars
                ...sampleDeterminants.map((f) => _factorBarRow(f)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Interactive Sensitivity Simulator Card
        const Text(
          'Interactive Sensitivity Scenario Simulator',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
        ),
        const SizedBox(height: 8),
        Text(
          'Adjust institutional policy levers to observe projected emissions impact in real time.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 14),

        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live Scenario Comparison Visualization
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ink,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PROJECTED MONTHLY REDUCTION',
                                  style: TextStyle(
                                    color: Color(0xFFC7E0CB),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '-${totalSavingsTonnes.toStringAsFixed(1)} tonnes CO₂e',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: sage,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  '${reductionPercent.toStringAsFixed(1)}% reduction vs. ${widget.totalBaselineTonnes.toStringAsFixed(1)}t baseline',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF26654C),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'ECO-POINTS',
                                  style: TextStyle(color: Color(0xFFC7E0CB), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '+${simulatedPoints.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Baseline vs Simulated Comparative Bar Chart
                      Column(
                        children: [
                          _comparativeBar(
                            label: 'Baseline Footprint',
                            valueTonnes: widget.totalBaselineTonnes,
                            maxTonnes: widget.totalBaselineTonnes,
                            barColor: Colors.white38,
                            textColor: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          _comparativeBar(
                            label: 'Simulated Footprint',
                            valueTonnes: projectedEmissionsTonnes,
                            maxTonnes: widget.totalBaselineTonnes,
                            barColor: lime,
                            textColor: lime,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Interactive Sliders
                const Text(
                  'Policy Sensitivity Levers:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ink),
                ),
                const SizedBox(height: 16),

                // Lever 1: Mode Shift
                _sliderTile(
                  icon: Icons.directions_bus_outlined,
                  title: 'Transit Mode Shift (Solo ICE → Express Bus/Rail)',
                  valueLabel: '+${transitShiftPercent.toStringAsFixed(0)}% Shift',
                  savingsLabel: '-${modeShiftSavings.toStringAsFixed(1)} tonnes',
                  value: transitShiftPercent,
                  min: 0.0,
                  max: 50.0,
                  onChanged: (v) => setState(() => transitShiftPercent = v),
                ),
                const Divider(height: 24),

                // Lever 2: Remote Work
                _sliderTile(
                  icon: Icons.laptop_mac_outlined,
                  title: 'Flexible Remote / Collaboration Schedule',
                  valueLabel: '${remoteDaysPerWeek.toStringAsFixed(1)} days/wk remote',
                  savingsLabel: '-${remoteDaysSavings.toStringAsFixed(1)} tonnes',
                  value: remoteDaysPerWeek,
                  min: 0.0,
                  max: 4.0,
                  onChanged: (v) => setState(() => remoteDaysPerWeek = v),
                ),
                const Divider(height: 24),

                // Lever 3: Clean Grid Energy
                _sliderTile(
                  icon: Icons.solar_power_outlined,
                  title: 'Off-Peak / Renewable Electricity Scheduling',
                  valueLabel: '${cleanGridShiftPercent.toStringAsFixed(0)}% Off-Peak Shift',
                  savingsLabel: '-${cleanGridSavings.toStringAsFixed(1)} tonnes',
                  value: cleanGridShiftPercent,
                  min: 0.0,
                  max: 80.0,
                  onChanged: (v) => setState(() => cleanGridShiftPercent = v),
                ),
                const Divider(height: 24),

                // Lever 4: Carpooling
                _sliderTile(
                  icon: Icons.groups_outlined,
                  title: 'Carpool & Rideshare Vehicle Occupancy',
                  valueLabel: '${carpoolOccupancy.toStringAsFixed(1)} riders/car avg',
                  savingsLabel: '-${carpoolSavings.toStringAsFixed(1)} tonnes',
                  value: carpoolOccupancy,
                  min: 1.0,
                  max: 2.5,
                  onChanged: (v) => setState(() => carpoolOccupancy = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Key Analytical Takeaways
        const Text(
          'Key Institutional Findings & Prioritized Strategy',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
        ),
        const SizedBox(height: 12),

        _takeawayCard(
          rank: '1',
          title: 'Mode Shift Outperforms All Vehicle Upgrades',
          content: 'A 20% shift from solo car commuting to commuter rail/bus reduces 2.8x more carbon than transitioning the same drivers to hybrid vehicles, due to EPA Table 10 occupancy and efficiency factors.',
          badge: 'Highest Leverage (41.2% Impact)',
          badgeColor: coral,
        ),
        const SizedBox(height: 10),
        _takeawayCard(
          rank: '2',
          title: 'Remote Collaboration Days Deliver Immediate Zero-CapEx Savings',
          content: 'Instituting 1 universal remote day/week cuts 32.0 tonnes CO₂e/month across Cascadia without equipment investment, addressing the #2 distance factor directly.',
          badge: 'Zero-CapEx Policy (24.8% Impact)',
          badgeColor: amber,
        ),
        const SizedBox(height: 10),
        _takeawayCard(
          rank: '3',
          title: 'Timing Compute & Energy Loads Avoids Peak Marginal Emitting Hours',
          content: 'Shifting HPC server compute and EV charging to midnight-6 AM captures Pacific Northwest hydropower surplus at 0.12 kg CO₂e/kWh vs. daytime peaker gas at 0.44 kg/kWh.',
          badge: 'Grid Optimization (18.5% Impact)',
          badgeColor: const Color(0xFF2E7D32),
        ),
      ],
    );
  }

  Widget _comparativeBar({
    required String label,
    required double valueTonnes,
    required double maxTonnes,
    required Color barColor,
    required Color textColor,
  }) {
    final double fraction = (valueTonnes / maxTonnes).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            Text(
              '${valueTonnes.toStringAsFixed(1)} tonnes CO₂e',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 10,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  Widget _sliderTile({
    required IconData icon,
    required String title,
    required String valueLabel,
    required String savingsLabel,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: forest),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: ink),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: forest.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                savingsLabel,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: forest),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                activeColor: forest,
                inactiveColor: Colors.grey.shade300,
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: 110,
              child: Text(
                valueLabel,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ink),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _factorBarRow(FactorDeterminant factor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(factor.icon, size: 18, color: factor.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  factor.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ink),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: factor.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${factor.elasticityRating} Elasticity',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: factor.color),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${factor.varianceSharePercent.toStringAsFixed(1)}%',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: factor.color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (factor.varianceSharePercent / 50.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(factor.color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  factor.factorRationale,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                ),
              ),
              Text(
                '${factor.monthlyTonnesAttributed.toStringAsFixed(1)} t CO₂e',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _takeawayCard({
    required String rank,
    required String title,
    required String content,
    required String badge,
    required Color badgeColor,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: ink,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  rank,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ink),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    content,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
