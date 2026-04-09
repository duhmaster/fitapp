import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fitflow/app.dart';
import 'package:fitflow/core/router/app_router.dart';

const _routesToCapture = <String>[
  '/home',
  '/calendar',
  '/exercises',
  '/templates',
  '/current-workout',
  '/timers',
  '/profile',
  '/progress',
  '/progress/measurements',
  '/progress/workouts',
  '/progress/exercises',
  '/progress/muscles',
  '/progress/achievements',
  '/progress/missions',
  '/progress/leaderboard',
  '/progress/xp-history',
  '/feed',
  '/system-messages',
  '/group-trainings',
  '/group-trainings/available',
  '/help',
  '/trainer/profile',
  '/trainer/trainees',
  '/trainer/group-training-templates',
  '/trainer/rankings',
  '/trainer/achievements',
  '/trainer/group-trainings',
  '/my-trainers',
  '/options',
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('visual smoke by routes with screenshots', (tester) async {
    await binding.setSurfaceSize(const Size(1280, 900));
    final runId = Platform.environment['VISUAL_RUN_ID'] ??
        DateTime.now()
            .toIso8601String()
            .replaceAll(':', '')
            .replaceAll('-', '')
            .replaceAll('.', '_');
    final platform = Platform.operatingSystem;
    final outputRoot = _resolveWritableOutputRoot(runId, platform);
    final screensDir = Directory('$outputRoot/screens')
      ..createSync(recursive: true);
    final reportFile = File('$outputRoot/report.json');

    final screenshotKey = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        child: RepaintBoundary(
          key: screenshotKey,
          child: const FitflowApp(),
        ),
      ),
    );
    await _settle(tester);

    final appContext = tester.element(find.byType(FitflowApp));
    final container = ProviderScope.containerOf(appContext, listen: false);
    final router = container.read(appRouterProvider);
    await _ensureLoggedOutAndRegisterFreshUser(tester, router, runId);
    await _settle(tester);

    final captured = <String>[];
    final failed = <Map<String, String>>[];

    Future<void> captureStep(String routeLikeName) async {
      await _captureWidget(
        screenshotKey: screenshotKey,
        outputFile:
            File('${screensDir.path}/${_routeToFileName(routeLikeName)}'),
      );
      captured.add(routeLikeName);
    }

    try {
      await _recoverAuthorizationIfNeeded(tester, router, runId);
      await _fillUserProfile(tester, router, runId);
      await _settle(tester);
      await captureStep('/scenarios/profile_filled');

      await _recoverAuthorizationIfNeeded(tester, router, runId);
      await _fillTrainerProfile(tester, router, runId);
      await _settle(tester);
      await captureStep('/scenarios/trainer_profile_filled');

      await _recoverAuthorizationIfNeeded(tester, router, runId);
      await _scenarioCreateWorkoutFromCalendarByTemplate(
        tester,
        router,
        templateName: 'Спина/Бицепс',
      );
      await _settle(tester);
      await captureStep('/scenarios/workout_created_from_calendar');

      await _scenarioFinishWorkout(tester);
      await _settle(tester);
      await captureStep('/scenarios/workout_finished');

      await _recoverAuthorizationIfNeeded(tester, router, runId);
      await _scenarioAddBodyMeasurements(tester, router);
      await _settle(tester);
      await captureStep('/scenarios/measurements_added');

      await _recoverAuthorizationIfNeeded(tester, router, runId);
      await _scenarioAddGymPowerClub(tester, router);
      await _settle(tester);
      await captureStep('/scenarios/gym_added');

      await _recoverAuthorizationIfNeeded(tester, router, runId);
      await _scenarioAddTrainerKnown(tester, router);
      await _settle(tester);
      await captureStep('/scenarios/trainer_added');
    } catch (e) {
      failed.add({'route': '/scenarios/acceptance_main_flow', 'error': '$e'});
    }

    try {
      await _recoverAuthorizationIfNeeded(tester, router, runId);
      await _scenarioCreateGroupTraining(tester, router);
      await _settle(tester);
      await captureStep('/scenarios/group_training_created');
    } catch (e) {
      failed.add({'route': '/scenarios/group_training_flow', 'error': '$e'});
    }

    try {
      await _recoverAuthorizationIfNeeded(tester, router, runId);
      await _scenarioCreateFilledTemplate(tester, router);
      await _settle(tester);
      await captureStep('/scenarios/test_template_created');
    } catch (e) {
      failed.add({'route': '/scenarios/test_template_flow', 'error': '$e'});
    }

    for (final route in _routesToCapture) {
      try {
        router.go(route);
        await _settle(tester);
        await _recoverAuthorizationIfNeeded(tester, router, runId);
        router.go(route);
        await _settle(tester);
        await captureStep(route);
      } catch (e) {
        failed.add({'route': route, 'error': '$e'});
      }
    }

    final report = <String, dynamic>{
      'run_id': runId,
      'platform': platform,
      'screens_dir': screensDir.path,
      'captured': captured,
      'failed': failed,
      'total': _routesToCapture.length,
    };
    try {
      reportFile.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(report));
    } catch (_) {
      final fallbackDir = Directory(
        '${Directory.systemTemp.path}/fitflow_visual/$runId/$platform',
      )..createSync(recursive: true);
      final fallbackReport = File('${fallbackDir.path}/report.json');
      fallbackReport.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(report));
      binding.reportData ??= <String, dynamic>{};
      binding.reportData!['visual_report_fallback_path'] = fallbackReport.path;
    }
    // Keep a copy in integration_test report for CI logs.
    binding.reportData ??= <String, dynamic>{};
    binding.reportData!['visual_report_path'] = reportFile.path;
    binding.reportData!['captured_count'] = captured.length;
    binding.reportData!['failed_count'] = failed.length;
    await binding.setSurfaceSize(null);

    expect(
      failed,
      isEmpty,
      reason:
          'Some routes failed during visual capture. See ${reportFile.path}',
    );
  });
}

String _resolveWritableOutputRoot(String runId, String platform) {
  final configured = Platform.environment['VISUAL_TEST_OUTPUT_DIR'];
  if (configured != null && configured.trim().isNotEmpty) {
    final abs = Directory(configured).absolute.path;
    try {
      final dir = Directory(abs)..createSync(recursive: true);
      final probe = File('${dir.path}/.write_probe');
      probe.writeAsStringSync('ok');
      probe.deleteSync();
      return abs;
    } catch (_) {
      // Fall through to temp fallback below.
    }
  }
  final fallback =
      Directory('${Directory.systemTemp.path}/fitflow_visual/$runId/$platform')
          .absolute
          .path;
  final dir = Directory(fallback)..createSync(recursive: true);
  final probe = File('${dir.path}/.write_probe');
  probe.writeAsStringSync('ok');
  probe.deleteSync();
  return fallback;
}

Future<void> _ensureLoggedOutAndRegisterFreshUser(
  WidgetTester tester,
  dynamic router,
  String runId,
) async {
  // If user is already authorized, force logout first.
  if (find.byType(TextFormField).evaluate().length < 2) {
    router.go('/home');
    await _settle(tester, timeout: const Duration(seconds: 10));
    Finder logout = find.byIcon(Icons.logout).hitTestable();
    if (logout.evaluate().isEmpty) {
      logout = find.byIcon(Icons.logout);
    }
    if (logout.evaluate().isNotEmpty) {
      await tester.tap(logout.first, warnIfMissed: false);
      await _settle(tester, timeout: const Duration(seconds: 20));
    }
  }

  // Ensure login screen is open.
  if (find.byType(TextFormField).evaluate().length < 2) {
    router.go('/login');
    await _settle(tester, timeout: const Duration(seconds: 12));
  }

  await _registerFreshUserFromLogin(tester, runId);
}

Future<void> _registerFreshUserFromLogin(
    WidgetTester tester, String runId) async {
  final emailFields = find.byType(TextFormField);
  if (emailFields.evaluate().length < 2) {
    throw StateError('Login/Register form is not visible.');
  }

  final password = Platform.environment['FITFLOW_E2E_PASSWORD'] ?? 'bbbbbbbb';
  final email =
      'e2e_${runId}_${DateTime.now().millisecondsSinceEpoch}@example.com';

  // Open registration from login screen.
  Finder createAccount =
      find.widgetWithText(TextButton, 'Создать аккаунт').hitTestable();
  if (createAccount.evaluate().isEmpty) {
    createAccount =
        find.widgetWithText(TextButton, 'Create account').hitTestable();
  }
  if (createAccount.evaluate().isNotEmpty) {
    await tester.tap(createAccount.first, warnIfMissed: false);
    await _settle(tester, timeout: const Duration(seconds: 20));
  }

  final fields = find.byType(TextFormField);
  if (fields.evaluate().length < 3) {
    throw StateError('Registration form is not visible.');
  }

  await tester.enterText(fields.at(0), 'autotest_$runId');
  await tester.enterText(fields.at(1), email);
  await tester.enterText(fields.at(2), password);

  // Accept terms.
  Finder termsCheckbox = find.byType(Checkbox).hitTestable();
  if (termsCheckbox.evaluate().isEmpty) {
    termsCheckbox = find.byType(Checkbox);
  }
  if (termsCheckbox.evaluate().isNotEmpty) {
    await tester.tap(termsCheckbox.first, warnIfMissed: false);
    await _settle(tester);
  }

  Finder registerBtn =
      find.widgetWithText(FilledButton, 'Регистрация').hitTestable();
  if (registerBtn.evaluate().isEmpty) {
    registerBtn = find.widgetWithText(FilledButton, 'Register').hitTestable();
  }
  if (registerBtn.evaluate().isEmpty) {
    registerBtn = find.byType(FilledButton).hitTestable();
  }
  if (registerBtn.evaluate().isEmpty) {
    throw StateError('Register submit button not found.');
  }
  await tester.tap(registerBtn.first, warnIfMissed: false);
  await _settle(tester, timeout: const Duration(seconds: 30));
}

bool _hasUnauthorizedErrorOnScreen() {
  return find
          .textContaining('missing authorization header')
          .evaluate()
          .isNotEmpty ||
      find.textContaining('(401)').evaluate().isNotEmpty ||
      find.textContaining('DioException').evaluate().isNotEmpty ||
      find.textContaining('authorization').evaluate().isNotEmpty ||
      find.textContaining('AppException').evaluate().isNotEmpty;
}

Future<void> _recoverAuthorizationIfNeeded(
  WidgetTester tester,
  dynamic router,
  String runId,
) async {
  return;
  if (!_hasUnauthorizedErrorOnScreen()) {
    return;
  }
  Finder retry = find.widgetWithText(FilledButton, 'Повторить').hitTestable();
  if (retry.evaluate().isEmpty) {
    retry = find.widgetWithText(FilledButton, 'Retry').hitTestable();
  }
  if (retry.evaluate().isNotEmpty) {
    await tester.tap(retry.first, warnIfMissed: false);
    await _settle(tester);
    if (!_hasUnauthorizedErrorOnScreen()) {
      return;
    }
  }
  final recoveryRunId = '${runId}_re';
  try {
    await _ensureLoggedOutAndRegisterFreshUser(tester, router, recoveryRunId);
  } catch (_) {
    // Do not fail whole flow if re-auth route guard changed.
    router.go('/home');
  }
  await _settle(tester);
  router.go('/home');
  await _settle(tester);
}

Future<void> _fillUserProfile(
  WidgetTester tester,
  dynamic router,
  String runId,
) async {
  router.go('/profile');
  await _settle(tester, timeout: const Duration(seconds: 20));

  final fields = find.byType(TextField);
  if (fields.evaluate().isNotEmpty) {
    await tester.enterText(fields.first, 'Autotest User $runId');
    await _settle(tester);
  }

  Finder save = find.widgetWithText(FilledButton, 'Сохранить').hitTestable();
  if (save.evaluate().isEmpty) {
    save = find.widgetWithText(FilledButton, 'Save').hitTestable();
  }
  if (save.evaluate().isEmpty) {
    save = find.widgetWithText(TextButton, 'Сохранить').hitTestable();
  }
  if (save.evaluate().isEmpty) {
    save = find.widgetWithText(TextButton, 'Save').hitTestable();
  }
  if (save.evaluate().isNotEmpty) {
    await tester.tap(save.first, warnIfMissed: false);
    await _settle(tester, timeout: const Duration(seconds: 12));
  }
}

Future<void> _fillTrainerProfile(
  WidgetTester tester,
  dynamic router,
  String runId,
) async {
  router.go('/trainer/profile');
  await _settle(tester, timeout: const Duration(seconds: 20));

  final fields = find.byType(TextField);
  if (fields.evaluate().isNotEmpty) {
    await tester.enterText(fields.first, 'Тренер autotest $runId');
    await _settle(tester);
  }
  if (fields.evaluate().length > 1) {
    await tester.enterText(fields.at(1), 'Москва');
    await _settle(tester);
  }

  Finder save = find.widgetWithText(FilledButton, 'Сохранить').hitTestable();
  if (save.evaluate().isEmpty) {
    save = find.widgetWithText(FilledButton, 'Save').hitTestable();
  }
  if (save.evaluate().isEmpty) {
    save = find.widgetWithText(TextButton, 'Сохранить').hitTestable();
  }
  if (save.evaluate().isEmpty) {
    save = find.widgetWithText(TextButton, 'Save').hitTestable();
  }
  if (save.evaluate().isNotEmpty) {
    await tester.tap(save.first, warnIfMissed: false);
    await _settle(tester, timeout: const Duration(seconds: 12));
  }
}

Future<void> _scenarioCreateWorkoutFromCalendarByTemplate(
  WidgetTester tester,
  dynamic router, {
  required String templateName,
}) async {
  router.go('/calendar');
  await _settle(tester, timeout: const Duration(seconds: 20));

  final dayNum = DateTime.now().day.toString();
  final dayFinder = find.text(dayNum);
  if (dayFinder.evaluate().isNotEmpty) {
    await tester.tap(dayFinder.first, warnIfMissed: false);
    await _settle(tester, timeout: const Duration(seconds: 12));
  }

  Finder createWorkout =
      find.widgetWithText(FilledButton, 'Создать тренировку').hitTestable();
  if (createWorkout.evaluate().isEmpty) {
    createWorkout =
        find.widgetWithText(FilledButton, 'Create workout').hitTestable();
  }
  if (createWorkout.evaluate().isEmpty) {
    createWorkout = find.text('Создать тренировку').hitTestable();
  }
  if (createWorkout.evaluate().isEmpty) {
    createWorkout = find.text('Create workout').hitTestable();
  }
  if (createWorkout.evaluate().isEmpty) {
    throw StateError('Create workout action not found in calendar day dialog.');
  }
  await tester.tap(createWorkout.first, warnIfMissed: false);
  await _settle(tester, timeout: const Duration(seconds: 20));

  Finder targetTemplate = find.textContaining(templateName);
  if (targetTemplate.evaluate().isEmpty) {
    targetTemplate = find.textContaining('спина');
  }
  if (targetTemplate.evaluate().isNotEmpty) {
    final row = find.ancestor(
        of: targetTemplate.first, matching: find.byType(ListTile));
    if (row.evaluate().isNotEmpty) {
      await tester.tap(row.first, warnIfMissed: false);
    } else {
      await tester.tap(targetTemplate.first, warnIfMissed: false);
    }
    await _settle(tester, timeout: const Duration(seconds: 12));
  }

  // Some flows start workout immediately after selecting template.
  if (find
          .widgetWithText(TextButton, 'Завершить тренировку')
          .evaluate()
          .isNotEmpty ||
      find.widgetWithText(TextButton, 'Finish workout').evaluate().isNotEmpty ||
      find.widgetWithText(FilledButton, 'Сохранить').evaluate().isNotEmpty ||
      find.widgetWithText(FilledButton, 'Save').evaluate().isNotEmpty) {
    return;
  }

  Finder startBtn =
      find.widgetWithText(FilledButton, 'Начать тренировку').hitTestable();
  if (startBtn.evaluate().isEmpty) {
    startBtn = find.widgetWithText(FilledButton, 'Start workout').hitTestable();
  }
  if (startBtn.evaluate().isEmpty) {
    Finder startAny = find.textContaining('Начать').hitTestable();
    if (startAny.evaluate().isEmpty) {
      startAny = find.textContaining('Start').hitTestable();
    }
    if (startAny.evaluate().isNotEmpty) {
      await tester.tap(startAny.first, warnIfMissed: false);
      await _settle(tester, timeout: const Duration(seconds: 20));
      return;
    }
    final allFilled = find.byType(FilledButton).hitTestable();
    if (allFilled.evaluate().isNotEmpty) {
      startBtn = allFilled.first;
    }
  }
  if (startBtn.evaluate().isEmpty) {
    throw StateError(
        'Start workout button not found after template selection.');
  }
  await tester.tap(startBtn.first, warnIfMissed: false);
  await _settle(tester, timeout: const Duration(seconds: 20));
}

Future<void> _scenarioAddBodyMeasurements(
  WidgetTester tester,
  dynamic router,
) async {
  router.go('/progress/measurements');
  await _settle(tester, timeout: const Duration(seconds: 20));

  Finder addBtn =
      find.widgetWithText(FilledButton, 'Добавить замер').hitTestable();
  if (addBtn.evaluate().isEmpty) {
    addBtn = find.widgetWithText(FilledButton, 'Add measurement').hitTestable();
  }
  if (addBtn.evaluate().isEmpty) {
    addBtn = find.byType(FloatingActionButton).hitTestable();
  }
  if (addBtn.evaluate().isNotEmpty) {
    await tester.tap(addBtn.first, warnIfMissed: false);
    await _settle(tester, timeout: const Duration(seconds: 12));
  }

  final fields = find.byType(TextField);
  if (fields.evaluate().isNotEmpty) {
    await tester.enterText(fields.first, '82');
    await _settle(tester);
  }
  if (fields.evaluate().length > 1) {
    await tester.enterText(fields.at(1), '98');
    await _settle(tester);
  }

  Finder save = find.widgetWithText(FilledButton, 'Сохранить').hitTestable();
  if (save.evaluate().isEmpty) {
    save = find.widgetWithText(FilledButton, 'Save').hitTestable();
  }
  if (save.evaluate().isNotEmpty) {
    await tester.tap(save.first, warnIfMissed: false);
    await _settle(tester, timeout: const Duration(seconds: 12));
  }
}

Future<void> _scenarioAddGymPowerClub(
  WidgetTester tester,
  dynamic router,
) async {
  router.go('/gym');
  await _settle(tester, timeout: const Duration(seconds: 20));
  if (find.textContaining('Power club').evaluate().isNotEmpty ||
      find.textContaining('Power Club').evaluate().isNotEmpty) {
    return;
  }
  await _addGymPowerClubFromCurrentScreen(tester);
}

Future<void> _scenarioAddTrainerKnown(
  WidgetTester tester,
  dynamic router,
) async {
  router.go('/my-trainers');
  await _settle(tester, timeout: const Duration(seconds: 20));
  if (find.textContaining('тренер').evaluate().isNotEmpty ||
      find.textContaining('b@b.b').evaluate().isNotEmpty) {
    return;
  }
  await _addTrainerByEmailFromCurrentScreen(tester, 'b@b.b');
}

Future<void> _addGymPowerClubFromCurrentScreen(WidgetTester tester) async {
  Finder addGymBtn =
      find.widgetWithText(FilledButton, 'Добавить зал').hitTestable();
  if (addGymBtn.evaluate().isEmpty) {
    addGymBtn = find.widgetWithText(FilledButton, 'Add gym').hitTestable();
  }
  if (addGymBtn.evaluate().isEmpty) {
    addGymBtn = find.byType(FloatingActionButton).hitTestable();
  }
  if (addGymBtn.evaluate().isEmpty) {
    throw StateError('Add gym action not found.');
  }
  await tester.tap(addGymBtn.first, warnIfMissed: false);
  await _settle(tester, timeout: const Duration(seconds: 20));

  final fields = find.byType(TextField);
  if (fields.evaluate().isEmpty) {
    throw StateError('Gym search input not found.');
  }
  await tester.enterText(fields.first, 'Power Club');
  await _settle(tester, timeout: const Duration(seconds: 2));

  Finder powerRow = find.textContaining('Power Club');
  if (powerRow.evaluate().isEmpty) {
    powerRow = find.textContaining('Power club');
  }
  if (powerRow.evaluate().isNotEmpty) {
    final tile =
        find.ancestor(of: powerRow.first, matching: find.byType(ListTile));
    if (tile.evaluate().isNotEmpty) {
      await tester.tap(tile.first, warnIfMissed: false);
      await _settle(tester, timeout: const Duration(seconds: 2));
    }
  }

  Finder addGymConfirm =
      find.widgetWithText(FilledButton, 'Добавить зал').hitTestable();
  if (addGymConfirm.evaluate().isEmpty) {
    addGymConfirm = find.widgetWithText(FilledButton, 'Add gym').hitTestable();
  }
  if (addGymConfirm.evaluate().isNotEmpty) {
    await tester.tap(addGymConfirm.first, warnIfMissed: false);
    await _settle(tester, timeout: const Duration(seconds: 20));
  }
}

Future<void> _addTrainerByEmailFromCurrentScreen(
  WidgetTester tester,
  String email,
) async {
  Finder addTrainer = find.byType(FloatingActionButton).hitTestable();
  if (addTrainer.evaluate().isEmpty) {
    throw StateError('Add trainer action not found.');
  }
  await tester.tap(addTrainer.first, warnIfMissed: false);
  await _settle(tester, timeout: const Duration(seconds: 10));

  final fields = find.byType(TextField);
  if (fields.evaluate().isEmpty) {
    throw StateError('Trainer search input not found.');
  }
  await tester.enterText(fields.first, email);
  await _settle(tester, timeout: const Duration(seconds: 3));

  final rows = find.byType(ListTile);
  if (rows.evaluate().isEmpty) {
    throw StateError('Trainer search results are empty.');
  }
  await tester.tap(rows.first, warnIfMissed: false);
  await _settle(tester, timeout: const Duration(seconds: 20));
}

Future<void> _scenarioCreateFilledTemplate(
  WidgetTester tester,
  dynamic router,
) async {
  const templateName = 'Тестовый шаблон';
  router.go('/templates');
  await _settle(tester, timeout: const Duration(seconds: 20));

  Finder createBtn =
      find.widgetWithText(FilledButton, 'Создать шаблон').hitTestable();
  if (createBtn.evaluate().isEmpty) {
    createBtn =
        find.widgetWithText(FilledButton, 'Create template').hitTestable();
  }
  if (createBtn.evaluate().isEmpty) {
    createBtn = find.widgetWithText(TextButton, 'Создать шаблон').hitTestable();
  }
  if (createBtn.evaluate().isEmpty) {
    createBtn =
        find.widgetWithText(TextButton, 'Create template').hitTestable();
  }
  if (createBtn.evaluate().isEmpty) {
    createBtn = find.byType(FloatingActionButton).hitTestable();
  }
  if (createBtn.evaluate().isEmpty) {
    final anyFilled = find.byType(FilledButton).hitTestable();
    if (anyFilled.evaluate().isNotEmpty) {
      createBtn = anyFilled.first;
    }
  }
  if (createBtn.evaluate().isEmpty) {
    final anyFilled = find.byType(FilledButton);
    if (anyFilled.evaluate().isNotEmpty) {
      await tester.ensureVisible(anyFilled.first);
      createBtn = anyFilled.first;
    }
  }
  if (createBtn.evaluate().isEmpty) {
    throw StateError('Create template button not found.');
  }
  await tester.tap(createBtn.first, warnIfMissed: false);
  await _settle(tester, timeout: const Duration(seconds: 12));

  final fields = find.byType(TextField);
  if (fields.evaluate().isEmpty) {
    throw StateError('Template name input not found.');
  }
  await tester.enterText(fields.first, templateName);
  await _settle(tester);

  Finder submit = find.widgetWithText(FilledButton, 'Создать').hitTestable();
  if (submit.evaluate().isEmpty) {
    submit = find.widgetWithText(FilledButton, 'Create').hitTestable();
  }
  if (submit.evaluate().isNotEmpty) {
    await tester.tap(submit.first, warnIfMissed: false);
    await _settle(tester, timeout: const Duration(seconds: 20));
  } else {
    // If create dialog did not appear (or duplicate name), open existing template.
    final existing = find.textContaining(templateName);
    if (existing.evaluate().isNotEmpty) {
      await tester.tap(existing.first, warnIfMissed: false);
      await _settle(tester, timeout: const Duration(seconds: 12));
    } else {
      throw StateError(
          'Template create submit not found and template missing.');
    }
  }

  // Add first 5 exercises from picker.
  for (var i = 0; i < 5; i++) {
    Finder addExerciseBtn =
        find.widgetWithText(TextButton, 'Добавить упражнение').hitTestable();
    if (addExerciseBtn.evaluate().isEmpty) {
      addExerciseBtn =
          find.widgetWithText(TextButton, 'Add exercise').hitTestable();
    }
    if (addExerciseBtn.evaluate().isEmpty) {
      throw StateError('Add exercise button not found on template edit.');
    }
    await tester.tap(addExerciseBtn.first, warnIfMissed: false);
    await _settle(tester, timeout: const Duration(seconds: 12));

    final rows = find.byType(ListTile);
    if (rows.evaluate().isEmpty) {
      throw StateError('Exercise picker has no rows.');
    }
    await tester.tap(rows.first, warnIfMissed: false);
    await _settle(tester, timeout: const Duration(seconds: 12));
  }

  // Add 2 sets (50kg x 10) for each exercise via add-set dialogs.
  for (var i = 0; i < 10; i++) {
    Finder addSetBtn =
        find.widgetWithText(TextButton, 'Добавить подход').hitTestable();
    if (addSetBtn.evaluate().isEmpty) {
      addSetBtn = find.widgetWithText(TextButton, 'Add set').hitTestable();
    }
    if (addSetBtn.evaluate().isEmpty) {
      break;
    }
    await tester.tap(addSetBtn.first, warnIfMissed: false);
    await _settle(tester, timeout: const Duration(seconds: 8));

    final dialogFields = find.byType(TextField);
    if (dialogFields.evaluate().isNotEmpty) {
      await tester.enterText(dialogFields.first, '50');
      if (dialogFields.evaluate().length > 1) {
        await tester.enterText(dialogFields.at(1), '10');
      }
      await _settle(tester, timeout: const Duration(seconds: 2));
    }

    Finder confirm =
        find.widgetWithText(FilledButton, 'Добавить подход').hitTestable();
    if (confirm.evaluate().isEmpty) {
      confirm = find.widgetWithText(FilledButton, 'Add set').hitTestable();
    }
    if (confirm.evaluate().isEmpty) {
      final allFilled = find.byType(FilledButton).hitTestable();
      if (allFilled.evaluate().isNotEmpty) {
        confirm = allFilled.first;
      }
    }
    if (confirm.evaluate().isNotEmpty) {
      await tester.tap(confirm.first, warnIfMissed: false);
      await _settle(tester, timeout: const Duration(seconds: 8));
    }
  }

  Finder saveTemplate =
      find.widgetWithText(TextButton, 'Сохранить').hitTestable();
  if (saveTemplate.evaluate().isEmpty) {
    saveTemplate = find.widgetWithText(TextButton, 'Save').hitTestable();
  }
  if (saveTemplate.evaluate().isNotEmpty) {
    await tester.tap(saveTemplate.first, warnIfMissed: false);
    await _settle(tester, timeout: const Duration(seconds: 12));
  }
}

Future<void> _scenarioFinishWorkout(WidgetTester tester) async {
  // Full flow: log sets until done, then finish workout.
  for (var i = 0; i < 20; i++) {
    Finder saveSet =
        find.widgetWithText(FilledButton, 'Сохранить').hitTestable();
    if (saveSet.evaluate().isEmpty) {
      saveSet = find.widgetWithText(FilledButton, 'Save').hitTestable();
    }
    if (saveSet.evaluate().isNotEmpty) {
      await tester.tap(saveSet.first, warnIfMissed: false);
      await _settle(tester, timeout: const Duration(seconds: 8));
      continue;
    }

    Finder continueBtn = find
        .widgetWithText(FilledButton, 'Продолжить тренировку')
        .hitTestable();
    if (continueBtn.evaluate().isEmpty) {
      continueBtn =
          find.widgetWithText(FilledButton, 'Continue workout').hitTestable();
    }
    if (continueBtn.evaluate().isNotEmpty) {
      await tester.tap(continueBtn.first, warnIfMissed: false);
      await _settle(tester, timeout: const Duration(seconds: 8));
      continue;
    }

    Finder finishMain =
        find.widgetWithText(FilledButton, 'Завершить тренировку').hitTestable();
    if (finishMain.evaluate().isEmpty) {
      finishMain =
          find.widgetWithText(FilledButton, 'Finish workout').hitTestable();
    }
    if (finishMain.evaluate().isNotEmpty) {
      await tester.tap(finishMain.first, warnIfMissed: false);
      await _settle(tester, timeout: const Duration(seconds: 12));
      break;
    }

    Finder finishTop =
        find.widgetWithText(TextButton, 'Завершить тренировку').hitTestable();
    if (finishTop.evaluate().isEmpty) {
      finishTop =
          find.widgetWithText(TextButton, 'Finish workout').hitTestable();
    }
    if (finishTop.evaluate().isNotEmpty) {
      await tester.tap(finishTop.first, warnIfMissed: false);
      await _settle(tester, timeout: const Duration(seconds: 12));
      break;
    }

    await _settle(tester, timeout: const Duration(seconds: 2));
  }
}

Future<void> _scenarioCreateGroupTraining(
  WidgetTester tester,
  dynamic router,
) async {
  router.go('/trainer/group-trainings/new');
  await _settle(tester, timeout: const Duration(seconds: 20));
  // New flow is a 3-step wizard. Defaults are preselected, so we just move through steps.
  Finder nextBtn = find.widgetWithText(FilledButton, 'Далее').hitTestable();
  if (nextBtn.evaluate().isEmpty) {
    nextBtn = find.widgetWithText(FilledButton, 'Next').hitTestable();
  }
  if (nextBtn.evaluate().isEmpty) {
    Finder anyFilled = find.byType(FilledButton).hitTestable();
    if (anyFilled.evaluate().isEmpty) {
      anyFilled = find.byType(FilledButton);
    }
    if (anyFilled.evaluate().isEmpty) {
      throw StateError(
          'Stepper primary button not found on group training wizard.');
    }
    nextBtn = anyFilled.first;
  }
  await tester.tap(nextBtn.first, warnIfMissed: false);
  await _settle(tester, timeout: const Duration(seconds: 10));

  nextBtn = find.widgetWithText(FilledButton, 'Далее').hitTestable();
  if (nextBtn.evaluate().isEmpty) {
    nextBtn = find.widgetWithText(FilledButton, 'Next').hitTestable();
  }
  if (nextBtn.evaluate().isNotEmpty) {
    await tester.tap(nextBtn.first, warnIfMissed: false);
    await _settle(tester, timeout: const Duration(seconds: 10));
  }

  Finder createBtn = find.widgetWithText(FilledButton, 'Создать').hitTestable();
  if (createBtn.evaluate().isEmpty) {
    createBtn = find.widgetWithText(FilledButton, 'Create').hitTestable();
  }
  if (createBtn.evaluate().isEmpty) {
    final allFilled = find.byType(FilledButton).hitTestable();
    if (allFilled.evaluate().isEmpty) {
      throw StateError('Create button not found on review step.');
    }
    createBtn = allFilled.first;
  }
  await tester.tap(createBtn.first, warnIfMissed: false);
  await _settle(tester, timeout: const Duration(seconds: 20));
}

Future<void> _captureWidget({
  required GlobalKey screenshotKey,
  required File outputFile,
}) async {
  final context = screenshotKey.currentContext;
  if (context == null) throw StateError('Screenshot context is not ready.');
  final boundary = context.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) throw StateError('Could not find render boundary.');
  final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) throw StateError('Failed to encode PNG.');
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsBytesSync(byteData.buffer.asUint8List());
  if (!outputFile.existsSync()) {
    throw StateError('Screenshot file was not created: ${outputFile.path}');
  }
  if (outputFile.lengthSync() == 0) {
    throw StateError('Screenshot file is empty: ${outputFile.path}');
  }
}

String _routeToFileName(String route) {
  var s = route.trim();
  if (s.isEmpty || s == '/') return 'root.png';
  s = s.replaceAll(RegExp('^/+'), '');
  s = s.replaceAll('/', '_');
  s = s.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  return '$s.png';
}

Future<void> _settle(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  // Keep waits short; avoid long blocking pauses.
  final effectiveTimeout = timeout > const Duration(seconds: 6)
      ? const Duration(seconds: 6)
      : timeout;
  final sw = Stopwatch()..start();
  while (sw.elapsed < effectiveTimeout) {
    await tester.pump(const Duration(milliseconds: 120));
    if (!tester.binding.hasScheduledFrame) {
      return;
    }
  }
  // One last pump to avoid hanging forever on ongoing animations.
  await tester.pump(const Duration(milliseconds: 120));
}
