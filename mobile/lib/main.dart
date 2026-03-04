import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/app.dart';
import 'package:fitflow/core/url_strategy_stub.dart'
    if (dart.library.html) 'package:fitflow/core/url_strategy_web.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  runApp(const ProviderScope(child: FitflowApp()));
}
