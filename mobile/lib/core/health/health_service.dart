import 'package:health/health.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HealthService {
  final Health _health = Health();
  bool _isConfigured = false;

  Future<void> _ensureConfigured() async {
    if (!_isConfigured) {
      await _health.configure();
      _isConfigured = true;
    }
  }

  Future<bool> requestPermissions() async {
    await _ensureConfigured();
    final types = [
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
    ];
    final permissions = [
      HealthDataAccess.READ,
      HealthDataAccess.READ,
    ];
    try {
      final granted = await _health.requestAuthorization(types, permissions: permissions);
      return granted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPermissions() async {
    await _ensureConfigured();
    final types = [
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
    ];
    final permissions = [
      HealthDataAccess.READ,
      HealthDataAccess.READ,
    ];
    try {
      final has = await _health.hasPermissions(types, permissions: permissions);
      return has ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<int> fetchStepsForDay(DateTime date) async {
    await _ensureConfigured();
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    try {
      final steps = await _health.getTotalStepsInInterval(start, end);
      return steps ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<double> fetchActiveCaloriesForDay(DateTime date) async {
    await _ensureConfigured();
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    try {
      final dataPoints = await _health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: start,
        endTime: end,
      );
      double total = 0.0;
      for (final point in dataPoints) {
        final val = point.value;
        if (val is NumericHealthValue) {
          total += val.numericValue.toDouble();
        }
      }
      return total;
    } catch (_) {
      return 0.0;
    }
  }
}

final healthServiceProvider = Provider<HealthService>((ref) {
  return HealthService();
});
