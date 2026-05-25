import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/notifications/notification_manager.dart';

class NotificationSettingsState {
  final bool breakfastReminder;
  final int breakfastHour;
  final int breakfastMinute;

  final bool lunchReminder;
  final int lunchHour;
  final int lunchMinute;

  final bool dinnerReminder;
  final int dinnerHour;
  final int dinnerMinute;

  final bool dailySummaryReminder;
  final int dailySummaryHour;
  final int dailySummaryMinute;

  final bool permissionGranted;

  const NotificationSettingsState({
    required this.breakfastReminder,
    required this.breakfastHour,
    required this.breakfastMinute,
    required this.lunchReminder,
    required this.lunchHour,
    required this.lunchMinute,
    required this.dinnerReminder,
    required this.dinnerHour,
    required this.dinnerMinute,
    required this.dailySummaryReminder,
    required this.dailySummaryHour,
    required this.dailySummaryMinute,
    required this.permissionGranted,
  });

  NotificationSettingsState copyWith({
    bool? breakfastReminder,
    int? breakfastHour,
    int? breakfastMinute,
    bool? lunchReminder,
    int? lunchHour,
    int? lunchMinute,
    bool? dinnerReminder,
    int? dinnerHour,
    int? dinnerMinute,
    bool? dailySummaryReminder,
    int? dailySummaryHour,
    int? dailySummaryMinute,
    bool? permissionGranted,
  }) {
    return NotificationSettingsState(
      breakfastReminder: breakfastReminder ?? this.breakfastReminder,
      breakfastHour: breakfastHour ?? this.breakfastHour,
      breakfastMinute: breakfastMinute ?? this.breakfastMinute,
      lunchReminder: lunchReminder ?? this.lunchReminder,
      lunchHour: lunchHour ?? this.lunchHour,
      lunchMinute: lunchMinute ?? this.lunchMinute,
      dinnerReminder: dinnerReminder ?? this.dinnerReminder,
      dinnerHour: dinnerHour ?? this.dinnerHour,
      dinnerMinute: dinnerMinute ?? this.dinnerMinute,
      dailySummaryReminder: dailySummaryReminder ?? this.dailySummaryReminder,
      dailySummaryHour: dailySummaryHour ?? this.dailySummaryHour,
      dailySummaryMinute: dailySummaryMinute ?? this.dailySummaryMinute,
      permissionGranted: permissionGranted ?? this.permissionGranted,
    );
  }
}

class NotificationSettingsNotifier extends Notifier<NotificationSettingsState> {
  static const _storageKey = 'notification_settings';

  @override
  NotificationSettingsState build() {
    Future.microtask(() => _loadSettings());

    return const NotificationSettingsState(
      breakfastReminder: true,
      breakfastHour: 8,
      breakfastMinute: 0,
      lunchReminder: true,
      lunchHour: 13,
      lunchMinute: 0,
      dinnerReminder: true,
      dinnerHour: 19,
      dinnerMinute: 0,
      dailySummaryReminder: true,
      dailySummaryHour: 21,
      dailySummaryMinute: 0,
      permissionGranted: false,
    );
  }

  Future<void> _loadSettings() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final jsonStr = await storage.read(key: _storageKey);
      if (jsonStr != null) {
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        state = NotificationSettingsState(
          breakfastReminder: data['breakfastReminder'] as bool? ?? true,
          breakfastHour: data['breakfastHour'] as int? ?? 8,
          breakfastMinute: data['breakfastMinute'] as int? ?? 0,
          lunchReminder: data['lunchReminder'] as bool? ?? true,
          lunchHour: data['lunchHour'] as int? ?? 13,
          lunchMinute: data['lunchMinute'] as int? ?? 0,
          dinnerReminder: data['dinnerReminder'] as bool? ?? true,
          dinnerHour: data['dinnerHour'] as int? ?? 19,
          dinnerMinute: data['dinnerMinute'] as int? ?? 0,
          dailySummaryReminder: data['dailySummaryReminder'] as bool? ?? true,
          dailySummaryHour: data['dailySummaryHour'] as int? ?? 21,
          dailySummaryMinute: data['dailySummaryMinute'] as int? ?? 0,
          permissionGranted: data['permissionGranted'] as bool? ?? false,
        );
      }
      _syncAllReminders();
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final data = {
        'breakfastReminder': state.breakfastReminder,
        'breakfastHour': state.breakfastHour,
        'breakfastMinute': state.breakfastMinute,
        'lunchReminder': state.lunchReminder,
        'lunchHour': state.lunchHour,
        'lunchMinute': state.lunchMinute,
        'dinnerReminder': state.dinnerReminder,
        'dinnerHour': state.dinnerHour,
        'dinnerMinute': state.dinnerMinute,
        'dailySummaryReminder': state.dailySummaryReminder,
        'dailySummaryHour': state.dailySummaryHour,
        'dailySummaryMinute': state.dailySummaryMinute,
        'permissionGranted': state.permissionGranted,
      };
      await storage.write(key: _storageKey, value: json.encode(data));
    } catch (_) {}
  }

  Future<void> requestPermissions() async {
    final manager = ref.read(notificationManagerProvider);
    final granted = await manager.requestPermissions();
    state = state.copyWith(permissionGranted: granted);
    await _saveSettings();
    if (granted) {
      _syncAllReminders();
    }
  }

  void _syncAllReminders() {
    final manager = ref.read(notificationManagerProvider);
    
    // Breakfast
    if (state.breakfastReminder) {
      manager.scheduleDailyMealReminder(
        id: 1,
        mealName: 'Breakfast',
        hour: state.breakfastHour,
        minute: state.breakfastMinute,
      );
    } else {
      manager.cancelReminder(1);
    }

    // Lunch
    if (state.lunchReminder) {
      manager.scheduleDailyMealReminder(
        id: 2,
        mealName: 'Lunch',
        hour: state.lunchHour,
        minute: state.lunchMinute,
      );
    } else {
      manager.cancelReminder(2);
    }

    // Dinner
    if (state.dinnerReminder) {
      manager.scheduleDailyMealReminder(
        id: 3,
        mealName: 'Dinner',
        hour: state.dinnerHour,
        minute: state.dinnerMinute,
      );
    } else {
      manager.cancelReminder(3);
    }

    // Daily Summary
    if (state.dailySummaryReminder) {
      manager.scheduleDailySummaryReminder(
        id: 4,
        hour: state.dailySummaryHour,
        minute: state.dailySummaryMinute,
      );
    } else {
      manager.cancelReminder(4);
    }
  }

  Future<void> updateBreakfastReminder(bool enabled) async {
    state = state.copyWith(breakfastReminder: enabled);
    await _saveSettings();
    _syncAllReminders();
  }

  Future<void> updateBreakfastTime(int hour, int minute) async {
    state = state.copyWith(breakfastHour: hour, breakfastMinute: minute);
    await _saveSettings();
    _syncAllReminders();
  }

  Future<void> updateLunchReminder(bool enabled) async {
    state = state.copyWith(lunchReminder: enabled);
    await _saveSettings();
    _syncAllReminders();
  }

  Future<void> updateLunchTime(int hour, int minute) async {
    state = state.copyWith(lunchHour: hour, lunchMinute: minute);
    await _saveSettings();
    _syncAllReminders();
  }

  Future<void> updateDinnerReminder(bool enabled) async {
    state = state.copyWith(dinnerReminder: enabled);
    await _saveSettings();
    _syncAllReminders();
  }

  Future<void> updateDinnerTime(int hour, int minute) async {
    state = state.copyWith(dinnerHour: hour, dinnerMinute: minute);
    await _saveSettings();
    _syncAllReminders();
  }

  Future<void> updateDailySummaryReminder(bool enabled) async {
    state = state.copyWith(dailySummaryReminder: enabled);
    await _saveSettings();
    _syncAllReminders();
  }

  Future<void> updateDailySummaryTime(int hour, int minute) async {
    state = state.copyWith(dailySummaryHour: hour, dailySummaryMinute: minute);
    await _saveSettings();
    _syncAllReminders();
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>(() {
  return NotificationSettingsNotifier();
});
