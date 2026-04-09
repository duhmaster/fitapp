import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/features/auth/presentation/auth_state.dart';
import 'package:fitflow/features/auth/presentation/login_screen.dart';
import 'package:fitflow/features/auth/presentation/register_screen.dart';
import 'package:fitflow/features/feed/feed_screen.dart';
import 'package:fitflow/features/profile/presentation/profile_screen.dart';
import 'package:fitflow/features/gym/gym_screen.dart';
import 'package:fitflow/features/gym/gym_detail_screen.dart';
import 'package:fitflow/features/options/options_screen.dart';
import 'package:fitflow/features/progress/presentation/progress_menu_screen.dart';
import 'package:fitflow/features/progress/presentation/progress_screen.dart';
import 'package:fitflow/features/progress/presentation/progress_workouts_screen.dart';
import 'package:fitflow/features/progress/presentation/progress_exercises_screen.dart';
import 'package:fitflow/features/progress/presentation/progress_muscles_screen.dart';
import 'package:fitflow/features/gamification/presentation/achievements_screen.dart';
import 'package:fitflow/features/gamification/presentation/missions_screen.dart';
import 'package:fitflow/features/gamification/presentation/leaderboard_screen.dart';
import 'package:fitflow/features/gamification/presentation/xp_history_screen.dart';
import 'package:fitflow/features/shell/main_shell_screen.dart';
import 'package:fitflow/features/trainer/my_trainers_screen.dart';
import 'package:fitflow/features/trainer/trainer_profile_screen.dart';
import 'package:fitflow/features/trainer/trainer_profile_edit_screen.dart';
import 'package:fitflow/features/trainer/presentation/trainer_achievements_screen.dart';
import 'package:fitflow/features/trainer/presentation/trainer_rankings_screen.dart';
import 'package:fitflow/features/trainer/trainer_trainees_screen.dart';
import 'package:fitflow/features/trainer/trainee_profile_screen.dart';
import 'package:fitflow/features/trainer/trainee_progress_screen.dart';
import 'package:fitflow/features/trainer/trainer_calendar_screen.dart';
import 'package:fitflow/features/trainer/trainer_public_screen.dart';
import 'package:fitflow/features/group_trainings/presentation/trainer_group_training_templates_screen.dart';
import 'package:fitflow/features/group_trainings/presentation/trainer_group_training_template_edit_screen.dart';
import 'package:fitflow/features/group_trainings/presentation/trainer_group_trainings_screen.dart';
import 'package:fitflow/features/group_trainings/presentation/trainer_group_training_detail_screen.dart';
import 'package:fitflow/features/group_trainings/presentation/trainer_group_training_edit_screen.dart';
import 'package:fitflow/features/workouts/presentation/active_workout_screen.dart';
import 'package:fitflow/features/workouts/presentation/workouts_list_screen.dart';
import 'package:fitflow/features/gamification/domain/gamification_profile.dart';
import 'package:fitflow/features/workouts/presentation/workout_stats_screen.dart';
import 'package:fitflow/features/home/home_screen.dart';
import 'package:fitflow/features/exercises/exercises_screen.dart';
import 'package:fitflow/features/templates/templates_screen.dart';
import 'package:fitflow/features/templates/template_edit_screen.dart';
import 'package:fitflow/features/templates/exercise_picker_screen.dart';
import 'package:fitflow/features/system_messages/presentation/system_messages_screen.dart';
import 'package:fitflow/features/calendar/calendar_screen.dart';
import 'package:fitflow/features/current_workout/current_workout_screen.dart';
import 'package:fitflow/features/timers/timers_screen.dart';
import 'package:fitflow/features/help/help_screen.dart';
import 'package:fitflow/features/help/help_topic_screen.dart';
import 'package:fitflow/features/group_trainings/presentation/my_group_trainings_screen.dart';
import 'package:fitflow/features/group_trainings/presentation/group_training_detail_screen.dart';
import 'package:fitflow/features/group_trainings/presentation/group_training_public_screen.dart';
import 'package:fitflow/features/group_trainings/presentation/available_group_trainings_screen.dart';
import 'package:fitflow/core/widgets/loading_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.read(authRedirectNotifierProvider);
  return GoRouter(
    initialLocation: '/loading',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      if (!authNotifier.isKnown) {
        authNotifier.check();
        return null;
      }
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isLoadingRoute = state.matchedLocation == '/loading';
      if (isLoadingRoute) return authNotifier.isLoggedIn ? '/home' : '/login';
      if (!authNotifier.isLoggedIn &&
          (state.matchedLocation.startsWith('/t/') ||
              state.matchedLocation == '/t' ||
              state.matchedLocation.startsWith('/g/') ||
              state.matchedLocation == '/g')) {
        return null;
      }
      if (!authNotifier.isLoggedIn && !isAuthRoute) return '/login';
      if (authNotifier.isLoggedIn && isAuthRoute) return '/home';
      if (state.matchedLocation == '/') return '/home';
      //if (state.matchedLocation == '/trainer') return '/trainer/profile';
      if (state.matchedLocation == '/trainer/calendar') return '/calendar';
      return null;
    },
    routes: [
      GoRoute(path: '/loading', builder: (_, __) => const LoadingScreen()),
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
              GoRoute(
                  path: 'home', builder: (_, __) => const WorkoutsListScreen()),
              GoRoute(
                  path: 'calendar', builder: (_, __) => const CalendarScreen()),
              GoRoute(
                  path: 'exercises',
                  builder: (_, __) => const ExercisesScreen()),
              GoRoute(
                path: 'templates',
                builder: (_, __) => const TemplatesScreen(),
                routes: [
                  GoRoute(
                    path: ':id/edit',
                    builder: (_, state) => TemplateEditScreen(
                        templateId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: ':id/pick-exercise',
                    builder: (_, state) => ExercisePickerScreen(
                        templateId: state.pathParameters['id']!),
                  ),
                ],
              ),
              GoRoute(
                  path: 'current-workout',
                  builder: (_, __) => const CurrentWorkoutScreen()),
              GoRoute(path: 'timers', builder: (_, __) => const TimersScreen()),
              GoRoute(
                  path: 'profile', builder: (_, __) => const ProfileScreen()),
              GoRoute(path: 'gym', builder: (_, __) => const GymScreen()),
              GoRoute(
                path: 'gym/:gymId',
                builder: (_, state) => GymDetailScreen(
                  gymId: state.pathParameters['gymId']!,
                  gymName: state.uri.queryParameters['name'],
                ),
              ),
              GoRoute(
                path: 'progress',
                builder: (_, __) => const ProgressMenuScreen(),
                routes: [
                  GoRoute(
                      path: 'measurements',
                      builder: (_, __) => const ProgressScreen()),
                  GoRoute(
                      path: 'workouts',
                      builder: (_, __) => const ProgressWorkoutsScreen()),
                  GoRoute(
                      path: 'exercises',
                      builder: (_, __) => const ProgressExercisesScreen()),
                  GoRoute(
                      path: 'muscles',
                      builder: (_, __) => const ProgressMusclesScreen()),
                  GoRoute(
                      path: 'achievements',
                      builder: (_, __) => const AchievementsScreen()),
                  GoRoute(
                      path: 'missions',
                      builder: (_, __) => const MissionsScreen()),
                  GoRoute(
                      path: 'leaderboard',
                      builder: (_, __) => const LeaderboardScreen()),
                  GoRoute(
                      path: 'xp-history',
                      builder: (_, __) => const XpHistoryScreen()),
                ],
              ),
              GoRoute(path: 'feed', builder: (_, __) => const FeedScreen()),
              GoRoute(
                  path: 'system-messages',
                  builder: (_, __) => const SystemMessagesScreen()),
              GoRoute(
                  path: 'group-trainings',
                  builder: (_, __) => const MyGroupTrainingsScreen()),
              // Статический путь должен быть выше :trainingId, иначе "available" попадёт в параметр.
              GoRoute(
                path: 'group-trainings/available',
                builder: (_, __) => const AvailableGroupTrainingsScreen(),
              ),
              GoRoute(
                path: 'group-trainings/:trainingId',
                builder: (_, state) => GroupTrainingDetailScreen(
                    trainingId: state.pathParameters['trainingId']!),
              ),
              GoRoute(
                path: 'help',
                builder: (_, __) => const HelpScreen(),
                routes: [
                  GoRoute(
                    path: ':topicId',
                    builder: (_, state) => HelpTopicScreen(
                        topicId: state.pathParameters['topicId']!),
                  ),
                ],
              ),
              GoRoute(
                path: 'workout/:id',
                builder: (_, state) => ActiveWorkoutScreen(
                  workoutId: state.pathParameters['id']!,
                  readOnly: state.uri.queryParameters['readOnly'] == '1',
                ),
              ),
              GoRoute(
                path: 'workout/:id/stats',
                builder: (_, state) => WorkoutStatsScreen(
                  workoutId: state.pathParameters['id']!,
                  openRewardFlow: state.uri.queryParameters['reward'] == '1',
                  profileBeforeWorkout: state.extra is GamificationProfile
                      ? state.extra as GamificationProfile
                      : null,
                ),
              ),
              GoRoute(
                path: 'trainer',
                builder: (_, __) => const TrainerProfileScreen(),
                //redirect: (_, state) => state.matchedLocation == '/trainer' ? '/trainer/profile' : null,
                routes: [
                  GoRoute(
                    path: 'profile',
                    builder: (_, __) => const TrainerProfileScreen(),
                    routes: [
                      GoRoute(
                          path: 'edit',
                          builder: (_, __) => const TrainerProfileEditScreen()),
                    ],
                  ),
                  GoRoute(
                    path: 'trainees',
                    builder: (_, __) => const TrainerTraineesScreen(),
                    routes: [
                      GoRoute(
                        path: ':clientId',
                        builder: (_, state) => TraineeProfileScreen(
                          clientId: state.pathParameters['clientId']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'progress',
                            builder: (_, state) => TraineeProgressScreen(
                              clientId: state.pathParameters['clientId']!,
                              clientName: state.uri.queryParameters['name'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                      path: 'calendar',
                      builder: (_, __) => const TrainerCalendarScreen()),
                  GoRoute(
                    path: 'group-training-templates',
                    builder: (_, __) =>
                        const TrainerGroupTrainingTemplatesScreen(),
                    routes: [
                      GoRoute(
                          path: 'new',
                          builder: (_, __) =>
                              const TrainerGroupTrainingTemplateEditScreen(
                                  templateIdOrNull: null)),
                      GoRoute(
                        path: ':templateId',
                        builder: (_, state) =>
                            TrainerGroupTrainingTemplateEditScreen(
                                templateIdOrNull:
                                    state.pathParameters['templateId']!),
                      ),
                    ],
                  ),
                  GoRoute(
                      path: 'rankings',
                      builder: (_, __) => const TrainerRankingsScreen()),
                  GoRoute(
                      path: 'achievements',
                      builder: (_, __) => const TrainerAchievementsScreen()),
                  GoRoute(
                    path: 'group-trainings',
                    builder: (_, __) => const TrainerGroupTrainingsScreen(),
                    routes: [
                      GoRoute(
                          path: 'new',
                          builder: (_, __) =>
                              const TrainerGroupTrainingEditScreen(
                                  trainingIdOrNull: null)),
                      GoRoute(
                        path: ':trainingId',
                        builder: (_, state) => TrainerGroupTrainingDetailScreen(
                            trainingId: state.pathParameters['trainingId']!),
                      ),
                      GoRoute(
                        path: ':trainingId/edit',
                        builder: (_, state) => TrainerGroupTrainingEditScreen(
                            trainingIdOrNull:
                                state.pathParameters['trainingId']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
              path: 'my-trainers',
              builder: (_, __) => const MyTrainersScreen()),
          GoRoute(path: 'options', builder: (_, __) => const OptionsScreen()),
        ],
      ),
      GoRoute(
        path: '/t/:userId',
        builder: (_, state) =>
            TrainerPublicScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/g/:trainingId',
        builder: (_, state) => GroupTrainingPublicScreen(
            trainingId: state.pathParameters['trainingId']!),
      ),
    ],
  );
});
