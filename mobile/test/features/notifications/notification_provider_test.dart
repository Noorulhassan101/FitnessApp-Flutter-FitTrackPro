import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/notifications/notification_manager.dart';
import 'package:mobile/features/notifications/providers/notification_provider.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}
class MockNotificationManager extends Mock implements NotificationManager {}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late MockNotificationManager mockNotificationManager;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(1);
  });

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    mockNotificationManager = MockNotificationManager();

    when(() => mockStorage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
    when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});
    when(() => mockNotificationManager.requestPermissions()).thenAnswer((_) async => true);
    when(() => mockNotificationManager.scheduleDailyMealReminder(
          id: any(named: 'id'),
          mealName: any(named: 'mealName'),
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
        )).thenAnswer((_) async {});
    when(() => mockNotificationManager.scheduleDailySummaryReminder(
          id: any(named: 'id'),
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
        )).thenAnswer((_) async {});
    when(() => mockNotificationManager.cancelReminder(any())).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(mockStorage),
        notificationManagerProvider.overrideWithValue(mockNotificationManager),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('NotificationSettingsNotifier', () {
    test('initial state has correct defaults', () {
      final state = container.read(notificationSettingsProvider);
      expect(state.breakfastReminder, true);
      expect(state.breakfastHour, 8);
      expect(state.breakfastMinute, 0);
      expect(state.lunchReminder, true);
      expect(state.lunchHour, 13);
      expect(state.lunchMinute, 0);
      expect(state.dinnerReminder, true);
      expect(state.dinnerHour, 19);
      expect(state.dinnerMinute, 0);
      expect(state.dailySummaryReminder, true);
      expect(state.dailySummaryHour, 21);
      expect(state.dailySummaryMinute, 0);
      expect(state.permissionGranted, false);
    });

    test('updating breakfast reminder updates state and cancels/schedules notification', () async {
      final notifier = container.read(notificationSettingsProvider.notifier);
      await notifier.updateBreakfastReminder(false);

      final state = container.read(notificationSettingsProvider);
      expect(state.breakfastReminder, false);
      verify(() => mockNotificationManager.cancelReminder(1)).called(1);
    });

    test('updating breakfast time updates state and schedules notification', () async {
      final notifier = container.read(notificationSettingsProvider.notifier);
      await notifier.updateBreakfastTime(9, 30);

      final state = container.read(notificationSettingsProvider);
      expect(state.breakfastHour, 9);
      expect(state.breakfastMinute, 30);
      verify(() => mockNotificationManager.scheduleDailyMealReminder(
            id: 1,
            mealName: 'Breakfast',
            hour: 9,
            minute: 30,
          )).called(1);
    });

    test('requesting permissions updates status', () async {
      final notifier = container.read(notificationSettingsProvider.notifier);
      await notifier.requestPermissions();

      final state = container.read(notificationSettingsProvider);
      expect(state.permissionGranted, true);
      verify(() => mockNotificationManager.requestPermissions()).called(1);
    });
  });
}
