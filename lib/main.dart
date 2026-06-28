import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lifeline/firebase/firebase_options.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/services/locale_controller.dart';
import 'package:lifeline/services/push_service.dart';
import 'package:lifeline/views/entry/splash_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Handles pushes that arrive while the app is backgrounded/terminated. Must
/// be a top-level entry point; Firebase needs its own init in this isolate.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // System tray display is handled by FCM via the manifest default channel;
  // tap routing is wired in PushService once the app resumes.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Route uncaught Flutter + platform errors to Crashlytics (I3).
  // Disabled in debug so test/analysis runs don't report crashes.
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Offline mode: persist Firestore locally so contacts, profile and chats are
  // readable without a connection, and outgoing writes (SOS/chat) queue and
  // auto-sync on reconnect.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  final localeController = LocaleController();
  await localeController.load();

  runApp(
    ChangeNotifierProvider.value(
      value: localeController,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeController = context.watch<LocaleController>();
    return MaterialApp(
      title: 'LifeLine',
      debugShowCheckedModeBanner: false,
      navigatorKey: PushService.navigatorKey,
      scaffoldMessengerKey: PushService.messengerKey,
      locale: localeController.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        // Seed the whole Material colour system from the brand orange so
        // defaults (buttons, switches, spinners, picker dialogs, text-field
        // cursor/selection) stop falling back to Flutter's stock purple.
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          brightness: Brightness.light,
        ),
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(color: AppColors.primary),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppColors.primary,
          selectionColor: AppColors.primary.withOpacity(0.25),
          selectionHandleColor: AppColors.primary,
        ),
        textTheme: GoogleFonts.nunitoTextTheme().apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textTertiary,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
