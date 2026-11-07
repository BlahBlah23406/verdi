// Overview: Adapter inferring travel and activities from bank/credit-card transaction feeds.
import '../../domain/automation.dart';
import '../../domain/carbon.dart';
import '../../domain/data_source.dart';
import 'multi_source_adapter.dart';

/// Financial transaction record used for carbon activity inference.
class BankTransaction {
  const BankTransaction({
    required this.transactionId,
    required this.merchant,
    required this.amountUsd,
    required this.timestamp,
    required this.mcc,
    this.location = '',
  });

  final String transactionId;
  final String merchant;
  final double amountUsd;
  final DateTime timestamp;
  final String mcc; // Merchant Category Code
  final String location;
}

/// Simulates open-banking financial aggregation (e.g. Plaid, Finicity, Teller)
/// and infers travel and energy activity from transaction records.
class BankInferenceAdapter implements MultiSourceAdapter {
  BankInferenceAdapter({
    this.institutionName = 'Cascadia Community Credit Union (Open Banking)',
    this.accountId = 'ACCT-CHECKING-5512',
    this.customTransactions,
  });

  final String institutionName;
  final String accountId;
  final List<BankTransaction>? customTransactions;

  @override
  String get sourceId => 'bank-inference';

  @override
  String get displayName => 'Bank & Card Transaction Inference';

  @override
  String get sourceType => 'bank_inference';

  @override
  TrackingFront get front => TrackingFront.travel;

  @override
  String get description =>
      'Infers commutes, transit fares, fuel purchases, and flights from bank transaction feeds.';

  @override
  bool get isConnected => true;

  @override
  double get baseFidelity => 0.75; // Inferred from financial receipts; high corroboration value

  @override
  Future<List<ActivityCandidate>> fetchCandidates({DateTime? since}) async {
    final transactions = customTransactions ?? _generateDefaultTransactions();
    final results = <ActivityCandidate>[];

    for (final tx in transactions) {
      if (since != null && !tx.timestamp.isAfter(since)) continue;
      final candidate = inferCandidate(tx);
      if (candidate != null) results.add(candidate);
    }

    return results;
  }

  /// Transforms a financial transaction into an activity candidate via MCC/merchant inference rules.
  ActivityCandidate? inferCandidate(BankTransaction tx) {
    // 1. Transit tap / faregate (MCC 4111: Local/Suburban Commuter Passenger Transportation)
    if (tx.mcc == '4111' || tx.merchant.toLowerCase().contains('transit') || tx.merchant.toLowerCase().contains('orca')) {
      // In urban transit, $3.00-$3.50 typically maps to a single standard rail/bus ride (~14 km)
      final estimatedKm = 14.2;
      return ActivityCandidate(
        id: 'bank-inference:${tx.transactionId}',
        source: 'bank-inference',
        start: tx.timestamp,
        end: tx.timestamp.add(const Duration(minutes: 35)),
        quantity: estimatedKm,
        kind: ActivityKind.train,
        confidence: 0.78,
        description: 'Bank Card: \$${tx.amountUsd.toStringAsFixed(2)} at ${tx.merchant} · Inferred commuter rail commute',
        metadata: {
          'sourceType': sourceType,
          'merchant': tx.merchant,
          'amountUsd': tx.amountUsd,
          'mcc': tx.mcc,
          'inferenceRule': 'transit_fare_to_commute_distance',
          'inferredMode': 'commuter_rail',
          'transactionId': tx.transactionId,
        },
      );
    }

    // 2. Rideshare / Taxi (MCC 4121: Taxicabs and Limousines, Uber, Lyft)
    if (tx.mcc == '4121' || tx.merchant.toLowerCase().contains('uber') || tx.merchant.toLowerCase().contains('lyft')) {
      // Average rideshare fare rate is ~$2.00/km
      final estimatedKm = (tx.amountUsd / 2.0).clamp(2.0, 80.0);
      return ActivityCandidate(
        id: 'bank-inference:${tx.transactionId}',
        source: 'bank-inference',
        start: tx.timestamp,
        end: tx.timestamp.add(Duration(minutes: (estimatedKm * 2.5).round().clamp(10, 90))),
        quantity: double.parse(estimatedKm.toStringAsFixed(1)),
        kind: ActivityKind.car,
        confidence: 0.72,
        description: 'Bank Card: \$${tx.amountUsd.toStringAsFixed(2)} at ${tx.merchant} · Inferred car journey (~${estimatedKm.toStringAsFixed(1)} km)',
        metadata: {
          'sourceType': sourceType,
          'merchant': tx.merchant,
          'amountUsd': tx.amountUsd,
          'mcc': tx.mcc,
          'inferenceRule': 'rideshare_fare_to_mileage',
          'inferredMode': 'car',
          'transactionId': tx.transactionId,
        },
      );
    }

    // 3. Airline ticket (MCC 4511: Airlines, Air Carriers)
    if (tx.mcc == '4511' || tx.merchant.toLowerCase().contains('air')) {
      // Inferred short-haul flight e.g. Seattle to Portland or San Francisco (~450 km)
      final estimatedKm = (tx.amountUsd * 2.5).clamp(250.0, 2500.0);
      return ActivityCandidate(
        id: 'bank-inference:${tx.transactionId}',
        source: 'bank-inference',
        start: tx.timestamp,
        end: tx.timestamp.add(const Duration(hours: 2)),
        quantity: double.parse(estimatedKm.toStringAsFixed(0)),
        kind: ActivityKind.flight,
        confidence: 0.82,
        description: 'Bank Card: \$${tx.amountUsd.toStringAsFixed(2)} at ${tx.merchant} · Inferred flight (~${estimatedKm.toStringAsFixed(0)} passenger-km)',
        metadata: {
          'sourceType': sourceType,
          'merchant': tx.merchant,
          'amountUsd': tx.amountUsd,
          'mcc': tx.mcc,
          'inferenceRule': 'airline_spend_to_passenger_km',
          'inferredMode': 'flight',
          'transactionId': tx.transactionId,
        },
      );
    }

    // 4. Gas station fuel purchase (MCC 5541 / 5542: Service Stations / Automated Fuel Dispensers)
    if (tx.mcc == '5541' || tx.mcc == '5542' || tx.merchant.toLowerCase().contains('chevron') || tx.merchant.toLowerCase().contains('shell')) {
      // ~$4.00/gal, ~30 mpg -> 1 gal = ~48 km. Inferred driving equivalent
      final gallons = tx.amountUsd / 3.85;
      final estimatedKm = gallons * 45.0;
      return ActivityCandidate(
        id: 'bank-inference:${tx.transactionId}',
        source: 'bank-inference',
        start: tx.timestamp,
        end: tx.timestamp.add(const Duration(minutes: 15)),
        quantity: double.parse(estimatedKm.toStringAsFixed(1)),
        kind: ActivityKind.car,
        confidence: 0.70,
        description: 'Bank Card: \$${tx.amountUsd.toStringAsFixed(2)} at ${tx.merchant} · Inferred ${gallons.toStringAsFixed(1)} gal fuel (~${estimatedKm.toStringAsFixed(0)} km car driving)',
        metadata: {
          'sourceType': sourceType,
          'merchant': tx.merchant,
          'amountUsd': tx.amountUsd,
          'mcc': tx.mcc,
          'inferredGallons': gallons,
          'inferenceRule': 'fuel_purchase_to_car_mileage',
          'inferredMode': 'car',
          'transactionId': tx.transactionId,
        },
      );
    }

    return null;
  }

  List<BankTransaction> _generateDefaultTransactions() {
    final now = DateTime.now();
    return [
      BankTransaction(
        transactionId: 'TX-BNK-901',
        merchant: 'ORCA Metro Transit Fare Tap',
        amountUsd: 3.25,
        // Aligns with Transport API Day 1 morning commute!
        timestamp: DateTime(now.year, now.month, now.day - 1, 8, 14),
        mcc: '4111',
        location: 'Seattle, WA',
      ),
      BankTransaction(
        transactionId: 'TX-BNK-902',
        merchant: 'Uber Trip Downtown',
        amountUsd: 18.50,
        timestamp: DateTime(now.year, now.month, now.day - 2, 21, 30),
        mcc: '4121',
        location: 'Seattle, WA',
      ),
      BankTransaction(
        transactionId: 'TX-BNK-903',
        merchant: 'Chevron Fuel Service #4210',
        amountUsd: 44.00,
        timestamp: DateTime(now.year, now.month, now.day - 3, 16, 45),
        mcc: '5541',
        location: 'Bellevue, WA',
      ),
      BankTransaction(
        transactionId: 'TX-BNK-904',
        merchant: 'Alaska Airlines SEA-PDX',
        amountUsd: 149.00,
        timestamp: DateTime(now.year, now.month, now.day - 5, 10, 0),
        mcc: '4511',
        location: 'Seatac, WA',
      ),
    ];
  }
}
