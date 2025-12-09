import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/recording/data/local_recording_repository.dart';
import 'features/upload/services/background_upload_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Hive for local storage
  await Hive.initFlutter();
  await LocalRecordingRepository.initialize();

  // Initialize Supabase
  await initSupabase();

  // Initialize background upload service (not available on web)
  // Note: workmanager only works on Android/iOS
  try {
    await initializeBackgroundUpload();
  } catch (e) {
    // Ignore on web/unsupported platforms
    debugPrint('Background upload not available: $e');
  }

  // TODO: Initialize Firebase for push notifications
  // await Firebase.initializeApp();

  runApp(
    const ProviderScope(
      child: DealMotionApp(),
    ),
  );
}

class DealMotionApp extends StatelessWidget {
  const DealMotionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DealMotion',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // Routing
      routerConfig: goRouter,
    );
  }
}
