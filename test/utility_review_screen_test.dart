// Overview: Drives the reviewed electricity flow from CSV text through preview, save and reload.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:verdi/data/activity_store.dart';
import 'package:verdi/data/automation_store.dart';
import 'package:verdi/data/evidence_archive_store.dart';
import 'package:verdi/data/utility_review_service.dart';
import 'package:verdi/data/utility_review_store.dart';
import 'package:verdi/domain/evidence_archive.dart';
import 'package:verdi/domain/footprint_ledger.dart';
import 'package:verdi/domain/service_zone.dart';
import 'package:verdi/domain/utility_evidence_adapter.dart';
import 'package:verdi/domain/utility_review.dart';
import 'package:verdi/features/utility_review_screen.dart';
import 'package:verdi/main.dart';

class KeyFailingStore extends InMemorySharedPreferencesStore {
  KeyFailingStore() : super.empty();
  bool fail = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (fail && key.endsWith(EvidenceArchiveStore.key)) return false;
    return super.setValue(valueType, key, value);
  }
}

const fixture =
    'record_id,date,kwh\nr-14,2026-10-14,10\nr-15,2026-10-15,12.5\n';
final clock = DateTime.utc(2026, 11, 3, 18);

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1000, 6000);
    view.devicePixelRatio = 1;
  });
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String key, String item) async {
    await tap(tester, find.byKey(ValueKey(key)));
    await tester.tap(find.textContaining(item).last);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.enterText(find.byKey(ValueKey(key)), text);
    await tester.pump();
  }

  /// Fills every review field. [nickname] null selects the existing meter.
  Future<void> review(
    WidgetTester tester, {
    String? nickname = 'Home',
    String csv = fixture,
    String quality = 'Confirmed quantity',
  }) async {
    if (nickname != null) {
      await enter(tester, 'meter-nickname', nickname);
      await choose(tester, 'zone-__new__', 'America/Los_Angeles');
    }
    await enter(tester, 'utility-csv', csv);
    await choose(tester, 'factor', 'US national average');
    await choose(tester, 'quality', quality);
    await enter(tester, 'share', '50');
    await choose(tester, 'decision', 'Approve for accounting');
    await enter(tester, 'reviewer', 'SH');
    await enter(tester, 'reason', 'October readings');
    await tap(tester, find.byKey(const ValueKey('consent')));
    await tap(tester, find.text('Preview accounting'));
  }

  Future<(SharedPreferences, EvidenceArchiveStore, UtilityReviewStore)>
  pumpScreen(
    WidgetTester tester, [
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final archive = EvidenceArchiveStore(prefs);
    final reviews = UtilityReviewStore(prefs);
    await tester.pumpWidget(
      MaterialApp(
        home: UtilityReviewScreen(
          archive: archive,
          reviews: reviews,
          clock: () => clock,
        ),
      ),
    );
    return (prefs, archive, reviews);
  }

  testWidgets(
    'Auto track route reviews CSV, previews, saves to the archive only and reloads',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final activities = ActivityStore(prefs);
      await tester.pumpWidget(VerdiApp(store: activities));
      await tester.tap(find.text('Auto track'));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Review into evidence archive'));
      expect(
        find.textContaining('does not add journal activities'),
        findsOneWidget,
      );

      // Saving is impossible before an explicit preview.
      expect(find.text('Save to evidence archive'), findsNothing);
      await tap(tester, find.text('Preview accounting'));
      expect(find.textContaining('Enter a meter nickname'), findsOneWidget);
      await enter(tester, 'meter-nickname', 'Acct 12345678');
      await tap(tester, find.text('Preview accounting'));
      expect(
        find.textContaining('Do not use account or meter numbers'),
        findsOneWidget,
      );
      await enter(tester, 'meter-nickname', 'Home');
      await tap(tester, find.text('Preview accounting'));
      expect(
        find.textContaining('Choose the service time zone'),
        findsOneWidget,
      );
      await choose(tester, 'zone-__new__', 'America/Los_Angeles');
      await choose(tester, 'factor', 'US national average');
      await tap(tester, find.text('Preview accounting'));
      expect(
        find.textContaining('Choose the evidence quality'),
        findsOneWidget,
      );

      await review(tester);
      expect(find.textContaining('2 new · 0 already archived'), findsOneWidget);
      expect(
        find.textContaining(
          '2026-10-15T07:00:00.000Z – 2026-10-16T07:00:00.000Z',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('2026-10 · 2 included · 0 held'),
        findsOneWidget,
      );
      final kg = 22.5 * 0.5 * utilityFactorChoices.single.kgCo2ePerUnit;
      expect(
        find.textContaining('${kg.toStringAsFixed(2)} kg CO₂e ·'),
        findsOneWidget,
      );

      // An edit after preview invalidates it.
      await enter(tester, 'share', '60');
      expect(find.text('Save to evidence archive'), findsNothing);
      await enter(tester, 'share', '50');
      await tap(tester, find.text('Preview accounting'));
      await tap(tester, find.text('Save to evidence archive'));
      expect(find.textContaining('Saved 2 revisions'), findsOneWidget);

      // Archive written; journal and basic review queue untouched.
      final archive = EvidenceArchiveStore(prefs).load();
      expect(archive.revisions, hasLength(2));
      expect(activities.load(), isEmpty);
      expect(AutomationStore(prefs).load().pending, isEmpty);
      final saved = UtilityReviewStore(prefs).load();
      expect(saved.batches.single.reviewer, 'SH');
      expect(saved.batches.single.consentVersion, utilityConsentVersion);
      expect(saved.batches.single.quality, EvidenceQuality.confirmedQuantity);
      expect(
        EvidenceArchiveStore(prefs).loadBatches().single.quality,
        EvidenceQuality.confirmedQuantity,
      );
      final namespace = saved.meters.single.namespace;
      expect(archive.revisions.every((r) => r.ref.source == namespace), isTrue);
      expect(
        prefs.getString(EvidenceArchiveStore.key),
        isNot(contains('Home')),
      );

      // Inspect after reload in the read-only history.
      await tap(tester, find.text('Open evidence history'));
      expect(find.text('Evidence history'), findsOneWidget);
      expect(find.textContaining('2 included'), findsOneWidget);
      expect(
        find.textContaining('${kg.toStringAsFixed(2)} kg CO₂e'),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      // A fresh screen reloads the durable meter and provenance; the same file
      // is recognized as already archived.
      await tap(tester, find.text('Review into evidence archive'));
      expect(find.textContaining('Saved review batches'), findsOneWidget);
      expect(find.textContaining('Reviewed by SH'), findsOneWidget);
      await choose(tester, 'meter-choice', 'Home');
      expect(find.textContaining(namespace), findsOneWidget);
      await review(tester, nickname: null);
      expect(find.textContaining('0 new · 2 already archived'), findsOneWidget);
      expect(find.textContaining('Nothing new to save'), findsOneWidget);
      final save = find.widgetWithText(
        FilledButton,
        'Save to evidence archive',
      );
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      // A corrected reading needs confirmation and becomes revision 2.
      await enter(
        tester,
        'utility-csv',
        'record_id,date,kwh\nr-14,2026-10-14,11\nr-15,2026-10-15,12.5\n',
      );
      await tap(tester, find.text('Preview accounting'));
      expect(find.textContaining('1 corrections'), findsOneWidget);
      expect(find.textContaining('needs confirmation'), findsOneWidget);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tap(tester, find.byKey(const ValueKey('confirm-corrections')));
      expect(find.textContaining('→ revision 2'), findsOneWidget);
      await tap(tester, find.text('Save to evidence archive'));
      expect(find.textContaining('Saved 1 revisions'), findsOneWidget);
      final head = EvidenceArchiveStore(prefs)
          .load()
          .heads[(namespace, 'r-14')]!;
      expect((head.ref.revision, head.evidence!.quantity), (2, 11.0));
      expect(UtilityReviewStore(prefs).load().meters, hasLength(1));
      expect(UtilityReviewStore(prefs).load().batches, hasLength(2));
      expect(activities.load(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a new meter cannot silently reuse an existing nickname', (
    tester,
  ) async {
    final (_, archive, reviews) = await pumpScreen(tester);
    final meter = UtilityReviewService.newMeter(
      label: 'Home',
      zoneId: ServiceZone.losAngeles.id,
      now: clock,
    );
    await reviews.update((s) => s.withMeter(meter));
    await tester.pumpWidget(
      MaterialApp(
        home: UtilityReviewScreen(
          key: const ValueKey('again'),
          archive: archive,
          reviews: reviews,
          clock: () => clock,
        ),
      ),
    );
    await review(tester, nickname: 'home');
    expect(
      find.textContaining('Select it so its identity is reused'),
      findsOneWidget,
    );
    expect(find.text('Save to evidence archive'), findsNothing);
  });

  testWidgets('a concurrent change to the meter makes the preview stale', (
    tester,
  ) async {
    final (prefs, archive, reviews) = await pumpScreen(tester);
    await review(tester);
    expect(find.text('Save to evidence archive'), findsOneWidget);
    // Another save for the same meter lands after this preview was built.
    final namespace =
        (tester.widget<Text>(find.textContaining('Meter Home · ')).data!)
            .split(' · ')
            .last;
    final meter = UtilityMeter(
      namespace: namespace,
      label: 'Home',
      zoneId: ServiceZone.losAngeles.id,
      createdAt: clock,
    );
    final other = planUtilityImport(
      csv: 'record_id,date,kwh\nr-15,2026-10-15,99\n',
      meter: meter,
      choices: UtilityReviewChoices(
        zone: ServiceZone.losAngeles,
        factor: utilityFactorChoices.single,
        quality: EvidenceQuality.confirmedQuantity,
        personalShare: 1,
        decision: UtilityReviewDecision.pendingReview,
        reviewer: 'other device',
        reason: 'concurrent',
        consentAcknowledged: true,
      ),
      archive: EvidenceArchive(),
      now: clock,
      batchId: 'concurrent',
    );
    await UtilityReviewService(archive: archive, reviews: reviews).save(other);
    await tap(tester, find.text('Save to evidence archive'));
    expect(find.textContaining('changed after this preview'), findsOneWidget);
    expect(find.text('Save to evidence archive'), findsNothing);
    final saved = EvidenceArchiveStore(prefs).load();
    expect(saved.revisions.single.evidence!.quantity, 99);
    // Previewing again shows the concurrent head and treats it as a correction.
    await tap(tester, find.text('Preview accounting'));
    expect(
      find.textContaining('1 new · 0 already archived · 1 corrections'),
      findsOneWidget,
    );
  });

  testWidgets('failed archive storage shows an error and retry saves once', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final backend = KeyFailingStore();
    SharedPreferencesStorePlatform.instance = backend;
    final prefs = await SharedPreferences.getInstance();
    final archive = EvidenceArchiveStore(prefs);
    await tester.pumpWidget(
      MaterialApp(
        home: UtilityReviewScreen(
          archive: archive,
          reviews: UtilityReviewStore(prefs),
          clock: () => clock,
        ),
      ),
    );
    await review(tester);
    backend.fail = true;
    await tap(tester, find.text('Save to evidence archive'));
    expect(find.textContaining('Retrying is safe'), findsOneWidget);
    expect(archive.load().revisions, isEmpty);
    expect(UtilityReviewStore(prefs).load().batches, isEmpty);
    backend.fail = false;
    await tap(tester, find.text('Retry save'));
    expect(find.textContaining('Saved 2 revisions'), findsOneWidget);
    await prefs.reload();
    expect(EvidenceArchiveStore(prefs).load().revisions, hasLength(2));
    expect(UtilityReviewStore(prefs).load().batches, hasLength(1));
  });

  testWidgets('a corrupt archive blocks preview and is left unchanged', (
    tester,
  ) async {
    final (prefs, _, _) = await pumpScreen(tester, {
      EvidenceArchiveStore.key: 'broken',
    });
    expect(find.textContaining('Nothing will be saved'), findsOneWidget);
    final preview = find.widgetWithText(FilledButton, 'Preview accounting');
    expect(tester.widget<FilledButton>(preview).onPressed, isNull);
    expect(prefs.getString(EvidenceArchiveStore.key), 'broken');
    expect(prefs.getString(UtilityReviewStore.key), isNull);
  });

  testWidgets(
    'review form renders, previews and saves on a narrow 360px phone at 1.5x text scale without overflow',
    (tester) async {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(360, 800);
      view.devicePixelRatio = 1;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: UtilityReviewScreen(
              archive: EvidenceArchiveStore(prefs),
              reviews: UtilityReviewStore(prefs),
              clock: () => clock,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Keep the 360px narrow width and 1.5x text scale while extending height
      // so every form dropdown, preview row and saved batch receipt is laid out.
      view.physicalSize = const Size(360, 6000);
      await tester.pumpAndSettle();
      await review(tester, quality: 'Actual meter reading');
      expect(find.textContaining('2 new · 0 already archived'), findsOneWidget);
      await tap(tester, find.text('Save to evidence archive'));
      expect(find.textContaining('Saved 2 revisions'), findsOneWidget);
      expect(find.textContaining('measuredQuantity'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
