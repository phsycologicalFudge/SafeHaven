import 'package:flutter/material.dart';

import '../../services/theme/theme_manager.dart';
import '../../widgets/footer.dart';
import '../account/developer_account_screen.dart';
import '../apps/catalogue.dart';
import '../apps/history_screen.dart';
import '../apps/my_apps_screen.dart';
import 'top_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  static const List<Widget> _screens = [
    CatalogueScreen(),
    HistoryScreen(),
    MyAppsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SafeHavenThemeManager.instance,
      builder: (context, _) {
        final colors = SafeHavenTheme.of(context);

        return Scaffold(
          backgroundColor: colors.background,
          appBar: selectedIndex == 0
              ? TopBanner.home(
            onAccountTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DeveloperAccountScreen(),
                ),
              );
            },
          )
              : TopBanner.defaultScreen(
            title: _titleForIndex(selectedIndex),
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: Stack(
              children: [
                for (int i = 0; i < _screens.length; i++)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: i != selectedIndex,
                      child: AnimatedOpacity(
                        opacity: i == selectedIndex ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: _screens[i],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          bottomNavigationBar: SafeHavenFooter(
            selectedIndex: selectedIndex,
            onSelected: (value) {
              setState(() {
                selectedIndex = value;
              });
            },
          ),
        );
      },
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 1:
        return 'History';
      case 2:
        return 'My Apps';
      default:
        return 'SafeHaven';
    }
  }
}