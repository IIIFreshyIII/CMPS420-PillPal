import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/utils/date_formatter.dart';

void main() {
  group('formatFullDate', () {
    test('formats full weekday, full month, day, no year', () {
      expect(formatFullDate(now: DateTime(2026, 9, 2)), 'Wednesday, September 2');
    });

    test('single-digit day has no leading zero', () {
      expect(formatFullDate(now: DateTime(2026, 10, 1)), 'Thursday, October 1');
    });
  });

  group('timeOfDayGreeting', () {
    test('before noon is morning', () {
      expect(timeOfDayGreeting(now: DateTime(2026, 1, 1, 6)), 'Good morning');
      expect(timeOfDayGreeting(now: DateTime(2026, 1, 1, 11, 59)), 'Good morning');
    });

    test('noon to before 5pm is afternoon', () {
      expect(timeOfDayGreeting(now: DateTime(2026, 1, 1, 12)), 'Good afternoon');
      expect(timeOfDayGreeting(now: DateTime(2026, 1, 1, 16, 59)), 'Good afternoon');
    });

    test('5pm onward is evening', () {
      expect(timeOfDayGreeting(now: DateTime(2026, 1, 1, 17)), 'Good evening');
      expect(timeOfDayGreeting(now: DateTime(2026, 1, 1, 23, 59)), 'Good evening');
    });
  });
}
