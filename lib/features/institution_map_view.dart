// Overview: Geospatial carbon mapping of institutional commuter corridors and facility emission hotspots.
import 'package:flutter/material.dart';

const Color ink = Color(0xFF163D32);
const Color forest = Color(0xFF174C38);
const Color paper = Color(0xFFF4F5EE);
const Color cream = Color(0xFFF6F7F2);
const Color lime = Color(0xFFD6EC92);
const Color amber = Color(0xFFD89361);
const Color coral = Color(0xFFD34528);
const Color sage = Color(0xFF98E2A7);

/// Commuter corridor or transit route with carbon metrics.
class CorridorRoute {
  const CorridorRoute({
    required this.id,
    required this.name,
    required this.code,
    required this.distanceKm,
    required this.monthlyTrips,
    required this.monthlyTonnesCo2e,
    required this.intensityGramPerPkm,
    required this.primaryMode,
    required this.modalShareDescription,
    required this.pathPoints, // Normalized 0.0 - 1.0 coordinates on map
    required this.severity, // 'high', 'moderate', 'low'
    required this.potentialSavingsTonnes,
    required this.recommendation,
  });

  final String id;
  final String name;
  final String code;
  final double distanceKm;
  final int monthlyTrips;
  final double monthlyTonnesCo2e;
  final double intensityGramPerPkm;
  final String primaryMode;
  final String modalShareDescription;
  final List<Offset> pathPoints;
  final String severity;
  final double potentialSavingsTonnes;
  final String recommendation;

  Color get color {
    switch (severity) {
      case 'high':
        return coral;
      case 'moderate':
        return amber;
      case 'low':
      default:
        return const Color(0xFF2E7D32);
    }
  }
}

/// Specific physical location with high carbon output (facility or commuter bottleneck).
class CarbonHotspot {
  const CarbonHotspot({
    required this.id,
    required this.name,
    required this.category,
    required this.coordinatesLabel,
    required this.mapPosition, // Normalized 0.0 - 1.0 position
    required this.monthlyTonnesCo2e,
    required this.percentageOfTotal,
    required this.primaryDriver,
    required this.status,
    required this.severity, // 'critical', 'high', 'moderate'
    required this.icon,
    required this.actionPlan,
  });

  final String id;
  final String name;
  final String category;
  final String coordinatesLabel;
  final Offset mapPosition;
  final double monthlyTonnesCo2e;
  final double percentageOfTotal;
  final String primaryDriver;
  final String status;
  final String severity;
  final IconData icon;
  final String actionPlan;

  Color get color {
    switch (severity) {
      case 'critical':
        return const Color(0xFFB71C1C);
      case 'high':
        return coral;
      case 'moderate':
      default:
        return amber;
    }
  }
}

/// Pre-seeded institutional geospatial datasets.
final List<CorridorRoute> sampleCorridors = [
  const CorridorRoute(
    id: 'corridor-i5',
    name: 'I-5 North Gateway Commute Corridor',
    code: 'COR-01',
    distanceKm: 28.4,
    monthlyTrips: 14200,
    monthlyTonnesCo2e: 41.8,
    intensityGramPerPkm: 185.5,
    primaryMode: 'Solo ICE Vehicle (76%)',
    modalShareDescription: '76% Solo Car, 14% Carpool, 10% Express Bus',
    pathPoints: [
      Offset(0.12, 0.15),
      Offset(0.24, 0.28),
      Offset(0.38, 0.42),
      Offset(0.50, 0.52),
    ],
    severity: 'high',
    potentialSavingsTonnes: 28.5,
    recommendation: 'Expand express bus route subsidies and implement peak-hour carpool priority parking.',
  ),
  const CorridorRoute(
    id: 'corridor-sr520',
    name: 'SR-520 Eastside Tech Bridge',
    code: 'COR-02',
    distanceKm: 19.6,
    monthlyTrips: 9800,
    monthlyTonnesCo2e: 26.4,
    intensityGramPerPkm: 162.0,
    primaryMode: 'Mixed Vehicle / Vanpool',
    modalShareDescription: '68% Solo Car (18% EV), 22% Regional Transit, 10% Vanpool',
    pathPoints: [
      Offset(0.88, 0.38),
      Offset(0.72, 0.45),
      Offset(0.58, 0.50),
      Offset(0.50, 0.52),
    ],
    severity: 'high',
    potentialSavingsTonnes: 14.2,
    recommendation: 'Target employer-sponsored vanpool matching to eliminate 2,200 single-occupant bridge trips.',
  ),
  const CorridorRoute(
    id: 'corridor-light-rail',
    name: 'University Link Light Rail & BRT Spine',
    code: 'COR-03',
    distanceKm: 22.0,
    monthlyTrips: 18600,
    monthlyTonnesCo2e: 6.4,
    intensityGramPerPkm: 34.2,
    primaryMode: 'Electric Light Rail & BRT',
    modalShareDescription: '82% Electric Light Rail, 18% Trolley Bus',
    pathPoints: [
      Offset(0.52, 0.90),
      Offset(0.51, 0.75),
      Offset(0.50, 0.62),
      Offset(0.50, 0.52),
    ],
    severity: 'low',
    potentialSavingsTonnes: 1.8,
    recommendation: 'Model high-efficiency transit corridor. Maintain 100% universal student & employee transit pass.',
  ),
  const CorridorRoute(
    id: 'corridor-sr908',
    name: 'Eastside Commuter Arterial (148th Ave)',
    code: 'COR-04',
    distanceKm: 15.2,
    monthlyTrips: 8400,
    monthlyTonnesCo2e: 22.1,
    intensityGramPerPkm: 178.0,
    primaryMode: 'Solo ICE Vehicle (81%)',
    modalShareDescription: '81% Solo Vehicle, 11% Local Bus, 8% Cycling',
    pathPoints: [
      Offset(0.85, 0.78),
      Offset(0.70, 0.68),
      Offset(0.58, 0.58),
      Offset(0.50, 0.52),
    ],
    severity: 'high',
    potentialSavingsTonnes: 12.0,
    recommendation: 'Install e-bike charging hubs and dedicated feeder shuttles to the regional transit center.',
  ),
  const CorridorRoute(
    id: 'corridor-shuttle',
    name: 'Inter-Facility Logistics & Shuttle Loop',
    code: 'COR-05',
    distanceKm: 12.5,
    monthlyTrips: 4500,
    monthlyTonnesCo2e: 11.2,
    intensityGramPerPkm: 110.0,
    primaryMode: 'Campus Fleet Hybrid / Diesel',
    modalShareDescription: '60% Hybrid Shuttle, 40% Diesel Logistics Vans',
    pathPoints: [
      Offset(0.50, 0.52),
      Offset(0.40, 0.44),
      Offset(0.44, 0.64),
      Offset(0.50, 0.52),
    ],
    severity: 'moderate',
    potentialSavingsTonnes: 6.8,
    recommendation: 'Replace legacy diesel vans with electric cargo fleet and optimize route dispatch intervals.',
  ),
];

final List<CarbonHotspot> sampleHotspots = [
  const CarbonHotspot(
    id: 'spot-steam-plant',
    name: 'North Campus District Cogeneration Plant',
    category: 'Facility Energy Baseload',
    coordinatesLabel: '47.658° N, 122.312° W',
    mapPosition: Offset(0.38, 0.35),
    monthlyTonnesCo2e: 88.4,
    percentageOfTotal: 34.2,
    primaryDriver: 'Natural gas heating boilers & winter morning thermal ramp (5-8 AM)',
    status: 'Transition Plan in Progress',
    severity: 'critical',
    icon: Icons.power_outlined,
    actionPlan: 'Deploy industrial heat pump retrofits to reduce morning gas boiler peaking by 42%.',
  ),
  const CarbonHotspot(
    id: 'spot-parking-pavilion',
    name: 'South Commuter Parking Pavilion & Hub',
    category: 'Commuter Vehicle Concentration',
    coordinatesLabel: '47.651° N, 122.316° W',
    mapPosition: Offset(0.50, 0.54),
    monthlyTonnesCo2e: 54.2,
    percentageOfTotal: 21.0,
    primaryDriver: '3,400 daily vehicle arrivals; 82% solo ICE vehicles with idle queuing',
    status: 'High Priority Action Area',
    severity: 'high',
    icon: Icons.directions_car_outlined,
    actionPlan: 'Automate entry gates to eliminate idle queues and convert 120 stalls to managed EV charging.',
  ),
  const CarbonHotspot(
    id: 'spot-data-center',
    name: 'Science & HPC Supercomputing Center',
    category: 'Compute & Power Load',
    coordinatesLabel: '47.654° N, 122.308° W',
    mapPosition: Offset(0.62, 0.42),
    monthlyTonnesCo2e: 42.6,
    percentageOfTotal: 16.5,
    primaryDriver: '24/7 continuous electricity load (PUE 1.38) during fossil peak hours',
    status: 'Optimization Active',
    severity: 'high',
    icon: Icons.dns_outlined,
    actionPlan: 'Schedule batch compute jobs during regional off-peak hydro/wind surplus windows (11 PM - 5 AM).',
  ),
  const CarbonHotspot(
    id: 'spot-biomed-lab',
    name: 'Biomedical Research Vivarium & Cleanrooms',
    category: 'Ventilation & Cold Storage',
    coordinatesLabel: '47.649° N, 122.310° W',
    mapPosition: Offset(0.48, 0.70),
    monthlyTonnesCo2e: 38.5,
    percentageOfTotal: 14.9,
    primaryDriver: '100% outside air HVAC exchange (15 ACH) & ultra-low temp freezers (-80°C)',
    status: 'Under Review',
    severity: 'high',
    icon: Icons.biotech_outlined,
    actionPlan: 'Implement run-around coil heat recovery ventilation and ultra-low freezer consolidation.',
  ),
  const CarbonHotspot(
    id: 'spot-logistics-depot',
    name: 'East Campus Freight & Materials Depot',
    category: 'Freight & Waste Logistics',
    coordinatesLabel: '47.655° N, 122.302° W',
    mapPosition: Offset(0.76, 0.60),
    monthlyTonnesCo2e: 19.8,
    percentageOfTotal: 7.7,
    primaryDriver: 'Heavy diesel delivery truck idling and uncompacted waste hauling',
    status: 'Scheduled for Audit',
    severity: 'moderate',
    icon: Icons.local_shipping_outlined,
    actionPlan: 'Enforce campus 3-minute idle limits and install commercial waste compaction to halve haul trips.',
  ),
];

/// Interactive institutional carbon map screen.
class InstitutionMapView extends StatefulWidget {
  const InstitutionMapView({
    super.key,
    this.organizationName = 'Cascadia University',
  });

  final String organizationName;

  @override
  State<InstitutionMapView> createState() => _InstitutionMapViewState();
}

class _InstitutionMapViewState extends State<InstitutionMapView> {
  String selectedFilter = 'all'; // 'all', 'high', 'corridors', 'hotspots'
  CorridorRoute? selectedRoute;
  CarbonHotspot? selectedHotspot;

  @override
  void initState() {
    super.initState();
    selectedHotspot = sampleHotspots.first;
  }

  List<CorridorRoute> get filteredCorridors {
    if (selectedFilter == 'hotspots') return [];
    if (selectedFilter == 'high') {
      return sampleCorridors.where((c) => c.severity == 'high').toList();
    }
    return sampleCorridors;
  }

  List<CarbonHotspot> get filteredHotspots {
    if (selectedFilter == 'corridors') return [];
    if (selectedFilter == 'high') {
      return sampleHotspots.where((h) => h.severity == 'critical' || h.severity == 'high').toList();
    }
    return sampleHotspots;
  }

  @override
  Widget build(BuildContext context) {
    final double totalHotspotTonnes = sampleHotspots.fold(0.0, (s, h) => s + h.monthlyTonnesCo2e);
    final double totalCorridorTonnes = sampleCorridors.fold(0.0, (s, c) => s + c.monthlyTonnesCo2e);
    final double totalPotentialSavings = sampleCorridors.fold(0.0, (s, c) => s + c.potentialSavingsTonnes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Text(
          'GEOSPATIAL CARBON INTELLIGENCE · EMISSION CORRIDORS',
          style: TextStyle(
            color: forest,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Carbon Map: Routes & Hotspots',
          style: TextStyle(
            fontSize: MediaQuery.sizeOf(context).width < 600 ? 26 : 32,
            fontWeight: FontWeight.w700,
            color: ink,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Spatial visualization of commuter transit corridors and high-emission facility nodes across ${widget.organizationName}.',
          style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 20),

        // KPI Summary Strip
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _statMetric(
              'Corridor Emissions',
              '${totalCorridorTonnes.toStringAsFixed(1)} t',
              '${sampleCorridors.length} Monitored Commute Routes',
              coral,
            ),
            _statMetric(
              'Facility Hotspots',
              '${totalHotspotTonnes.toStringAsFixed(1)} t',
              '${sampleHotspots.length} High-Output Facility Nodes',
              const Color(0xFFB71C1C),
            ),
            _statMetric(
              'Mitigation Potential',
              '${totalPotentialSavings.toStringAsFixed(1)} t',
              'Identified Corridor Interventions',
              const Color(0xFF2E7D32),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('all', 'All Routes & Places (${sampleCorridors.length + sampleHotspots.length})'),
              const SizedBox(width: 8),
              _filterChip('high', 'High Carbon Only (≥22t)'),
              const SizedBox(width: 8),
              _filterChip('corridors', 'Commuter Corridors (${sampleCorridors.length})'),
              const SizedBox(width: 8),
              _filterChip('hotspots', 'Facility Hotspots (${sampleHotspots.length})'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Interactive Map Card
        Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              // Map Canvas Container
              Container(
                height: 380,
                width: double.infinity,
                color: const Color(0xFFE9EFE6),
                child: Stack(
                  children: [
                    // Vector Canvas
                    CustomPaint(
                      size: Size.infinite,
                      painter: _CarbonMapPainter(
                        corridors: filteredCorridors,
                        hotspots: filteredHotspots,
                        selectedRouteId: selectedRoute?.id,
                        selectedHotspotId: selectedHotspot?.id,
                      ),
                    ),

                    // Clickable hotspots overlay
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: filteredHotspots.map((hotspot) {
                            final double x = hotspot.mapPosition.dx * constraints.maxWidth;
                            final double y = hotspot.mapPosition.dy * constraints.maxHeight;
                            final bool isSelected = selectedHotspot?.id == hotspot.id;

                            return Positioned(
                              left: x - 26,
                              top: y - 26,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedHotspot = hotspot;
                                    selectedRoute = null;
                                  });
                                },
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isSelected ? ink : hotspot.color,
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (isSelected ? ink : hotspot.color).withValues(alpha: 0.4),
                                              blurRadius: isSelected ? 12 : 6,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                          border: Border.all(
                                            color: Colors.white,
                                            width: isSelected ? 2.5 : 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(hotspot.icon, size: 12, color: Colors.white),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${hotspot.monthlyTonnesCo2e.toStringAsFixed(0)}t',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    // Map Overlay Badges & Legend
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.explore, size: 14, color: forest),
                            SizedBox(width: 6),
                            Text(
                              'CASCADIA METRO & CAMPUS REGION',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Map Legend
                    Positioned(
                      bottom: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'EMISSION INTENSITY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _legendItem(coral, 'High (>25t)'),
                                const SizedBox(width: 10),
                                _legendItem(amber, 'Moderate (10-25t)'),
                                const SizedBox(width: 10),
                                _legendItem(const Color(0xFF2E7D32), 'Clean (<10t)'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Interactive Selection Inspector Card
              if (selectedHotspot != null)
                _buildHotspotInspector(selectedHotspot!)
              else if (selectedRoute != null)
                _buildRouteInspector(selectedRoute!)
              else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Tap any corridor route or hotspot marker to inspect localized carbon drivers and interventions.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Corridors & Places Table Section
        const Text(
          'Monitored Commuter Routes & Emissions Breakdown',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
        ),
        const SizedBox(height: 12),
        ...sampleCorridors.map((c) => _corridorCard(c)),

        const SizedBox(height: 24),
        const Text(
          'Specific Physical Places with High Carbon Output',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
        ),
        const SizedBox(height: 12),
        ...sampleHotspots.map((h) => _hotspotCard(h)),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _filterChip(String key, String label) {
    final bool active = selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      selectedColor: ink,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: active ? Colors.white : ink,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      side: BorderSide(color: active ? ink : Colors.grey.shade300),
      onSelected: (_) => setState(() => selectedFilter = key),
    );
  }

  Widget _statMetric(String label, String value, String subtext, Color accent) {
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: accent,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtext,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHotspotInspector(CarbonHotspot spot) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cream,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: spot.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(spot.icon, color: spot.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          spot.category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: spot.color,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            spot.status,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spot.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ink),
                    ),
                    Text(
                      'GPS Coordinates: ${spot.coordinatesLabel}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Monthly Output', style: TextStyle(fontSize: 11, color: Colors.black54)),
                      const SizedBox(height: 2),
                      Text(
                        '${spot.monthlyTonnesCo2e.toStringAsFixed(1)} tonnes CO₂e',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: spot.color),
                      ),
                      Text('${spot.percentageOfTotal.toStringAsFixed(1)}% of campus total', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Primary Carbon Driver', style: TextStyle(fontSize: 11, color: Colors.black54)),
                      const SizedBox(height: 2),
                      Text(
                        spot.primaryDriver,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ink),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: forest.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: forest.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: forest, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'High-Impact Intervention: ${spot.actionPlan}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: forest),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInspector(CorridorRoute route) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cream,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: route.color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  route.code,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  route.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ink),
                ),
              ),
              Text(
                '${route.monthlyTonnesCo2e.toStringAsFixed(1)} tonnes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: route.color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Modal Profile: ${route.modalShareDescription}',
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _metricChip('Distance', '${route.distanceKm.toStringAsFixed(1)} km'),
              const SizedBox(width: 8),
              _metricChip('Monthly Trips', '${route.monthlyTrips}'),
              const SizedBox(width: 8),
              _metricChip('Intensity', '${route.intensityGramPerPkm.toStringAsFixed(0)} g/p-km'),
              const SizedBox(width: 8),
              _metricChip('Target Savings', '-${route.potentialSavingsTonnes.toStringAsFixed(1)} t', accentColor: const Color(0xFF2E7D32)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Recommended Action: ${route.recommendation}',
            style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: forest),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String value, {Color? accentColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: accentColor ?? ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _corridorCard(CorridorRoute route) {
    final bool isSelected = selectedRoute?.id == route.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isSelected ? forest : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              selectedRoute = route;
              selectedHotspot = null;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: route.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(Icons.route_outlined, color: route.color),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: route.color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              route.code,
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              route.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ink),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${route.distanceKm} km · ${route.monthlyTrips} trips · ${route.modalShareDescription}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${route.monthlyTonnesCo2e.toStringAsFixed(1)} t',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: route.color),
                    ),
                    Text(
                      'Savings: -${route.potentialSavingsTonnes.toStringAsFixed(1)}t',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hotspotCard(CarbonHotspot spot) {
    final bool isSelected = selectedHotspot?.id == spot.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isSelected ? forest : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              selectedHotspot = spot;
              selectedRoute = null;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: spot.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(spot.icon, color: spot.color),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${spot.category} · ${spot.primaryDriver}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${spot.monthlyTonnesCo2e.toStringAsFixed(1)} t',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: spot.color),
                    ),
                    Text(
                      '${spot.percentageOfTotal.toStringAsFixed(1)}% of total',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom Vector Canvas Painter rendering routes, terrain context and hotspot pulses.
class _CarbonMapPainter extends CustomPainter {
  _CarbonMapPainter({
    required this.corridors,
    required this.hotspots,
    this.selectedRouteId,
    this.selectedHotspotId,
  });

  final List<CorridorRoute> corridors;
  final List<CarbonHotspot> hotspots;
  final String? selectedRouteId;
  final String? selectedHotspotId;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 1. Draw subtle background terrain lines & lake outline
    final terrainPaint = Paint()
      ..color = const Color(0xFFDCE6D7)
      ..style = PaintingStyle.fill;

    // Water representation (Lake Washington curve)
    final waterPath = Path();
    waterPath.moveTo(w * 0.65, 0);
    waterPath.quadraticBezierTo(w * 0.60, h * 0.5, w * 0.72, h);
    waterPath.lineTo(w, h);
    waterPath.lineTo(w, 0);
    waterPath.close();
    canvas.drawPath(
      waterPath,
      Paint()..color = const Color(0xFFD2DFDB),
    );

    // Water label
    const textStyle = TextStyle(
      color: Color(0xFF869E96),
      fontSize: 11,
      fontWeight: FontWeight.bold,
      letterSpacing: 2,
    );
    final textPainter = TextPainter(
      text: const TextSpan(text: 'LAKE WASHINGTON', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(w * 0.75, h * 0.35));

    // Subtle coordinate grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1.0;
    for (double x = 40; x < w; x += 70) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = 40; y < h; y += 70) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Campus boundary polygon
    final campusPath = Path();
    campusPath.moveTo(w * 0.36, h * 0.28);
    campusPath.lineTo(w * 0.65, h * 0.30);
    campusPath.lineTo(w * 0.62, h * 0.72);
    campusPath.lineTo(w * 0.35, h * 0.68);
    campusPath.close();
    canvas.drawPath(campusPath, terrainPaint);

    final campusBorder = Paint()
      ..color = const Color(0xFFB5C9AF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(campusPath, campusBorder);

    // 2. Draw Corridor Routes
    for (final corridor in corridors) {
      if (corridor.pathPoints.length < 2) continue;
      final bool isSelected = corridor.id == selectedRouteId;

      final path = Path();
      final p0 = Offset(corridor.pathPoints[0].dx * w, corridor.pathPoints[0].dy * h);
      path.moveTo(p0.dx, p0.dy);

      for (int i = 1; i < corridor.pathPoints.length; i++) {
        final p = Offset(corridor.pathPoints[i].dx * w, corridor.pathPoints[i].dy * h);
        path.lineTo(p.dx, p.dy);
      }

      // Outer glow for high-carbon or selected route
      if (isSelected || corridor.severity == 'high') {
        final glowPaint = Paint()
          ..color = corridor.color.withValues(alpha: isSelected ? 0.35 : 0.18)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = isSelected ? 16.0 : 10.0;
        canvas.drawPath(path, glowPaint);
      }

      // Main corridor polyline
      final routePaint = Paint()
        ..color = corridor.color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = isSelected ? 6.0 : (corridor.severity == 'high' ? 4.5 : 3.0);
      canvas.drawPath(path, routePaint);
    }

    // 3. Draw Hotspot pulse halos
    for (final hotspot in hotspots) {
      final double x = hotspot.mapPosition.dx * w;
      final double y = hotspot.mapPosition.dy * h;
      final bool isSelected = hotspot.id == selectedHotspotId;

      // Pulse halo
      final haloPaint = Paint()
        ..color = hotspot.color.withValues(alpha: isSelected ? 0.35 : 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), isSelected ? 26.0 : 18.0, haloPaint);

      // Core anchor dot
      final corePaint = Paint()
        ..color = hotspot.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 5.0, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CarbonMapPainter oldDelegate) {
    return oldDelegate.selectedRouteId != selectedRouteId ||
        oldDelegate.selectedHotspotId != selectedHotspotId ||
        oldDelegate.corridors != corridors ||
        oldDelegate.hotspots != hotspots;
  }
}
