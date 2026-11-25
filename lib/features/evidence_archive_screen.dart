// Overview: Inspects saved experimental evidence, reconciliation and revision history.
import 'package:flutter/material.dart';

import '../data/evidence_archive_store.dart';
import '../domain/evidence_archive.dart';
import '../domain/footprint_ledger.dart';

class EvidenceArchiveScreen extends StatefulWidget {
  const EvidenceArchiveScreen({
    super.key,
    required this.store,
    this.initialMonth,
  });
  final EvidenceArchiveStore store;
  final DateTime? initialMonth;

  @override
  State<EvidenceArchiveScreen> createState() => _EvidenceArchiveScreenState();
}

class _EvidenceArchiveScreenState extends State<EvidenceArchiveScreen> {
  late DateTime month;
  EvidenceArchive? archive;
  String? error;

  @override
  void initState() {
    super.initState();
    final date = widget.initialMonth ?? DateTime.now().toUtc();
    month = DateTime.utc(date.year, date.month);
    load();
  }

  void load() {
    try {
      archive = widget.store.load();
      error = null;
    } catch (_) {
      archive = null;
      error = 'Saved evidence could not be read. It has been kept unchanged.';
    }
  }

  String date(DateTime value) => value.toIso8601String().split('T').first;
  String ref(EvidenceRef value) =>
      '${value.source} / ${value.id} · revision ${value.revision}';
  String words(String value) =>
      value.replaceAllMapped(RegExp('[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}');

  @override
  Widget build(BuildContext context) {
    final end = DateTime.utc(month.year, month.month + 1);
    FootprintReport? report;
    Map<FootprintBasis, double>? totals;
    var reportFailed = false;
    if (archive != null) {
      try {
        report = archive!.reconcile(
          start: month,
          end: end,
          expectedSectors: FootprintSector.values.toSet(),
        );
        totals = report.kgCo2eByBasis;
      } catch (_) {
        reportFailed = true;
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evidence history'),
        actions: [
          IconButton(
            tooltip: 'Reload evidence',
            onPressed: () => setState(load),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Experimental evidence archive. These estimates are separate from your dashboard. This view lets you inspect saved records; imports and the activity journal do not yet populate it.',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => setState(() {
                      month = DateTime.utc(month.year, month.month - 1);
                    }),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '${date(month)} to ${date(end)} (exclusive) · UTC',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: () => setState(() => month = end),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              if (error != null) Text(error!),
              if (archive != null && archive!.revisions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No evidence saved. Missing data does not mean zero emissions.',
                  ),
                ),
              if (reportFailed)
                const Text(
                  'This month could not be calculated. Review the saved records below; no data was changed.',
                ),
              if (report != null && !reportFailed) ...[
                heading('Monthly reconciliation'),
                Text(
                  '${report.included.length} included · ${report.suppressed.length} nonadditive · ${report.issues.length} issues',
                ),
                if (totals!.isEmpty)
                  const Text('No accepted estimate for this month.'),
                for (final entry in totals.entries)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '${entry.value.toStringAsFixed(2)} kg CO₂e\n${entry.key.boundary} · ${entry.key.gwp} · ${entry.key.method}',
                      ),
                    ),
                  ),
                const Text(
                  'Each accounting basis is shown separately. Records crossing month boundaries require review; they are not prorated.',
                ),
                heading('Coverage gaps'),
                Text(
                  report.missingSectors.isEmpty
                      ? 'Every expected sector has some accepted evidence. This does not establish complete coverage.'
                      : 'No accepted evidence: ${report.missingSectors.map((s) => s.name).join(', ')}. Evidence in other sectors may still cover only part of the month.',
                ),
                for (final issue in report.issues)
                  Card(
                    child: ListTile(
                      title: Text(issue.coverageKey),
                      subtitle: Text(issue.reason),
                    ),
                  ),
              ],
              if (archive != null && archive!.revisions.isNotEmpty) ...[
                heading('Source records and revisions'),
                for (final head in archive!.heads.values)
                  recordCard(head, reportFailed ? null : report, end),
                heading('Relationship decisions'),
                if (archive!.relations.isEmpty)
                  const Text(
                    'No matching decisions saved. Different record keys are not automatically matched.',
                  ),
                for (final relation in archive!.relations)
                  relationCard(relation),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget heading(String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );

  Widget recordCard(
    EvidenceRevision head,
    FootprintReport? report,
    DateTime end,
  ) {
    final e = head.evidence;
    bool contains(List<FootprintEvidence> records) =>
        records.any((r) => r.source == head.ref.source && r.id == head.ref.id);
    final status = e == null
        ? 'Withdrawn'
        : !e.start.isBefore(end) || !e.end.isAfter(month)
        ? 'Outside this month'
        : report == null
        ? 'Calculation unavailable'
        : contains(report.included)
        ? 'Included'
        : contains(report.suppressed)
        ? 'Nonadditive alternative or contained record'
        : 'Held for review';
    final revisions =
        archive!.revisions
            .where((r) => r.ref.identity == head.ref.identity)
            .toList()
          ..sort((a, b) => b.ref.revision.compareTo(a.ref.revision));
    return Card(
      child: ExpansionTile(
        key: ValueKey(head.ref.key),
        title: Text('${head.ref.source} / ${head.ref.id}'),
        subtitle: Text('$status · current revision ${head.ref.revision}'),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.all(16),
        children: [
          for (final revision in revisions) ...[
            Text(
              'Revision ${revision.ref.revision} · received ${revision.receivedAt.toIso8601String()}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (revision.evidence == null)
              const Text('Explicit withdrawal; earlier evidence is retained.')
            else
              evidenceDetail(revision.evidence!),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget evidenceDetail(FootprintEvidence e) {
    final factor = e.factor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${e.quantity} ${e.unit} · personal share ${e.personalShare}'),
        Text(
          '${e.start.toIso8601String()} to ${e.end.toIso8601String()} (exclusive)',
        ),
        Text(
          '${e.sector.name} · ${words(e.quality.name)} · ${e.reviewed ? 'reviewed' : 'unreviewed'}',
        ),
        Text('Component: ${e.coverageKey} · boundary: ${e.boundary}'),
        if (factor == null)
          const Text('No factor selected.')
        else ...[
          Text(
            'Factor: ${factor.id} / ${factor.version} · ${factor.kgCo2ePerUnit} kg CO₂e/${factor.unit}',
          ),
          Text(
            'Factor sector: ${factor.sector.name} · boundary: ${factor.boundary}',
          ),
          Text(
            '${factor.geography} · data year ${factor.dataYear} · ${factor.gwpVersion} · ${factor.accountingMethod}',
          ),
          SelectableText(factor.sourceUrl),
        ],
      ],
    );
  }

  Widget relationCard(EvidenceRelation relation) {
    final current = !archive!.relations.any(
      (r) => r.id == relation.id && r.revision > relation.revision,
    );
    final stale = [relation.from, relation.to].any(
      (r) =>
          archive!.heads[r.identity]?.ref.key != r.key ||
          archive!.heads[r.identity]?.evidence == null,
    );
    return Card(
      child: ExpansionTile(
        title: Text('${relation.id} · revision ${relation.revision}'),
        subtitle: Text(
          '${current ? 'Current decision' : 'Historical decision'} · ${words(relation.kind.name)} · ${relation.reviewed ? 'reviewed' : 'unreviewed'}${stale ? ' · source revised or withdrawn' : ''}',
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Text('From: ${ref(relation.from)}'),
          Text('To: ${ref(relation.to)}'),
          Text(relation.reason),
        ],
      ),
    );
  }
}
