import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/carbon.dart';
import '../domain/institutional_aggregation.dart';

/// Interactive sample of the personal-journal to institutional-report boundary.
class ConsentRollupCard extends StatefulWidget {
  const ConsentRollupCard({super.key, required this.organizationId});
  final String organizationId;

  @override
  State<ConsentRollupCard> createState() => _ConsentRollupCardState();
}

class _ConsentRollupCardState extends State<ConsentRollupCard> {
  bool sharing = false;

  @override
  Widget build(BuildContext context) {
    final date = DateTime(2026, 11, 6);
    final journals = List.generate(
      4,
      (i) => ConsentedJournal(
        memberId: 'sample-member-$i',
        organizationId: widget.organizationId,
        consentedAt: i == 3 || (i == 0 && !sharing) ? null : date,
        activities: [
          Activity(
            id: 'utility',
            kind: ActivityKind.electricity,
            quantity: 18 + i.toDouble(),
            date: date,
            source: 'utility-api',
          ),
          Activity(
            id: 'commute',
            kind: ActivityKind.train,
            quantity: 14.2,
            date: date,
            source: 'transport-api',
          ),
          Activity(
            id: 'device',
            kind: ActivityKind.electricity,
            quantity: 7,
            date: date,
            source: 'smart-iot',
            note: 'Separate workplace charger; outside home meter boundary',
          ),
          Activity(
            id: 'purchase',
            kind: ActivityKind.product,
            quantity: 24,
            date: date,
            source: 'bank-inference',
          ),
        ],
      ),
    );
    final rollup = const InstitutionalAggregator().aggregate(
      organizationId: widget.organizationId,
      journals: journals,
      start: DateTime(2026, 11),
      end: DateTime(2026, 12),
      asOf: date,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Consent in action · sample cohort',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Four fictional personal journals, with reviewed utility, transit, separate workplace charger and inferred purchase records. One member has never opted in.',
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Share sample member 1 with this organization'),
              subtitle: const Text(
                'Explicit opt-in. Turning off withdraws this member from the roll-up immediately.',
              ),
              value: sharing,
              onChanged: (value) => setState(() => sharing = value),
            ),
            Text(
              '${rollup.members} of 4 members sharing · ${rollup.totalKg.toStringAsFixed(2)} kg CO₂e',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Wrap(
              spacing: 16,
              children: rollup.categoriesKg.entries
                  .map(
                    (e) => Text('${e.key}: ${e.value.toStringAsFixed(2)} kg'),
                  )
                  .toList(),
            ),
            const Text(
              'Calculated from individual records using stored emission factors. Organization reports contain totals only, without personal journals. Separate from the illustrative organization scenario below.',
            ),
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copy consent-based sample report'),
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text: jsonEncode({
                      'organizationId': widget.organizationId,
                      'period': '2026-11',
                      'sampleData': true,
                      ...rollup.toJson(),
                    }),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
