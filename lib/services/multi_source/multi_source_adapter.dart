// Overview: Defines the base interface for simulated multi-source automated carbon tracking adapters.
import '../../domain/automation.dart';
import '../../domain/data_source.dart';

/// Base class for all multi-source ingestion adapters (utility, transit, IoT, bank inference).
abstract class MultiSourceAdapter {
  /// Unique identifier for this adapter (e.g. 'utility-smartmeter', 'transport-transit-agency').
  String get sourceId;

  /// Human-readable display title for this data adapter.
  String get displayName;

  /// Canonical source type category ('utility_api', 'transport_api', 'smart_iot', 'bank_inference').
  String get sourceType;

  /// Associated tracking front (Travel, Home, Products, Waste, Food).
  TrackingFront get front;

  /// Short description of the adapter provider and data modality.
  String get description;

  /// Connection status indicator for this adapter.
  bool get isConnected;

  /// Baseline data fidelity/precision score (0.0 to 1.0) used in reconciliation arbitration.
  double get baseFidelity;

  /// Fetches activity candidates from the simulated source.
  /// If [since] is provided, only returns records occurring after [since].
  Future<List<ActivityCandidate>> fetchCandidates({DateTime? since});
}
