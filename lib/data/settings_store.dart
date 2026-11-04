// Overview: Persists user settings (onboarding complete, vehicle type, occupancy, region) in shared preferences.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/regional_factors.dart';

/// User-configurable settings that affect emission calculations and app experience.
class UserSettings {
  const UserSettings({
    this.onboarded = false,
    this.vehicleType = 'gasoline',
    this.occupancy = 1,
    this.regionId = 'us',
  });

  final bool onboarded;
  final String vehicleType; // gasoline, hybrid, ev, diesel
  final int occupancy; // 1–5 occupants for car trips
  final String regionId; // regional electricity factor id

  UserSettings copyWith({
    bool? onboarded,
    String? vehicleType,
    int? occupancy,
    String? regionId,
  }) =>
      UserSettings(
        onboarded: onboarded ?? this.onboarded,
        vehicleType: vehicleType ?? this.vehicleType,
        occupancy: occupancy ?? this.occupancy,
        regionId: regionId ?? this.regionId,
      );

  RegionalFactor get region => RegionalFactor.byId(regionId);

  Map<String, dynamic> toJson() => {
    'onboarded': onboarded,
    'vehicleType': vehicleType,
    'occupancy': occupancy,
    'regionId': regionId,
  };

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
    onboarded: json['onboarded'] as bool? ?? false,
    vehicleType: json['vehicleType'] as String? ?? 'gasoline',
    occupancy: (json['occupancy'] as num?)?.toInt() ?? 1,
    regionId: json['regionId'] as String? ?? 'us',
  );
}

class SettingsStore {
  SettingsStore(this.preferences);
  final SharedPreferences preferences;
  static const key = 'verdi.settings.v1';

  UserSettings load() {
    final raw = preferences.getString(key);
    if (raw == null) return const UserSettings();
    try {
      return UserSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const UserSettings();
    }
  }

  Future<void> save(UserSettings settings) async {
    final ok = await preferences.setString(key, jsonEncode(settings.toJson()));
    if (!ok) throw StateError('Could not save settings.');
  }
}

/// Vehicle type options shown in settings and onboarding.
class VehicleTypeOption {
  const VehicleTypeOption(this.id, this.label, this.description);
  final String id, label, description;

  static const all = [
    VehicleTypeOption('gasoline', 'Gasoline car', 'Average passenger car, EPA 2025 factor'),
    VehicleTypeOption('hybrid', 'Hybrid car', 'Uses EPA passenger car factor (average includes hybrids)'),
    VehicleTypeOption('ev', 'Electric vehicle', 'EV — emissions depend on your electricity region'),
    VehicleTypeOption('diesel', 'Diesel car', 'Uses EPA passenger car factor as proxy'),
  ];

  static VehicleTypeOption byId(String id) =>
      all.firstWhere((v) => v.id == id, orElse: () => all.first);
}
