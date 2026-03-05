import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/features/auth/presentation/auth_state.dart';
import 'package:fitflow/features/auth/presentation/login_screen.dart';
import 'package:fitflow/features/auth/presentation/register_screen.dart';
import 'package:fitflow/features/feed/feed_screen.dart';
import 'package:fitflow/features/profile/presentation/profile_screen.dart';
import 'package:fitflow/features/gym/gym_screen.dart';
import 'package:fitflow/features/options/options_screen.dart';
import 'package:fitflow/features/progress/presentation/progress_screen.dart';
import 'package:fitflow/features/shell/main_shell_screen.dart';
import 'package:fitflow/features/trainer/trainer_screen.dart';
import 'package:fitflow/features/workouts/presentation/active_workout_screen.dart';
import 'package:fitflow/features/workouts/presentation/workout_detail_screen.dart';
import 'package:fitflow/features/workouts/presentation/workouts_list_screen.dart';
import 'package:fitflow/features/home/home_screen.dart';
import 'package:fitflow/features/exercises/exercises_screen.dart';
import 'package:fitflow/features/templates/templates_screen.dart';
import 'package:fitflow/features/templates/template_edit_screen.dart';
import 'package:fitflow/features/templates/exercise_picker_screen.dart';
import 'package:fitflow/features/current_workout/current_workout_screen.dart';


final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.read(authRedirectNotifierProvider);
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      if (!authNotifier.isKnown) {
        authNotifier.check();
        return null;
      }
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      if (!authNotifier.isLoggedIn && !isAuthRoute) return '/login';
      if (authNotifier.isLoggedIn && isAuthRoute) return '/home';
      if (state.matchedLocation == '/') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/',
        builder: (_, __) => const HomeScreen(),
        routes: [
          ShellRoute(
            builder: (context, state, child) => MainShellScreen(
              location: state.matchedLocation,
              child: child,
            ),
            routes: [
              GoRoute(path: 'home', builder: (_, __) => const WorkoutsListScreen()),
              GoRoute(path: 'exercises', builder: (_, __) => const ExercisesScreen()),
              GoRoute(
                path: 'templates',
                builder: (_, __) => const TemplatesScreen(),
                routes: [
                  GoRoute(
                    path: ':id/edit',
                    builder: (_, state) => TemplateEditScreen(templateId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: ':id/pick-exercise',
                    builder: (_, state) => ExercisePickerScreen(templateId: state.pathParameters['id']!),
                  ),
                ],
              ),
              GoRoute(path: 'current-workout', builder: (_, __) => const CurrentWorkoutScreen()),
              GoRoute(path: 'profile', builder: (_, __) => const ProfileScreen()),
              GoRoute(path: 'progress', builder: (_, __) => const ProgressScreen()),
              GoRoute(path: 'feed', builder: (_, __) => const FeedScreen()),
            ],
          ),
          GoRoute(
            path: 'workout/:id',
            builder: (_, state) => WorkoutDetailScreen(workoutId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'active',
                builder: (_, state) => ActiveWorkoutScreen(workoutId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: 'gym', builder: (_, __) => const GymScreen()),
          GoRoute(path: 'trainer', builder: (_, __) => const TrainerScreen()),
          GoRoute(path: 'options', builder: (_, __) => const OptionsScreen()),
        ],
      ),
    ],
  );
});
