// Overview: Defines regional US electricity emission factors from EPA eGRID 2023 subregion data.
import 'emission_factors.dart';

/// Regional electricity emission factors derived from EPA eGRID 2023 subregion data.
/// Each factor represents generation-only CO₂e per kWh for the named region.
/// Source: EPA eGRID 2023 (data year 2023), published January 2025.
/// Values converted from lb CO₂e/MWh to kg CO₂e/kWh using 0.45359237 kg/lb.
class RegionalFactor {
  const RegionalFactor(this.id, this.label, this.kgCo2ePerKwh, this.subregions);
  final String id, label;
  final double kgCo2ePerKwh;
  final String subregions;

  static const version = 'us-epa-egrid-2023-v1';
  static const sourceUrl =
      'https://www.epa.gov/system/files/documents/2025-01/ghg-emission-factors-hub-2025.pdf';

  /// Pacific Northwest: NWPP subregion — hydro-heavy, lower carbon intensity.
  static const pacificNorthwest = RegionalFactor(
    'pnw',
    'Pacific Northwest',
    (372.7 + 0.031 * 28 + 0.004 * 265) * 0.45359237 / 1000,
    'eGRID NWPP (Northwest Power Pool)',
  );

  /// California: CAMX subregion — mix of natural gas, solar, wind, hydro.
  static const california = RegionalFactor(
    'ca',
    'California',
    (435.5 + 0.025 * 28 + 0.003 * 265) * 0.45359237 / 1000,
    'eGRID CAMX (California-Mexico Power Pool)',
  );

  /// Texas: ERCT subregion — natural gas and wind dominant.
  static const texas = RegionalFactor(
    'tx',
    'Texas',
    (842.6 + 0.042 * 28 + 0.006 * 265) * 0.45359237 / 1000,
    'eGRID ERCT (ERCOT region)',
  );

  /// Northeast: multiple subregions combined — RFCE, RFCY, NPCC.
  static const northeast = RegionalFactor(
    'ne',
    'Northeast',
    (651.8 + 0.048 * 28 + 0.007 * 265) * 0.45359237 / 1000,
    'eGRID RFCE + RFCY + NPCC (Northeast)',
  );

  /// US national average — fallback when no region selected.
  static final nationalAverage = RegionalFactor(
    'us',
    'US average',
    EmissionFactor.electricity.kgCo2ePerUnit,
    'eGRID 2023 national average',
  );

  static List<RegionalFactor> all = [
    nationalAverage,
    pacificNorthwest,
    california,
    texas,
    northeast,
  ];

  static RegionalFactor byId(String id) =>
      all.firstWhere((r) => r.id == id, orElse: () => nationalAverage);

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'kgCo2ePerKwh': kgCo2ePerKwh,
    'version': version,
    'subregions': subregions,
    'sourceUrl': sourceUrl,
  };
}
