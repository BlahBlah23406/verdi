// Overview: Plans reviewed electricity imports and records meter identity and reviewer provenance.
//
// Experimental. The plan feeds the evidence archive only; it never creates
// journal activities or changes dashboard totals.
import 'dart:convert';

import 'automation.dart';
import 'emission_factors.dart';
import 'evidence_archive.dart';
import 'footprint_ledger.dart';
import 'service_zone.dart';
import 'utility_evidence_adapter.dart';

/// Prefix reserved for reviewed utility meters in the evidence archive. Raw
/// archive appends may not write under it; see `EvidenceArchiveStore`.
const utilityNamespacePrefix = 'verdi-utility:';

/// Version of the consent statement a reviewer acknowledges.
const utilityConsentVersion = 'utility-file-consent-v1';
const utilityConsentStatement =
    'I am authorized to use this electricity account/meter data, I exported '
    'this file myself or with the account holder\'s permission, and it '
    'contains no passwords or access tokens.';

/// Electricity factors a reviewer can choose from. There is deliberately no
/// default; this list contains only factors already pinned in the app.
final utilityFactorChoices = [
  FootprintFactor(
    id: EmissionFactor.electricity.id,
    version: EmissionFactor.version,
    sector: FootprintSector.electricity,
    unit: 'kWh',
    boundary: 'electricity-generation',
    geography: EmissionFactor.geography,
    dataYear: 2023,
    sourceUrl: EmissionFactor.sourceUrl,
    gwpVersion: 'IPCC-AR5-100yr-CH4-28-N2O-265',
    accountingMethod: 'location-based-US-fallback',
    kgCo2ePerUnit: EmissionFactor.electricity.kgCo2ePerUnit,
  ),
];

/// Evidence qualities a reviewer can assert for normalized kWh readings.
/// The normalized CSV has no actual/estimated flag, so there is no default.
const utilityQualityChoices = [
  EvidenceQuality.modelEstimate,
  EvidenceQuality.confirmedQuantity,
  EvidenceQuality.measuredQuantity,
];

/// Human-readable label for an allowed utility [EvidenceQuality] choice.
String utilityQualityLabel(EvidenceQuality quality) => switch (quality) {
  EvidenceQuality.modelEstimate => 'Utility estimate (modelled or prorated)',
  EvidenceQuality.confirmedQuantity =>
    'Confirmed quantity (reviewed bill or export)',
  EvidenceQuality.measuredQuantity =>
    'Actual meter reading (explicitly confirmed)',
  EvidenceQuality.spendEstimate =>
    throw ArgumentError('A kWh reading is not a spend estimate.'),
};

/// A durable pseudonymous meter identity. The namespace is random and never
/// derived from an account number; the label is a local nickname only.
class UtilityMeter {
  UtilityMeter({
    required this.namespace,
    required this.label,
    required this.zoneId,
    required this.createdAt,
  }) {
    if (!namespace.startsWith(utilityNamespacePrefix) ||
        namespace.length > 120 ||
        !createdAt.isUtc) {
      throw ArgumentError('Invalid meter identity.');
    }
    final problem = validateMeterLabel(label);
    if (problem != null) throw ArgumentError(problem);
    ServiceZone.byId(zoneId);
  }
  final String namespace, label, zoneId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'namespace': namespace,
    'label': label,
    'zoneId': zoneId,
    'createdAt': createdAt.toIso8601String(),
  };
  factory UtilityMeter.fromJson(Map<String, dynamic> j) => UtilityMeter(
    namespace: j['namespace'] as String,
    label: j['label'] as String,
    zoneId: j['zoneId'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}

/// Returns a problem message, or null when the nickname is acceptable. Long
/// digit runs are rejected so account or meter numbers are not stored.
String? validateMeterLabel(String label) {
  if (label != label.trim() || label.isEmpty || label.length > 80) {
    return 'Enter a meter nickname (1–80 characters).';
  }
  if (RegExp(r'\d{5,}').hasMatch(label.replaceAll(RegExp(r'[\s-]'), ''))) {
    return 'Do not use account or meter numbers in the nickname.';
  }
  return null;
}

/// Reviewer provenance for one saved batch. Committed atomically with the
/// batch's archive revisions; legacy batches lacking [quality] remain readable.
class UtilityReviewBatch {
  UtilityReviewBatch({
    required this.id,
    required this.namespace,
    required this.reviewer,
    required this.reason,
    required this.consentVersion,
    required this.reviewedAt,
    required this.zoneId,
    required this.factorId,
    required this.factorVersion,
    required this.personalShare,
    required this.decision,
    required this.revisionKeys,
    this.quality,
  }) {
    if (id.trim().isEmpty ||
        !namespace.startsWith(utilityNamespacePrefix) ||
        namespace.length > 120 ||
        reviewer.trim().isEmpty ||
        reviewer.length > 80 ||
        reason.trim().isEmpty ||
        reason.length > 280 ||
        consentVersion.isEmpty ||
        !reviewedAt.isUtc ||
        factorId.trim().isEmpty ||
        factorVersion.trim().isEmpty ||
        !personalShare.isFinite ||
        personalShare <= 0 ||
        personalShare > 1 ||
        quality == EvidenceQuality.spendEstimate ||
        revisionKeys.isEmpty) {
      throw ArgumentError(
        'A batch needs reviewer, reason, consent and records.',
      );
    }
    ServiceZone.byId(zoneId);
  }
  final String id, namespace, reviewer, reason, consentVersion;
  final String zoneId, factorId, factorVersion;
  final DateTime reviewedAt;
  final double personalShare;
  final UtilityReviewDecision decision;
  final EvidenceQuality? quality;
  final List<String> revisionKeys;

  Map<String, dynamic> toJson() => {
    'id': id,
    'namespace': namespace,
    'reviewer': reviewer,
    'reason': reason,
    'consentVersion': consentVersion,
    'reviewedAt': reviewedAt.toIso8601String(),
    'zoneId': zoneId,
    'factorId': factorId,
    'factorVersion': factorVersion,
    'personalShare': personalShare,
    'decision': decision.name,
    if (quality != null) 'quality': quality!.name,
    'revisionKeys': revisionKeys,
  };
  factory UtilityReviewBatch.fromJson(Map<String, dynamic> j) =>
      UtilityReviewBatch(
        id: j['id'] as String,
        namespace: j['namespace'] as String,
        reviewer: j['reviewer'] as String,
        reason: j['reason'] as String,
        consentVersion: j['consentVersion'] as String,
        reviewedAt: DateTime.parse(j['reviewedAt'] as String),
        zoneId: j['zoneId'] as String,
        factorId: j['factorId'] as String,
        factorVersion: j['factorVersion'] as String,
        personalShare: (j['personalShare'] as num).toDouble(),
        decision: UtilityReviewDecision.values.byName(j['decision'] as String),
        quality: j['quality'] == null
            ? null
            : EvidenceQuality.values.byName(j['quality'] as String),
        revisionKeys: List<String>.from(j['revisionKeys'] as List),
      );
}

/// Persisted meters and batches. Unknown keys are ignored for forward
/// compatibility; a missing value is an empty state.
class UtilityReviewState {
  UtilityReviewState(
    List<UtilityMeter> meters,
    List<UtilityReviewBatch> batches,
  ) : meters = List.unmodifiable(meters),
      batches = List.unmodifiable(batches) {
    final namespaces = meters.map((m) => m.namespace).toSet();
    final labels = meters.map((m) => m.label.toLowerCase()).toSet();
    final ids = batches.map((b) => b.id).toSet();
    if (namespaces.length != meters.length ||
        labels.length != meters.length ||
        ids.length != batches.length) {
      throw ArgumentError('Duplicate meter or batch identity.');
    }
  }
  final List<UtilityMeter> meters;
  final List<UtilityReviewBatch> batches;

  UtilityMeter? meterByLabel(String label) {
    for (final m in meters) {
      if (m.label.toLowerCase() == label.trim().toLowerCase()) return m;
    }
    return null;
  }

  /// Adds a meter; an identical existing meter is a no-op replay.
  UtilityReviewState withMeter(UtilityMeter meter) {
    final same = meters.where((m) => m.namespace == meter.namespace);
    if (same.isNotEmpty) {
      if (jsonEncode(same.single.toJson()) != jsonEncode(meter.toJson())) {
        throw StateError('Meter ${meter.namespace} already differs.');
      }
      return this;
    }
    return UtilityReviewState([...meters, meter], batches);
  }

  /// Adds a batch; an identical existing batch is a no-op replay.
  UtilityReviewState withBatch(UtilityReviewBatch batch) {
    final same = batches.where((b) => b.id == batch.id);
    if (same.isNotEmpty) {
      if (jsonEncode(same.single.toJson()) != jsonEncode(batch.toJson())) {
        throw StateError('Review batch ${batch.id} already differs.');
      }
      return this;
    }
    if (!meters.any((m) => m.namespace == batch.namespace)) {
      throw StateError('Review batch references an unknown meter.');
    }
    return UtilityReviewState(meters, [...batches, batch]);
  }

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'meters': meters.map((m) => m.toJson()).toList(),
    'batches': batches.map((b) => b.toJson()).toList(),
  };
  factory UtilityReviewState.fromJson(Map<String, dynamic> j) {
    if (j['schema'] != 1) {
      throw const FormatException('Unsupported utility review schema.');
    }
    return UtilityReviewState(
      (j['meters'] as List)
          .map(
            (e) => UtilityMeter.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      (j['batches'] as List)
          .map(
            (e) => UtilityReviewBatch.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

/// Explicit reviewer choices for a whole import.
///
/// [quality] has no default because normalized CSVs carry no actual/estimated
/// meter flag; the reviewer must state what their source confirms.
class UtilityReviewChoices {
  UtilityReviewChoices({
    required this.zone,
    required this.factor,
    required this.quality,
    required this.personalShare,
    required this.decision,
    required this.reviewer,
    required this.reason,
    required this.consentAcknowledged,
    this.confirmCorrections = false,
  }) {
    if (quality == EvidenceQuality.spendEstimate) {
      throw ArgumentError('A kWh reading is not a spend estimate.');
    }
    if (!consentAcknowledged) {
      throw ArgumentError('Acknowledge the consent statement first.');
    }
    if (reviewer.trim().isEmpty || reviewer.trim().length > 80) {
      throw ArgumentError('Enter the reviewer name or initials (1–80).');
    }
    if (reason.trim().isEmpty || reason.trim().length > 280) {
      throw ArgumentError('Enter a review reason (1–280 characters).');
    }
    if (!personalShare.isFinite || personalShare <= 0 || personalShare > 1) {
      throw ArgumentError('Personal share must be above 0% and at most 100%.');
    }
  }
  final ServiceZone zone;
  final FootprintFactor factor;
  final EvidenceQuality quality;
  final double personalShare;
  final UtilityReviewDecision decision;
  final String reviewer, reason;
  final bool consentAcknowledged, confirmCorrections;
}

enum UtilityRowStatus { added, unchanged, correction, rejected }

class UtilityPlanRow {
  const UtilityPlanRow({
    required this.recordId,
    required this.date,
    required this.kwh,
    required this.status,
    this.change,
    this.previous,
    this.problem,
  });
  final String recordId, date;
  final double kwh;
  final UtilityRowStatus status;

  /// The change to append; null for unchanged, rejected or unconfirmed rows.
  final UtilityRevisionChange? change;

  /// Current archived head for corrections.
  final EvidenceRevision? previous;
  final String? problem;
  FootprintEvidence? get evidence => change?.revision.evidence;
}

/// A reviewed preview. Saving re-checks [baseline] against the archive inside
/// the store's write queue; any change to this meter's records fails it.
class UtilityImportPlan {
  UtilityImportPlan({
    required this.meter,
    required this.choices,
    required this.adapter,
    required this.rows,
    required this.baseline,
    required this.batchId,
    required this.reviewedAt,
    required this.projected,
  });
  final UtilityMeter meter;
  final UtilityReviewChoices choices;
  final UtilityEvidenceAdapter adapter;
  final List<UtilityPlanRow> rows;
  final Set<String> baseline;
  final String batchId;
  final DateTime reviewedAt;

  /// The archive as it would be after saving (for preview only).
  final EvidenceArchive projected;

  List<UtilityRevisionChange> get changes => [
    for (final r in rows)
      if (r.change != null) r.change!,
  ];
  int count(UtilityRowStatus s) => rows.where((r) => r.status == s).length;
  bool get hasUnconfirmedCorrections => rows.any(
    (r) => r.status == UtilityRowStatus.correction && r.change == null,
  );

  UtilityReviewBatch get batch => UtilityReviewBatch(
    id: batchId,
    namespace: meter.namespace,
    reviewer: choices.reviewer.trim(),
    reason: choices.reason.trim(),
    consentVersion: utilityConsentVersion,
    reviewedAt: reviewedAt,
    zoneId: choices.zone.id,
    factorId: choices.factor.id,
    factorVersion: choices.factor.version,
    personalShare: choices.personalShare,
    decision: choices.decision,
    quality: choices.quality,
    revisionKeys: [for (final c in changes) c.revision.ref.key],
  );

  /// UTC months touched by the readings, oldest first.
  List<DateTime> get months {
    final result = <DateTime>{};
    for (final r in rows) {
      final e = r.evidence ?? r.previous?.evidence;
      if (e == null) continue;
      final last = e.end.subtract(const Duration(microseconds: 1));
      result.add(DateTime.utc(e.start.year, e.start.month));
      result.add(DateTime.utc(last.year, last.month));
    }
    return result.toList()..sort();
  }
}

/// Keys of every archived revision in [namespace]; used as the stale check.
Set<String> namespaceKeys(EvidenceArchive archive, String namespace) => {
  for (final r in archive.revisions)
    if (r.ref.source == namespace) r.ref.key,
};

/// Builds a preview of [csv] for [meter] against [archive]. Throws
/// [FormatException] for an unreadable file. Rows that cannot be represented
/// are marked rejected rather than guessed.
UtilityImportPlan planUtilityImport({
  required String csv,
  required UtilityMeter meter,
  required UtilityReviewChoices choices,
  required EvidenceArchive archive,
  required DateTime now,
  required String batchId,
}) {
  if (!now.isUtc) throw ArgumentError('Review time must be UTC.');
  if (choices.zone.id != meter.zoneId) {
    throw ArgumentError('This meter is reviewed in ${meter.zoneId}.');
  }
  final adapter = UtilityEvidenceAdapter(
    sourceNamespace: meter.namespace,
    accountNickname: meter.label,
  );
  final candidates = parseUtilityCsv(csv, meter.label)
    ..sort((a, b) => a.start.compareTo(b.start));
  final rows = <UtilityPlanRow>[];
  for (final c in candidates) {
    final recordId = adapter.recordIdOf(c);
    final date =
        '${c.start.year.toString().padLeft(4, '0')}-'
        '${c.start.month.toString().padLeft(2, '0')}-'
        '${c.start.day.toString().padLeft(2, '0')}';
    UtilityPlanRow reject(String problem) => UtilityPlanRow(
      recordId: recordId,
      date: date,
      kwh: c.quantity,
      status: UtilityRowStatus.rejected,
      problem: problem,
    );
    final head = archive.heads[(meter.namespace, recordId)];
    try {
      final (start, end) = choices.zone.civilDay(
        c.start.year,
        c.start.month,
        c.start.day,
      );
      UtilityReadingReview review(int revision, int? supersedes) =>
          UtilityReadingReview(
            revision: revision,
            supersedes: supersedes,
            receivedAt: now,
            decision: choices.decision,
            coverageKey: '${meter.namespace}:electricity:$date',
            serviceStart: start,
            serviceEnd: end,
            boundary: choices.factor.boundary,
            quality: choices.quality,
            factor: choices.factor,
            personalShare: choices.personalShare,
          );
      if (head == null) {
        final change = adapter.reading(c, review(1, null));
        rows.add(
          UtilityPlanRow(
            recordId: recordId,
            date: date,
            kwh: c.quantity,
            status: UtilityRowStatus.added,
            change: change,
          ),
        );
        continue;
      }
      final same = adapter.reading(c, review(head.ref.revision, null));
      if (head.evidence != null &&
          jsonEncode(head.evidence!.toJson()) ==
              jsonEncode(same.revision.evidence!.toJson())) {
        rows.add(
          UtilityPlanRow(
            recordId: recordId,
            date: date,
            kwh: c.quantity,
            status: UtilityRowStatus.unchanged,
            previous: head,
          ),
        );
        continue;
      }
      // A different reading or review is a new revision naming the head. The
      // reviewer must confirm it; it is never applied silently.
      final change = adapter.reading(
        c,
        review(head.ref.revision + 1, head.ref.revision),
      );
      rows.add(
        UtilityPlanRow(
          recordId: recordId,
          date: date,
          kwh: c.quantity,
          status: UtilityRowStatus.correction,
          change: choices.confirmCorrections ? change : null,
          previous: head,
        ),
      );
    } on ArgumentError catch (e) {
      rows.add(reject('${e.message}'));
    }
  }
  final changes = [
    for (final r in rows)
      if (r.change != null) r.change!,
  ];
  return UtilityImportPlan(
    meter: meter,
    choices: choices,
    adapter: adapter,
    rows: rows,
    baseline: namespaceKeys(archive, meter.namespace),
    batchId: batchId,
    reviewedAt: now,
    projected: adapter.append(archive, changes),
  );
}
