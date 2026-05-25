import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/auth/presentation/landing_page.dart';
import 'package:mobile/features/auth/presentation/login_page.dart';
import 'package:mobile/features/auth/presentation/signup_page.dart';
import 'package:mobile/features/auth/presentation/onboarding_page.dart';
import 'package:mobile/features/home/presentation/home_page.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/workouts/presentation/add_workout_page.dart';
import 'package:mobile/features/meals/presentation/add_meal_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/landing',
    redirect: (context, state) {
      final status = authState.status;
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';
      final isLanding = state.matchedLocation == '/landing';

      if (status == AuthStatus.initial || status == AuthStatus.loading) {
        return null;
      }

      if (status == AuthStatus.unauthenticated) {
        if (!loggingIn) return '/landing';
        return null;
      }

      if (status == AuthStatus.onboardingRequired) {
        if (state.matchedLocation != '/onboarding') return '/onboarding';
        return null;
      }

      if (status == AuthStatus.authenticated) {
        if (loggingIn || isLanding || state.matchedLocation == '/onboarding') return '/home';
        return null;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/landing',
        builder: (context, state) => const LandingPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/add-workout',
        builder: (context, state) => const AddWorkoutPage(),
      ),
      GoRoute(
        path: '/add-meal',
        builder: (context, state) => const AddMealPage(),
      ),
    ],
  );
});
