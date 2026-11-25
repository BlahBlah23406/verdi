// Run: dart run tool/preview_footprint.dart
// Imaginary household inputs; demonstrates reconciliation, NOT PSE compatibility.
import 'dart:convert';
import 'dart:io';

import 'package:verdi/domain/emission_factors.dart';
import 'package:verdi/domain/evidence_archive.dart';
import 'package:verdi/domain/footprint_ledger.dart';

void main() {
  final start = DateTime.utc(2026, 10), end = DateTime.utc(2026, 11);
  final electricity = FootprintFactor(
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
  );
  final meter = FootprintEvidence(
    id: 'synthetic-meter-october',
    source: 'example-only',
    coverageKey: 'person-A/home-A/october/electricity-generation',
    sector: FootprintSector.electricity,
    start: start,
    end: end,
    boundary: 'electricity-generation',
    unit: 'kWh',
    quantity: 300,
    quality: EvidenceQuality.measuredQuantity,
    reviewed: true,
    factor: electricity,
    personalShare: 0.5,
  );
  final payment = FootprintEvidence(
    id: 'synthetic-utility-payment',
    source: 'example-bank-only',
    coverageKey: 'person-A/bank/utility-payment-october',
    sector: meter.sector,
    start: start,
    end: end,
    boundary: meter.boundary,
    unit: 'USD',
    quantity: 70,
    quality: EvidenceQuality.spendEstimate,
    reviewed: true,
    // No factor required for supporting evidence suppressed by a physical record.
  );
  final meterRevision = EvidenceRevision(
    ref: EvidenceRef(meter.source, meter.id, 1),
    receivedAt: end,
    evidence: meter,
  );
  final paymentRevision = EvidenceRevision(
    ref: EvidenceRef(payment.source, payment.id, 1),
    receivedAt: end,
    evidence: payment,
  );
  final archive = EvidenceArchive().append(
    revisions: [paymentRevision, meterRevision],
    relations: [
      EvidenceRelation(
        id: 'example-utility-match',
        from: paymentRevision.ref,
        to: meterRevision.ref,
        kind: EvidenceRelationKind.supports,
        reviewed: true,
        reason: 'Synthetic bill/account/service-period match; never inferred from merchant alone.',
      ),
    ],
  );
  final restored = EvidenceArchive.fromJson(
    jsonDecode(jsonEncode(archive.toJson())) as Map<String, dynamic>,
  );
  final report = restored.reconcile(
    start: start,
    end: end,
    expectedSectors: FootprintSector.values.toSet(),
  );
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'status': 'synthetic demonstration; not a complete personal footprint',
      'retainedSourceRevisions': restored.revisions.length,
      'reviewedRelationships': restored.relations.length,
      'included': report.included.map((e) => e.id).toList(),
      'suppressed': report.suppressed.map((e) => e.id).toList(),
      'estimates': report.kgCo2eByBasis.entries
          .map(
            (e) => {
              'boundary': e.key.boundary,
              'gwp': e.key.gwp,
              'method': e.key.method,
              'kgCo2e': e.value,
            },
          )
          .toList(),
      'factorGeography': electricity.geography,
      'missingSectors': report.missingSectors.map((s) => s.name).toList(),
      'coverage': 'One synthetic monthly meter, with a declared half-household share. Missing categories are not zero.',
      'issues': report.issues
          .map((e) => {'coverageKey': e.coverageKey, 'reason': e.reason})
          .toList(),
    }),
  );
}
