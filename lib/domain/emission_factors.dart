// Overview: Defines the versioned EPA emission factors, unit conversions, and source metadata.
/// Pinned EPA 2025 dataset; see docs/ALGORITHM.md for boundaries.
class EmissionFactor {
  const EmissionFactor(
    this.id,
    this.kgCo2ePerUnit,
    this.sourceTable,
    this.scope,
  );
  final String id, sourceTable, scope;
  final double kgCo2ePerUnit;
  static const version = 'us-epa-2025-v1';
  static const sourceUrl =
      'https://www.epa.gov/system/files/documents/2025-01/ghg-emission-factors-hub-2025.pdf';
  static const geography = 'US national average';
  static const publicationDate = '2025-01-15';
  static const retrievedDate = '2026-10-23';
  // Table 10: kg CO2/mile + g CH4/mile + g N2O/mile.
  // AR5 100-year GWPs: CH4=28, N2O=265 (Table 11). 1 mile=1.609344 km.
  static const car = EmissionFactor(
    'passenger-car',
    (0.297 + 0.0059 * 28 / 1000 + 0.0053 * 265 / 1000) / 1.609344,
    '10, 11',
    'Operational travel; average passenger car, one occupant; excludes upstream fuel and manufacturing.',
  );
  static const bus = EmissionFactor(
    'bus',
    (0.066 + 0.0046 * 28 / 1000 + 0.0019 * 265 / 1000) / 1.609344,
    '10, 11',
    'Operational travel per passenger; average occupancy embedded in factor.',
  );
  static const train = EmissionFactor(
    'commuter-rail',
    (0.133 + 0.0105 * 28 / 1000 + 0.0026 * 265 / 1000) / 1.609344,
    '10, 11',
    'Commuter rail per passenger; not subway or intercity rail.',
  );
  static const electricity = EmissionFactor(
    'electricity-us-average',
    (771.5 + 0.057 * 28 + 0.008 * 265) * 0.45359237 / 1000,
    '6, 11',
    'Generation emissions, eGRID 2023 national fallback; excludes transmission losses and upstream lifecycle.',
  );
  static const bicycle = EmissionFactor(
    'bicycle-operational',
    0,
    'Verdi boundary assumption',
    'Unassisted bicycle: no operational fuel/electricity emissions; excludes food and manufacturing.',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'kgCo2ePerUnit': kgCo2ePerUnit,
    'sourceUrl': id == 'bicycle-operational' ? null : sourceUrl,
    'sourceTable': sourceTable,
    'geography': geography,
    'publicationDate': id == 'bicycle-operational' ? null : publicationDate,
    'retrievedDate': retrievedDate,
    'scope': scope,
    'uncertainty':
        'Not quantified; average factors are not individual measurements.',
  };
}
