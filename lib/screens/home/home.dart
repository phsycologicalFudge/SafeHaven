import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/theme/theme_manager.dart';
import '../../widgets/footer.dart';
import '../account/settings/settings_screen.dart';
import '../apps/catalogue_screen/catalogue_screen.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermission();
    });
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  }

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
                PageRouteBuilder<void>(
                  pageBuilder: (_, __, ___) => const SettingsScreen(),
                  transitionDuration: const Duration(milliseconds: 260),
                  reverseTransitionDuration: const Duration(milliseconds: 210),
                  transitionsBuilder: (_, animation, __, child) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    );
                    return FadeTransition(
                      opacity: curved,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(curved),
                        child: child,
                      ),
                    );
                  },
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
        return 'Recently Viewed';
      case 2:
        return 'My Apps';
      default:
        return 'SafeHaven';
    }
  }
}