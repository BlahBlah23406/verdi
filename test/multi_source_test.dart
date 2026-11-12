// Overview: Unit tests for multi-source adapters, registry, reconciliation engine, and ingestion orchestrator.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:verdi/data/activity_store.dart';
import 'package:verdi/data/automation_store.dart';
import 'package:verdi/domain/automation.dart';
import 'package:verdi/domain/carbon.dart';
import 'package:verdi/services/multi_source/bank_inference_adapter.dart';
import 'package:verdi/services/multi_source/ingestion_orchestrator.dart';
import 'package:verdi/services/multi_source/reconciliation_engine.dart';
import 'package:verdi/services/multi_source/green_button_adapter.dart';
import 'package:verdi/services/multi_source/smart_iot_adapter.dart';
import 'package:verdi/services/multi_source/source_registry.dart';
import 'package:verdi/services/multi_source/transport_adapter.dart';
import 'package:verdi/services/multi_source/utility_adapter.dart';

void main() {
  group('Multi-Source Adapters', () {
    test('UtilityApiAdapter fetches electricity meter readings with rich metadata', () async {
      final adapter = UtilityApiAdapter();
      expect(adapter.sourceId, 'utility-api');
      expect(adapter.sourceType, 'utility_api');
      expect(adapter.isConnected, isTrue);

      final candidates = await adapter.fetchCandidates();
      expect(candidates, isNotEmpty);
      final first = candidates.first;
      expect(first.kind, ActivityKind.electricity);
      expect(first.quantity, greaterThan(0));
      expect(first.confidence, adapter.baseFidelity);
      expect(first.metadata['sourceType'], 'utility_api');
      expect(first.metadata['meterId'], adapter.meterId);
      expect(first.metadata['rateTier'], isNotNull);

      // Filtering with since
      final futureDate = DateTime.now().add(const Duration(days: 1));
      final empty = await adapter.fetchCandidates(since: futureDate);
      expect(empty, isEmpty);
    });

    test('TransportApiAdapter fetches transit trips with transit agency metadata', () async {
      final adapter = TransportApiAdapter();
      expect(adapter.sourceId, 'transport-api');
      expect(adapter.sourceType, 'transport_api');
      expect(adapter.isConnected, isTrue);

      final trips = await adapter.fetchCandidates();
      expect(trips, isNotEmpty);
      final railTrip = trips.firstWhere((t) => t.kind == ActivityKind.train);
      expect(railTrip.quantity, 14.2);
      expect(railTrip.metadata['agency'], adapter.agencyName);
      expect(railTrip.metadata['cardId'], adapter.smartcardId);
      expect(railTrip.metadata['boardStop'], isNotNull);
      expect(railTrip.metadata['exitStop'], isNotNull);
    });

    test('SmartIotAdapter fetches EV charging sessions and smart sub-meter readings', () async {
      final adapter = SmartIotAdapter();
      expect(adapter.sourceId, 'smart-iot');
      expect(adapter.sourceType, 'smart_iot');

      final sessions = await adapter.fetchCandidates();
      expect(sessions, isNotEmpty);
      final evSession = sessions.firstWhere((s) => s.metadata['deviceCategory'] == 'ev_charger');
      expect(evSession.quantity, greaterThan(20.0));
      expect(evSession.kind, ActivityKind.electricity);
      expect(evSession.metadata['deviceModel'], contains('ChargePoint'));
    });

    test('BankInferenceAdapter transforms banking MCC transactions into inferred carbon candidates', () async {
      final adapter = BankInferenceAdapter();
      expect(adapter.sourceId, 'bank-inference');
      expect(adapter.sourceType, 'bank_inference');

      final candidates = await adapter.fetchCandidates();
      expect(candidates, isNotEmpty);

      // Verify transit tap inference
      final transitCandidate = candidates.firstWhere((c) => c.metadata['mcc'] == '4111');
      expect(transitCandidate.kind, ActivityKind.train);
      expect(transitCandidate.quantity, 14.2);

      // Verify rideshare inference
      final rideshareCandidate = candidates.firstWhere((c) => c.metadata['mcc'] == '4121');
      expect(rideshareCandidate.kind, ActivityKind.car);

      // Verify gas station fuel inference
      final fuelCandidate = candidates.firstWhere((c) => c.metadata['mcc'] == '5541');
      expect(fuelCandidate.kind, ActivityKind.car);
      expect(fuelCandidate.quantity, greaterThan(100.0));

      // Verify airline flight inference
      final flightCandidate = candidates.firstWhere((c) => c.metadata['mcc'] == '4511');
      expect(flightCandidate.kind, ActivityKind.flight);
      expect(flightCandidate.quantity, greaterThan(200.0));
    });
  });

  group('MultiSourceRegistry', () {
    test('Initializes with the real utility adapter by default', () {
      final registry = MultiSourceRegistry();
      expect(registry.length, 1);
      expect(registry.getAdapter('utility-green-button'), isA<GreenButtonUtilityAdapter>());
    });

    test('Initializes with the four canonical adapters and manages registry lifecycle', () {
      final registry = MultiSourceRegistry.canonical();
      expect(registry.length, 4);

      final adapters = registry.listAdapters();
      expect(adapters.map((a) => a.sourceId), containsAll([
        'utility-api',
        'transport-api',
        'smart-iot',
        'bank-inference',
      ]));

      expect(registry.getAdapter('utility-api'), isA<UtilityApiAdapter>());
      expect(registry.getAdapter('transport-api'), isA<TransportApiAdapter>());
      expect(registry.getAdapter('smart-iot'), isA<SmartIotAdapter>());
      expect(registry.getAdapter('bank-inference'), isA<BankInferenceAdapter>());

      // Unregister and register
      registry.unregister('smart-iot');
      expect(registry.length, 3);
      expect(registry.getAdapter('smart-iot'), isNull);

      registry.register(SmartIotAdapter());
      expect(registry.length, 4);
      expect(registry.getAdapter('smart-iot'), isNotNull);
    });
  });

  group('ReconciliationEngine', () {
    final engine = const ReconciliationEngine();
    final now = DateTime(2026, 11, 6, 8, 30);

    test('Combines overlapping travel signals and chooses most accurate quantity', () {
      final phoneGpsTrip = ActivityCandidate(
        id: 'phone:1',
        source: 'phone-location',
        start: now,
        end: now.add(const Duration(minutes: 28)),
        quantity: 14.5, // 14.5 km from GPS Haversine
        confidence: 0.80,
        description: 'Phone location detected journey',
      );

      final transportApiTrip = ActivityCandidate(
        id: 'transport:1',
        source: 'transport-api',
        start: now.add(const Duration(minutes: 1)),
        end: now.add(const Duration(minutes: 27)),
        quantity: 14.2, // 14.2 km turnstile verified track mileage
        confidence: 0.95,
        kind: ActivityKind.train,
        description: 'Metro Transit Line 1 commuter rail',
      );

      final bankFareTap = ActivityCandidate(
        id: 'bank:1',
        source: 'bank-inference',
        start: now.subtract(const Duration(minutes: 2)),
        end: now.add(const Duration(minutes: 30)),
        quantity: 14.2, // $3.25 fare inferred commute
        confidence: 0.78,
        kind: ActivityKind.train,
        description: 'Bank Card \$3.25 ORCA tap',
      );

      final reconciled = engine.reconcile([phoneGpsTrip, transportApiTrip, bankFareTap]);
      expect(reconciled, hasLength(1));

      final result = reconciled.single;
      expect(result.metadata['reconciled'], isTrue);
      expect(result.metadata['strategy'], 'chosen_most_accurate');
      expect(result.quantity, 14.2); // Chose verified transport API distance
      expect(result.kind, ActivityKind.train); // Mode disambiguated
      expect(result.confidence!, greaterThan(0.95)); // Corroborated confidence boost
      expect(result.metadata['contributingSources'], containsAll([
        'phone-location',
        'transport-api',
        'bank-inference',
      ]));
    });

    test('Averages signals within tolerance when sources have close fidelity', () {
      final sourceA = ActivityCandidate(
        id: 'gps:a',
        source: 'phone-location-a',
        start: now,
        end: now.add(const Duration(minutes: 20)),
        quantity: 10.0,
        confidence: 0.82,
        description: 'Sensor A',
      );

      final sourceB = ActivityCandidate(
        id: 'gps:b',
        source: 'phone-location-b',
        start: now.add(const Duration(minutes: 2)),
        end: now.add(const Duration(minutes: 22)),
        quantity: 10.4,
        confidence: 0.84,
        description: 'Sensor B',
      );

      final reconciled = engine.reconcile([sourceA, sourceB]);
      expect(reconciled, hasLength(1));
      expect(reconciled.single.metadata['strategy'], 'averaged_within_tolerance');
      expect(reconciled.single.quantity, closeTo(10.2, 0.05));
    });

    test('Does not combine non-overlapping signals across time or domains', () {
      final morningCommute = ActivityCandidate(
        id: 'commute:morning',
        source: 'transport-api',
        start: now,
        end: now.add(const Duration(minutes: 30)),
        quantity: 14.0,
        kind: ActivityKind.train,
        description: 'Morning commute',
      );

      final eveningCommute = ActivityCandidate(
        id: 'commute:evening',
        source: 'transport-api',
        start: now.add(const Duration(hours: 9)),
        end: now.add(const Duration(hours: 9, minutes: 30)),
        quantity: 14.0,
        kind: ActivityKind.train,
        description: 'Evening commute',
      );

      final electricityReading = ActivityCandidate(
        id: 'utility:1',
        source: 'utility-api',
        start: now,
        end: now.add(const Duration(hours: 24)),
        quantity: 18.5,
        kind: ActivityKind.electricity,
        description: 'Daily electricity',
      );

      final results = engine.reconcile([morningCommute, eveningCommute, electricityReading]);
      expect(results, hasLength(3));
    });
  });

  group('IngestionOrchestrator', () {
    test('Orchestrates fetching, normalizing, reconciling, and queuing candidates', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final autoStore = AutomationStore(prefs);
      final activityStore = ActivityStore(prefs);
      final registry = MultiSourceRegistry.canonical();

      final orchestrator = IngestionOrchestrator(
        registry: registry,
        automationStore: autoStore,
        activityStore: activityStore,
      );

      final result = await orchestrator.ingest();
      expect(result.totalFetched, greaterThanOrEqualTo(10));
      expect(result.queuedCount, greaterThan(0));

      final state = autoStore.load();
      expect(state.pending, hasLength(result.queuedCount));

      // Re-running ingestion skips duplicates
      final rerun = await orchestrator.ingest();
      expect(rerun.queuedCount, 0);
      expect(rerun.duplicatesSkipped, greaterThan(0));
    });
  });
}
