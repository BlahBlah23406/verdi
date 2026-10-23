import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/automation.dart';

class AutomationState {
  const AutomationState(this.pending, this.dismissed);
  final List<ActivityCandidate> pending;
  final Set<String> dismissed;
}

class AutomationStore {
  AutomationStore(this.preferences);
  final SharedPreferences preferences;
  static const key = 'verdi.automation.v1';
  AutomationState load() {
    final raw = preferences.getString(key);
    if (raw == null) return const AutomationState([], {});
    final data = jsonDecode(raw) as Map;
    return AutomationState(
      (data['pending'] as List)
          .map(
            (e) =>
                ActivityCandidate.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      (data['dismissed'] as List).cast<String>().toSet(),
    );
  }

  Future<void> save(AutomationState state) async {
    if (!await preferences.setString(
      key,
      jsonEncode({
        'pending': state.pending.map((c) => c.toJson()).toList(),
        'dismissed': state.dismissed.toList(),
      }),
    )) {
      throw StateError('Could not save review queue.');
    }
  }
}
