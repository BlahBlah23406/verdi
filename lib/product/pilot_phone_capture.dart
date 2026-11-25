import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/automation.dart';
import '../services/phone_tracking.dart';

/// Account-scoped foreground capture. Only derived summaries are stored.
class PilotPhoneCapture extends ChangeNotifier with WidgetsBindingObserver {
  PilotPhoneCapture(
    this.preferences,
    String scope, {
    this.tracking = const PhoneTracking(),
  }) : _key = 'verdi.pilot.phone.v1.$scope' {
    try {
      final saved = preferences.getString(_key);
      if (saved != null) {
        final json = jsonDecode(saved) as Map<String, dynamic>;
        _enabled = json['enabled'] as bool;
        _pending = (json['pending'] as List)
            .map(
              (row) => ActivityCandidate.fromJson(row as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (_) {
      storageError = 'Saved phone setup could not be read.';
    }
    WidgetsBinding.instance.addObserver(this);
  }

  final SharedPreferences preferences;
  final String _key;
  final PhoneTracking tracking;
  final _detector = TripDetector();
  StreamSubscription<LocationSample>? _subscription;
  Future<void> _queue = Future.value();
  bool _enabled = false, _consented = false, _disposed = false;
  List<ActivityCandidate> _pending = [];
  String? error, storageError;
  bool get enabled => _enabled;
  bool get listening => _subscription != null;
  List<ActivityCandidate> get pending => List.unmodifiable(_pending);

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _queue.then((_) async {
      if (!_disposed) await operation();
    });
    _queue = result.catchError((Object _) {});
    return result;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _save() async {
    try {
      if (!await preferences.setString(
        _key,
        jsonEncode({'enabled': _enabled, 'pending': _pending}),
      )) {
        throw StateError('Could not save phone setup.');
      }
      storageError = null;
    } catch (_) {
      storageError = 'Could not save changes on this phone. Try again.';
      _changed();
      rethrow;
    }
  }

  Future<void> setConsent(bool value) => _serialize(() async {
    _consented = value;
    if (value) {
      _start();
    } else {
      await _stop();
    }
  });

  Future<void> setEnabled(bool value) => _serialize(() async {
    if (storageError == 'Saved phone setup could not be read.') return;
    _enabled = value;
    try {
      if (!value) await _stop();
      await _save();
      if (value) _start(requestPermission: true);
    } finally {
      _changed();
    }
  });

  void _start({bool requestPermission = false}) {
    if (!_enabled ||
        !_consented ||
        _disposed ||
        storageError != null ||
        listening ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    error = null;
    _subscription = tracking
        .samples(requestPermission: requestPermission)
        .listen(
          (sample) => _run(() async {
            if (listening) await _keep(_detector.add(sample));
          }),
          onError: (Object issue) => _run(() async {
            if (!listening) return;
            if (issue is! PlatformException || issue.code != 'paused') {
              error = issue is PlatformException
                  ? issue.message ?? 'Location is unavailable.'
                  : 'Location is unavailable.';
            }
            await _stop();
          }),
          onDone: () => _run(_stop),
        );
    _changed();
  }

  Future<void> _stop() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    await _keep(_detector.finish());
    _changed();
  }

  Future<void> _keep(ActivityCandidate? candidate) async {
    if (candidate == null) return;
    _pending.add(candidate);
    await _save();
    _changed();
  }

  Future<void> remove(String id) => _serialize(() async {
    final previous = _pending;
    _pending = _pending.where((item) => item.id != id).toList();
    try {
      await _save();
    } catch (_) {
      _pending = previous;
      rethrow;
    }
    _changed();
  });

  void _run(Future<void> Function() operation) =>
      unawaited(_serialize(operation).catchError((Object _) {}));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _run(() async => _start());
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _run(_stop);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
