import 'package:flutter/material.dart';
import 'screens/boot_screen/boot.dart';

void main() {
  runApp(const SafeHavenApp());
}

class SafeHavenApp extends StatelessWidget {
  const SafeHavenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeHaven',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF08090C),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF20C464),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const BootScreen(),
    );
  }
}
