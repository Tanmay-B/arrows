import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'providers/game_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'services/ad_service.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  final gameProvider = GameProvider();
  final settingsProvider = SettingsProvider();

  await Future.wait([
    gameProvider.restoreProgress(),
    settingsProvider.load(),
  ]);

  runApp(
    ArrowsApp(
      gameProvider: gameProvider,
      settingsProvider: settingsProvider,
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    FlutterNativeSplash.remove();
    unawaited(_initializeAds());
  });
}

Future<void> _initializeAds() async {
  await MobileAds.instance.initialize();
  unawaited(AdService.instance.preloadInterstitial());
}

class ArrowsApp extends StatefulWidget {
  const ArrowsApp({
    super.key,
    required this.gameProvider,
    required this.settingsProvider,
  });

  final GameProvider gameProvider;
  final SettingsProvider settingsProvider;

  @override
  State<ArrowsApp> createState() => _ArrowsAppState();
}

class _ArrowsAppState extends State<ArrowsApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.gameProvider.saveProgress();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.gameProvider),
        ChangeNotifierProvider.value(value: widget.settingsProvider),
      ],
      child: MaterialApp(
        title: 'Arrow Maze',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFB07B26),
            brightness: Brightness.light,
            surface: const Color(0xFFF7F0DE),
          ),
          scaffoldBackgroundColor: const Color(0xFFF7F0DE),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(elevation: 0, centerTitle: false),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
