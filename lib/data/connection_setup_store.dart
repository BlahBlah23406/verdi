// Overview: Remembers which connection routes the user chose or deferred; never stores credentials or live-link state.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum ConnectionChoice { planned, deferred }

class ConnectionSetupStore {
  ConnectionSetupStore(this.preferences);
  final SharedPreferences preferences;
  static const key = 'verdi.connection-setup.v1';

  /// Connection id to the user's last choice. Unknown values are ignored so a
  /// newer app version's data cannot break an older one.
  Map<String, ConnectionChoice> load() {
    final raw = preferences.getString(key);
    if (raw == null) return {};
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return {
        for (final e in decoded.entries)
          for (final c in ConnectionChoice.values)
            if (c.name == e.value) e.key: c,
      };
    } catch (_) {
      throw const FormatException(
        'Saved connection choices are unreadable; they have not been overwritten.',
      );
    }
  }

  /// Passing null clears the choice.
  Future<void> set(String id, ConnectionChoice? choice) async {
    final next = load();
    if (choice == null) {
      next.remove(id);
    } else {
      next[id] = choice;
    }
    final ok = await preferences.setString(
      key,
      jsonEncode({for (final e in next.entries) e.key: e.value.name}),
    );
    if (!ok) throw StateError('Connection choice could not be saved.');
  }
}
