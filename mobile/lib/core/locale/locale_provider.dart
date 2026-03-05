import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/locale/locale_repository.dart';

/// Currently selected locale code (saved). Use this to trigger reload of strings.
final selectedLocaleCodeProvider = StateProvider<String>((ref) => 'en');

/// Load selected locale at app start and optionally refresh from server.
final selectedLocaleCodeInitProvider = FutureProvider<String>((ref) async {
  final repo = ref.watch(localeRepositoryProvider);
  final code = await repo.getSelectedLocale();
  ref.read(selectedLocaleCodeProvider.notifier).update((_) => code);
  return code;
});

/// Current locale strings (from cache or server). Uses cached if offline.
final localeStringsProvider = FutureProvider<Map<String, String>>((ref) async {
  final code = ref.watch(selectedLocaleCodeProvider);
  final repo = ref.watch(localeRepositoryProvider);
  Map<String, String>? strings = await repo.getCachedLocale(code);
  if (strings == null || strings.isEmpty) {
    final fetched = await repo.fetchLocale(code);
    if (fetched != null && fetched.isNotEmpty) {
      await repo.cacheLocale(code, fetched);
      strings = fetched;
    }
  }
  if (strings == null || strings.isEmpty) {
    final en = await repo.getCachedLocale('en');
    if (en != null && en.isNotEmpty) return en;
    final fetchEn = await repo.fetchLocale('en');
    if (fetchEn != null && fetchEn.isNotEmpty) {
      await repo.cacheLocale('en', fetchEn);
      return fetchEn;
    }
  }
  return strings ?? _fallbackStrings;
});

/// List of available locale codes (from server, or default [en, ru]).
final localeListProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(localeRepositoryProvider).fetchLocaleList();
});

/// Fallback when no locale data is available (e.g. offline first launch).
final Map<String, String> _fallbackStrings = {
  'app_name': 'FITFLOW',
  'sign_in': 'Sign in',
  'create_account': 'Create account',
  'email': 'Email',
  'password': 'Password',
  'name': 'Name',
  'back_to_sign_in': 'Back to sign in',
  'register': 'Register',
  'profile': 'Profile',
  'cancel': 'Cancel',
  'save': 'Save',
  'saving': 'Saving...',
  'profile_saved': 'Profile saved',
  'edit': 'Edit',
  'display_name': 'Display name',
  'height_cm': 'Height (cm)',
  'weight_kg': 'Weight (kg)',
  'body_fat_pct': 'Body fat (%)',
  'no_name_set': 'No name set',
  'tap_edit_to_update': 'Tap edit to update name, height, weight, and body fat.',
  'height': 'Height',
  'weight': 'Weight',
  'body_fat': 'Body fat',
  'workouts': 'Workouts',
  'search_workouts': 'Search workouts',
  'all': 'All',
  'active': 'Active',
  'completed': 'Completed',
  'no_workouts_match': 'No workouts match.',
  'no_workouts_yet': 'No workouts yet. Create one to start.',
  'create_workout': 'Create workout',
  'in_progress': 'In progress',
  'completed_status': 'Completed',
  'not_started': 'Not started',
  'workout': 'Workout',
  'workout_detail': 'Workout',
  'status': 'Status',
  'started': 'Started',
  'finished': 'Finished',
  'stat': 'Stat',
  'exercises_count': 'Exercises',
  'no_exercises_added': 'No exercises added. Add exercises from the exercise list.',
  'start_session': 'Start session',
  'starting': 'Starting...',
  'active_workout': 'Active workout',
  'finish': 'Finish',
  'no_exercises_in_workout': 'No exercises in this workout. Add exercises from the workout detail.',
  'reps': 'Reps',
  'log_set': 'Log set',
  'progress': 'Progress',
  'latest_weight': 'Latest weight',
  'body_fat_pct_label': 'Body fat',
  'min_weight': 'Min weight',
  'max_weight': 'Max weight',
  'weight_chart': 'Weight',
  'body_fat_chart': 'Body fat %',
  'no_data_in_range': 'No data in this date range. Record weight or body fat in Profile.',
  'home_profile_subtitle': 'View and edit your profile',
  'home_gym_subtitle': 'Search gyms, check-in',
  'home_workout_subtitle': 'Builder and active workout',
  'home_progress_subtitle': 'Charts and metrics',
  'home_feed_subtitle': 'Social feed',
  'home_trainer_subtitle': 'Trainer dashboard',
  'options': 'Options',
  'language': 'Language',
  'retry': 'Retry',
  'gym': 'Gym',
  'feed': 'Feed',
  'trainer': 'Trainer',
  'enter_email': 'Enter email',
  'enter_password': 'Enter password',
  'enter_name': 'Enter name',
  'name_required': 'Name is required',
  'email_required': 'Email is required',
  'enter_valid_email': 'Enter a valid email',
  'this_field_required': 'This field is required',
  'at_least_6_chars': 'At least 6 characters',
  'exercises': 'Exercises',
  'exercises_base': 'Exercise database',
  'templates': 'Templates',
  'current_workout': 'Current workout',
  'description': 'Description',
  'instruction': 'Instructions',
  'formula': 'Formula',
  'equipment': 'Equipment',
  'exercise': 'Exercise',
  'difficulty': 'Difficulty',
  'no_exercises_found': 'No exercises found.',
  'no_templates': 'No templates yet.',
  'create_template': 'Create template',
  'start_workout': 'Start workout',
  'continue_workout': 'Continue workout',
  'no_active_workout': 'No active workout. Start one from a template.',
  'start_from_template': 'Start from template',
};

/// Helper to get a localized string by key.
String t(Map<String, String>? strings, String key) {
  if (strings == null) return key;
  return strings[key] ?? key;
}

/// Returns a translate function for the current locale. Use in widgets: final tr = ref.watch(trProvider); tr('key')
final trProvider = Provider<String Function(String)>((ref) {
  final strings = ref.watch(localeStringsProvider).valueOrNull;
  return (String key) => t(strings, key);
});
