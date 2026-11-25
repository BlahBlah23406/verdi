// Experimental evidence reconciliation; intentionally separate from app totals.
// An adapter/reviewer must establish coverageKey; this is not an entity matcher.
enum FootprintSector {
  electricity,
  heating,
  travel,
  food,
  goods,
  services,
  water,
  waste,
}

enum EvidenceQuality {
  spendEstimate,
  modelEstimate,
  confirmedQuantity,
  measuredQuantity,
}

/// A versioned factor selected explicitly by the caller, not by an AI model.
/// Unit includes denominator basis, e.g. passenger-km, vehicle-km or USD-2022.
class FootprintFactor {
  FootprintFactor({
    required this.id,
    required this.version,
    required this.sector,
    required this.unit,
    required this.boundary,
    required this.geography,
    required this.dataYear,
    required this.sourceUrl,
    required this.gwpVersion,
    required this.accountingMethod,
    required this.kgCo2ePerUnit,
  }) {
    if ([
          id,
          version,
          unit,
          boundary,
          geography,
          gwpVersion,
          accountingMethod,
        ].any((s) => s.trim().isEmpty) ||
        dataYear < 1900 ||
        dataYear > 2200 ||
        !kgCo2ePerUnit.isFinite ||
        kgCo2ePerUnit < 0 ||
        !['https', 'http'].contains(Uri.tryParse(sourceUrl)?.scheme) ||
        (Uri.tryParse(sourceUrl)?.host.isEmpty ?? true)) {
      throw ArgumentError(
        'A factor needs units, boundary and source provenance.',
      );
    }
  }
  final String id, version, unit, boundary, geography, sourceUrl;
  final String gwpVersion, accountingMethod;
  final int dataYear;
  final FootprintSector sector;
  final double kgCo2ePerUnit;

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'sector': sector.name,
    'unit': unit,
    'boundary': boundary,
    'geography': geography,
    'dataYear': dataYear,
    'sourceUrl': sourceUrl,
    'gwpVersion': gwpVersion,
    'accountingMethod': accountingMethod,
    'kgCo2ePerUnit': kgCo2ePerUnit,
  };
  factory FootprintFactor.fromJson(Map<String, dynamic> j) => FootprintFactor(
    id: j['id'] as String,
    version: j['version'] as String,
    sector: FootprintSector.values.byName(j['sector'] as String),
    unit: j['unit'] as String,
    boundary: j['boundary'] as String,
    geography: j['geography'] as String,
    dataYear: j['dataYear'] as int,
    sourceUrl: j['sourceUrl'] as String,
    gwpVersion: j['gwpVersion'] as String,
    accountingMethod: j['accountingMethod'] as String,
    kgCo2ePerUnit: (j['kgCo2ePerUnit'] as num).toDouble(),
  );

  bool sameValue(FootprintFactor other) =>
      id == other.id &&
      version == other.version &&
      unit == other.unit &&
      sector == other.sector &&
      boundary == other.boundary &&
      kgCo2ePerUnit == other.kgCo2ePerUnit &&
      geography == other.geography &&
      dataYear == other.dataYear &&
      sourceUrl == other.sourceUrl &&
      gwpVersion == other.gwpVersion &&
      accountingMethod == other.accountingMethod;
}

class FootprintEvidence {
  FootprintEvidence({
    required this.id,
    required this.source,
    required this.coverageKey,
    required this.sector,
    required this.start,
    required this.end,
    required this.boundary,
    required this.unit,
    required this.quantity,
    required this.quality,
    required this.reviewed,
    this.factor,
    this.personalShare = 1,
  }) {
    if ([
          id,
          source,
          coverageKey,
          boundary,
          unit,
        ].any((s) => s.trim().isEmpty) ||
        !start.isUtc ||
        !end.isUtc ||
        !end.isAfter(start) ||
        !quantity.isFinite ||
        quantity < 0 ||
        !personalShare.isFinite ||
        personalShare <= 0 ||
        personalShare > 1) {
      throw ArgumentError(
        'Evidence needs a UTC interval, units and valid quantity/share.',
      );
    }
  }
  final String id, source, coverageKey, boundary, unit;
  final FootprintSector sector;
  final DateTime start, end;
  final double quantity, personalShare;
  final EvidenceQuality quality;
  final bool reviewed;
  final FootprintFactor? factor;

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'coverageKey': coverageKey,
    'sector': sector.name,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'boundary': boundary,
    'unit': unit,
    'quantity': quantity,
    'quality': quality.name,
    'reviewed': reviewed,
    'factor': factor?.toJson(),
    'personalShare': personalShare,
  };
  factory FootprintEvidence.fromJson(Map<String, dynamic> j) =>
      FootprintEvidence(
        id: j['id'] as String,
        source: j['source'] as String,
        coverageKey: j['coverageKey'] as String,
        sector: FootprintSector.values.byName(j['sector'] as String),
        start: DateTime.parse(j['start'] as String),
        end: DateTime.parse(j['end'] as String),
        boundary: j['boundary'] as String,
        unit: j['unit'] as String,
        quantity: (j['quantity'] as num).toDouble(),
        quality: EvidenceQuality.values.byName(j['quality'] as String),
        reviewed: j['reviewed'] as bool,
        factor: j['factor'] == null
            ? null
            : FootprintFactor.fromJson(
                Map<String, dynamic>.from(j['factor'] as Map),
              ),
        personalShare: (j['personalShare'] as num).toDouble(),
      );

  FootprintEvidence withCoverageKey(String key) => FootprintEvidence(
    id: id,
    source: source,
    coverageKey: key,
    sector: sector,
    start: start,
    end: end,
    boundary: boundary,
    unit: unit,
    quantity: quantity,
    quality: quality,
    reviewed: reviewed,
    factor: factor,
    personalShare: personalShare,
  );

  bool get compatibleFactor =>
      factor != null &&
      factor!.unit == unit &&
      factor!.sector == sector &&
      factor!.boundary == boundary;
  double get kgCo2e {
    if (!compatibleFactor) throw StateError('Missing or incompatible factor.');
    final value = quantity * factor!.kgCo2ePerUnit * personalShare;
    if (!value.isFinite) throw StateError('Emissions overflow.');
    return value;
  }
}

class FootprintIssue {
  const FootprintIssue(this.coverageKey, this.reason);
  final String coverageKey, reason;
}

typedef FootprintBasis = ({String boundary, String gwp, String method});

class FootprintReport {
  FootprintReport(
    List<FootprintEvidence> included,
    List<FootprintEvidence> suppressed,
    List<FootprintIssue> issues,
    Set<FootprintSector> missingSectors,
  ) : included = List.unmodifiable(included),
      suppressed = List.unmodifiable(suppressed),
      issues = List.unmodifiable(issues),
      missingSectors = Set.unmodifiable(missingSectors);
  final List<FootprintEvidence> included, suppressed;
  final List<FootprintIssue> issues;
  final Set<FootprintSector> missingSectors;

  /// Never combine operational and lifecycle boundaries into one headline total.
  Map<FootprintBasis, double> get kgCo2eByBasis {
    final result = <FootprintBasis, double>{};
    for (final e in included) {
      final basis = (
        boundary: e.boundary,
        gwp: e.factor!.gwpVersion,
        method: e.factor!.accountingMethod,
      );
      final next = (result[basis] ?? 0) + e.kgCo2e;
      if (!next.isFinite) throw StateError('Aggregate emissions overflow.');
      result[basis] = next;
    }
    return Map.unmodifiable(result);
  }
}

class FootprintLedger {
  const FootprintLedger();

  /// Call only after splitting overlapping intervals and assigning canonical keys.
  /// A key represents ONE event/component for ONE person and accounting boundary.
  /// This conservatively holds partial-period records instead of prorating them.
  FootprintReport reconcile(
    Iterable<FootprintEvidence> input, {
    required DateTime start,
    required DateTime end,
    Set<FootprintSector> expectedSectors = const {},
  }) {
    if (!start.isUtc || !end.isUtc || !end.isAfter(start)) {
      throw ArgumentError('Reporting requires a nonempty UTC interval.');
    }
    final included = <FootprintEvidence>[];
    final suppressed = <FootprintEvidence>[];
    final issues = <FootprintIssue>[];
    final groups = <String, List<FootprintEvidence>>{};
    final identities = <(String, String), FootprintEvidence>{};
    final conflictedKeys = <String>{};
    for (final e in input) {
      final identity = (e.source, e.id);
      final old = identities[identity];
      if (old != null &&
          (old.coverageKey != e.coverageKey ||
              old.sector != e.sector ||
              old.boundary != e.boundary ||
              old.start != e.start ||
              old.end != e.end ||
              old.reviewed != e.reviewed ||
              old.quality != e.quality ||
              !_sameCalculation(old, e))) {
        conflictedKeys.addAll([old.coverageKey, e.coverageKey]);
      }
      identities[identity] = e;
      if (!e.start.isBefore(end) || !e.end.isAfter(start)) continue;
      groups.putIfAbsent(e.coverageKey, () => []).add(e);
    }
    final orderedKeys = groups.keys.toList()..sort();
    for (final key in orderedKeys) {
      final entry = MapEntry(key, groups[key]!);
      final all = entry.value;
      final first = all.first;
      String? problem;
      if (conflictedKeys.contains(entry.key)) {
        problem = 'Source record identity has conflicting revisions or coverage keys.';
      } else if (all.any(
        (e) => e.start.isBefore(start) || e.end.isAfter(end),
      )) {
        problem =
            'Split the evidence at reporting boundaries before accounting.';
      } else if (all.any(
        (e) =>
            e.sector != first.sector ||
            e.boundary != first.boundary ||
            e.start != first.start ||
            e.end != first.end,
      )) {
        problem = 'Coverage key has different sectors, boundaries or intervals; review matching.';
      }
      final reviewed = all.where((e) => e.reviewed).toList();
      if (problem == null && reviewed.isEmpty) {
        problem = 'Evidence requires review.';
      }
      if (problem != null) {
        issues.add(FootprintIssue(entry.key, problem));
        continue;
      }
      reviewed.sort((a, b) {
        final quality = b.quality.index.compareTo(a.quality.index);
        if (quality != 0) return quality;
        final identity = a.source.compareTo(b.source);
        return identity != 0 ? identity : a.id.compareTo(b.id);
      });
      final best = reviewed.first;
      if (all.any(
        (e) => !e.reviewed && e.quality.index >= best.quality.index,
      )) {
        issues.add(
          FootprintIssue(
            entry.key,
            'Equal or stronger evidence requires review; no weaker fallback.',
          ),
        );
        continue;
      }
      final tied = reviewed.where((e) => e.quality == best.quality);
      if (tied.any((e) => !_sameCalculation(e, best))) {
        issues.add(
          FootprintIssue(
            entry.key,
            'Conflicting evidence of equal quality; review required.',
          ),
        );
        continue;
      }
      if (!best.compatibleFactor) {
        issues.add(
          FootprintIssue(
            entry.key,
            'Best evidence needs a matching reviewed factor; no spend fallback.',
          ),
        );
        continue;
      }
      if (reviewed.any(
        (e) =>
            e.compatibleFactor &&
            (e.factor!.gwpVersion != best.factor!.gwpVersion ||
                e.factor!.accountingMethod != best.factor!.accountingMethod),
      )) {
        issues.add(
          FootprintIssue(
            entry.key,
            'Coverage key mixes incompatible GWP sets or accounting methods; review factor selection.',
          ),
        );
        continue;
      }
      if (!(best.quantity * best.factor!.kgCo2ePerUnit * best.personalShare)
          .isFinite) {
        issues.add(
          FootprintIssue(entry.key, 'Emissions overflow; review input.'),
        );
        continue;
      }
      included.add(best);
      // The chosen observation replaces all other evidence for this exact component.
      var selected = false;
      for (final e in all) {
        if (!selected && identical(e, best)) {
          selected = true;
        } else {
          suppressed.add(e);
        }
      }
    }
    return FootprintReport(
      included,
      suppressed,
      issues,
      expectedSectors.difference(included.map((e) => e.sector).toSet()),
    );
  }

  bool _sameCalculation(FootprintEvidence a, FootprintEvidence b) {
    final x = a.factor, y = b.factor;
    return a.quantity == b.quantity &&
        a.unit == b.unit &&
        a.personalShare == b.personalShare &&
        (x == null && y == null || x != null && y != null && x.sameValue(y));
  }
}
