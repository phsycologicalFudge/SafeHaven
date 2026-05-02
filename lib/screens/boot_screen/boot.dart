import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/theme/theme_manager.dart';
import '../home/home.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SafeHavenThemeManager.instance,
      builder: (context, _) {
        final colors = SafeHavenTheme.of(context);

        return Scaffold(
          backgroundColor: colors.background,
          body: Center(
            child: ShaderMask(
              shaderCallback: (bounds) {
                return colors.accentGradient.createShader(bounds);
              },
              child: const Text(
                'SafeHaven',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}