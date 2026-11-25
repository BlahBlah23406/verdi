// Overview: Resolves local civil days to UTC for the narrowly supported service zones.
//
// No time-zone database is bundled. Only America/Los_Angeles is supported, for
// an explicit date range, using the US daylight-saving rules in force since
// 2007 (Energy Policy Act of 2005). Results never depend on the device zone.
import 'utility_evidence_adapter.dart';

class ServiceZone {
  const ServiceZone._(this.id, this.label, this.firstDate, this.lastDate);

  /// Pacific Time: PST (UTC−08:00) and PDT (UTC−07:00).
  static final losAngeles = ServiceZone._(
    'America/Los_Angeles',
    'Pacific Time (America/Los_Angeles)',
    DateTime.utc(2007, 1, 1),
    DateTime.utc(2030, 12, 31),
  );

  /// Every zone this app can resolve. Arbitrary zones are not claimed.
  static final supported = [losAngeles];

  static ServiceZone byId(String id) => supported.firstWhere(
    (z) => z.id == id,
    orElse: () => throw ArgumentError('Unsupported service zone: $id'),
  );

  final String id, label;

  /// Inclusive civil-date range for which the rules below are known to apply.
  /// Later dates are rejected because the rules may change by law.
  final DateTime firstDate, lastDate;

  /// Second Sunday in March and first Sunday in November, as UTC-coded dates.
  static (DateTime, DateTime) _transitions(int year) {
    DateTime sunday(int month, int nth) {
      final first = DateTime.utc(year, month);
      final offset = (DateTime.sunday - first.weekday) % 7;
      return DateTime.utc(year, month, 1 + offset + 7 * (nth - 1));
    }

    return (sunday(3, 2), sunday(11, 1));
  }

  /// Offset in force at local midnight that STARTS [civil] (a UTC-coded date).
  /// Transitions happen at 02:00 local, so midnight of the March transition
  /// day is still PST and midnight of the November transition day is PDT.
  Duration _offsetAtMidnight(DateTime civil) {
    final (start, end) = _transitions(civil.year);
    final daylight = civil.isAfter(start) && !civil.isAfter(end);
    return Duration(hours: daylight ? -7 : -8);
  }

  bool supports(int year, int month, int day) {
    final civil = DateTime.utc(year, month, day);
    return !civil.isBefore(firstDate) && !civil.isAfter(lastDate);
  }

  /// UTC bounds of one local civil day in this zone (23 or 25 hours on
  /// transition days). Throws [ArgumentError] outside the supported range.
  (DateTime, DateTime) civilDay(int year, int month, int day) {
    final civil = DateTime.utc(year, month, day);
    if (civil.year != year || civil.month != month || civil.day != day) {
      throw ArgumentError('Invalid civil date.');
    }
    if (!supports(year, month, day)) {
      throw ArgumentError(
        '$id is supported only from ${_date(firstDate)} to ${_date(lastDate)}.',
      );
    }
    return civilDayInUtc(
      year,
      month,
      day,
      offsetAtStart: _offsetAtMidnight(civil),
      offsetAtEnd: _offsetAtMidnight(DateTime.utc(year, month, day + 1)),
    );
  }

  static String _date(DateTime d) => d.toIso8601String().substring(0, 10);
}
