import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:verdi/domain/automation.dart';
import 'package:verdi/product/pilot_phone_capture.dart';
import 'package:verdi/services/phone_tracking.dart';

class TestTracking extends PhoneTracking {
  final requests = <bool>[];
  late StreamController<LocationSample> stream;

  @override
  Stream<LocationSample> samples({bool requestPermission = true}) {
    requests.add(requestPermission);
    stream = StreamController<LocationSample>.broadcast(sync: true);
    return stream.stream;
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'opt-in persists, stops offscreen and resumes without prompting',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final tracking = TestTracking();
      final capture = PilotPhoneCapture(prefs, 'pilot-a', tracking: tracking);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      addTearDown(
        () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
      );
      await capture.setConsent(true);
      expect(tracking.requests, isEmpty);
      await capture.setEnabled(true);
      expect(tracking.requests, [true]);
      await capture.setConsent(true);
      expect(tracking.requests, [true]);

      final start = DateTime(2026, 11, 25, 9);
      tracking.stream
        ..add(LocationSample(47.67, -122.12, 5, start))
        ..add(
          LocationSample(
            47.68,
            -122.12,
            5,
            start.add(const Duration(seconds: 75)),
          ),
        );
      await Future<void>.delayed(Duration.zero);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await Future<void>.delayed(Duration.zero);
      expect(capture.listening, isFalse);
      expect(capture.pending.single.quantity, closeTo(1.112, 0.001));
      final stored = prefs.getString('verdi.pilot.phone.v1.pilot-a')!;
      expect(stored, isNot(contains('47.68')));

      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(tracking.requests, [true, false]);
      capture.dispose();

      final reloaded = PilotPhoneCapture(prefs, 'pilot-a', tracking: tracking);
      final anotherAccount = PilotPhoneCapture(
        prefs,
        'pilot-b',
        tracking: tracking,
      );
      addTearDown(reloaded.dispose);
      addTearDown(anotherAccount.dispose);
      expect(anotherAccount.enabled, isFalse);
      expect(anotherAccount.pending, isEmpty);
      expect(reloaded.pending, hasLength(1));
      await reloaded.setConsent(true);
      expect(tracking.requests, [true, false, false]);
      await reloaded.setConsent(false);
      expect(reloaded.listening, isFalse);
      expect(reloaded.pending, hasLength(1));
      await reloaded.setEnabled(false);
      await reloaded.remove(reloaded.pending.single.id);
      await reloaded.setConsent(true);
      expect(reloaded.listening, isFalse);
      expect(reloaded.pending, isEmpty);
    },
  );

  test('denial stays visible without prompting again on resume', () async {
    SharedPreferences.setMockInitialValues({});
    final tracking = TestTracking();
    final capture = PilotPhoneCapture(
      await SharedPreferences.getInstance(),
      'pilot',
      tracking: tracking,
    );
    addTearDown(capture.dispose);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await capture.setConsent(true);
    await capture.setEnabled(true);
    tracking.stream.addError(
      PlatformException(code: 'permission', message: 'Location denied'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(capture.error, 'Location denied');
    expect(capture.listening, isFalse);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await Future<void>.delayed(Duration.zero);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(tracking.requests, [true, false]);
    await capture.setEnabled(false);
    expect(capture.listening, isFalse);
  });
}
