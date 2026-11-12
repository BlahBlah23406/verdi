// Overview: Institutional aggregation dashboard for enterprise and university carbon footprint reporting.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'consent_rollup_card.dart';

const forest = Color(0xFF174C38);
const cream = Color(0xFFF6F7F2);

/// Department or team contributor within an organization.
class DepartmentContributor {
  const DepartmentContributor({
    required this.name,
    required this.departmentHead,
    required this.members,
    required this.emissionsTonnes,
    required this.momChangePercent,
    required this.keyAction,
  });

  final String name;
  final String departmentHead;
  final int members;
  final double emissionsTonnes;
  final double momChangePercent;
  final String keyAction;

  Map<String, dynamic> toJson() => {
    'name': name,
    'departmentHead': departmentHead,
    'members': members,
    'emissionsTonnes': emissionsTonnes,
    'momChangePercent': momChangePercent,
    'keyAction': keyAction,
  };
}

/// Monthly emissions trend point for an organization.
class MonthlyTrendPoint {
  const MonthlyTrendPoint({
    required this.month,
    required this.year,
    required this.totalTonnesCo2e,
    required this.momChangePercent,
  });

  final String month;
  final int year;
  final double totalTonnesCo2e;
  final double momChangePercent;

  String get label => '$month $year';

  Map<String, dynamic> toJson() => {
    'month': month,
    'year': year,
    'label': label,
    'totalTonnesCo2e': totalTonnesCo2e,
    'momChangePercent': momChangePercent,
  };
}

/// Organization profile with aggregate statistics and multi-front carbon metrics.
class OrganizationProfile {
  const OrganizationProfile({
    required this.id,
    required this.name,
    required this.type,
    required this.totalMembers,
    required this.reportingMonth,
    required this.commitment,
    required this.categoryEmissionsKg,
    required this.topContributors,
    required this.monthlyTrend,
  });

  final String id;
  final String name;
  final String type;
  final int totalMembers;
  final String reportingMonth;
  final String commitment;
  final Map<String, double> categoryEmissionsKg;
  final List<DepartmentContributor> topContributors;
  final List<MonthlyTrendPoint> monthlyTrend;

  double get totalEmissionsKg =>
      categoryEmissionsKg.values.fold(0.0, (sum, v) => sum + v);

  double get totalEmissionsTonnes => totalEmissionsKg / 1000.0;

  double get perCapitaKgCo2e =>
      totalMembers > 0 ? totalEmissionsKg / totalMembers : 0.0;

  double get latestMomChangePercent =>
      monthlyTrend.isNotEmpty ? monthlyTrend.last.momChangePercent : 0.0;

  Map<String, dynamic> generateReportJson() {
    final categoryBreakdown = <String, Map<String, dynamic>>{};
    final total = totalEmissionsKg;
    for (final entry in categoryEmissionsKg.entries) {
      final pct = total > 0 ? (entry.value / total) * 100.0 : 0.0;
      categoryBreakdown[entry.key] = {
        'emissionsKg': double.parse(entry.value.toStringAsFixed(1)),
        'emissionsTonnes': double.parse((entry.value / 1000.0).toStringAsFixed(2)),
        'percentageOfTotal': double.parse(pct.toStringAsFixed(1)),
      };
    }

    return {
      'reportId': 'VERDI-INST-${id.toUpperCase()}-${DateTime.now().year}',
      'generatedAt': DateTime.now().toIso8601String(),
      'organization': {
        'id': id,
        'name': name,
        'type': type,
        'totalMembers': totalMembers,
        'commitment': commitment,
        'reportingMonth': reportingMonth,
      },
      'summary': {
        'totalEmissionsMetricTonnes': double.parse(totalEmissionsTonnes.toStringAsFixed(2)),
        'totalEmissionsKg': double.parse(totalEmissionsKg.toStringAsFixed(1)),
        'perCapitaKgCo2e': double.parse(perCapitaKgCo2e.toStringAsFixed(2)),
        'monthOverMonthChangePercent': double.parse(latestMomChangePercent.toStringAsFixed(1)),
      },
      'categoryRollup': categoryBreakdown,
      'topContributors': topContributors.map((t) => t.toJson()).toList(),
      'monthlyTrend': monthlyTrend.map((m) => m.toJson()).toList(),
      'standard': 'Illustrative sample scenario; not audited or certified for compliance',
      'sampleData': true,
    };
  }
}

/// Pre-seeded demo organizations for VC presentation.
final List<OrganizationProfile> demoOrganizations = [
  OrganizationProfile(
    id: 'cascadia-uni',
    name: 'Cascadia University',
    type: 'Higher Education Institution',
    totalMembers: 1420,
    reportingMonth: 'November 2026',
    commitment: 'Campus Net-Zero by 2030',
    categoryEmissionsKg: {
      'Travel': 48200.0,
      'Home & Facilities': 39500.0,
      'Products': 14300.0,
      'Waste': 9000.0,
    },
    topContributors: [
      DepartmentContributor(
        name: 'College of the Environment',
        departmentHead: 'Dr. Elena Rostova',
        members: 280,
        emissionsTonnes: 14.2,
        momChangePercent: -18.4,
        keyAction: '84% public transit & rail adoption for campus commutes',
      ),
      DepartmentContributor(
        name: 'School of Computer Science',
        departmentHead: 'Prof. David Chen',
        members: 410,
        emissionsTonnes: 21.5,
        momChangePercent: -12.1,
        keyAction: 'Virtual lab compute & off-peak overnight servers',
      ),
      DepartmentContributor(
        name: 'Campus Facilities & Operations',
        departmentHead: 'Marcus Williams',
        members: 190,
        emissionsTonnes: 32.8,
        momChangePercent: -9.5,
        keyAction: 'Heat pump retrofits in resident student halls',
      ),
      DepartmentContributor(
        name: 'School of Medicine',
        departmentHead: 'Dr. Sarah Jenkins',
        members: 320,
        emissionsTonnes: 26.4,
        momChangePercent: -5.2,
        keyAction: 'Consolidated hospital shuttle routes & EV fleet',
      ),
      DepartmentContributor(
        name: 'Athletics & Recreation',
        departmentHead: 'Coach Travis Miller',
        members: 220,
        emissionsTonnes: 16.1,
        momChangePercent: -14.8,
        keyAction: 'Charter rail travel for regional athletic meets',
      ),
    ],
    monthlyTrend: [
      MonthlyTrendPoint(month: 'Jun', year: 2026, totalTonnesCo2e: 132.4, momChangePercent: -2.1),
      MonthlyTrendPoint(month: 'Jul', year: 2026, totalTonnesCo2e: 128.0, momChangePercent: -3.3),
      MonthlyTrendPoint(month: 'Aug', year: 2026, totalTonnesCo2e: 124.5, momChangePercent: -2.7),
      MonthlyTrendPoint(month: 'Sep', year: 2026, totalTonnesCo2e: 121.2, momChangePercent: -2.6),
      MonthlyTrendPoint(month: 'Oct', year: 2026, totalTonnesCo2e: 118.6, momChangePercent: -2.1),
      MonthlyTrendPoint(month: 'Nov', year: 2026, totalTonnesCo2e: 111.0, momChangePercent: -6.4),
    ],
  ),
  OrganizationProfile(
    id: 'acme-cleantech',
    name: 'Acme CleanTech Corp',
    type: 'Enterprise Technology',
    totalMembers: 350,
    reportingMonth: 'November 2026',
    commitment: '100% Renewable Operations by 2028',
    categoryEmissionsKg: {
      'Travel': 18400.0,
      'Home & Facilities': 14200.0,
      'Products': 8100.0,
      'Waste': 3300.0,
    },
    topContributors: [
      DepartmentContributor(
        name: 'Software Engineering',
        departmentHead: 'Aria Vance',
        members: 140,
        emissionsTonnes: 9.8,
        momChangePercent: -15.6,
        keyAction: 'Remote-first schedule with EV commuter incentives',
      ),
      DepartmentContributor(
        name: 'Hardware R&D',
        departmentHead: 'Kenji Sato',
        members: 85,
        emissionsTonnes: 15.2,
        momChangePercent: -8.4,
        keyAction: '3D print scrap closed-loop filament recycling',
      ),
      DepartmentContributor(
        name: 'Sales & Client Operations',
        departmentHead: 'Rachel Adams',
        members: 75,
        emissionsTonnes: 12.6,
        momChangePercent: -11.0,
        keyAction: 'Replacement of short flights with Amtrak Pacific service',
      ),
      DepartmentContributor(
        name: 'People & Workplace',
        departmentHead: 'Jamal Harris',
        members: 50,
        emissionsTonnes: 6.4,
        momChangePercent: -19.2,
        keyAction: 'Zero-waste catered office lunches & composting',
      ),
    ],
    monthlyTrend: [
      MonthlyTrendPoint(month: 'Jun', year: 2026, totalTonnesCo2e: 54.2, momChangePercent: -1.5),
      MonthlyTrendPoint(month: 'Jul', year: 2026, totalTonnesCo2e: 52.8, momChangePercent: -2.6),
      MonthlyTrendPoint(month: 'Aug', year: 2026, totalTonnesCo2e: 50.1, momChangePercent: -5.1),
      MonthlyTrendPoint(month: 'Sep', year: 2026, totalTonnesCo2e: 48.0, momChangePercent: -4.2),
      MonthlyTrendPoint(month: 'Oct', year: 2026, totalTonnesCo2e: 46.5, momChangePercent: -3.1),
      MonthlyTrendPoint(month: 'Nov', year: 2026, totalTonnesCo2e: 44.0, momChangePercent: -5.4),
    ],
  ),
  OrganizationProfile(
    id: 'pnw-health',
    name: 'Pacific Northwest Health',
    type: 'Healthcare & Hospital System',
    totalMembers: 820,
    reportingMonth: 'November 2026',
    commitment: 'Health Sector Climate Pledge 2030',
    categoryEmissionsKg: {
      'Travel': 32400.0,
      'Home & Facilities': 41800.0,
      'Products': 19200.0,
      'Waste': 11600.0,
    },
    topContributors: [
      DepartmentContributor(
        name: 'Ambulatory Care Network',
        departmentHead: 'Dr. Nathan Reed',
        members: 240,
        emissionsTonnes: 18.5,
        momChangePercent: -10.2,
        keyAction: 'Expanded telemedicine visits eliminating 45,000 km',
      ),
      DepartmentContributor(
        name: 'Clinical Operations',
        departmentHead: 'Nurse Dir. Maya Patel',
        members: 310,
        emissionsTonnes: 34.0,
        momChangePercent: -6.8,
        keyAction: 'LED surgical lighting & anesthesia gas capture',
      ),
      DepartmentContributor(
        name: 'Medical Research Institute',
        departmentHead: 'Dr. Gregory House',
        members: 150,
        emissionsTonnes: 29.5,
        momChangePercent: -8.1,
        keyAction: 'Ultra-low temperature freezer energy management',
      ),
      DepartmentContributor(
        name: 'Administrative HQ',
        departmentHead: 'Claire Underwood',
        members: 120,
        emissionsTonnes: 23.0,
        momChangePercent: -13.5,
        keyAction: 'Transit pass subsidy with 76% employee uptake',
      ),
    ],
    monthlyTrend: [
      MonthlyTrendPoint(month: 'Jun', year: 2026, totalTonnesCo2e: 124.0, momChangePercent: -1.0),
      MonthlyTrendPoint(month: 'Jul', year: 2026, totalTonnesCo2e: 121.5, momChangePercent: -2.0),
      MonthlyTrendPoint(month: 'Aug', year: 2026, totalTonnesCo2e: 118.2, momChangePercent: -2.7),
      MonthlyTrendPoint(month: 'Sep', year: 2026, totalTonnesCo2e: 114.6, momChangePercent: -3.0),
      MonthlyTrendPoint(month: 'Oct', year: 2026, totalTonnesCo2e: 111.0, momChangePercent: -3.1),
      MonthlyTrendPoint(month: 'Nov', year: 2026, totalTonnesCo2e: 105.0, momChangePercent: -5.4),
    ],
  ),
];

/// Institutional Carbon Aggregation Dashboard widget.
class InstitutionalDashboard extends StatefulWidget {
  const InstitutionalDashboard({
    super.key,
    this.initialOrgId,
  });

  final String? initialOrgId;

  @override
  State<InstitutionalDashboard> createState() => _InstitutionalDashboardState();
}

class _InstitutionalDashboardState extends State<InstitutionalDashboard> {
  late OrganizationProfile selectedOrg;

  @override
  void initState() {
    super.initState();
    selectedOrg = demoOrganizations.firstWhere(
      (o) => o.id == widget.initialOrgId,
      orElse: () => demoOrganizations.first,
    );
  }

  void _downloadReportJson() {
    final reportData = selectedOrg.generateReportJson();
    final jsonString = const JsonEncoder.withIndent('  ').convert(reportData);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.file_download_outlined, color: forest),
            const SizedBox(width: 8),
            Text('Report: ${selectedOrg.name}'),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sample scenario report (${selectedOrg.reportingMonth}). Estimates only; not an audited inventory.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                height: 240,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonString,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: forest),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              if (ctx.mounted) Navigator.pop(ctx);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'Report JSON for ${selectedOrg.name} copied to clipboard!',
                  ),
                  backgroundColor: forest,
                ),
              );
              try {
                await Clipboard.setData(ClipboardData(text: jsonString));
              } catch (_) {}
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy JSON Report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final org = selectedOrg;
    final totalTonnes = org.totalEmissionsTonnes;
    final mom = org.latestMomChangePercent;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        // Heading & Eyebrow
        const Text(
          'INSTITUTIONAL AGGREGATION · SCOPE 1, 2 & 3 COMMUTER',
          style: TextStyle(
            color: forest,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Organization Emissions View',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sample data only. Explore consent-based personal aggregation and illustrative organization reporting.',
          style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 24),

        ConsentRollupCard(key: ValueKey(org.id), organizationId: org.id),
        const SizedBox(height: 24),
        // Organization Selector Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Organization:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<OrganizationProfile>(
                  isExpanded: true,
                  initialValue: org,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(),
                  ),
                  items: demoOrganizations
                      .map(
                        (o) => DropdownMenuItem(
                          value: o,
                          child: Text(
                            '${o.name} (${o.type})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (newOrg) {
                    if (newOrg != null) {
                      setState(() => selectedOrg = newOrg);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Key Metric Rollup Hero Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: forest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    org.name.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFC7E0CB),
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF26654C),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${org.totalMembers} Active Members',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${totalTonnes.toStringAsFixed(1)} tonnes',
                style: const TextStyle(
                  fontSize: 44,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'CO₂e footprint for ${org.reportingMonth}',
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 20,
                runSpacing: 12,
                children: [
                  _statChip(
                    label: 'Per-Capita',
                    value: '${org.perCapitaKgCo2e.toStringAsFixed(1)} kg CO₂e',
                  ),
                  _statChip(
                    label: 'Month-over-Month',
                    value: '${mom >= 0 ? "+" : ""}${mom.toStringAsFixed(1)}%',
                    valueColor: mom <= 0 ? const Color(0xFF98E2A7) : const Color(0xFFFFB4AB),
                  ),
                  _statChip(
                    label: 'Commitment',
                    value: org.commitment,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Actions: Download Report JSON
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: forest,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            onPressed: _downloadReportJson,
            icon: const Icon(Icons.download, size: 20),
            label: const Text(
              'Download Report (JSON Export)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Per-Category Emissions Roll-Up Section
        const Text(
          'Per-Category Emissions Roll-Up',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: org.categoryEmissionsKg.entries.map((entry) {
                final pct = (entry.value / org.totalEmissionsKg) * 100.0;
                final tonnes = entry.value / 1000.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          Text(
                            '${tonnes.toStringAsFixed(1)} t (${pct.toStringAsFixed(1)}%)',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (pct / 100.0).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            entry.key == 'Travel'
                                ? forest
                                : entry.key.contains('Home')
                                    ? const Color(0xFF2E7D32)
                                    : entry.key == 'Products'
                                        ? const Color(0xFF00796B)
                                        : const Color(0xFF5D4037),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Month-over-Month Trend Section
        const Text(
          'Month-over-Month Trend',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: org.monthlyTrend.map((m) {
                    final maxT = org.monthlyTrend
                        .map((t) => t.totalTonnesCo2e)
                        .reduce((a, b) => a > b ? a : b);
                    final barHeight = (m.totalTonnesCo2e / maxT) * 90;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${m.totalTonnesCo2e.toStringAsFixed(0)}t',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: forest,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 28,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: forest.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          m.month,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${m.momChangePercent >= 0 ? "+" : ""}${m.momChangePercent.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: m.momChangePercent <= 0 ? Colors.green.shade800 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                const Divider(height: 28),
                Row(
                  children: [
                    const Icon(Icons.trending_down, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Total institutional emissions reduced by ${(org.monthlyTrend.first.totalTonnesCo2e - org.monthlyTrend.last.totalTonnesCo2e).toStringAsFixed(1)} tonnes since June 2026.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Top Contributors Section
        const Text(
          'Top Department Contributors',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...org.topContributors.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.momChangePercent <= 0
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: c.momChangePercent <= 0
                                ? Colors.green.shade200
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Text(
                          '${c.momChangePercent >= 0 ? "+" : ""}${c.momChangePercent.toStringAsFixed(1)}% MoM',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.momChangePercent <= 0
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Lead: ${c.departmentHead} · ${c.members} members · ${c.emissionsTonnes.toStringAsFixed(1)} tonnes CO₂e',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          c.keyAction,
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        )),
      ],
    );
  }

  Widget _statChip({
    required String label,
    required String value,
    Color valueColor = Colors.white,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFC7E0CB), fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
