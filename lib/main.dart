import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:lifeline/firebase/firebase_options.dart';
import 'package:lifeline/constants/app_colors.dart';
import 'package:lifeline/views/entry/splash_screen.dart';
import 'package:google_fonts/google_fonts.dart';

// Import your DynamicColors class here if in another file
// import 'path_to_dynamic_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Hive.initFlutter();
  await Hive.openBox('chat_sessions');

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkMode = false;

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = DynamicColors(isDarkMode);

    return MaterialApp(
        title: 'LifeLine',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: isDarkMode ? Brightness.dark : Brightness.light,
          scaffoldBackgroundColor: colors.background,
          primaryColor: colors.primary,
          textTheme: GoogleFonts.nunitoTextTheme().apply(
            bodyColor: colors.textPrimary,
            displayColor: colors.textPrimary,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: colors.primary,
            foregroundColor: colors.textTertiary,
            elevation: 0,
          ),
        ),
        home: const SplashScreen());
  }
}
