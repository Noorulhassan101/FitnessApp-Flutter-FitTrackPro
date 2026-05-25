import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/database/local_database.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/workouts/providers/workouts_provider.dart';
import 'package:mobile/features/home/providers/home_provider.dart';

final userWeightProvider = FutureProvider<double>((ref) async {
  final db = ref.watch(databaseProvider);
  final authState = ref.watch(authProvider);
  final userId = authState.userId;
  if (userId == null) return 70.0;
  final user = await (db.select(db.users)..where((t) => t.id.equals(userId))).getSingleOrNull();
  return user?.weightKg ?? 70.0;
});

class AddWorkoutPage extends ConsumerStatefulWidget {
  const AddWorkoutPage({super.key});

  @override
  ConsumerState<AddWorkoutPage> createState() => _AddWorkoutPageState();
}

class _AddWorkoutPageState extends ConsumerState<AddWorkoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _durationController = TextEditingController(text: '30');

  String _selectedActivity = 'Running';
  double _durationMin = 30.0;
  DateTime _loggedAt = DateTime.now();
  bool _isLoading = false;

  final Map<String, IconData> _activityIcons = {
    'Running': Icons.directions_run_rounded,
    'Cycling': Icons.directions_bike_rounded,
    'Swimming': Icons.pool_rounded,
    'Weightlifting': Icons.fitness_center_rounded,
    'Walking': Icons.directions_walk_rounded,
    'Yoga': Icons.self_improvement_rounded,
    'Other': Icons.star_rounded,
  };

  final Map<String, double> _activityMets = {
    'Running': 9.8,
    'Cycling': 7.5,
    'Swimming': 6.0,
    'Weightlifting': 5.0,
    'Walking': 3.5,
    'Yoga': 2.5,
    'Other': 4.0,
  };

  @override
  void dispose() {
    _notesController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  double _calculateEstimatedCalories(double weight) {
    final met = _activityMets[_selectedActivity] ?? 4.0;
    return met * weight * (_durationMin / 60.0);
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _loggedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_loggedAt),
      );

      if (time != null && mounted) {
        setState(() {
          _loggedAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  Future<void> _submit(double userWeight) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final met = _activityMets[_selectedActivity] ?? 4.0;
    final estimatedCals = _calculateEstimatedCalories(userWeight);

    final success = await ref.read(workoutsNotifierProvider.notifier).addWorkout(
          activityType: _selectedActivity,
          durationMin: _durationMin.round(),
          caloriesBurned: estimatedCals,
          metEstimate: met,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          loggedAt: _loggedAt,
        );

    setState(() => _isLoading = false);

    if (success && mounted) {
      // Invalidate home data provider so it reloads immediately
      ref.invalidate(homeDataProvider);
      context.pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save workout')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final weightAsync = ref.watch(userWeightProvider);
    final userWeight = weightAsync.value ?? 70.0;

    final estimatedCalories = _calculateEstimatedCalories(userWeight);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Log Workout',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Activity selection header
                const Text(
                  'Select Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Horizontal scroll of activities
                SizedBox(
                  height: 95,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _activityIcons.keys.length,
                    itemBuilder: (context, index) {
                      final name = _activityIcons.keys.elementAt(index);
                      final icon = _activityIcons[name]!;
                      final isSelected = _selectedActivity == name;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedActivity = name),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 85,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1A36A8) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? Colors.transparent : Colors.black12,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF1A36A8).withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                icon,
                                color: isSelected ? Colors.white : Colors.black54,
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // Duration Slider & Input Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Duration (minutes)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: TextFormField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null && parsed >= 1 && parsed <= 300) {
                            setState(() {
                              _durationMin = parsed;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF1A36A8),
                    inactiveTrackColor: Colors.black12,
                    thumbColor: const Color(0xFF1A36A8),
                    overlayColor: const Color(0xFF1A36A8).withValues(alpha: 0.1),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _durationMin.clamp(1.0, 180.0),
                    min: 1.0,
                    max: 180.0,
                    onChanged: (val) {
                      setState(() {
                        _durationMin = val;
                        _durationController.text = val.round().toString();
                      });
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Live Calorie Estimation Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3358D4), Color(0xFF1A36A8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1A36A8).withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'ESTIMATED CALORIES BURNED',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            estimatedCalories.toStringAsFixed(0),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'kcal',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Based on your weight (${userWeight.toStringAsFixed(0)} kg) and activity MET',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Logged At picker row
                GestureDetector(
                  onTap: _selectDateTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, color: Colors.black54, size: 20),
                            SizedBox(width: 12),
                            Text(
                              'Date & Time',
                              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                            ),
                          ],
                        ),
                        Text(
                          '${_loggedAt.day}/${_loggedAt.month}/${_loggedAt.year} ${_loggedAt.hour.toString().padLeft(2, '0')}:${_loggedAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A36A8)),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Notes input field
                const Text(
                  'Notes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Add workout details, e.g., intensity, route, or equipment used.',
                    hintStyle: const TextStyle(color: Colors.black26),
                    fillColor: Colors.white,
                    filled: true,
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black12),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Log Workout Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _submit(userWeight),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A36A8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Log Workout',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
