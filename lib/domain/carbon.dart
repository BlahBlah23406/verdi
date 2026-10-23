// Deliberately illustrative factors, not verified accounting data.
enum ActivityKind {
  car('Car journey', 'Travel', 'km', 0.20),
  bus('Bus journey', 'Travel', 'km', 0.08),
  train('Train journey', 'Travel', 'km', 0.04),
  bicycle('Bicycle journey', 'Travel', 'km', 0),
  electricity('Home electricity', 'Home', 'kWh', 0.30),
  food('Food purchases', 'Food', 'USD', 0.50),
  shopping('Other purchases', 'Shopping', 'USD', 0.35),
  waste('Landfill waste', 'Waste', 'kg', 0.60);

  const ActivityKind(this.label, this.category, this.unit, this.factor);
  final String label, category, unit;
  final double factor;
  static const factorVersion = 'illustrative-v1';
}

class Activity {
  Activity({
    required this.id,
    required this.kind,
    required this.quantity,
    required this.date,
    this.note = '',
    this.factorVersion = ActivityKind.factorVersion,
    double? factor,
  }) : factor = factor ?? kind.factor {
    if (id.isEmpty ||
        !quantity.isFinite ||
        quantity <= 0 ||
        !this.factor.isFinite ||
        this.factor < 0) {
      throw ArgumentError(
        'Activity requires an ID and valid positive quantity.',
      );
    }
  }
  final String id, note, factorVersion;
  final ActivityKind kind;
  final double quantity, factor;
  final DateTime date;
  double get emissions => quantity * factor;
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'quantity': quantity,
    'date': date.toIso8601String(),
    'note': note,
    'factor': factor,
    'factorVersion': factorVersion,
  };
  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
    id: json['id'] as String,
    kind: ActivityKind.values.byName(json['kind'] as String),
    quantity: (json['quantity'] as num).toDouble(),
    date: DateTime.parse(json['date'] as String),
    note: json['note'] as String,
    factor: (json['factor'] as num).toDouble(),
    factorVersion: json['factorVersion'] as String,
  );
}

class CarbonEngine {
  const CarbonEngine();
  // Half-open date range; duplicate imported IDs must not double count.
  List<Activity> inPeriod(
    Iterable<Activity> activities,
    DateTime start,
    DateTime end,
  ) {
    if (!end.isAfter(start)) throw ArgumentError('Invalid reporting period.');
    final seen = <String>{};
    return activities
        .where(
          (a) =>
              !a.date.isBefore(start) && a.date.isBefore(end) && seen.add(a.id),
        )
        .toList();
  }

  double total(Iterable<Activity> activities) =>
      activities.fold(0, (sum, a) => sum + a.emissions);
  Map<String, double> breakdown(Iterable<Activity> activities) {
    final result = <String, double>{};
    for (final a in activities) {
      result.update(
        a.kind.category,
        (v) => v + a.emissions,
        ifAbsent: () => a.emissions,
      );
    }
    return result;
  }

  double potentialTravelSaving(double km, ActivityKind alternative) {
    if (!km.isFinite || km < 0 || alternative.category != 'Travel') {
      throw ArgumentError('Use a valid distance and travel alternative.');
    }
    return km * (ActivityKind.car.factor - alternative.factor);
  }

  // Preview only. No reward balance is issued from unverified activity logs.
  int previewPoints(double saving) {
    if (!saving.isFinite || saving < 0) throw ArgumentError('Invalid saving.');
    return (saving * 10).floor();
  }
}
