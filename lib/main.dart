import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:lifeline/chatbot/providers/chat_provider.dart';
import 'package:lifeline/chatbot/providers/settings_provider.dart';
import 'package:lifeline/firebase/firebase_options.dart';
import 'package:lifeline/screens/auth_screens/loading_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; 


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Gemini API (Hive storage for chat data)
  await ChatProvider.initHive();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ChatProvider()), 
        ChangeNotifierProvider(create: (context) => SettingsProvider()), 
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeLine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.nunitoTextTheme(),
      ),
      home: const LoadingScreen(),
    );
  }
}
