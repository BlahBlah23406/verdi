// Overview: Registry managing multi-source adapters for automated carbon tracking.
import 'bank_inference_adapter.dart';
import 'multi_source_adapter.dart';
import 'smart_iot_adapter.dart';
import 'transport_adapter.dart';
import 'utility_adapter.dart';

/// Central registry managing all multi-source carbon data adapters.
class MultiSourceRegistry {
  MultiSourceRegistry([List<MultiSourceAdapter>? initialAdapters]) {
    final adapters = initialAdapters ??
        [
          UtilityApiAdapter(),
          TransportApiAdapter(),
          SmartIotAdapter(),
          BankInferenceAdapter(),
        ];
    for (final adapter in adapters) {
      _adapters[adapter.sourceId] = adapter;
    }
  }

  final Map<String, MultiSourceAdapter> _adapters = {};

  /// Returns all registered adapters.
  List<MultiSourceAdapter> listAdapters() =>
      List.unmodifiable(_adapters.values.toList());

  /// Retrieves an adapter by its unique [sourceId].
  MultiSourceAdapter? getAdapter(String sourceId) => _adapters[sourceId];

  /// Registers or replaces an adapter.
  void register(MultiSourceAdapter adapter) {
    _adapters[adapter.sourceId] = adapter;
  }

  /// Removes an adapter by [sourceId].
  void unregister(String sourceId) {
    _adapters.remove(sourceId);
  }

  /// Total count of registered adapters.
  int get length => _adapters.length;
}
