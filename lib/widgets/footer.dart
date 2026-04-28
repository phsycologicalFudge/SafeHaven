import 'package:flutter/material.dart';

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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: 58 + bottomPadding,
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0C10),
        border: Border(
          top: BorderSide(color: Color(0xFF171A21), width: 1),
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
            icon: Icons.search_rounded,
            label: 'Search',
            onSelected: onSelected,
          ),
          _FooterItem(
            index: 2,
            selectedIndex: selectedIndex,
            icon: Icons.history_rounded,
            label: 'History',
            onSelected: onSelected,
          ),
          _FooterItem(
            index: 3,
            selectedIndex: selectedIndex,
            icon: Icons.person_outline_rounded,
            label: 'Account',
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
    final selected = index == selectedIndex;
    final color = selected ? Colors.white : const Color(0xFF8B909B);

    return Expanded(
      child: InkWell(
        onTap: () => onSelected(index),
        child: SizedBox(
          height: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
