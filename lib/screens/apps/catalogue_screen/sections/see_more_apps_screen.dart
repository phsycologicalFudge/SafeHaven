import 'package:flutter/material.dart';
import '../../../../services/catalogue_service.dart';
import '../../../../services/store_service.dart';
import '../../../../services/theme/theme_manager.dart';
import '../widgets/catalogue_app_tiles.dart';
import '../widgets/catalogue_shared_widgets.dart';

class SeeMoreAppsScreen extends StatefulWidget {
  const SeeMoreAppsScreen({
    required this.title,
    required this.apps,
  });

  final String title;
  final List<PublicStoreApp> apps;

  @override
  State<SeeMoreAppsScreen> createState() => _SeeMoreAppsScreenState();
}

class _SeeMoreAppsScreenState extends State<SeeMoreAppsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);
    List<PublicStoreApp> displayedApps = widget.apps;

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      displayedApps = displayedApps.where((app) {
        return app.name.toLowerCase().contains(query) ||
            app.developerName.toLowerCase().contains(query) ||
            app.packageName.toLowerCase().contains(query);
      }).toList();
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 18, 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: colors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${displayedApps.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                          SafeHavenThemeManager.instance.isDark ? 0.16 : 0.045,
                        ),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(
                        Icons.search_rounded,
                        size: 22,
                        color: colors.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                          style: TextStyle(
                            fontSize: 15,
                            color: colors.text,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search apps',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: colors.textMuted,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: colors.textMuted,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 14),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (displayedApps.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: CatalogueEmptyBlock(),
                ),
              )
            else
              SliverList.builder(
                itemCount: displayedApps.length,
                itemBuilder: (context, index) {
                  return CatalogueAppWideRow(app: displayedApps[index]);
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
          ],
        ),
      ),
    );
  }
}
