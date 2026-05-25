import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'local_database.g.dart';

// User Table Definition
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get name => text().nullable()();
  IntColumn get age => integer().nullable()();
  TextColumn get gender => text().nullable()();
  RealColumn get heightCm => real().nullable()();
  RealColumn get weightKg => real().nullable()();
  TextColumn get fitnessGoal => text().nullable()();
  TextColumn get unitPreference => text().withDefault(const Constant('metric'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// Workout Log Table Definition
class Workouts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get activityType => text()();
  IntColumn get durationMin => integer()();
  RealColumn get caloriesBurned => real()();
  RealColumn get metEstimate => real()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get loggedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// Meal Log Table Definition
class Meals extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get mealCategory => text()(); // breakfast, lunch, dinner, snack
  TextColumn get foodName => text()();
  RealColumn get caloriesConsumed => real()();
  DateTimeColumn get loggedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// Daily Summary Table Definition
class DailySummaries extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get date => dateTime()();
  RealColumn get totalCaloriesBurned => real().withDefault(const Constant(0.0))();
  RealColumn get totalCaloriesConsumed => real().withDefault(const Constant(0.0))();
  RealColumn get netCalories => real().withDefault(const Constant(0.0))();
  IntColumn get streakDay => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Users, Workouts, Meals, DailySummaries])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(dailySummaries);
          }
        },
      );

  // Workout Queries
  Stream<List<Workout>> watchWorkoutsForDay(String userId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    return (select(workouts)
          ..where((t) => t.userId.equals(userId) & t.loggedAt.isBetweenValues(startOfDay, endOfDay))
          ..orderBy([(t) => OrderingTerm(expression: t.loggedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<Workout>> getUnsyncedWorkouts() {
    return (select(workouts)..where((t) => t.isSynced.equals(false))).get();
  }

  Future<void> upsertWorkout(Workout workout) {
    return into(workouts).insertOnConflictUpdate(workout);
  }

  Future<void> deleteWorkoutLocal(String id) {
    return (delete<Workouts, Workout>(workouts)..where((t) => t.id.equals(id))).go();
  }

  // Meal Queries
  Stream<List<Meal>> watchMealsForDay(String userId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    return (select(meals)
          ..where((t) => t.userId.equals(userId) & t.loggedAt.isBetweenValues(startOfDay, endOfDay))
          ..orderBy([(t) => OrderingTerm(expression: t.loggedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<Meal>> getUnsyncedMeals() {
    return (select(meals)..where((t) => t.isSynced.equals(false))).get();
  }

  Future<void> upsertMeal(Meal meal) {
    return into(meals).insertOnConflictUpdate(meal);
  }

  Future<void> deleteMealLocal(String id) {
    return (delete<Meals, Meal>(meals)..where((t) => t.id.equals(id))).go();
  }

  // Daily Summary Queries
  Stream<List<DailySummary>> watchWeeklySummaries(String userId) {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return (select(dailySummaries)
          ..where((t) => t.userId.equals(userId) & t.date.isBiggerThanValue(sevenDaysAgo))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.asc)]))
        .watch();
  }

  Future<void> upsertSummary(DailySummary summary) {
    return into(dailySummaries).insertOnConflictUpdate(summary);
  }

  // User Queries
  Stream<User?> watchUser(String userId) {
    return (select(users)..where((t) => t.id.equals(userId))).watchSingleOrNull();
  }

  Future<void> upsertUser(User user) {
    return into(users).insertOnConflictUpdate(user);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'fittrackpro.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

final databaseProvider = Provider<LocalDatabase>((ref) {
  final db = LocalDatabase();
  ref.onDispose(db.close);
  return db;
});
