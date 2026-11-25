// Overview: Converts explicitly reviewed normalized utility readings into archive revisions.
//
// Experimental and pure: no storage, UI or dashboard wiring. It accepts only
// `parseUtilityCsv` electricity candidates (record_id,date,kwh). It does not
// read provider-native exports or establish compatibility with any provider.
import 'dart:convert';

import 'automation.dart';
import 'carbon.dart';
import 'evidence_archive.dart';
import 'footprint_ledger.dart';

/// Reviewer decision. There is deliberately no default: pending readings are
/// archived as unreviewed evidence, which the ledger holds rather than counts.
enum UtilityReviewDecision { approved, pendingReview }

/// The explicit choices a reviewer/provider makes for one normalized reading.
///
/// Nothing here is inferred from arrival order, the row description or the
/// device time zone.
class UtilityReadingReview {
  UtilityReadingReview({
    required this.revision,
    required this.receivedAt,
    required this.decision,
    required this.coverageKey,
    required this.serviceStart,
    required this.serviceEnd,
    required this.boundary,
    required this.quality,
    required this.factor,
    required this.personalShare,
    this.supersedes,
  }) {
    if (revision < 1 || supersedes != null && supersedes! >= revision) {
      throw ArgumentError(
        'Revision must be positive and greater than the revision it supersedes.',
      );
    }
    if (supersedes != null && supersedes! < 1) {
      throw ArgumentError('Superseded revision must be positive.');
    }
    if (!receivedAt.isUtc || !serviceStart.isUtc || !serviceEnd.isUtc) {
      throw ArgumentError(
        'Receipt and service interval must be explicit UTC instants.',
      );
    }
    if (coverageKey.trim().isEmpty ||
        coverageKey != coverageKey.trim() ||
        boundary.trim().isEmpty) {
      throw ArgumentError('A reviewed coverage key and boundary are required.');
    }
    if (quality == EvidenceQuality.spendEstimate) {
      throw ArgumentError('A kWh reading is not a spend estimate.');
    }
    if (factor.sector != FootprintSector.electricity ||
        factor.unit != 'kWh' ||
        factor.boundary != boundary) {
      throw ArgumentError(
        'Factor must be an electricity kWh factor for the reviewed boundary.',
      );
    }
    if (!personalShare.isFinite || personalShare <= 0 || personalShare > 1) {
      throw ArgumentError('Personal share must be in (0, 1].');
    }
  }

  /// Provider/reviewer revision number. Never allocated by this adapter.
  final int revision;

  /// The revision this one corrects; null only for a record's first revision.
  final int? supersedes;
  final DateTime receivedAt, serviceStart, serviceEnd;
  final UtilityReviewDecision decision;
  final String coverageKey, boundary;
  final EvidenceQuality quality;
  final FootprintFactor factor;
  final double personalShare;
}

/// One adapter output, ready for [UtilityEvidenceAdapter.append].
class UtilityRevisionChange {
  const UtilityRevisionChange._(this.revision, this.supersedes);
  final EvidenceRevision revision;

  /// Explicit predecessor; null declares a first observation of the record.
  final int? supersedes;
  bool get isWithdrawal => revision.evidence == null;
}

/// UTC bounds of one local civil day, given the zone offsets in force at its
/// start and end (they differ on daylight-saving transition days).
/// UTC = local - offset, so 2026-10-15 at -07:00 starts at 07:00Z.
(DateTime, DateTime) civilDayInUtc(
  int year,
  int month,
  int day, {
  required Duration offsetAtStart,
  required Duration offsetAtEnd,
}) {
  for (final o in [offsetAtStart, offsetAtEnd]) {
    if (o < const Duration(hours: -12) || o > const Duration(hours: 14)) {
      throw ArgumentError('UTC offsets must be between -12:00 and +14:00.');
    }
  }
  final date = DateTime.utc(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    throw ArgumentError('Invalid civil date.');
  }
  return (
    date.subtract(offsetAtStart),
    DateTime.utc(year, month, day + 1).subtract(offsetAtEnd),
  );
}

/// Adapter for ONE consented account/meter.
///
/// * [sourceNamespace] is a stable pseudonym for the account/meter (for example
///   `pse-meter:home-a`), never an account number or bare provider name. It
///   becomes [EvidenceRef.source]. Pseudonymity is the caller's responsibility.
/// * [accountNickname] must equal the nickname given to `parseUtilityCsv`.
///   Candidates from any other nickname are rejected, isolating accounts.
/// * Record IDs are the raw CSV `record_id`, recovered from the candidate ID
///   (never the description), so renaming the nickname keeps them stable.
///   Raw record IDs must be unique per meter at the provider.
class UtilityEvidenceAdapter {
  UtilityEvidenceAdapter({
    required this.sourceNamespace,
    required String accountNickname,
  }) : accountNickname = accountNickname.trim() {
    if (sourceNamespace.trim().isEmpty ||
        sourceNamespace != sourceNamespace.trim() ||
        sourceNamespace.length > 120 ||
        sourceNamespace == _parserSource) {
      throw ArgumentError(
        'Use a stable pseudonymous account/meter namespace, not the import format.',
      );
    }
    if (this.accountNickname.isEmpty) {
      throw ArgumentError('The parsed account nickname is required.');
    }
  }
  static const _parserSource = 'utility-csv';
  final String sourceNamespace, accountNickname;

  /// Raw record ID for a normalized candidate of this account.
  String recordIdOf(ActivityCandidate candidate) {
    const prefix = 'utility:';
    final encoded = candidate.id.startsWith(prefix)
        ? candidate.id.substring(prefix.length)
        : null;
    Object? decoded;
    try {
      if (encoded != null) {
        decoded = jsonDecode(utf8.decode(base64Url.decode(encoded)));
      }
    } on FormatException {
      decoded = null;
    }
    if (decoded is! List ||
        decoded.length != 2 ||
        decoded[0] is! String ||
        decoded[1] is! String ||
        base64Url.encode(utf8.encode(jsonEncode(decoded))) != encoded ||
        (decoded[1] as String).trim().isEmpty) {
      throw ArgumentError('Not a normalized utility candidate ID.');
    }
    if (decoded[0] != accountNickname) {
      throw ArgumentError('Candidate belongs to a different account nickname.');
    }
    return decoded[1] as String;
  }

  /// Builds a reading revision. Throws [ArgumentError] (fail closed) when the
  /// candidate is not a normalized daily electricity reading or the reviewed
  /// interval cannot represent its civil date.
  ///
  /// Zero is rejected: the normalized format cannot express a measured zero,
  /// and an absent reading is not zero consumption.
  UtilityRevisionChange reading(
    ActivityCandidate candidate,
    UtilityReadingReview review,
  ) {
    final recordId = recordIdOf(candidate);
    final start = candidate.start;
    if (candidate.source != _parserSource ||
        candidate.kind != ActivityKind.electricity) {
      throw ArgumentError('Only normalized utility electricity readings.');
    }
    if (!candidate.quantity.isFinite ||
        candidate.quantity <= 0 ||
        candidate.quantity > 1000000) {
      throw ArgumentError('Reading must be a positive finite kWh value.');
    }
    // Parser dates are local civil dates; read their fields, never convert.
    if (start.isUtc ||
        candidate.end.isUtc ||
        start != DateTime(start.year, start.month, start.day) ||
        candidate.end != DateTime(start.year, start.month, start.day + 1)) {
      throw ArgumentError('Reading must cover exactly one local civil day.');
    }
    final civilStart = DateTime.utc(start.year, start.month, start.day);
    final civilEnd = DateTime.utc(start.year, start.month, start.day + 1);
    bool plausible(DateTime instant, DateTime civil) =>
        !instant.isBefore(civil.subtract(const Duration(hours: 14))) &&
        !instant.isAfter(civil.add(const Duration(hours: 12)));
    final length = review.serviceEnd.difference(review.serviceStart);
    if (!plausible(review.serviceStart, civilStart) ||
        !plausible(review.serviceEnd, civilEnd) ||
        length < const Duration(hours: 23) ||
        length > const Duration(hours: 25)) {
      throw ArgumentError(
        'Service interval must be the UTC bounds of ${civilStart.toIso8601String().substring(0, 10)} in one real zone.',
      );
    }
    return UtilityRevisionChange._(
      EvidenceRevision(
        ref: EvidenceRef(sourceNamespace, recordId, review.revision),
        receivedAt: review.receivedAt,
        evidence: FootprintEvidence(
          id: recordId,
          source: sourceNamespace,
          coverageKey: review.coverageKey,
          sector: FootprintSector.electricity,
          start: review.serviceStart,
          end: review.serviceEnd,
          boundary: review.boundary,
          unit: 'kWh',
          quantity: candidate.quantity,
          quality: review.quality,
          reviewed: review.decision == UtilityReviewDecision.approved,
          factor: review.factor,
          personalShare: review.personalShare,
        ),
      ),
      review.supersedes,
    );
  }

  /// Explicit provider/reviewer withdrawal of [recordId]. It is a null payload,
  /// not a zero reading, and must name the current revision it supersedes.
  UtilityRevisionChange withdrawal({
    required String recordId,
    required int revision,
    required int supersedes,
    required DateTime receivedAt,
  }) {
    if (supersedes < 1 || supersedes >= revision) {
      throw ArgumentError('Withdrawal must follow the revision it supersedes.');
    }
    return UtilityRevisionChange._(
      EvidenceRevision(
        ref: EvidenceRef(sourceNamespace, recordId, revision),
        receivedAt: receivedAt,
      ),
      supersedes,
    );
  }

  /// Atomically appends [changes] in order; on any error the input archive is
  /// the only result (archives are immutable).
  ///
  /// * Same revision, identical payload: replay, no change (any `supersedes`).
  /// * Same revision, different payload: [StateError] from the archive.
  /// * New revision without `supersedes`: only if the record has no revisions.
  /// * New revision with `supersedes`: it must name the current head exactly;
  ///   stale or guessed predecessors fail. A withdrawn record cannot be
  ///   withdrawn again, but a later reading may reinstate it.
  EvidenceArchive append(
    EvidenceArchive archive,
    Iterable<UtilityRevisionChange> changes,
  ) {
    var next = archive;
    for (final change in changes) {
      final r = change.revision;
      if (r.ref.source != sourceNamespace) {
        throw ArgumentError('Change belongs to another source namespace.');
      }
      if (next.revisions.any((e) => e.ref.key == r.ref.key)) {
        next = next.append(revisions: [r]);
        continue;
      }
      final head = next.heads[r.ref.identity];
      if (change.supersedes == null) {
        if (head != null) {
          throw StateError(
            'Record ${r.ref.id} already has revision ${head.ref.revision}; '
            'state the revision this corrects.',
          );
        }
      } else if (head == null || head.ref.revision != change.supersedes) {
        throw StateError(
          'Revision ${r.ref.revision} supersedes ${change.supersedes}, but the '
          'current revision is ${head?.ref.revision ?? 'absent'}.',
        );
      } else if (change.isWithdrawal && head.evidence == null) {
        throw StateError('Record ${r.ref.id} is already withdrawn.');
      }
      next = next.append(revisions: [r]);
    }
    return next;
  }
}
