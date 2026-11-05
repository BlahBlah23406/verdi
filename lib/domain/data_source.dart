// Overview: Defines the abstract data source interface for multi-front carbon tracking
// (purchases, flights, waste, utilities, phone trips) and stub implementations.
import 'automation.dart';
import 'carbon.dart';

/// Categorises the tracking front that a data source serves.
enum TrackingFront {
  travel('Travel', 'Commutes, flights, and other journeys'),
  home('Home', 'Electricity, gas, and other household energy'),
  products('Products', 'Purchases and their embodied emissions'),
  waste('Waste', 'Landfill, recycling, and compost streams'),
  food('Food', 'Dietary emissions from food consumption');

  const TrackingFront(this.label, this.description);
  final String label, description;
}

/// A normalised record from any third-party or on-device data source.
/// Each source converts its native format into this common shape so the
/// review pipeline, duplicate checks, and emission engine can work uniformly.
class SourceRecord {
  const SourceRecord({
    required this.id,
    required this.front,
    required this.timestamp,
    required this.description,
    required this.quantity,
    required this.unit,
    this.suggestedKind,
    this.metadata = const {},
  });

  final String id; // stable, dedup-capable identity
  final TrackingFront front;
  final DateTime timestamp;
  final String description;
  final double quantity;
  final String unit;
  final ActivityKind? suggestedKind;
  final Map<String, dynamic> metadata;

  ActivityCandidate toCandidate() {
    return ActivityCandidate(
      id: id,
      source: 'data-source:${front.name}',
      start: timestamp,
      end: timestamp,
      quantity: quantity,
      description: description,
      kind: suggestedKind,
    );
  }
}

/// Contract for any data source that can feed activity candidates into Verdi.
///
/// Implementations are responsible for:
/// - Authenticating with their provider (or reading local data).
/// - Normalising provider-specific formats into [SourceRecord]s.
/// - Respecting user consent and handling errors gracefully.
///
/// The [status] method returns a human-readable connection state so the UI
/// can show which fronts are active, pending, or unavailable.
abstract class DataSource {
  /// Unique identifier for this source (e.g. 'purchase-plaid', 'flight-airline').
  String get sourceId;

  /// The tracking front this source serves.
  TrackingFront get front;

  /// Human-readable name shown in the UI.
  String get displayName;

  /// Current connection or availability status.
  DataSourceStatus get status;

  /// Fetch new records since [since]. If [since] is null, fetch the most
  /// recent batch available. Returns an empty list if nothing is new.
  ///
  /// Stub implementations return an empty list and set status to [DataSourceStatus.notConnected].
  Future<List<SourceRecord>> fetch({DateTime? since});

  /// Release any held resources (tokens, streams, file handles).
  void dispose() {}
}

/// Lifecycle state of a data source connection.
enum DataSourceStatus {
  connected('Connected'),
  pending('Awaiting consent'),
  notConnected('Not connected'),
  error('Error');

  const DataSourceStatus(this.label);
  final String label;
}

// ---------------------------------------------------------------------------
// Stub implementations — each shows the interface contract and returns empty
// data.  Real implementations will connect to provider APIs with user consent.
// ---------------------------------------------------------------------------

/// Purchase data source — transaction-level spending data mapped to product
/// emission categories.
class PurchaseDataSource extends DataSource {
  @override
  String get sourceId => 'purchase-stub';

  @override
  TrackingFront get front => TrackingFront.products;

  @override
  String get displayName => 'Purchase history';

  @override
  DataSourceStatus get status => DataSourceStatus.notConnected;

  @override
  Future<List<SourceRecord>> fetch({DateTime? since}) async => [];
}

/// Flight data source — airline bookings or boarding passes mapped to
/// flight emission estimates.
class FlightDataSource extends DataSource {
  @override
  String get sourceId => 'flight-stub';

  @override
  TrackingFront get front => TrackingFront.travel;

  @override
  String get displayName => 'Flight history';

  @override
  DataSourceStatus get status => DataSourceStatus.notConnected;

  @override
  Future<List<SourceRecord>> fetch({DateTime? since}) async => [];
}

/// Waste data source — municipal waste-weighing or smart-bin data mapped to
/// landfill / recycling / compost emission factors.
class WasteDataSource extends DataSource {
  @override
  String get sourceId => 'waste-stub';

  @override
  TrackingFront get front => TrackingFront.waste;

  @override
  String get displayName => 'Waste tracking';

  @override
  DataSourceStatus get status => DataSourceStatus.notConnected;

  @override
  Future<List<SourceRecord>> fetch({DateTime? since}) async => [];
}

/// Registry of all available data sources, used by the UI to show the
/// multi-front tracking vision.
class DataSourceRegistry {
  DataSourceRegistry() : sources = [
      PurchaseDataSource(),
      FlightDataSource(),
      WasteDataSource(),
    ];

  final List<DataSource> sources;

  /// Group sources by their tracking front for UI display.
  Map<TrackingFront, List<DataSource>> get byFront {
    final map = <TrackingFront, List<DataSource>>{};
    for (final s in sources) {
      map.putIfAbsent(s.front, () => []).add(s);
    }
    return map;
  }

  void dispose() {
    for (final s in sources) {
      s.dispose();
    }
  }
}
