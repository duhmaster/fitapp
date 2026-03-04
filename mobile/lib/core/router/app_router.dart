import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/features/auth/data/auth_repository.dart';
import 'package:fitflow/features/auth/presentation/login_screen.dart';
import 'package:fitflow/features/auth/presentation/register_screen.dart';
import 'package:fitflow/features/home/home_screen.dart';
import 'package:fitflow/features/profile/profile_screen.dart';
import 'package:fitflow/features/gym/gym_screen.dart';
import 'package:fitflow/features/workout/workout_screen.dart';
import 'package:fitflow/features/progress/progress_screen.dart';
import 'package:fitflow/features/feed/feed_screen.dart';
import 'package:fitflow/features/trainer/trainer_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      final isLoggedIn = await ref.read(authRepositoryProvider).isLoggedIn();
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/',
        builder: (_, __) => const HomeScreen(),
        routes: [
          GoRoute(path: 'profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(path: 'gym', builder: (_, __) => const GymScreen()),
          GoRoute(path: 'workout', builder: (_, __) => const WorkoutScreen()),
          GoRoute(path: 'progress', builder: (_, __) => const ProgressScreen()),
          GoRoute(path: 'feed', builder: (_, __) => const FeedScreen()),
          GoRoute(path: 'trainer', builder: (_, __) => const TrainerScreen()),
        ],
      ),
    ],
  );
});
