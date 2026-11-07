// Overview: Adapter simulating a transit agency smartcard / contactless tap-in tap-out API.
import '../../domain/automation.dart';
import '../../domain/carbon.dart';
import '../../domain/data_source.dart';
import 'multi_source_adapter.dart';

/// Simulates a Regional Transit Agency contactless smartcard / GTFS-RT tap-in tap-out API.
class TransportApiAdapter implements MultiSourceAdapter {
  TransportApiAdapter({
    this.agencyName = 'Cascadia Regional Transit (ORCA/TapGo)',
    this.smartcardId = 'TAP-CARD-44091',
    List<ActivityCandidate>? simulatedTrips,
  }) : _trips = simulatedTrips;

  final String agencyName;
  final String smartcardId;
  final List<ActivityCandidate>? _trips;

  @override
  String get sourceId => 'transport-api';

  @override
  String get displayName => 'Public Transit Agency API';

  @override
  String get sourceType => 'transport_api';

  @override
  TrackingFront get front => TrackingFront.travel;

  @override
  String get description =>
      'Automated tap-in/tap-out transit journeys and distance verification from $agencyName.';

  @override
  bool get isConnected => true;

  @override
  double get baseFidelity => 0.95; // Turnstile/faregate verified origin-destination mileage

  @override
  Future<List<ActivityCandidate>> fetchCandidates({DateTime? since}) async {
    if (_trips != null) {
      if (since == null) return List.unmodifiable(_trips);
      return _trips.where((t) => t.start.isAfter(since)).toList();
    }

    final now = DateTime.now();
    final results = <ActivityCandidate>[];

    // Simulated tap-in tap-out commuter rail & bus trips
    final tripConfigs = [
      (
        1,
        8,
        15,
        8,
        42,
        ActivityKind.train,
        14.2,
        'Line 1 Commuter Rail: Pioneer Square -> University District',
        'Pioneer Square',
        'University District',
      ),
      (
        1,
        17,
        10,
        17,
        38,
        ActivityKind.train,
        14.2,
        'Line 1 Commuter Rail: University District -> Pioneer Square',
        'University District',
        'Pioneer Square',
      ),
      (
        2,
        9,
        0,
        9,
        22,
        ActivityKind.bus,
        6.5,
        'RapidRide E Line Express Bus: Fremont -> Downtown Hub',
        'Fremont Ave N',
        '3rd & Pike',
      ),
      (
        3,
        8,
        20,
        8,
        48,
        ActivityKind.train,
        14.2,
        'Line 1 Commuter Rail: Pioneer Square -> University District',
        'Pioneer Square',
        'University District',
      ),
      (
        4,
        18,
        0,
        18,
        25,
        ActivityKind.bus,
        7.1,
        'RapidRide C Line Bus: West Seattle -> Downtown Transit Tunnel',
        'Alaska Junction',
        'University St Station',
      ),
    ];

    for (final (dayOffset, startHour, startMin, endHour, endMin, kind, km, routeDesc, boardStop, exitStop) in tripConfigs) {
      final start = DateTime(now.year, now.month, now.day - dayOffset, startHour, startMin);
      final end = DateTime(now.year, now.month, now.day - dayOffset, endHour, endMin);
      if (since != null && !start.isAfter(since)) continue;

      final id = 'transport-api:$smartcardId:${start.microsecondsSinceEpoch}';
      results.add(
        ActivityCandidate(
          id: id,
          source: 'transport-api',
          start: start,
          end: end,
          quantity: km,
          kind: kind,
          confidence: baseFidelity,
          description: '$agencyName · $routeDesc',
          metadata: {
            'sourceType': sourceType,
            'agency': agencyName,
            'cardId': smartcardId,
            'mode': kind.name,
            'boardStop': boardStop,
            'exitStop': exitStop,
            'verifiedTrackDistanceKm': km,
            'fareTransactionId': 'TX-${start.millisecondsSinceEpoch % 100000}',
          },
        ),
      );
    }

    return results;
  }
}
