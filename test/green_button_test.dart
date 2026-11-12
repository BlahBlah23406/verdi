import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:verdi/data/activity_store.dart';
import 'package:verdi/data/automation_store.dart';
import 'package:verdi/domain/carbon.dart';
import 'package:verdi/services/multi_source/green_button_adapter.dart';
import 'package:verdi/services/multi_source/ingestion_orchestrator.dart';
import 'package:verdi/services/multi_source/reconciliation_engine.dart';
import 'package:verdi/services/multi_source/source_registry.dart';

void main() {
  final fixture = File('examples/green-button-electricity.xml')
      .readAsStringSync();
  final now = DateTime.utc(2026, 11, 12);
  List<dynamic> parse(String xml) =>
      parseGreenButtonXml(xml, account: 'Home', now: now);

  test(
    'maps ESPI Wh intervals to UTC kWh without raw account/link identifiers',
    () {
      final readings = parseGreenButtonXml(fixture, account: 'Home', now: now);
      expect(readings.map((r) => r.quantity), [1.25, 0.75]);
      expect(readings.first.start, DateTime.utc(2026));
      expect(readings.first.end, DateTime.utc(2026, 1, 1, 1));
      expect(readings.first.kind, ActivityKind.electricity);
      expect(readings.first.confidence, isNull);
      expect(readings.first.metadata['accuracyVerified'], false);
      expect(readings.first.id, isNot(contains('Home')));
      expect(
        readings.first.toJson().toString(),
        isNot(contains('example.invalid')),
      );
      expect(
        parseGreenButtonXml(fixture, account: 'Other', now: now).first.id,
        readings.first.id,
      ); // Nicknames cannot bypass repeat-import deduplication.
    },
  );

  test('uses namespace URIs rather than fixed XML prefixes', () {
    expect(
      parse(
        fixture
            .replaceAll('espi:', 'gb:')
            .replaceAll('xmlns:espi=', 'xmlns:gb='),
      ),
      hasLength(2),
    );
  });

  test('applies positive and negative power-of-ten scaling', () {
    final positive = fixture.replaceAll('Multiplier>0<', 'Multiplier>3<');
    final negative = fixture.replaceAll('Multiplier>0<', 'Multiplier>-3<');
    expect(
      parseGreenButtonXml(positive, account: 'Home', now: now).first.quantity,
      1250,
    );
    expect(
      parseGreenButtonXml(negative, account: 'Home', now: now).first.quantity,
      0.00125,
    );
  });

  test('resolves relative Atom links through inherited xml:base', () {
    final relative = fixture
        .replaceFirst(
          '<feed ',
          '<feed xml:base="https://example.invalid/espi/" ',
        )
        .replaceAll('href="https://example.invalid/espi/', 'href="');
    expect(
      parseGreenButtonXml(relative, account: 'Home', now: now).first.id,
      parseGreenButtonXml(fixture, account: 'Home', now: now).first.id,
    );
  });

  test(
    'does not accept unsafe XML, mismatched namespaces or unresolved links',
    () {
      for (final bad in [
        '<!DOCTYPE feed [<!ENTITY x "y">]>$fixture',
        fixture.replaceAll('http://naesb.org/espi', 'http://wrong.example'),
        fixture.replaceFirst('rel="related"', 'rel="broken"'),
        '<feed>',
        ' ' * 1000001,
      ]) {
        expect(() => parse(bad), throwsFormatException);
      }
      expect(
        () => parseGreenButtonXml(fixture, account: ''),
        throwsFormatException,
      );
    },
  );

  test(
    'rejects power, gas, export, cumulative, unknown units and missing scaling',
    () {
      for (final bad in [
        fixture.replaceAll('uom>72<', 'uom>38<'),
        fixture.replaceAll('commodity>1<', 'commodity>7<'),
        fixture.replaceAll('flowDirection>1<', 'flowDirection>2<'),
        fixture.replaceAll(
          'accumulationBehaviour>4<',
          'accumulationBehaviour>12<',
        ),
        fixture.replaceAll('kind>12<', 'kind>37<'),
        fixture.replaceAll('Multiplier>0<', 'Multiplier>99<'),
        fixture.replaceAll(
          '<espi:powerOfTenMultiplier>0</espi:powerOfTenMultiplier>',
          '',
        ),
      ]) {
        expect(() => parse(bad), throwsFormatException);
      }
    },
  );

  test('validates durations, timestamps, integer values and overlapping intervals atomically', () {
    for (final bad in [
      fixture.replaceAll('duration>3600<', 'duration>0<'),
      fixture.replaceAll('value>1250<', 'value>-1<'),
      fixture.replaceAll('value>1250<', 'value>1.25<'),
      fixture.replaceAll('1767225600', '4767225600'),
      fixture.replaceAll('1767229200', '1767226600'),
    ]) {
      expect(() => parse(bad), throwsFormatException);
    }
  });

  test(
    'zero consumption is valid and does not create a positive-emissions record',
    () {
      expect(
        parse(
          fixture
              .replaceAll('value>1250<', 'value>0<')
              .replaceAll('value>750<', 'value>0<'),
        ),
        isEmpty,
      );
    },
  );

  test('resolves each meter type separately in multi-meter exports', () {
    final entries = fixture.substring(
      fixture.indexOf('  <entry>'),
      fixture.indexOf('</feed>'),
    );
    final other = entries
        .replaceAll('ReadingType/1', 'ReadingType/2')
        .replaceAll('MeterReading/1', 'MeterReading/2')
        .replaceAll('Multiplier>0<', 'Multiplier>3<');
    final readings = parseGreenButtonXml(
      fixture.replaceFirst('</feed>', '$other</feed>'),
      account: 'Home',
      now: now,
    );
    expect(readings, hasLength(4));
    expect(readings.fold<double>(0, (n, r) => n + r.quantity), 2002);
  });

  test(
    'default registry has no simulation, disconnected import yields no data',
    () async {
      final registry = MultiSourceRegistry();
      expect(registry.listAdapters(), hasLength(1));
      final real = registry.getAdapter('utility-green-button')!;
      expect(real.isConnected, false);
      expect(await real.fetchCandidates(), isEmpty);
      final connected = GreenButtonUtilityAdapter(
        xml: fixture,
        account: 'Home',
        now: now,
      );
      expect(connected.isConnected, true);
      expect(
        await connected.fetchCandidates(since: DateTime.utc(2026, 1, 1, 1)),
        hasLength(1),
      );
    },
  );

  test('real import survives reconciliation, queues review, confirms and deduplicates repeat files', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final activities = ActivityStore(preferences);
    final queue = AutomationStore(preferences);
    final adapter = GreenButtonUtilityAdapter(
      xml: fixture,
      account: 'Home',
      now: now,
    );
    final raw = await adapter.fetchCandidates();
    expect(const ReconciliationEngine().reconcile(raw), hasLength(2));
    final orchestrator = IngestionOrchestrator(
      registry: MultiSourceRegistry([adapter]),
      automationStore: queue,
      activityStore: activities,
    );
    final first = await orchestrator.ingest();
    expect(first.queuedCount, 2);
    expect(activities.load(), isEmpty); // Mandatory user review.
    expect(
      queue.load().pending.fold<double>(0, (sum, r) => sum + r.quantity),
      2,
    );
    await activities.save(
      queue
          .load()
          .pending
          .map((r) => r.confirm(ActivityKind.electricity))
          .toList(),
    );
    expect(activities.load().fold<double>(0, (sum, a) => sum + a.quantity), 2);
    expect((await orchestrator.ingest()).queuedCount, 0);
    expect((await orchestrator.ingest()).duplicatesSkipped, 2);
  });
}
