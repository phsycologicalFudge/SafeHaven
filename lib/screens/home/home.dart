import 'package:flutter/material.dart';

import '../../widgets/footer.dart';
import '../account/developer_account_screen.dart';
import '../apps/catalogue.dart';
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
    return Scaffold(
      appBar: selectedIndex == 0 ? TopBanner.home() : TopBanner.defaultScreen(title: _titleForIndex(selectedIndex)),
      body: SafeArea(
        top: false,
        bottom: false,
        child: IndexedStack(
          index: selectedIndex,
          children: const [
            CatalogueScreen(),
            _PlaceholderScreen(subtitle: 'Search will live here.'),
            _PlaceholderScreen(subtitle: 'Viewed, installed, and saved apps will live here.'),
            DeveloperAccountScreen(),
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
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 1:
        return 'Search';
      case 2:
        return 'History';
      case 3:
        return 'Developer';
      default:
        return 'SafeHaven';
    }
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Color(0xFF9EA3AD),
          ),
        ),
      ),
    );
  }
}
