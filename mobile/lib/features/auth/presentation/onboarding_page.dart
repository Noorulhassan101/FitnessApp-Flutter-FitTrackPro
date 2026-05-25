import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _currentStep = 1;

  // Step 1 values
  String _selectedGender = 'Male';
  final _ageController = TextEditingController(text: '25');
  final _heightController = TextEditingController(text: '175');
  final _weightController = TextEditingController(text: '70');

  String _heightUnit = 'cm'; // cm, ft
  String _weightUnit = 'kg'; // kg, lbs

  // Step 2 values
  String _selectedActivity = 'Moderately Active'; // Sedentary, Lightly Active, Moderately Active, Very Active

  // Step 3 values
  String _selectedGoal = 'deficit'; // deficit, surplus, maintain

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // Unit conversion helpers
  double get _heightInCm {
    final val = double.tryParse(_heightController.text.trim()) ?? 170.0;
    final cm = (_heightUnit == 'ft') ? val * 30.48 : val;
    return cm.clamp(50.0, 300.0); // guard against impossible values
  }

  double get _weightInKg {
    final val = double.tryParse(_weightController.text.trim()) ?? 70.0;
    final kg = (_weightUnit == 'lbs') ? val * 0.453592 : val;
    return kg.clamp(20.0, 500.0);
  }

  int get _age {
    final val = int.tryParse(_ageController.text.trim()) ?? 25;
    return val.clamp(1, 120);
  }

  // Dynamic BMR Calculation (Mifflin-St Jeor)
  double get _calculatedBMR {
    final weight = _weightInKg;
    final height = _heightInCm;
    final age = _age;

    if (_selectedGender == 'Male') {
      return 10 * weight + 6.25 * height - 5 * age + 5;
    } else if (_selectedGender == 'Female') {
      return 10 * weight + 6.25 * height - 5 * age - 161;
    } else {
      // Other: Average of male/female
      return 10 * weight + 6.25 * height - 5 * age - 78;
    }
  }

  Future<void> _submit() async {
    final success = await ref.read(authProvider.notifier).submitOnboarding(
          gender: _selectedGender,
          age: _age,
          heightCm: _heightInCm,
          weightKg: _weightInKg,
          unitPreference: _weightUnit == 'lbs' ? 'imperial' : 'metric',
          activityLevel: _selectedActivity,
          fitnessGoal: _selectedGoal,
        );

    if (success && mounted) {
      context.go('/home');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save onboarding data. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Onboarding Header Bar (Indicator + Progress Line)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step $_currentStep of 3',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF000080),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () => ref.read(authProvider.notifier).logout(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress Bar line
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: _currentStep / 3,
                      backgroundColor: Colors.black12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF000080)),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildStepContent(),
              ),
            ),

            // Bottom Navigation Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: () {
                  if (_currentStep < 3) {
                    setState(() {
                      _currentStep++;
                    });
                  } else {
                    _submit();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF000080),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _currentStep == 3 ? 'Get Started' : 'Continue',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      default:
        return const SizedBox.shrink();
    }
  }

  // STEP 1 UI: Let's get to know you
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Let's get to know you",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "This helps us calculate your daily targets accurately.",
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 32),

        // Gender Selector
        const Text(
          'Gender',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildGenderCard('Male', Icons.male),
            const SizedBox(width: 12),
            _buildGenderCard('Female', Icons.female),
            const SizedBox(width: 12),
            _buildGenderCard('Other', Icons.transgender),
          ],
        ),

        const SizedBox(height: 24),

        // Age Input
        const Text(
          'Age',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        _buildTextFieldWithSuffix(
          controller: _ageController,
          hintText: 'e.g. 28',
          suffix: 'years',
        ),

        const SizedBox(height: 24),

        // Height Input with Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Height',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            _buildUnitSegmentedToggle(
              options: ['cm', 'ft'],
              selected: _heightUnit,
              onChanged: (val) => setState(() => _heightUnit = val),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextFieldWithSuffix(
          controller: _heightController,
          hintText: 'e.g. 175',
          suffix: _heightUnit,
        ),

        const SizedBox(height: 24),

        // Weight Input with Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Weight',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            _buildUnitSegmentedToggle(
              options: ['kg', 'lbs'],
              selected: _weightUnit,
              onChanged: (val) => setState(() => _weightUnit = val),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextFieldWithSuffix(
          controller: _weightController,
          hintText: 'e.g. 70',
          suffix: _weightUnit,
        ),
      ],
    );
  }

  // STEP 2 UI: Activity level selection
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "What is your activity level?",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "We use this to estimate your daily calorie burn from resting.",
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 32),

        _buildSelectionCard(
          title: 'Sedentary',
          description: 'Office job, little to no regular exercise.',
          value: 'Sedentary',
        ),
        const SizedBox(height: 16),
        _buildSelectionCard(
          title: 'Lightly Active',
          description: 'Light exercise or walking 1-3 days per week.',
          value: 'Lightly Active',
        ),
        const SizedBox(height: 16),
        _buildSelectionCard(
          title: 'Moderately Active',
          description: 'Moderate exercise or sports 3-5 days per week.',
          value: 'Moderately Active',
        ),
        const SizedBox(height: 16),
        _buildSelectionCard(
          title: 'Very Active',
          description: 'Hard exercise or intense sports 6-7 days per week.',
          value: 'Very Active',
        ),
      ],
    );
  }

  // STEP 3 UI: Fitness goal & BMR Display
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Choose your fitness goal",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "This determines your calorie surplus or deficit targets.",
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 24),

        // Dynamic BMR Highlight Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF000080).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF000080).withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              const Text(
                'YOUR ESTIMATED BMR',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF000080),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${_calculatedBMR.toStringAsFixed(0)} kcal',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF000080),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This is the resting energy your body burns daily.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        _buildGoalCard(
          title: 'Calorie Deficit (Weight Loss)',
          description: 'Consume fewer calories than burned to drop weight.',
          value: 'deficit',
        ),
        const SizedBox(height: 16),
        _buildGoalCard(
          title: 'Calorie Surplus (Muscle Gain)',
          description: 'Consume extra calories to support weight and muscle growth.',
          value: 'surplus',
        ),
        const SizedBox(height: 16),
        _buildGoalCard(
          title: 'Calorie Maintenance',
          description: 'Balance calories burned and consumed to maintain current weight.',
          value: 'maintain',
        ),
      ],
    );
  }

  // WIDGET BUILDERS

  // Custom Gender Card Builder
  Widget _buildGenderCard(String value, IconData icon) {
    final isSelected = _selectedGender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF000080) : Colors.black12,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: const Color(0xFF000080).withValues(alpha: 0.1), blurRadius: 8)]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected ? const Color(0xFF000080) : Colors.black45,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFF000080) : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Text Field with suffix badge — selects all text on tap so default is replaced cleanly
  Widget _buildTextFieldWithSuffix({
    required TextEditingController controller,
    required String hintText,
    required String suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
              // Select all on tap so typing replaces the default value completely
              onTap: () {
                controller.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: controller.text.length,
                );
              },
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.black26),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: InputBorder.none,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F2F6),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(11),
                bottomRight: Radius.circular(11),
              ),
            ),
            child: Text(
              suffix,
              style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Segmented unit toggle
  Widget _buildUnitSegmentedToggle({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFE4E5EA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map<Widget>((option) {
          final isSelected = selected == option;
          return GestureDetector(
            onTap: () => onChanged(option),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isSelected
                    ? [const BoxShadow(color: Colors.black12, blurRadius: 2)]
                    : null,
              ),
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black87 : Colors.black45,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Custom Selector Card for Activity Step
  Widget _buildSelectionCard({
    required String title,
    required String description,
    required String value,
  }) {
    final isSelected = _selectedActivity == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedActivity = value),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF000080) : Colors.black12,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF000080).withValues(alpha: 0.05), blurRadius: 8)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF000080) : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  // Custom Selector Card for Goal Step
  Widget _buildGoalCard({
    required String title,
    required String description,
    required String value,
  }) {
    final isSelected = _selectedGoal == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedGoal = value),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF000080) : Colors.black12,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF000080).withValues(alpha: 0.05), blurRadius: 8)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF000080) : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
