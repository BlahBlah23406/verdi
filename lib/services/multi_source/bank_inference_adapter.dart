// Overview: Adapter inferring travel and activities from bank/credit-card transaction feeds.
import '../../domain/automation.dart';
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
    // Merchant spend proves a payment, not distance, mode, fuel volume or travel date.
    // Wait for a linked journey/receipt with physical units. Bank records still
    // support round-ups in the backend transaction ledger.
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
