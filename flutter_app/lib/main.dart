import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'data/stroll_repository.dart';
import 'presentation/screens/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final repository = AppServices.repository;
  String? startupError;
  const recommendationApiBaseUrl =
      String.fromEnvironment('STROLL_RECOMMEND_API_BASE_URL', defaultValue: 'http://127.0.0.1:8787');

  try {
    await repository.initialize(
      recommendationApiBaseUrl: recommendationApiBaseUrl.trim().isEmpty ? 'http://127.0.0.1:8787' : recommendationApiBaseUrl,
    );
  } catch (error) {
    startupError = error.toString();
  }

  runApp(StrollApp(repository: repository, startupError: startupError));
}

class StrollApp extends StatelessWidget {
  const StrollApp({
    super.key,
    required this.repository,
    this.startupError,
  });

  final StrollRepository repository;
  final String? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PULSE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: MainScreen(
        repository: repository,
        startupError: startupError,
      ),
    );
  }
}
