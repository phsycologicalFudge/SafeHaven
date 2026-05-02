import 'package:flutter/material.dart';

import '../../services/theme/theme_manager.dart';
import '../../widgets/footer.dart';
import '../account/developer_account_screen.dart';
import '../apps/catalogue.dart';
import '../apps/history_screen.dart';
import '../apps/search_screen.dart';
import 'top_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

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
            child: IndexedStack(
              index: selectedIndex,
              children: const [
                CatalogueScreen(),
                SearchScreen(),
                HistoryScreen(),
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
        return 'Search';
      case 2:
        return 'History';
      default:
        return 'SafeHaven';
    }
  }
}