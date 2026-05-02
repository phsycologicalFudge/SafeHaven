import 'package:flutter/material.dart';

import '../../services/theme/theme_manager.dart';

class TopBanner {
  static PreferredSizeWidget home({VoidCallback? onAccountTap}) {
    return _SafeHavenTopBanner(
      title: 'SafeHaven',
      large: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: IconButton(
            onPressed: onAccountTap,
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
    return _SafeHavenTopBanner(
      title: title,
      large: true,
      actions: actions,
    );
  }
}

class _SafeHavenTopBanner extends StatelessWidget
    implements PreferredSizeWidget {
  const _SafeHavenTopBanner({
    required this.title,
    required this.large,
    required this.actions,
  });

  final String title;
  final bool large;
  final List<Widget> actions;

  @override
  Size get preferredSize => Size.fromHeight(large ? 62 : kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colors.background,
      foregroundColor: colors.text,
      surfaceTintColor: Colors.transparent,
      titleSpacing: large ? 20 : 0,
      toolbarHeight: large ? 62 : kToolbarHeight,
      title: ShaderMask(
        shaderCallback: (bounds) {
          return colors.accentGradient.createShader(bounds);
        },
        child: Text(
          title,
          style: TextStyle(
            fontSize: large ? 28 : 19,
            fontWeight: large ? FontWeight.w800 : FontWeight.w700,
            letterSpacing: large ? -1 : -0.3,
            color: Colors.white,
          ),
        ),
      ),
      actions: actions,
    );
  }
}