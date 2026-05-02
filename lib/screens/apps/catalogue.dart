import 'package:flutter/material.dart';
import '../../services/theme/theme_manager.dart';
import '../../services/index_service.dart';
import '../../services/store_service.dart';
import '../../widgets/identity_setup_dialog.dart';
import 'app_screen.dart';

class CatalogueScreen extends StatefulWidget {
  const CatalogueScreen({super.key});

  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<StoreIndex> _future;
  String _query = '';
  String? _selectedCategory;
  List<String> _shuffledCategoryKeys = [];

  void _loadFuture({bool forceRefresh = false}) {
    _future = IndexService.instance.fetchIndex(forceRefresh: forceRefresh);
    _future.then((index) {
      if (mounted && _shuffledCategoryKeys.isEmpty) {
        setState(() {
          _shuffledCategoryKeys =
              IndexService.instance.shuffledCategoryKeys(index.categories);
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadFuture();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      IdentitySetupDialog.showIfNeeded(context);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _shuffledCategoryKeys = [];
      _loadFuture(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StoreIndex>(
      future: _future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final index = snapshot.data;

        final allApps = index?.apps ?? const [];
        final categoryFiltered = IndexService.instance.filterByCategory(
          allApps,
          _selectedCategory,
        );
        final searchFiltered = _applySearch(categoryFiltered);
        final recommended = IndexService.instance.recommended(searchFiltered);
        final topCharts = IndexService.instance.topCharts(searchFiltered);

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _SearchArea(controller: _searchController),
              ),
              if (index != null && index.categories.isNotEmpty)
                SliverToBoxAdapter(
                  child: _CategoryTabs(
                    categoryKeys: _shuffledCategoryKeys,
                    categories: index.categories,
                    selected: _selectedCategory,
                    onSelected: (key) {
                      setState(() {
                        _selectedCategory = key;
                      });
                    },
                  ),
                ),
              if (loading)
                const SliverToBoxAdapter(child: _LoadingBlock()),
              if (snapshot.hasError)
                SliverToBoxAdapter(
                  child: _ErrorBlock(
                    message: snapshot.error.toString(),
                    onRetry: _reload,
                  ),
                ),
              if (!loading && !snapshot.hasError && searchFiltered.isEmpty)
                SliverToBoxAdapter(child: _EmptyBlock(query: _query)),
              if (!loading && !snapshot.hasError && searchFiltered.isNotEmpty)
                ...[
                  if (recommended.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _HorizontalSection(
                        title: 'Recommended for you',
                        apps: recommended,
                      ),
                    ),
                  if (topCharts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _HorizontalSection(
                        title: 'Top charts',
                        apps: topCharts,
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: _VerticalSection(
                      title: 'All apps',
                      apps: searchFiltered,
                    ),
                  ),
                ],
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
            ],
          ),
        );
      },
    );
  }

  List<PublicStoreApp> _applySearch(List<PublicStoreApp> apps) {
    if (_query.isEmpty) return apps;
    return apps.where((app) {
      return app.name.toLowerCase().contains(_query) ||
          app.packageName.toLowerCase().contains(_query) ||
          app.displaySummary.toLowerCase().contains(_query);
    }).toList();
  }
}

class _SearchArea extends StatelessWidget {
  const _SearchArea({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
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
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Search apps',
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: colors.textMuted,
                  ),
                ),
                style: TextStyle(fontSize: 15, color: colors.text),
              ),
            ),
            if (controller.text.isNotEmpty)
              IconButton(
                onPressed: controller.clear,
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: colors.textMuted,
                ),
              )
            else
              const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.categoryKeys,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categoryKeys;
  final Map<String, String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Container(
      height: 44,
      alignment: Alignment.bottomLeft,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: [
          _CategoryTabItem(
            label: 'For you',
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          ...categoryKeys.map((key) {
            final label = categories[key] ?? key;
            return _CategoryTabItem(
              label: label,
              selected: selected == key,
              onTap: () => onSelected(key),
            );
          }),
        ],
      ),
    );
  }
}

class _CategoryTabItem extends StatelessWidget {
  const _CategoryTabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.only(right: 26),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? colors.text : colors.textMuted,
                  ),
                ),
              ),
            ),
            Container(
              width: 28,
              height: 3,
              decoration: BoxDecoration(
                gradient: selected ? colors.accentGradient : null,
                color: selected ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _HorizontalSection extends StatelessWidget {
  const _HorizontalSection({required this.title, required this.apps});

  final String title;
  final List<PublicStoreApp> apps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        children: [
          _SectionHeader(title: title),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: apps.length,
              separatorBuilder: (_, __) => const SizedBox(width: 18),
              itemBuilder: (context, index) =>
                  _AppSmallTile(app: apps[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalSection extends StatelessWidget {
  const _VerticalSection({required this.title, required this.apps});

  final String title;
  final List<PublicStoreApp> apps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        children: [
          _SectionHeader(title: title),
          const SizedBox(height: 4),
          ...apps.map((app) => _AppWideRow(app: app)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: colors.text,
              ),
            ),
          ),
          Icon(
            Icons.arrow_forward_rounded,
            size: 20,
            color: colors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _AppSmallTile extends StatelessWidget {
  const _AppSmallTile({required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return SizedBox(
      width: 96,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AppScreen(app: app)),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AppIcon(app: app, size: 74),
            const SizedBox(height: 8),
            Text(
              app.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
            if (app.ratingCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${app.displayRating} ★',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: colors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppWideRow extends StatelessWidget {
  const _AppWideRow({required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AppScreen(app: app)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
        child: Row(
          children: [
            _AppIcon(app: app, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colors.textSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        app.displayVersion,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textMuted,
                        ),
                      ),
                      if (app.ratingCount > 0) ...[
                        Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                        ),
                        Text(
                          '${app.displayRating} ★',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.app, required this.size});

  final PublicStoreApp app;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.iconBackground,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: app.iconUrl.isEmpty
          ? null
          : Image.network(
        app.iconUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(18, 44, 18, 44),
      child: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 44, 18, 44),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Color(0xFF9EA3AD),
            size: 34,
          ),
          const SizedBox(height: 14),
          const Text(
            'Could not load catalogue',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF9EA3AD),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 54, 18, 54),
      child: Center(
        child: Text(
          query.isEmpty
              ? 'No apps are live yet.'
              : 'No apps matched your search.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF9EA3AD),
            height: 1.45,
          ),
        ),
      ),
    );
  }
}
