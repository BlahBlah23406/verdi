// Overview: Adapter simulating an electric/gas utility REST API (e.g. Green Button Connect).
import '../../domain/automation.dart';
import '../../domain/carbon.dart';
import '../../domain/data_source.dart';
import 'multi_source_adapter.dart';

/// Simulates a Smart Meter / Energy Utility REST API (e.g. Green Button Connect).
class UtilityApiAdapter implements MultiSourceAdapter {
  UtilityApiAdapter({
    this.providerName = 'Pacific Grid & Electric (Green Button)',
    this.meterId = 'PGE-SMART-98421',
    this.accountNumber = 'ACC-8841-01',
    List<ActivityCandidate>? simulatedReadings,
  }) : _readings = simulatedReadings;

  final String providerName;
  final String meterId;
  final String accountNumber;
  final List<ActivityCandidate>? _readings;

  @override
  String get sourceId => 'utility-api';

  @override
  String get displayName => 'Utility Provider API';

  @override
  String get sourceType => 'utility_api';

  @override
  TrackingFront get front => TrackingFront.home;

  @override
  String get description =>
      'Automated daily Green Button smart-meter electricity feeds from $providerName.';

  @override
  bool get isConnected => true;

  @override
  double get baseFidelity => 0.98; // Revenue-grade certified hardware meter

  @override
  Future<List<ActivityCandidate>> fetchCandidates({DateTime? since}) async {
    if (_readings != null) {
      if (since == null) return List.unmodifiable(_readings);
      return _readings.where((r) => r.start.isAfter(since)).toList();
    }

    final now = DateTime.now();
    // Generate realistic daily smart meter readings for the past several days
    final results = <ActivityCandidate>[];
    final days = [
      (1, 14.8, 'Daily interval: off-peak baseline + evening lighting'),
      (2, 19.2, 'Daily interval: laundry + heat pump heating'),
      (3, 16.4, 'Daily interval: standard weekday residential consumption'),
      (5, 21.0, 'Daily interval: weekend cooking and appliances'),
      (7, 15.5, 'Daily interval: residential base load'),
    ];

    for (final (dayOffset, kwh, note) in days) {
      final date = DateTime(now.year, now.month, now.day - dayOffset);
      final endDate = DateTime(now.year, now.month, now.day - dayOffset + 1);
      if (since != null && !date.isAfter(since)) continue;

      final id = 'utility-api:$meterId:${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
      results.add(
        ActivityCandidate(
          id: id,
          source: 'utility-api',
          start: date,
          end: endDate,
          quantity: kwh,
          kind: ActivityKind.electricity,
          confidence: baseFidelity,
          description: '$providerName · Meter $meterId · $note',
          metadata: {
            'sourceType': sourceType,
            'provider': providerName,
            'meterId': meterId,
            'accountNumber': accountNumber,
            'rateTier': 'Time-of-Use Residential (TOU-D)',
            'meterAccuracy': 'revenue_grade_99.5%',
            'intervalKwh': kwh,
          },
        ),
      );
    }

    return results;
  }
}
