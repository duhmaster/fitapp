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
    final screensDir = Directory('$outputRoot/screens')..createSync(recursive: true);
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

    await _loginIfNeeded(tester);
    await _settle(tester);

    final appContext = tester.element(find.byType(FitflowApp));
    final container = ProviderScope.containerOf(appContext, listen: false);
    final router = container.read(appRouterProvider);

    final captured = <String>[];
    final failed = <Map<String, String>>[];

    Future<void> captureStep(String routeLikeName) async {
      await _captureWidget(
        screenshotKey: screenshotKey,
        outputFile: File('${screensDir.path}/${_routeToFileName(routeLikeName)}'),
      );
      captured.add(routeLikeName);
    }

    try {
      await _scenarioCreateTemplateAndStartWorkout(tester, router);
      await _settle(tester);
      await captureStep('/scenarios/template_created');
      await _scenarioFinishWorkout(tester);
      await _settle(tester);
      await captureStep('/scenarios/workout_finished');
    } catch (e) {
      failed.add({'route': '/scenarios/template_workout_flow', 'error': '$e'});
    }

    try {
      await _scenarioCreateGroupTraining(tester, router);
      await _settle(tester);
      await captureStep('/scenarios/group_training_created');
    } catch (e) {
      failed.add({'route': '/scenarios/group_training_flow', 'error': '$e'});
    }

    for (final route in _routesToCapture) {
      try {
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
      reportFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    } catch (_) {
      final fallbackDir = Directory(
        '${Directory.systemTemp.path}/fitflow_visual/$runId/$platform',
      )..createSync(recursive: true);
      final fallbackReport = File('${fallbackDir.path}/report.json');
      fallbackReport.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
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
      reason: 'Some routes failed during visual capture. See ${reportFile.path}',
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
      Directory('${Directory.systemTemp.path}/fitflow_visual/$runId/$platform').absolute.path;
  final dir = Directory(fallback)..createSync(recursive: true);
  final probe = File('${dir.path}/.write_probe');
  probe.writeAsStringSync('ok');
  probe.deleteSync();
  return fallback;
}

Future<void> _loginIfNeeded(WidgetTester tester) async {
  // If login form is visible, authenticate using env vars.
  final emailFields = find.byType(TextFormField);
  if (emailFields.evaluate().length < 2) return;

  final email = Platform.environment['FITFLOW_E2E_EMAIL'];
  final password = Platform.environment['FITFLOW_E2E_PASSWORD'];
  if (email == null || password == null || email.isEmpty || password.isEmpty) {
    throw StateError(
      'Set FITFLOW_E2E_EMAIL and FITFLOW_E2E_PASSWORD to run visual tests from login screen.',
    );
  }

  await tester.enterText(emailFields.at(0), email);
  await tester.enterText(emailFields.at(1), password);

  Finder submit = find.byType(FilledButton).hitTestable();
  if (submit.evaluate().isEmpty) {
    submit = find.byType(FilledButton);
  }
  if (submit.evaluate().isEmpty) {
    throw StateError('Login submit button not found.');
  }
  await tester.ensureVisible(submit.first);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(submit.first, warnIfMissed: false);
  await _settle(tester, timeout: const Duration(seconds: 25));
}

Future<void> _scenarioCreateTemplateAndStartWorkout(
  WidgetTester tester,
  dynamic router,
) async {
  final unique = DateTime.now().millisecondsSinceEpoch;
  final templateName = 'autotest_$unique';
  router.go('/templates');
  await _settle(tester);

  // Open create-template dialog.
  final createBtn = find.byType(FilledButton).first;
  await tester.ensureVisible(createBtn);
  await tester.tap(createBtn, warnIfMissed: false);
  await _settle(tester);

  // Fill name and submit.
  final textField = find.byType(TextField).first;
  await tester.enterText(textField, templateName);
  final submit = find.byType(FilledButton).last;
  await tester.tap(submit, warnIfMissed: false);
  await _settle(tester, timeout: const Duration(seconds: 20));

  // Back to templates list and start workout from first template via play icon.
  router.go('/templates');
  await _settle(tester);
  final play = find.byIcon(Icons.play_arrow).first;
  await tester.ensureVisible(play);
  await tester.tap(play, warnIfMissed: false);
  await _settle(tester, timeout: const Duration(seconds: 20));
}

Future<void> _scenarioFinishWorkout(WidgetTester tester) async {
  // ActiveWorkout has finish action as first appbar TextButton in normal flow.
  Finder finishButton = find.byType(TextButton).hitTestable();
  if (finishButton.evaluate().isEmpty) {
    finishButton = find.byType(TextButton);
  }
  if (finishButton.evaluate().isNotEmpty) {
    await tester.tap(finishButton.first, warnIfMissed: false);
    await _settle(tester, timeout: const Duration(seconds: 20));
  }
}

Future<void> _scenarioCreateGroupTraining(
  WidgetTester tester,
  dynamic router,
) async {
  router.go('/trainer/group-trainings/new');
  await _settle(tester, timeout: const Duration(seconds: 20));
  // Form has defaults for template/gym, save is AppBar TextButton.
  Finder saveButton = find.byType(TextButton).hitTestable();
  if (saveButton.evaluate().isEmpty) {
    saveButton = find.byType(TextButton);
  }
  if (saveButton.evaluate().isEmpty) {
    throw StateError('Save button not found on group training edit screen.');
  }
  await tester.tap(saveButton.first, warnIfMissed: false);
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
  final sw = Stopwatch()..start();
  while (sw.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 120));
    if (!tester.binding.hasScheduledFrame) {
      return;
    }
  }
  // One last pump to avoid hanging forever on ongoing animations.
  await tester.pump(const Duration(milliseconds: 120));
}
