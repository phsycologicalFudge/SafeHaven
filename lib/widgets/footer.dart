import 'package:flutter/material.dart';

import '../services/theme/theme_manager.dart';

class SafeHavenFooter extends StatelessWidget {
  const SafeHavenFooter({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: 60 + bottomPadding,
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: colors.navBackground,
        border: Border(
          top: BorderSide(color: colors.navBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          _FooterItem(
            index: 0,
            selectedIndex: selectedIndex,
            icon: Icons.apps_rounded,
            label: 'Apps',
            onSelected: onSelected,
          ),
          _FooterItem(
            index: 1,
            selectedIndex: selectedIndex,
            icon: Icons.history_rounded,
            label: 'History',
            onSelected: onSelected,
          ),
          _FooterItem(
            index: 2,
            selectedIndex: selectedIndex,
            icon: Icons.install_mobile_rounded,
            label: 'My Apps',
            onSelected: onSelected,
          ),
        ],
      ),
    );
  }
}

class _FooterItem extends StatelessWidget {
  const _FooterItem({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final int index;
  final int selectedIndex;
  final IconData icon;
  final String label;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);
    final selected = index == selectedIndex;

    return Expanded(
      child: InkWell(
        onTap: () => onSelected(index),
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 4,
                  ),
                  decoration: colors.gradientPill,
                  child: Icon(icon, size: 19, color: Colors.white),
                )
              else
                Icon(icon, size: 21, color: colors.textMuted),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.text : colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}