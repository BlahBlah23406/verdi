import 'package:flutter/services.dart';

import '../domain/automation.dart';

class PhoneTracking {
  static const channel = EventChannel('verdi/phone_location');
  Stream<LocationSample> samples() => channel.receiveBroadcastStream().map((
    event,
  ) {
    final map = Map<String, dynamic>.from(event as Map);
    return LocationSample(
      (map['latitude'] as num).toDouble(),
      (map['longitude'] as num).toDouble(),
      (map['accuracy'] as num).toDouble(),
      DateTime.fromMillisecondsSinceEpoch((map['timestamp'] as num).toInt()),
    );
  });
}
