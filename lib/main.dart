import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'screens/auth/login_screen.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SORECO',
      theme: ThemeData(
        primaryColor: const Color(0xFFFFA000), // Orange
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.orange).copyWith(
          secondary: const Color(0xFFFFC107), // Amber/Yellow
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFA000),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFA000),
            foregroundColor: Colors.white,
          ),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8E1), // light amber
      ),
      home: const LoginScreen(),
    );
  }
}