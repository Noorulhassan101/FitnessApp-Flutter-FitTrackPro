import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/home/providers/home_provider.dart';
import 'package:mobile/features/workouts/providers/workouts_provider.dart';
import 'package:mobile/features/meals/providers/meals_provider.dart';
import 'package:mobile/features/stats/presentation/stats_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(homeDataProvider);

    return homeAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFFF9F9FB),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: const Color(0xFFF9F9FB),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Failed to load data'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(homeDataProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (homeData) => _HomeContent(homeData: homeData),
    );
  }
}

class _HomeContent extends ConsumerStatefulWidget {
  final HomeData homeData;
  const _HomeContent({required this.homeData});

  @override
  ConsumerState<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends ConsumerState<_HomeContent> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final homeData = widget.homeData;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A36A8).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFF1A36A8), size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
                ),
                Text(
                  homeData.userName,
                  style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.black54),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(homeData),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF1A36A8),
        unselectedItemColor: Colors.black38,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        elevation: 0,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.insert_chart_rounded), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildBody(HomeData homeData) {
    switch (_currentIndex) {
      case 1:
        return const StatsPage();
      case 2:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_rounded, size: 64, color: Colors.black26),
              SizedBox(height: 16),
              Text('Coming Soon', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black54)),
              SizedBox(height: 8),
              Text('Profile will be available in a future update.', style: TextStyle(color: Colors.black38)),
            ],
          ),
        );
      default:
        return _buildHomeTab(homeData);
    }
  }

  Widget _buildHomeTab(HomeData homeData) {
    final workoutsAsync = ref.watch(todayWorkoutsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Daily Summary Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3358D4), Color(0xFF1A36A8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A36A8).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Calories Remaining',
                  style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  homeData.caloriesRemaining.round().toStringAsFixed(0).replaceAllMapped(
                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                    (m) => '${m[1]},',
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: -1),
                ),
                const SizedBox(height: 20),
                // Target - Consumed + Burned Breakdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSummaryMini('Base Target', homeData.dailyCalorieTarget.round().toString()),
                    const Text('-', style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
                    _buildSummaryMini('Food', homeData.caloriesConsumed.round().toString()),
                    const Text('+', style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
                    _buildSummaryMini('Active', homeData.caloriesBurned.round().toString()),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMacroIndicator('Protein', '${homeData.proteinTarget.round()}g', Colors.white),
                    _buildMacroIndicator('Carbs', '${homeData.carbsTarget.round()}g', Colors.white),
                    _buildMacroIndicator('Fats', '${homeData.fatTarget.round()}g', Colors.white),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Today's Meals Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today\'s Meals',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              TextButton(
                onPressed: () => context.push('/add-meal'),
                child: const Text('Add Meal', style: TextStyle(color: Color(0xFF1A36A8), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ref.watch(todayMealsProvider).when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Failed to load meals: $error', style: const TextStyle(color: Colors.red)),
              ),
            ),
            data: (meals) {
              if (meals.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.restaurant_menu_rounded, size: 64, color: Colors.black12),
                      SizedBox(height: 16),
                      Text(
                        'No meals logged yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Track your first meal to see your progress.',
                        style: TextStyle(fontSize: 14, color: Colors.black38),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final Map<String, IconData> mealIcons = {
                'breakfast': Icons.wb_sunny_rounded,
                'lunch': Icons.lunch_dining_rounded,
                'dinner': Icons.dinner_dining_rounded,
                'snack': Icons.cookie_rounded,
              };

              String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: meals.length,
                itemBuilder: (context, index) {
                  final meal = meals[index];
                  final categoryKey = meal.mealCategory.toLowerCase();
                  final icon = mealIcons[categoryKey] ?? Icons.restaurant_menu_rounded;

                  return Dismissible(
                    key: Key(meal.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                    ),
                    onDismissed: (direction) async {
                      await ref.read(mealsNotifierProvider.notifier).deleteMeal(meal.id);
                      ref.invalidate(homeDataProvider);
                    },
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.black12),
                      ),
                      elevation: 0,
                      color: Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A36A8).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: const Color(0xFF1A36A8), size: 24),
                        ),
                        title: Text(
                          meal.foodName,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              capitalize(meal.mealCategory),
                              style: const TextStyle(color: Colors.black54, fontSize: 13),
                            ),
                            if (!meal.isSynced) ...[
                              const SizedBox(height: 4),
                              const Row(
                                children: [
                                  Icon(Icons.cloud_off_rounded, size: 12, color: Colors.black38),
                                  SizedBox(width: 4),
                                  Text('Saved offline', style: TextStyle(fontSize: 10, color: Colors.black38)),
                                ],
                              ),
                            ],
                          ],
                        ),
                        trailing: Text(
                          '-${meal.caloriesConsumed.round()} kcal',
                          style: const TextStyle(
                            color: Color(0xFFD9383A),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 32),

          // Today's Workouts Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today\'s Workouts',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              TextButton(
                onPressed: () => context.push('/add-workout'),
                child: const Text('Add Workout', style: TextStyle(color: Color(0xFF1A36A8), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Workouts Content
          workoutsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Failed to load workouts: $error', style: const TextStyle(color: Colors.red)),
              ),
            ),
            data: (workouts) {
              if (workouts.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.fitness_center_rounded, size: 64, color: Colors.black12),
                      SizedBox(height: 16),
                      Text(
                        'No workouts logged today',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Burn calories and reach your goals by tracking your activity.',
                        style: TextStyle(fontSize: 14, color: Colors.black38),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final Map<String, IconData> activityIcons = {
                'Running': Icons.directions_run_rounded,
                'Cycling': Icons.directions_bike_rounded,
                'Swimming': Icons.pool_rounded,
                'Weightlifting': Icons.fitness_center_rounded,
                'Walking': Icons.directions_walk_rounded,
                'Yoga': Icons.self_improvement_rounded,
                'Other': Icons.star_rounded,
              };

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: workouts.length,
                itemBuilder: (context, index) {
                  final workout = workouts[index];
                  final icon = activityIcons[workout.activityType] ?? Icons.star_rounded;

                  return Dismissible(
                    key: Key(workout.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                    ),
                    onDismissed: (direction) async {
                      await ref.read(workoutsNotifierProvider.notifier).deleteWorkout(workout.id);
                      ref.invalidate(homeDataProvider);
                    },
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.black12),
                      ),
                      elevation: 0,
                      color: Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A36A8).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: const Color(0xFF1A36A8), size: 24),
                        ),
                        title: Text(
                          workout.activityType,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${workout.durationMin} mins${workout.notes != null ? ' • ${workout.notes}' : ''}',
                              style: const TextStyle(color: Colors.black54, fontSize: 13),
                            ),
                            if (!workout.isSynced) ...[
                              const SizedBox(height: 4),
                              const Row(
                                  children: [
                                    Icon(Icons.cloud_off_rounded, size: 12, color: Colors.black38),
                                    SizedBox(width: 4),
                                    Text('Saved offline', style: TextStyle(fontSize: 10, color: Colors.black38)),
                                  ],
                                ),
                            ],
                          ],
                        ),
                        trailing: Text(
                          '+${workout.caloriesBurned.round()} kcal',
                          style: const TextStyle(
                            color: Color(0xFF1D976C),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMini(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMacroIndicator(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
