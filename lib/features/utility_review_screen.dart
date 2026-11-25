// Overview: Reviews normalized electricity CSV readings, previews accounting and saves them to the evidence archive.
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/evidence_archive_store.dart';
import '../data/utility_review_service.dart';
import '../data/utility_review_store.dart';
import '../domain/automation.dart';
import '../domain/evidence_archive.dart';
import '../domain/footprint_ledger.dart';
import '../domain/service_zone.dart';
import '../domain/utility_evidence_adapter.dart';
import '../domain/utility_review.dart';
import 'evidence_archive_screen.dart';

class UtilityReviewScreen extends StatefulWidget {
  const UtilityReviewScreen({
    super.key,
    required this.archive,
    required this.reviews,
    this.journalIds,
    this.clock,
  });
  final EvidenceArchiveStore archive;
  final UtilityReviewStore reviews;

  /// Candidate IDs already in the journal or basic review queue.
  final Set<String> Function()? journalIds;
  final DateTime Function()? clock;

  @override
  State<UtilityReviewScreen> createState() => _UtilityReviewScreenState();
}

class _UtilityReviewScreenState extends State<UtilityReviewScreen> {
  static const newMeter = '__new__';
  late final service = UtilityReviewService(
    archive: widget.archive,
    reviews: widget.reviews,
  );
  final nickname = TextEditingController();
  final csv = TextEditingController();
  final share = TextEditingController();
  final reviewer = TextEditingController();
  final reason = TextEditingController();
  UtilityReviewState? state;
  String? loadError, formError, saveError, saved;
  String meterChoice = newMeter;
  ServiceZone? zone;
  FootprintFactor? factor;
  EvidenceQuality? quality;
  UtilityReviewDecision? decision;
  bool consent = false, confirmCorrections = false, saving = false;
  UtilityImportPlan? plan;
  UtilityMeter? pendingMeter;
  int journalOverlap = 0;

  DateTime now() => (widget.clock?.call() ?? DateTime.now()).toUtc();

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    for (final c in [nickname, csv, share, reviewer, reason]) {
      c.dispose();
    }
    super.dispose();
  }

  void reload() {
    try {
      widget.archive.load();
      state = widget.reviews.load();
      loadError = null;
    } on FormatException catch (e) {
      state = null;
      loadError = '${e.message} Nothing will be saved until it is restored.';
    } catch (_) {
      state = null;
      loadError = 'Saved evidence could not be read. Nothing will be saved until it is restored.';
    }
    if (state != null &&
        meterChoice == newMeter &&
        pendingMeter != null &&
        state!.meters.any((m) => m.namespace == pendingMeter!.namespace)) {
      meterChoice = pendingMeter!.namespace;
      pendingMeter = null;
    }
    if (state != null &&
        meterChoice != newMeter &&
        !state!.meters.any((m) => m.namespace == meterChoice)) {
      meterChoice = newMeter;
    }
  }

  /// Any edit invalidates the preview; it must be built again before saving.
  void edited([VoidCallback? change]) => setState(() {
    change?.call();
    plan = null;
    saved = null;
    saveError = null;
  });

  UtilityMeter? selectedMeter() {
    if (meterChoice != newMeter) {
      return state!.meters.firstWhere((m) => m.namespace == meterChoice);
    }
    final label = nickname.text.trim();
    final problem = validateMeterLabel(label);
    if (problem != null) throw ArgumentError(problem);
    final existing = state!.meterByLabel(label);
    if (existing != null) {
      throw ArgumentError(
        'A meter named "${existing.label}" exists. Select it so its identity is reused.',
      );
    }
    // Keep one generated identity per unsaved new meter while previewing.
    final kept = pendingMeter;
    if (kept != null && kept.label == label && kept.zoneId == zone!.id) {
      return kept;
    }
    return pendingMeter = UtilityReviewService.newMeter(
      label: label,
      zoneId: zone!.id,
      now: now(),
    );
  }

  Future<void> chooseFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || !mounted) return;
      final file = result.files.single;
      if (file.size > 1000000 || file.bytes == null) {
        throw const FormatException('Choose a readable CSV smaller than 1 MB.');
      }
      final text = utf8.decode(file.bytes!);
      edited(() => csv.text = text);
    } catch (e) {
      edited(
        () => formError = e is FormatException
            ? e.message
            : 'The file could not be read.',
      );
    }
  }

  void preview() {
    setState(() {
      plan = null;
      saved = null;
      saveError = null;
      formError = null;
      reload();
      if (loadError != null) return;
      try {
        if (meterChoice == newMeter) {
          final problem = validateMeterLabel(nickname.text.trim());
          if (problem != null) throw ArgumentError(problem);
        }
        if (zone == null) throw ArgumentError('Choose the service time zone.');
        if (factor == null) {
          throw ArgumentError('Choose an electricity factor.');
        }
        if (quality == null) {
          throw ArgumentError('Choose the evidence quality.');
        }
        if (decision == null) throw ArgumentError('Choose a review decision.');
        final percent = double.tryParse(share.text.trim());
        if (percent == null) {
          throw ArgumentError(
            'Enter your share of this meter as a percentage.',
          );
        }
        final meter = selectedMeter()!;
        final archive = widget.archive.load();
        plan = planUtilityImport(
          csv: csv.text,
          meter: meter,
          choices: UtilityReviewChoices(
            zone: zone!,
            factor: factor!,
            quality: quality!,
            personalShare: percent / 100,
            decision: decision!,
            reviewer: reviewer.text,
            reason: reason.text,
            consentAcknowledged: consent,
            confirmCorrections: confirmCorrections,
          ),
          archive: archive,
          now: now(),
          batchId: UtilityReviewService.newBatchId(),
        );
        final known = widget.journalIds?.call() ?? const <String>{};
        journalOverlap = parseUtilityCsv(
          csv.text,
          meter.label,
        ).where((c) => known.contains(c.id)).length;
      } on ArgumentError catch (e) {
        formError = '${e.message}';
      } on FormatException catch (e) {
        formError = e.message;
      } catch (_) {
        formError = 'The preview could not be built. Nothing was saved.';
      }
    });
  }

  Future<void> save() async {
    final current = plan;
    if (current == null) return;
    setState(() {
      saving = true;
      saveError = null;
    });
    try {
      await service.save(current);
      if (!mounted) return;
      setState(() {
        saved =
            'Saved ${current.changes.length} revisions to the experimental evidence archive. Your journal and dashboard are unchanged.';
        plan = null;
        pendingMeter = null;
        reload();
        meterChoice = current.meter.namespace;
      });
    } on StaleEvidenceException catch (e) {
      if (mounted) {
        setState(() {
          plan = null;
          reload();
          saveError = e.toString();
        });
      }
    } on FormatException {
      if (mounted) {
        setState(() {
          saveError = 'Saved evidence could not be read, so nothing was written. Restore it, then retry.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saveError = 'Saving did not finish. Retrying is safe: already-saved revisions are not duplicated.';
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review electricity evidence')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Experimental evidence archive. Saving here does not add journal activities or change dashboard totals. '
                  'Readings stay held unless you approve them, and each correction becomes a new revision. '
                  'This reads the normalized format below; it is not a live utility connection or a native provider export.',
                ),
              ),
            ),
            if (loadError != null) ...[
              const SizedBox(height: 12),
              Text(loadError!, style: const TextStyle(color: Colors.red)),
              TextButton(
                onPressed: () => setState(reload),
                child: const Text('Reload saved data'),
              ),
            ],
            if (state != null) ...meterSection(),
            heading('Readings'),
            TextField(
              key: const ValueKey('utility-csv'),
              controller: csv,
              minLines: 3,
              maxLines: 8,
              onChanged: (_) => edited(),
              decoration: const InputDecoration(
                labelText: 'Normalized CSV',
                hintText: 'record_id,date,kwh\nreading-001,2026-01-01,12.5',
                border: OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: chooseFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Choose CSV file'),
              ),
            ),
            ...reviewSection(),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: loadError != null || saving ? null : preview,
              child: const Text('Preview accounting'),
            ),
            if (formError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  formError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (plan != null) ...previewSection(plan!),
            if (saveError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  saveError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (saved != null) ...[
              const SizedBox(height: 12),
              Text(saved!),
              OutlinedButton.icon(
                onPressed: openHistory,
                icon: const Icon(Icons.history),
                label: const Text('Open evidence history'),
              ),
            ],
            if (state != null && state!.batches.isNotEmpty) ...batchSection(),
          ],
        ),
      ),
    ),
  );

  DateTime? lastMonth;
  Future<void> openHistory() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) =>
          EvidenceArchiveScreen(store: widget.archive, initialMonth: lastMonth),
    ),
  );

  Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ),
  );

  List<Widget> meterSection() => [
    heading('Meter'),
    DropdownButtonFormField<String>(
      key: const ValueKey('meter-choice'),
      isExpanded: true,
      initialValue: meterChoice,
      decoration: const InputDecoration(labelText: 'Meter'),
      items: [
        for (final m in state!.meters)
          DropdownMenuItem(
            value: m.namespace,
            child: Text(m.label, overflow: TextOverflow.ellipsis),
          ),
        const DropdownMenuItem(
          value: newMeter,
          child: Text('New meter…', overflow: TextOverflow.ellipsis),
        ),
      ],
      onChanged: (v) => edited(() {
        meterChoice = v!;
        if (v != newMeter) {
          zone = ServiceZone.byId(
            state!.meters.firstWhere((m) => m.namespace == v).zoneId,
          );
        }
      }),
    ),
    if (meterChoice == newMeter)
      TextField(
        key: const ValueKey('meter-nickname'),
        controller: nickname,
        maxLength: 80,
        onChanged: (_) => edited(),
        decoration: const InputDecoration(
          labelText: 'Meter nickname',
          helperText: 'A local label such as "Home". Do not enter account or meter numbers.',
          helperMaxLines: 3,
        ),
      )
    else
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Pseudonymous archive ID: $meterChoice · reused for every import of this meter.',
        ),
      ),
    const SizedBox(height: 4),
    const Text(
      'Verdi assigns each meter a random archive ID. It is reused on later imports so corrections and duplicates are recognized.',
    ),
  ];

  List<Widget> reviewSection() => [
    heading('Review'),
    DropdownButtonFormField<ServiceZone>(
      key: ValueKey('zone-$meterChoice'),
      isExpanded: true,
      initialValue: zone,
      decoration: const InputDecoration(
        labelText: 'Service time zone',
        helperText: 'Dates are local service days. Only listed zones and dates are supported.',
        helperMaxLines: 3,
      ),
      items: [
        for (final z in ServiceZone.supported)
          DropdownMenuItem(
            value: z,
            child: Text(
              '${z.label} · ${z.firstDate.year}–${z.lastDate.year}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: meterChoice == newMeter ? (z) => edited(() => zone = z) : null,
    ),
    DropdownButtonFormField<FootprintFactor>(
      key: const ValueKey('factor'),
      isExpanded: true,
      initialValue: factor,
      decoration: const InputDecoration(labelText: 'Electricity factor'),
      items: [
        for (final f in utilityFactorChoices)
          DropdownMenuItem(
            value: f,
            child: Text(
              '${f.geography} · ${f.kgCo2ePerUnit.toStringAsFixed(3)} kg/kWh · ${f.version}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (f) => edited(() => factor = f),
    ),
    if (factor != null)
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${factor!.boundary} · ${factor!.accountingMethod} · ${factor!.gwpVersion} · data year ${factor!.dataYear}\n${factor!.sourceUrl}',
        ),
      ),
    DropdownButtonFormField<EvidenceQuality>(
      key: const ValueKey('quality'),
      isExpanded: true,
      initialValue: quality,
      decoration: const InputDecoration(
        labelText: 'Evidence quality',
        helperText:
            'Normalized CSV has no actual/estimated flag; state what your source confirms.',
        helperMaxLines: 3,
      ),
      items: [
        for (final q in utilityQualityChoices)
          DropdownMenuItem(
            value: q,
            child: Text(
              utilityQualityLabel(q),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (q) => edited(() => quality = q),
    ),
    TextField(
      key: const ValueKey('share'),
      controller: share,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => edited(),
      decoration: const InputDecoration(
        labelText: 'Your share of this meter (%)',
        helperText: 'For example 50 if two people share the home equally.',
        helperMaxLines: 3,
      ),
    ),
    DropdownButtonFormField<UtilityReviewDecision>(
      key: const ValueKey('decision'),
      isExpanded: true,
      initialValue: decision,
      decoration: const InputDecoration(labelText: 'Decision'),
      items: const [
        DropdownMenuItem(
          value: UtilityReviewDecision.approved,
          child: Text(
            'Approve for accounting',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem(
          value: UtilityReviewDecision.pendingReview,
          child: Text(
            'Keep pending (held, not counted)',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
      onChanged: (d) => edited(() => decision = d),
    ),
    TextField(
      key: const ValueKey('reviewer'),
      controller: reviewer,
      maxLength: 80,
      onChanged: (_) => edited(),
      decoration: const InputDecoration(labelText: 'Reviewer name or initials'),
    ),
    TextField(
      key: const ValueKey('reason'),
      controller: reason,
      maxLength: 280,
      onChanged: (_) => edited(),
      decoration: const InputDecoration(labelText: 'Review reason'),
    ),
    CheckboxListTile(
      key: const ValueKey('consent'),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: consent,
      onChanged: (v) => edited(() => consent = v ?? false),
      title: const Text(utilityConsentStatement),
    ),
  ];

  List<Widget> previewSection(UtilityImportPlan p) {
    final corrections = p.count(UtilityRowStatus.correction);
    final rejected = p.rows.where((r) => r.status == UtilityRowStatus.rejected);
    final months = p.months;
    lastMonth = months.isEmpty ? null : months.first;
    return [
      heading('Preview'),
      Text(
        '${p.count(UtilityRowStatus.added)} new · ${p.count(UtilityRowStatus.unchanged)} already archived · $corrections corrections · ${rejected.length} rejected',
      ),
      Text('Meter ${p.meter.label} · ${p.meter.namespace}'),
      if (journalOverlap > 0)
        Text(
          '$journalOverlap of these readings are also in your journal or basic review queue. Saving here does not add them to the journal again or to dashboard totals.',
        ),
      if (corrections > 0)
        CheckboxListTile(
          key: const ValueKey('confirm-corrections'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: confirmCorrections,
          onChanged: (v) {
            confirmCorrections = v ?? false;
            preview();
          },
          title: Text(
            'Save $corrections changed readings as corrections (new revisions; earlier revisions are kept).',
          ),
        ),
      for (final r in p.rows.take(60)) rowTile(r),
      if (p.rows.length > 60) Text('+${p.rows.length - 60} more readings'),
      heading('Accounting preview (UTC months)'),
      for (final m in months) monthTile(p.projected, m),
      const Text(
        'Days crossing a UTC month boundary are held, not prorated. Pending readings are held. Missing sectors are not zero emissions.',
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: saving || p.changes.isEmpty || p.hasUnconfirmedCorrections
            ? null
            : save,
        icon: const Icon(Icons.save_outlined),
        label: Text(
          saveError == null ? 'Save to evidence archive' : 'Retry save',
        ),
      ),
      if (p.changes.isEmpty)
        const Text(
          'Nothing new to save: every reading is already archived or rejected.',
        ),
    ];
  }

  Widget rowTile(UtilityPlanRow r) {
    final e = r.evidence;
    final String detail;
    switch (r.status) {
      case UtilityRowStatus.rejected:
        detail = 'Rejected: ${r.problem}';
      case UtilityRowStatus.unchanged:
        detail = 'Already archived as revision ${r.previous!.ref.revision}';
      case UtilityRowStatus.correction:
        final old = r.previous!.evidence;
        detail =
            'Correction of revision ${r.previous!.ref.revision}${old == null ? ' (withdrawn)' : ' (${old.quantity} kWh)'}'
            '${r.change == null ? ' · needs confirmation' : ' → revision ${r.change!.revision.ref.revision}'}';
      case UtilityRowStatus.added:
        detail = 'New · revision 1';
    }
    final interval = e == null
        ? ''
        : '\n${e.start.toIso8601String()} – ${e.end.toIso8601String()}'
              '${e.reviewed ? ' · ${e.kgCo2e.toStringAsFixed(2)} kg CO₂e' : ' · held pending review'}';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('${r.date} · ${r.recordId} · ${r.kwh} kWh'),
      subtitle: Text('$detail$interval'),
    );
  }

  Widget monthTile(EvidenceArchive archive, DateTime month) {
    final end = DateTime.utc(month.year, month.month + 1);
    final label = month.toIso8601String().substring(0, 7);
    try {
      final report = archive.reconcile(start: month, end: end);
      final totals = report.kgCo2eByBasis;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            [
              '$label · ${report.included.length} included · ${report.issues.length} held',
              if (totals.isEmpty) 'No accepted estimate',
              for (final t in totals.entries)
                '${t.value.toStringAsFixed(2)} kg CO₂e · ${t.key.boundary} · ${t.key.method}',
            ].join('\n'),
          ),
        ),
      );
    } catch (_) {
      return Text('$label could not be calculated; nothing was changed.');
    }
  }

  List<Widget> batchSection() => [
    heading('Saved review batches'),
    for (final b in state!.batches.reversed)
      ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(
          '${state!.meters.where((m) => m.namespace == b.namespace).map((m) => m.label).firstOrNull ?? b.namespace} · ${b.revisionKeys.length} revisions · ${b.decision == UtilityReviewDecision.approved ? 'approved' : 'pending'}',
        ),
        subtitle: Text(
          'Reviewed by ${b.reviewer} at ${b.reviewedAt.toIso8601String()} · ${b.reason}\n'
          'Consent acknowledged: ${b.consentVersion} · ${b.zoneId} · ${b.factorId} ${b.factorVersion}'
          '${b.quality == null ? '' : ' · ${b.quality!.name}'}'
          ' · share ${(b.personalShare * 100).toStringAsFixed(0)}%',
        ),
      ),
  ];
}
