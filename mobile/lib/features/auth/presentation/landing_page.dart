import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Sparkle> _sparkles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..addListener(() {
        _updateSparkles();
      })..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sparkles.isEmpty) {
      final size = MediaQuery.of(context).size;
      for (var i = 0; i < 55; i++) {
        _sparkles.add(
          Sparkle(
            x: _random.nextDouble() * size.width,
            y: _random.nextDouble() * size.height,
            radius: _random.nextDouble() * 2.2 + 0.8,
            speed: _random.nextDouble() * 0.7 + 0.3,
            opacity: _random.nextDouble() * 0.45 + 0.1,
          ),
        );
      }
    }
  }

  void _updateSparkles() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    setState(() {
      for (final s in _sparkles) {
        s.y -= s.speed;
        if (s.y < -s.radius) {
          s.y = size.height + s.radius;
          s.x = _random.nextDouble() * size.width;
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Royal blue gradient — matches reference image exactly
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF3358D4), // bright royal blue top
                  Color(0xFF2448C0), // mid blue
                  Color(0xFF1A36A8), // deep royal blue bottom
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Subtle radial center glow to match reference image
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.35),
                radius: 0.75,
                colors: [
                  Color(0x3A5578F8), // lighter blue glow
                  Color(0x00000000), // transparent
                ],
              ),
            ),
          ),

          // Floating sparkle dots
          CustomPaint(
            size: size,
            painter: SparklePainter(sparkles: _sparkles),
          ),

          // Main UI
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Flame icon in semi-transparent circle (matches reference)
                  Center(
                    child: Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.local_fire_department_rounded,
                          size: 58,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Brand title
                  const Text(
                    'FitTrack Pro',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Tagline
                  Text(
                    'Your calories, your control.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const Spacer(),

                  // Buttons
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // "Get Started" — white filled pill
                      ElevatedButton(
                        onPressed: () => context.push('/signup'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1A36A8),
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // "Log In" — white outline pill
                      OutlinedButton(
                        onPressed: () => context.push('/login'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: const Text(
                          'Log In',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Sparkle {
  double x;
  double y;
  final double radius;
  final double speed;
  final double opacity;

  Sparkle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.opacity,
  });
}

class SparklePainter extends CustomPainter {
  final List<Sparkle> sparkles;
  SparklePainter({required this.sparkles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in sparkles) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: s.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(s.x, s.y), s.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
