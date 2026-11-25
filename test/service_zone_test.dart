// Overview: Checks the narrow America/Los_Angeles civil-day resolver against US DST rules.
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi/domain/service_zone.dart';

void main() {
  final la = ServiceZone.losAngeles;
  Duration length((DateTime, DateTime) day) => day.$2.difference(day.$1);

  test('ordinary standard and daylight days are 24 hours in UTC', () {
    expect(la.civilDay(2026, 1, 15), (
      DateTime.utc(2026, 1, 15, 8),
      DateTime.utc(2026, 1, 16, 8),
    ));
    expect(la.civilDay(2026, 7, 4), (
      DateTime.utc(2026, 7, 4, 7),
      DateTime.utc(2026, 7, 5, 7),
    ));
  });

  test('spring-forward and fall-back days follow the midnight offsets', () {
    // 2026: second Sunday in March is the 8th; first Sunday in November the 1st.
    expect(la.civilDay(2026, 3, 8), (
      DateTime.utc(2026, 3, 8, 8),
      DateTime.utc(2026, 3, 9, 7),
    ));
    expect(length(la.civilDay(2026, 3, 8)), const Duration(hours: 23));
    expect(la.civilDay(2026, 3, 7).$1, DateTime.utc(2026, 3, 7, 8));
    expect(la.civilDay(2026, 3, 9).$1, DateTime.utc(2026, 3, 9, 7));
    expect(la.civilDay(2026, 11, 1), (
      DateTime.utc(2026, 11, 1, 7),
      DateTime.utc(2026, 11, 2, 8),
    ));
    expect(length(la.civilDay(2026, 11, 1)), const Duration(hours: 25));
    expect(la.civilDay(2026, 10, 31).$1, DateTime.utc(2026, 10, 31, 7));
    expect(la.civilDay(2026, 11, 2).$1, DateTime.utc(2026, 11, 2, 8));
  });

  test('transition dates are computed per year, including edge weekdays', () {
    // Known 2007–2030 transitions (second Sunday March, first Sunday November).
    final known = {
      2007: (11, 4),
      2015: (8, 1),
      2020: (8, 1),
      2024: (10, 3),
      2025: (9, 2),
      2027: (14, 7),
      2030: (10, 3),
    };
    for (final MapEntry(key: year, value: (march, november)) in known.entries) {
      expect(
        length(la.civilDay(year, 3, march)),
        const Duration(hours: 23),
        reason: '$year-03-$march',
      );
      expect(
        length(la.civilDay(year, 11, november)),
        const Duration(hours: 25),
        reason: '$year-11-$november',
      );
      expect(
        length(la.civilDay(year, 3, march - 1)),
        const Duration(hours: 24),
      );
      expect(
        length(la.civilDay(year, 11, november + 1)),
        const Duration(hours: 24),
      );
    }
    var short = 0, long = 0;
    for (
      var d = DateTime.utc(2028);
      d.year == 2028;
      d = d.add(const Duration(days: 1))
    ) {
      final h = length(la.civilDay(d.year, d.month, d.day)).inHours;
      if (h == 23) short++;
      if (h == 25) long++;
    }
    expect((short, long), (1, 1));
  });

  test('dates outside the supported range and invalid dates are rejected', () {
    expect(() => la.civilDay(2006, 12, 31), throwsArgumentError);
    expect(() => la.civilDay(2031, 1, 1), throwsArgumentError);
    expect(() => la.civilDay(2026, 2, 30), throwsArgumentError);
    expect(la.civilDay(2030, 12, 31).$2, DateTime.utc(2031, 1, 1, 8));
    expect(() => ServiceZone.byId('Europe/London'), throwsArgumentError);
    expect(ServiceZone.supported.map((z) => z.id), ['America/Los_Angeles']);
  });
}
