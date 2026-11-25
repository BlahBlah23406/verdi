// Overview: Converts native location events into typed Dart location samples.
import 'package:flutter/services.dart';

import '../domain/automation.dart';

class PhoneTracking {
  const PhoneTracking();

  static const channel = EventChannel('verdi/phone_location');
  Stream<LocationSample> samples({bool requestPermission = true}) =>
      channel.receiveBroadcastStream(requestPermission).map((event) {
        final map = Map<String, dynamic>.from(event as Map);
        return LocationSample(
          (map['latitude'] as num).toDouble(),
          (map['longitude'] as num).toDouble(),
          (map['accuracy'] as num).toDouble(),
          DateTime.fromMillisecondsSinceEpoch(
            (map['timestamp'] as num).toInt(),
          ),
        );
      });
}
