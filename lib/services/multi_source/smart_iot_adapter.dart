// Overview: Adapter simulating smart home IoT devices (e.g. EV chargers, smart plugs, heat pump monitors).
import '../../domain/automation.dart';
import '../../domain/carbon.dart';
import '../../domain/data_source.dart';
import 'multi_source_adapter.dart';

/// Simulates smart home IoT devices such as Level-2 EV chargers, smart sub-meters, and smart plugs.
class SmartIotAdapter implements MultiSourceAdapter {
  SmartIotAdapter({
    this.deviceModel = 'ChargePoint Home Flex (WiFi)',
    this.deviceId = 'IOT-EV-CHG-9021',
    List<ActivityCandidate>? simulatedSessions,
  }) : _sessions = simulatedSessions;

  final String deviceModel;
  final String deviceId;
  final List<ActivityCandidate>? _sessions;

  @override
  String get sourceId => 'smart-iot';

  @override
  String get displayName => 'Smart Home & IoT Devices';

  @override
  String get sourceType => 'smart_iot';

  @override
  TrackingFront get front => TrackingFront.home;

  @override
  String get description =>
      'Device-level telemetry from connected EV chargers, heat pumps, and energy sub-meters.';

  @override
  bool get isConnected => true;

  @override
  double get baseFidelity => 0.92; // Hardware current-transformer / CT clamp accuracy

  @override
  Future<List<ActivityCandidate>> fetchCandidates({DateTime? since}) async {
    if (_sessions != null) {
      if (since == null) return List.unmodifiable(_sessions);
      return _sessions.where((s) => s.start.isAfter(since)).toList();
    }

    final now = DateTime.now();
    final results = <ActivityCandidate>[];

    final sessions = [
      (
        1,
        22,
        0,
        2,
        30,
        28.5,
        'EV Overnight Charge Session: 28.5 kWh at 9.6 kW (ChargePoint Home Flex)',
        'ev_charger',
        'ChargePoint Home Flex',
      ),
      (
        2,
        13,
        0,
        15,
        0,
        8.2,
        'Smart Heat Pump Water Heater cycle: 8.2 kWh (EcoBee EcoNet)',
        'heat_pump',
        'EcoBee EcoNet Monitor',
      ),
      (
        4,
        23,
        15,
        3,
        45,
        32.1,
        'EV Overnight Charge Session: 32.1 kWh at 9.6 kW (ChargePoint Home Flex)',
        'ev_charger',
        'ChargePoint Home Flex',
      ),
      (
        6,
        14,
        0,
        18,
        30,
        5.4,
        'Induction Range & Kitchen Sub-meter: 5.4 kWh (Emporia Vue Gen 2)',
        'sub_meter',
        'Emporia Vue Sub-meter',
      ),
    ];

    for (final (dayOffset, startHour, startMin, endHour, endMin, kwh, sessionNote, category, model) in sessions) {
      final start = DateTime(now.year, now.month, now.day - dayOffset, startHour, startMin);
      // For sessions going past midnight, add day offset accordingly
      final isNextDay = endHour < startHour;
      final end = DateTime(
        now.year,
        now.month,
        now.day - dayOffset + (isNextDay ? 1 : 0),
        endHour,
        endMin,
      );
      if (since != null && !start.isAfter(since)) continue;

      final id = 'smart-iot:$deviceId:${start.microsecondsSinceEpoch}';
      results.add(
        ActivityCandidate(
          id: id,
          source: 'smart-iot',
          start: start,
          end: end,
          quantity: kwh,
          kind: ActivityKind.electricity,
          confidence: baseFidelity,
          description: '$model · $sessionNote',
          metadata: {
            'sourceType': sourceType,
            'deviceId': deviceId,
            'deviceModel': model,
            'deviceCategory': category,
            'measuredKwh': kwh,
            'currentSensorAccuracy': 'CT_clamp_class_1',
          },
        ),
      );
    }

    return results;
  }
}
