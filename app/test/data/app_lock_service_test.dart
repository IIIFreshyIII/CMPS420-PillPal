import 'package:flutter_test/flutter_test.dart';

import 'package:pillpal/data/services/app_lock_service.dart';

void main() {
  final t0 = DateTime(2026, 10, 5, 12);

  test('never backgrounded: a resume does not relock', () {
    expect(AppLockService().shouldRelockOnResume(t0), isFalse);
  });

  test('back within the grace period: no relock', () {
    final s = AppLockService()..recordBackgrounded(t0);
    expect(
        s.shouldRelockOnResume(t0.add(const Duration(seconds: 59))), isFalse);
  });

  test('away longer than the grace period: relock', () {
    final s = AppLockService()..recordBackgrounded(t0);
    expect(s.shouldRelockOnResume(t0.add(const Duration(seconds: 61))), isTrue);
  });

  test('one backgrounding is judged once', () {
    final s = AppLockService()..recordBackgrounded(t0);
    expect(s.shouldRelockOnResume(t0.add(const Duration(minutes: 5))), isTrue);
    expect(s.shouldRelockOnResume(t0.add(const Duration(minutes: 6))), isFalse);
  });
}
