import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/database/local_database.dart';
import 'package:mobile/features/profile/providers/profile_provider.dart';
import 'package:mobile/features/notifications/providers/notification_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  String _gender = 'Male';
  String _activityLevel = 'Moderately Active';
  String _fitnessGoal = 'maintain';
  String _unitPreference = 'metric';

  bool _initialized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ageController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();

    // Trigger profile sync from backend on load
    Future.microtask(() {
      ref.read(profileNotifierProvider.notifier).syncProfile();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _initializeValues(User user) {
    if (_initialized) return;

    _nameController.text = user.name ?? '';
    _ageController.text = user.age?.toString() ?? '25';
    _gender = user.gender ?? 'Male';
    _activityLevel = user.fitnessGoal == 'weight_loss' ? 'Moderately Active' : 'Moderately Active'; // Default baseline
    _unitPreference = user.unitPreference;
    
    // Attempt to match activityLevel from local schema if not set
    // For local database fallback support:
    _fitnessGoal = user.fitnessGoal ?? 'maintain';

    // Set height and weight based on preferred unit preference
    final heightCm = user.heightCm ?? 170.0;
    final weightKg = user.weightKg ?? 70.0;

    if (_unitPreference == 'imperial') {
      _heightController.text = (heightCm / 2.54).toStringAsFixed(1);
      _weightController.text = (weightKg * 2.20462).toStringAsFixed(1);
    } else {
      _heightController.text = heightCm.toStringAsFixed(1);
      _weightController.text = weightKg.toStringAsFixed(1);
    }

    _initialized = true;
  }

  // Unit Toggle handler
  void _toggleUnitPreference(String newPreference) {
    if (_unitPreference == newPreference) return;

    final currentHeight = double.tryParse(_heightController.text) ?? 0.0;
    final currentWeight = double.tryParse(_weightController.text) ?? 0.0;

    setState(() {
      _unitPreference = newPreference;
      if (newPreference == 'imperial') {
        // Metric -> Imperial (cm -> inches, kg -> lbs)
        _heightController.text = (currentHeight / 2.54).toStringAsFixed(1);
        _weightController.text = (currentWeight * 2.20462).toStringAsFixed(1);
      } else {
        // Imperial -> Metric (inches -> cm, lbs -> kg)
        _heightController.text = (currentHeight * 2.54).toStringAsFixed(1);
        _weightController.text = (currentWeight / 2.20462).toStringAsFixed(1);
      }
    });
  }

  // Live computed metrics (BMR & TDEE)
  Map<String, double> _calculateLiveMetrics() {
    final age = int.tryParse(_ageController.text) ?? 25;
    final heightInput = double.tryParse(_heightController.text) ?? 170.0;
    final weightInput = double.tryParse(_weightController.text) ?? 70.0;

    // Convert to metric if currently in imperial
    double heightCm = heightInput;
    double weightKg = weightInput;
    if (_unitPreference == 'imperial') {
      heightCm = heightInput * 2.54;
      weightKg = weightInput / 2.20462;
    }

    // Mifflin-St Jeor Formula
    double bmr = 0.0;
    final genderLower = _gender.toLowerCase();
    if (genderLower == 'male' || genderLower == 'm') {
      bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
    } else if (genderLower == 'female' || genderLower == 'f') {
      bmr = 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
    } else {
      bmr = 10 * weightKg + 6.25 * heightCm - 5 * age - 78;
    }

    final activityMultipliers = {
      'Sedentary': 1.2,
      'Lightly Active': 1.375,
      'Moderately Active': 1.55,
      'Very Active': 1.725,
    };
    final multiplier = activityMultipliers[_activityLevel] ?? 1.55;
    final tdee = bmr * multiplier;

    return {'bmr': bmr, 'tdee': tdee};
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final name = _nameController.text.trim();
    final age = int.parse(_ageController.text);
    final heightInput = double.parse(_heightController.text);
    final weightInput = double.parse(_weightController.text);

    // Normalize to metric for backend submission
    double heightCm = heightInput;
    double weightKg = weightInput;
    if (_unitPreference == 'imperial') {
      heightCm = heightInput * 2.54;
      weightKg = weightInput / 2.20462;
    }

    final success = await ref.read(profileNotifierProvider.notifier).updateProfile(
          name: name,
          gender: _gender,
          age: age,
          heightCm: heightCm,
          weightKg: weightKg,
          unitPreference: _unitPreference,
          activityLevel: _activityLevel,
          fitnessGoal: _fitnessGoal,
        );

    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Profile updated successfully!' : 'Failed to update profile.',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: success ? Colors.green : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile Settings',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text('Failed to load profile: $err'),
              ],
            ),
          ),
          data: (user) {
            if (user == null) {
              return const Center(child: Text('No active user profile.'));
            }

            _initializeValues(user);
            final liveMetrics = _calculateLiveMetrics();
            final computedBmr = liveMetrics['bmr'] ?? 1500.0;
            final computedTdee = liveMetrics['tdee'] ?? 2000.0;

            // Compute target calories based on goal
            double targetCalories = computedTdee;
            if (_fitnessGoal == 'deficit') {
              targetCalories = computedTdee - 500;
            } else if (_fitnessGoal == 'surplus') {
              targetCalories = computedTdee + 300;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Form(
                key: _formKey,
                onChanged: () => setState(() {}), // Trigger live calculation update
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // User Overview Header
                    _buildHeaderCard(user),
                    const SizedBox(height: 24),

                    // Live computed target calorie metrics card
                    _buildLiveCalculationsCard(computedBmr, computedTdee, targetCalories),
                    const SizedBox(height: 24),

                    // Physical metrics sections
                    _buildSectionHeader('Physical Metrics'),
                    const SizedBox(height: 12),
                    _buildPhysicalMetricsFields(),
                    const SizedBox(height: 24),

                    // Goals & Preferences sections
                    _buildSectionHeader('Goals & Preferences'),
                    const SizedBox(height: 12),
                    _buildGoalsPreferencesFields(),
                    const SizedBox(height: 24),

                    // Reminders & Settings
                    _buildSectionHeader('Reminders & Settings'),
                    const SizedBox(height: 12),
                    _buildRemindersCard(),
                    const SizedBox(height: 32),

                    // Save Button
                    ElevatedButton(
                      onPressed: _saving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A36A8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Save Profile Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderCard(User user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF1A36A8).withValues(alpha: 0.1),
            child: const Icon(Icons.person_rounded, color: Color(0xFF1A36A8), size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name ?? 'User',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCalculationsCard(double bmr, double tdee, double target) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A36A8), Color(0xFF3358D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A36A8).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate_outlined, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text(
                'Live Target Estimates',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricColumn('BMR', '${bmr.round()} kcal'),
              _buildMetricSeparator(),
              _buildMetricColumn('TDEE', '${tdee.round()} kcal'),
              _buildMetricSeparator(),
              _buildMetricColumn('Daily Goal', '${target.round()} kcal'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMetricSeparator() {
    return Container(
      height: 28,
      width: 1,
      color: Colors.white24,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  Widget _buildPhysicalMetricsFields() {
    final heightLabel = _unitPreference == 'metric' ? 'Height (cm)' : 'Height (inches)';
    final weightLabel = _unitPreference == 'metric' ? 'Weight (kg)' : 'Weight (lbs)';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Full Name Text Field
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Full Name', hintText: 'Enter your name'),
            validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 16),

          // Unit Preference Segmented Toggles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Unit Preference', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'metric', label: Text('Metric')),
                  ButtonSegment(value: 'imperial', label: Text('Imperial')),
                ],
                selected: {_unitPreference},
                onSelectionChanged: (set) => _toggleUnitPreference(set.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Age, Height, Weight fields in a row layout
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age'),
                  validator: (val) {
                    final parsed = int.tryParse(val ?? '');
                    if (parsed == null || parsed <= 0) return 'Invalid';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: heightLabel),
                  validator: (val) {
                    final parsed = double.tryParse(val ?? '');
                    if (parsed == null || parsed <= 0) return 'Invalid';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: weightLabel),
                  validator: (val) {
                    final parsed = double.tryParse(val ?? '');
                    if (parsed == null || parsed <= 0) return 'Invalid';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Gender Dropdown
          DropdownButtonFormField<String>(
            value: _gender,
            decoration: const InputDecoration(labelText: 'Gender'),
            items: ['Male', 'Female', 'Other'].map((g) {
              return DropdownMenuItem(value: g, child: Text(g));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _gender = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsPreferencesFields() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          // Activity Level selector dropdown
          DropdownButtonFormField<String>(
            value: _activityLevel,
            decoration: const InputDecoration(labelText: 'Activity Level'),
            items: ['Sedentary', 'Lightly Active', 'Moderately Active', 'Very Active'].map((level) {
              return DropdownMenuItem(value: level, child: Text(level));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _activityLevel = val);
            },
          ),
          const SizedBox(height: 16),

          // Fitness Goal Selector dropdown
          DropdownButtonFormField<String>(
            value: _fitnessGoal,
            decoration: const InputDecoration(labelText: 'Fitness Goal'),
            items: const [
              DropdownMenuItem(value: 'deficit', child: Text('Weight Loss (Deficit)')),
              DropdownMenuItem(value: 'surplus', child: Text('Muscle Gain (Surplus)')),
              DropdownMenuItem(value: 'maintain', child: Text('Maintenance')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _fitnessGoal = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersCard() {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Permission status / Grant action
          if (!settings.permissionGranted) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A36A8).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_outlined, color: Color(0xFF1A36A8)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Notifications are disabled. Enable reminders to stay on track!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A36A8),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => notifier.requestPermissions(),
                    child: const Text(
                      'Enable',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A36A8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Breakfast Reminder
          _buildReminderRow(
            title: 'Breakfast Reminder',
            subtitle: 'Log your morning meal',
            enabled: settings.breakfastReminder,
            hour: settings.breakfastHour,
            minute: settings.breakfastMinute,
            onChanged: (val) => notifier.updateBreakfastReminder(val),
            onTapTime: () => _selectTime(
              context,
              settings.breakfastHour,
              settings.breakfastMinute,
              (h, m) => notifier.updateBreakfastTime(h, m),
            ),
          ),
          const Divider(height: 24, thickness: 0.8),

          // Lunch Reminder
          _buildReminderRow(
            title: 'Lunch Reminder',
            subtitle: 'Log your midday meal',
            enabled: settings.lunchReminder,
            hour: settings.lunchHour,
            minute: settings.lunchMinute,
            onChanged: (val) => notifier.updateLunchReminder(val),
            onTapTime: () => _selectTime(
              context,
              settings.lunchHour,
              settings.lunchMinute,
              (h, m) => notifier.updateLunchTime(h, m),
            ),
          ),
          const Divider(height: 24, thickness: 0.8),

          // Dinner Reminder
          _buildReminderRow(
            title: 'Dinner Reminder',
            subtitle: 'Log your evening meal',
            enabled: settings.dinnerReminder,
            hour: settings.dinnerHour,
            minute: settings.dinnerMinute,
            onChanged: (val) => notifier.updateDinnerReminder(val),
            onTapTime: () => _selectTime(
              context,
              settings.dinnerHour,
              settings.dinnerMinute,
              (h, m) => notifier.updateDinnerTime(h, m),
            ),
          ),
          const Divider(height: 24, thickness: 0.8),

          // Daily Summary Reminder
          _buildReminderRow(
            title: 'Daily Summary',
            subtitle: 'Calorie and streak analysis',
            enabled: settings.dailySummaryReminder,
            hour: settings.dailySummaryHour,
            minute: settings.dailySummaryMinute,
            onChanged: (val) => notifier.updateDailySummaryReminder(val),
            onTapTime: () => _selectTime(
              context,
              settings.dailySummaryHour,
              settings.dailySummaryMinute,
              (h, m) => notifier.updateDailySummaryTime(h, m),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderRow({
    required String title,
    required String subtitle,
    required bool enabled,
    required int hour,
    required int minute,
    required ValueChanged<bool> onChanged,
    required VoidCallback onTapTime,
  }) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour == 0
        ? 12
        : hour > 12
            ? hour - 12
            : hour;
    final formattedMinute = minute.toString().padLeft(2, '0');
    final timeText = '$formattedHour:$formattedMinute $period';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
        if (enabled) ...[
          OutlinedButton(
            onPressed: onTapTime,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: const BorderSide(color: Colors.black12),
            ),
            child: Text(
              timeText,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A36A8)),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Switch.adaptive(
          value: enabled,
          onChanged: onChanged,
          activeColor: const Color(0xFF1A36A8),
        ),
      ],
    );
  }

  Future<void> _selectTime(
      BuildContext context, int currentHour, int currentMinute, Function(int, int) onTimeSelected) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: currentMinute),
    );
    if (picked != null) {
      onTimeSelected(picked.hour, picked.minute);
    }
  }
}
