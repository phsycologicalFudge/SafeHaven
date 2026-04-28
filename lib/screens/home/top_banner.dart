import 'package:flutter/material.dart';

class TopBanner {
  static PreferredSizeWidget home() {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: const Color(0xFF08090C),
      surfaceTintColor: Colors.transparent,
      titleSpacing: 20,
      toolbarHeight: 62,
      title: const Text(
        'SafeHaven',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.person_outline_rounded),
          ),
        ),
      ],
    );
  }

  static PreferredSizeWidget defaultScreen({
    required String title,
    List<Widget> actions = const [],
  }) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: const Color(0xFF08090C),
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      actions: actions,
    );
  }
}
