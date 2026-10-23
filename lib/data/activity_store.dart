import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/carbon.dart';

class ActivityStore {
  ActivityStore(this.preferences);
  final SharedPreferences preferences;
  static const key = 'verdi.activities.v1';
  List<Activity> load() {
    final raw = preferences.getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map(
          (item) => Activity.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> save(List<Activity> activities) async {
    final saved = await preferences.setString(
      key,
      jsonEncode(activities.map((a) => a.toJson()).toList()),
    );
    if (!saved) throw StateError('Could not save activities.');
  }
}
