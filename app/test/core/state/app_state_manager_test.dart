import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillpal/core/state/app_state_manager.dart';

class MockSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockSecureStorage mockStorage;
  late AppStateManager manager;

  setUp(() {
    mockStorage = MockSecureStorage();
    manager = AppStateManager(storage: mockStorage);
  });

  test('initial state defaults correctly', () {
    expect(manager.hasCompletedOnboarding, isFalse);
    expect(manager.hasSeenScheduleTour, isFalse);
    expect(manager.hasSeenMedsTour, isFalse);
    expect(manager.hasSeenAccountTour, isFalse);
    expect(manager.userName, isEmpty);
    expect(manager.isSeededTestingMode, isTrue);
  });

  test('setHasCompletedOnboarding updates value and persists', () async {
    var notified = false;
    manager.addListener(() => notified = true);

    await manager.setHasCompletedOnboarding(true);

    expect(manager.hasCompletedOnboarding, isTrue);
    expect(notified, isTrue);
    expect(await mockStorage.read(key: 'has_completed_onboarding'), 'true');
  });

  test('setTourSeen updates individual walkthrough flags', () async {
    await manager.setTourSeen(schedule: true);
    expect(manager.hasSeenScheduleTour, isTrue);
    expect(manager.hasSeenMedsTour, isFalse);

    await manager.setTourSeen(meds: true, account: true);
    expect(manager.hasSeenMedsTour, isTrue);
    expect(manager.hasSeenAccountTour, isTrue);
  });

  test('setUserName saves trimmed name', () async {
    await manager.setUserName('  Jane Doe  ');
    expect(manager.userName, 'Jane Doe');
    expect(await mockStorage.read(key: 'user_name'), 'Jane Doe');
  });

  test('Preset 1: resetToFreshOnboarding resets flags and disables seeded mode',
      () async {
    await manager.setHasCompletedOnboarding(true);
    await manager.setTourSeen(schedule: true, meds: true, account: true);
    await manager.setUserName('Alex');
    await manager.setSeededTestingMode(true);

    await manager.resetToFreshOnboarding();

    expect(manager.hasCompletedOnboarding, isFalse);
    expect(manager.hasSeenScheduleTour, isFalse);
    expect(manager.hasSeenMedsTour, isFalse);
    expect(manager.hasSeenAccountTour, isFalse);
    expect(manager.isSeededTestingMode, isFalse);
    expect(manager.userName, isEmpty);
  });

  test('Preset 2: setSeededUiTesting enables completed state with test data',
      () async {
    await manager.resetToFreshOnboarding();

    await manager.setSeededUiTesting();

    expect(manager.hasCompletedOnboarding, isTrue);
    expect(manager.hasSeenScheduleTour, isTrue);
    expect(manager.hasSeenMedsTour, isTrue);
    expect(manager.hasSeenAccountTour, isTrue);
    expect(manager.isSeededTestingMode, isTrue);
    expect(manager.userName, 'Me');
  });

  test('Preset 3: replayTabTutorials only resets the 3 tour flags', () async {
    await manager.setHasCompletedOnboarding(true);
    await manager.setTourSeen(schedule: true, meds: true, account: true);

    await manager.replayTabTutorials();

    expect(manager.hasCompletedOnboarding, isTrue);
    expect(manager.hasSeenScheduleTour, isFalse);
    expect(manager.hasSeenMedsTour, isFalse);
    expect(manager.hasSeenAccountTour, isFalse);
  });

  test('setBiometricsEnabled updates value, appLockService, and storage',
      () async {
    expect(manager.biometricsEnabled, isFalse);
    await manager.setBiometricsEnabled(true);
    expect(manager.biometricsEnabled, isTrue);
    expect(manager.appLockService?.isEnabled, isTrue);
    expect(await mockStorage.read(key: 'app_lock_enabled'), 'true');

    await manager.resetToFreshOnboarding();
    expect(manager.biometricsEnabled, isFalse);
    expect(manager.appLockService?.isEnabled, isFalse);
  });
}
