// Overview: Retains source revisions and reviewed relationships for experimental accounting.
import 'dart:convert';

import 'footprint_ledger.dart';

class EvidenceRef {
  EvidenceRef(this.source, this.id, this.revision) {
    if (source.trim().isEmpty || id.trim().isEmpty || revision < 1) {
      throw ArgumentError(
        'Evidence references need source, record ID and revision.',
      );
    }
  }
  final String source, id;
  final int revision;
  // Source must be scoped to the consented account/meter, not just provider name.
  (String, String) get identity => (source, id);
  String get key => jsonEncode([source, id, revision]);
  Map<String, dynamic> toJson() => {
    'source': source,
    'id': id,
    'revision': revision,
  };
  factory EvidenceRef.fromJson(Map<String, dynamic> j) => EvidenceRef(
    j['source'] as String,
    j['id'] as String,
    j['revision'] as int,
  );
}

class EvidenceRevision {
  EvidenceRevision({
    required this.ref,
    required this.receivedAt,
    this.evidence,
  }) {
    if (!receivedAt.isUtc ||
        evidence != null &&
            (evidence!.source != ref.source || evidence!.id != ref.id)) {
      throw ArgumentError(
        'Revision must retain source identity and UTC receipt time.',
      );
    }
  }
  final EvidenceRef ref;
  final DateTime receivedAt;
  // A null payload is an explicit withdrawal, never a zero-consumption reading.
  final FootprintEvidence? evidence;
  Map<String, dynamic> toJson() => {
    'ref': ref.toJson(),
    'receivedAt': receivedAt.toIso8601String(),
    'evidence': evidence?.toJson(),
  };
  factory EvidenceRevision.fromJson(Map<String, dynamic> j) => EvidenceRevision(
    ref: EvidenceRef.fromJson(Map<String, dynamic>.from(j['ref'] as Map)),
    receivedAt: DateTime.parse(j['receivedAt'] as String),
    evidence: j['evidence'] == null
        ? null
        : FootprintEvidence.fromJson(
            Map<String, dynamic>.from(j['evidence'] as Map),
          ),
  );
}

enum EvidenceRelationKind {
  sameComponent,
  supports,
  containedIn,
  separateComponent,
}

class EvidenceRelation {
  EvidenceRelation({
    required this.id,
    required this.from,
    required this.to,
    required this.kind,
    required this.reviewed,
    required this.reason,
    this.revision = 1,
  }) {
    if (id.trim().isEmpty ||
        reason.trim().isEmpty ||
        from.identity == to.identity ||
        revision < 1) {
      throw ArgumentError(
        'A relationship needs two distinct records and a reason.',
      );
    }
  }
  final String id, reason;
  final int revision;
  String get key => jsonEncode([id, revision]);
  final EvidenceRef from, to;
  final EvidenceRelationKind kind;
  final bool reviewed;
  Map<String, dynamic> toJson() => {
    'id': id,
    'from': from.toJson(),
    'to': to.toJson(),
    'kind': kind.name,
    'reviewed': reviewed,
    'reason': reason,
    'revision': revision,
  };
  factory EvidenceRelation.fromJson(Map<String, dynamic> j) => EvidenceRelation(
    id: j['id'] as String,
    from: EvidenceRef.fromJson(Map<String, dynamic>.from(j['from'] as Map)),
    to: EvidenceRef.fromJson(Map<String, dynamic>.from(j['to'] as Map)),
    kind: EvidenceRelationKind.values.byName(j['kind'] as String),
    reviewed: j['reviewed'] as bool,
    reason: j['reason'] as String,
    revision: j['revision'] as int,
  );
}

class EvidenceArchive {
  EvidenceArchive._(this.revisions, this.relations);
  factory EvidenceArchive() => EvidenceArchive._(const [], const []);
  final List<EvidenceRevision> revisions;
  final List<EvidenceRelation> relations;

  /// Atomic, immutable append. Same revision replay is ignored; conflicts fail.
  /// A change in review/matching/factor needs a new revision, retaining old evidence.
  EvidenceArchive append({
    Iterable<EvidenceRevision> revisions = const [],
    Iterable<EvidenceRelation> relations = const [],
  }) {
    final records = {for (final r in this.revisions) r.ref.key: r};
    for (final r in revisions) {
      final old = records[r.ref.key];
      if (old != null &&
          jsonEncode(old.evidence?.toJson()) !=
              jsonEncode(r.evidence?.toJson())) {
        throw StateError('Conflicting immutable source revision: ${r.ref.key}');
      }
      records.putIfAbsent(r.ref.key, () => r);
    }
    final links = {for (final r in this.relations) r.key: r};
    for (final r in relations) {
      for (final previous in links.values.where((e) => e.id == r.id)) {
        final before = {previous.from.identity, previous.to.identity};
        if (!before.contains(r.from.identity) ||
            !before.contains(r.to.identity)) {
          throw ArgumentError(
            'Relationship revisions must retain the same pair of source identities.',
          );
        }
      }
      if (!records.containsKey(r.from.key) || !records.containsKey(r.to.key)) {
        throw ArgumentError(
          'Relationship references missing source revisions.',
        );
      }
      final old = links[r.key];
      if (old != null && jsonEncode(old.toJson()) != jsonEncode(r.toJson())) {
        throw StateError(
          'A relationship revision is immutable; append a new revision.',
        );
      }
      links.putIfAbsent(r.key, () => r);
    }
    return EvidenceArchive._(
      List.unmodifiable(records.values),
      List.unmodifiable(links.values),
    );
  }

  Map<(String, String), EvidenceRevision> get heads {
    final result = <(String, String), EvidenceRevision>{};
    for (final r in revisions) {
      final old = result[r.ref.identity];
      if (old == null || r.ref.revision > old.ref.revision) {
        result[r.ref.identity] = r;
      }
    }
    return Map.unmodifiable(result);
  }

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'revisions': revisions.map((e) => e.toJson()).toList(),
    'relations': relations.map((e) => e.toJson()).toList(),
  };
  factory EvidenceArchive.fromJson(Map<String, dynamic> j) {
    if (j['schema'] != 1) {
      throw const FormatException('Unsupported evidence schema.');
    }
    return EvidenceArchive().append(
      revisions: (j['revisions'] as List).map(
        (e) => EvidenceRevision.fromJson(Map<String, dynamic>.from(e as Map)),
      ),
      relations: (j['relations'] as List).map(
        (e) => EvidenceRelation.fromJson(Map<String, dynamic>.from(e as Map)),
      ),
    );
  }

  /// Exact-component and conservative containment reconciliation only.
  /// No heuristic matching, interval proration, provider inference or silent relinking.
  FootprintReport reconcile({
    required DateTime start,
    required DateTime end,
    Set<FootprintSector> expectedSectors = const {},
  }) {
    if (!start.isUtc || !end.isUtc || !end.isAfter(start)) {
      throw ArgumentError('Reporting requires a nonempty UTC interval.');
    }
    final current = heads;
    final active = {
      for (final r in current.values)
        if (r.evidence != null) r.ref.key: r.evidence!,
    };
    final groups = {
      for (final e in active.values) e.coverageKey: e.coverageKey,
    };
    String root(String k) {
      while (groups[k] != k) {
        k = groups[k]!;
      }
      return k;
    }

    void join(String a, String b) {
      final x = root(a), y = root(b);
      if (x != y) {
        if (x.compareTo(y) < 0) {
          groups[y] = x;
        } else {
          groups[x] = y;
        }
      }
    }

    final issues = <FootprintIssue>[];
    final blocked = <String>{};
    final usable = <EvidenceRelation>[];
    void hold(EvidenceRelation r, String reason) {
      // Hold all current evidence for those identities, even when a link is stale.
      for (final ref in [r.from, r.to]) {
        final e = current[ref.identity]?.evidence;
        if (e != null) {
          blocked.add(e.coverageKey);
          issues.add(
            FootprintIssue(e.coverageKey, 'Relationship ${r.id}: $reason'),
          );
        }
      }
    }

    // For the same pair, the newest referenced revisions supersede stale links.
    // Links to prior revisions remain for audit, but cannot silently apply to corrections.
    final latestPairs = <String, List<EvidenceRelation>>{};
    final relationshipHeads = <String, EvidenceRelation>{};
    for (final r in relations) {
      final old = relationshipHeads[r.id];
      if (old == null || r.revision > old.revision) relationshipHeads[r.id] = r;
    }
    for (final r in relationshipHeads.values) {
      final pair = [
        jsonEncode([r.from.source, r.from.id]),
        jsonEncode([r.to.source, r.to.id]),
      ]..sort();
      latestPairs.putIfAbsent(jsonEncode(pair), () => []).add(r);
    }
    for (final pair in latestPairs.values) {
      final live = pair
          .where(
            (r) =>
                current[r.from.identity]?.ref.key == r.from.key &&
                current[r.to.identity]?.ref.key == r.to.key,
          )
          .toList();
      if (live.isEmpty) {
        hold(
          pair.first,
          'A source was revised or withdrawn; review its relationship again.',
        );
        continue;
      }
      final signatures = live.map((r) {
        final endpoints = [r.from.key, r.to.key];
        if (r.kind == EvidenceRelationKind.sameComponent ||
            r.kind == EvidenceRelationKind.separateComponent) {
          endpoints.sort();
        }
        return jsonEncode([endpoints, r.kind.name, r.reviewed]);
      }).toSet();
      if (signatures.length > 1) {
        for (final r in live) {
          hold(r, 'Conflicting relationship decisions require review.');
        }
        continue;
      }
      final r = live.first;
      if (!r.reviewed) {
        hold(r, 'Matching decision requires review.');
        continue;
      }
      if (!active.containsKey(r.from.key) || !active.containsKey(r.to.key)) {
        hold(r, 'A source is withdrawn; review its relationship again.');
        continue;
      }
      usable.add(r);
      if (r.kind == EvidenceRelationKind.sameComponent) {
        join(active[r.from.key]!.coverageKey, active[r.to.key]!.coverageKey);
      }
    }
    // Support records must match the same period/sector/boundary; the ledger then
    // selects stronger physical evidence. Supporting money cannot hide physical data.
    for (final r in usable.where(
      (r) => r.kind == EvidenceRelationKind.supports,
    )) {
      final a = active[r.from.key]!, b = active[r.to.key]!;
      if (!a.reviewed || !b.reviewed) {
        hold(r, 'Supporting and primary evidence must be reviewed.');
      } else if (a.quality.index > b.quality.index) {
        hold(
          r,
          'Supporting evidence cannot outrank its primary evidence; review relationship direction.',
        );
      }
      join(a.coverageKey, b.coverageKey);
    }
    // Validate every canonical group before containment can remove its aliases.
    // Expand only this validation window; the final report still holds records
    // crossing the caller's reporting boundaries instead of prorating them.
    var validationStart = start, validationEnd = end;
    for (final e in active.values) {
      if (e.start.isBefore(validationStart)) validationStart = e.start;
      if (e.end.isAfter(validationEnd)) validationEnd = e.end;
    }
    final checked = const FootprintLedger().reconcile(
      active.values.map((e) => e.withCoverageKey(root(e.coverageKey))),
      start: validationStart,
      end: validationEnd,
    );
    // A match is invalid even when its conflicting alias falls outside the
    // requested month. Otherwise the same component can count in two months.
    issues.addAll(checked.issues);
    blocked.addAll(checked.issues.map((issue) => issue.coverageKey));
    final selected = {for (final e in checked.included) e.coverageKey: e};
    final excluded = <String>{};
    final children = <String, List<FootprintEvidence>>{};
    final containment = usable
        .where((r) => r.kind == EvidenceRelationKind.containedIn)
        .toList();
    final parentKeys = <String, Set<String>>{};
    for (final r in containment) {
      parentKeys
          .putIfAbsent(root(active[r.from.key]!.coverageKey), () => {})
          .add(root(active[r.to.key]!.coverageKey));
    }
    final seenContainmentPairs = <(String, String)>{};
    for (final r in containment) {
      final childKey = root(active[r.from.key]!.coverageKey);
      final parentKey = root(active[r.to.key]!.coverageKey);
      if (!seenContainmentPairs.add((childKey, parentKey))) continue;
      final child = selected[childKey], parent = selected[parentKey];
      if (child == null || parent == null) {
        hold(
          r,
          'Canonical evidence has conflicts or missing factors; resolve it before containment.',
        );
        continue;
      }
      final x = child.factor, y = parent.factor;
      final compatible =
          child.reviewed &&
          parent.reviewed &&
          child.compatibleFactor &&
          parent.compatibleFactor &&
          child.quality != EvidenceQuality.spendEstimate &&
          parent.quality != EvidenceQuality.spendEstimate &&
          const {
            'kWh',
            'therm',
            'kg',
            'm3',
            'vehicle-km',
            'passenger-km',
          }.contains(child.unit) &&
          child.unit == parent.unit &&
          child.boundary == parent.boundary &&
          child.personalShare == parent.personalShare &&
          !child.start.isBefore(parent.start) &&
          !child.end.isAfter(parent.end) &&
          child.quantity <= parent.quantity &&
          root(child.coverageKey) != root(parent.coverageKey) &&
          x!.kgCo2ePerUnit == y!.kgCo2ePerUnit &&
          x.gwpVersion == y.gwpVersion &&
          x.accountingMethod == y.accountingMethod &&
          x.geography == y.geography &&
          x.dataYear == y.dataYear;
      if (!compatible) {
        hold(
          r,
          'Containment needs compatible physical units, periods, allocation and factors.',
        );
        continue;
      }
      // Nested containment and competing parents are held; no graph guessing.
      if (parentKeys[root(child.coverageKey)]!.length > 1 ||
          usable.any(
            (q) =>
                q.kind == EvidenceRelationKind.containedIn &&
                (root(active[q.from.key]!.coverageKey) ==
                        root(parent.coverageKey) ||
                    root(active[q.to.key]!.coverageKey) ==
                        root(child.coverageKey)),
          )) {
        hold(r, 'Nested or competing containment requires review.');
        continue;
      }
      excluded.add(r.from.key);
      final siblings = children.putIfAbsent(parentKey, () => []);
      if (!siblings.any((e) => e.coverageKey == childKey)) siblings.add(child);
    }
    for (final entry in children.entries) {
      final parent = selected[entry.key]!;
      final entries = entry.value;
      final total = entries.fold(0.0, (v, e) => v + e.quantity);
      final overlap = entries.any(
        (a) => entries.any(
          (b) =>
              !identical(a, b) &&
              a.start.isBefore(b.end) &&
              b.start.isBefore(a.end),
        ),
      );
      if (total > parent.quantity || overlap) {
        blocked.add(parent.coverageKey);
        blocked.addAll(entries.map((e) => e.coverageKey));
        issues.add(
          FootprintIssue(
            parent.coverageKey,
            'Contained quantities overlap or exceed their parent; review allocation.',
          ),
        );
      }
    }
    for (final r in usable.where(
      (r) => r.kind == EvidenceRelationKind.separateComponent,
    )) {
      final a = active[r.from.key]!, b = active[r.to.key]!;
      final aKey = root(a.coverageKey), bKey = root(b.coverageKey);
      if (aKey == bKey ||
          containment.any((q) {
            final child = root(active[q.from.key]!.coverageKey);
            final parent = root(active[q.to.key]!.coverageKey);
            return child == aKey && parent == bKey ||
                child == bKey && parent == aKey;
          })) {
        hold(
          r,
          'Separate-component decision contradicts a canonical match or containment.',
        );
      }
    }
    final blockedGroups = blocked.map(root).toSet();
    final excludedGroups = excluded
        .map((key) => root(active[key]!.coverageKey))
        .toSet();
    final candidates = active.entries
        .where(
          (e) =>
              !excludedGroups.contains(root(e.value.coverageKey)) &&
              !blockedGroups.contains(root(e.value.coverageKey)),
        )
        .map((e) => e.value.withCoverageKey(root(e.value.coverageKey)));
    final report = const FootprintLedger().reconcile(
      candidates,
      start: start,
      end: end,
      expectedSectors: expectedSectors,
    );
    // Only suppress a child when its exact parent made it into the report.
    final includedIdentities = report.included
        .map((e) => (e.source, e.id))
        .toSet();
    final contained = <FootprintEvidence>[];
    final recordedChildren = <(String, String)>{};
    for (final entry in children.entries) {
      final parent = selected[entry.key]!;
      if (blockedGroups.contains(root(parent.coverageKey))) continue;
      if (includedIdentities.contains((parent.source, parent.id))) {
        final childGroups = entry.value
            .where((e) => !blockedGroups.contains(root(e.coverageKey)))
            .map((e) => root(e.coverageKey))
            .toSet();
        contained.addAll(
          active.values.where(
            (e) =>
                childGroups.contains(root(e.coverageKey)) &&
                recordedChildren.add((e.source, e.id)),
          ),
        );
      } else if (entry.value.any(
        (e) =>
            !blockedGroups.contains(root(e.coverageKey)) &&
            e.start.isBefore(end) &&
            e.end.isAfter(start),
      )) {
        issues.add(
          FootprintIssue(
            parent.coverageKey,
            'Containing parent is unresolved for this period; child is not counted separately.',
          ),
        );
      }
    }
    final relevantIssues = <FootprintIssue>[];
    final seenIssues = <(String, String)>{};
    for (final issue in issues) {
      final canonicalKey = root(issue.coverageKey);
      if (active.values.any(
            (e) =>
                root(e.coverageKey) == canonicalKey &&
                e.start.isBefore(end) &&
                e.end.isAfter(start),
          ) &&
          seenIssues.add((canonicalKey, issue.reason))) {
        relevantIssues.add(FootprintIssue(canonicalKey, issue.reason));
      }
    }
    return FootprintReport(
      report.included,
      [...report.suppressed, ...contained],
      [...report.issues, ...relevantIssues],
      report.missingSectors,
    );
  }
}
