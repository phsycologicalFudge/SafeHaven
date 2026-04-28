import 'package:flutter/material.dart';

import '../../services/store_service.dart';
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

  @override
  void initState() {
    super.initState();
    _future = StoreService.instance.fetchIndex();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = StoreService.instance.fetchIndex();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StoreIndex>(
      future: _future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final apps = _filteredApps(snapshot.data?.apps ?? const []);
        final reviewedApps = apps.where((app) => app.securityReviewed).toList();
        final updatedApps = [...apps]..sort((a, b) => (b.latestVersion?.added ?? 0).compareTo(a.latestVersion?.added ?? 0));

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _SearchArea(controller: _searchController)),
              const SliverToBoxAdapter(child: _CategoryTabs()),
              if (loading) const SliverToBoxAdapter(child: _LoadingBlock()),
              if (snapshot.hasError) SliverToBoxAdapter(child: _ErrorBlock(message: snapshot.error.toString(), onRetry: _reload)),
              if (!loading && !snapshot.hasError && apps.isEmpty) SliverToBoxAdapter(child: _EmptyBlock(query: _query)),
              if (!loading && !snapshot.hasError && apps.isNotEmpty) ...[
                SliverToBoxAdapter(child: _HorizontalSection(title: 'Recommended for you', apps: apps)),
                SliverToBoxAdapter(child: _HorizontalSection(title: 'New and updated apps', apps: updatedApps)),
                if (reviewedApps.isNotEmpty) SliverToBoxAdapter(child: _VerticalSection(title: 'Security Reviewed', apps: reviewedApps)),
                SliverToBoxAdapter(child: _VerticalSection(title: 'All apps', apps: apps)),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
            ],
          ),
        );
      },
    );
  }

  List<PublicStoreApp> _filteredApps(List<PublicStoreApp> apps) {
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF11141A),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFF222734)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search_rounded, size: 22, color: Color(0xFF9EA3AD)),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Search apps',
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintStyle: TextStyle(fontSize: 15, color: Color(0xFF9EA3AD)),
                ),
                style: const TextStyle(fontSize: 15, color: Colors.white),
              ),
            ),
            if (controller.text.isNotEmpty)
              IconButton(
                onPressed: controller.clear,
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF9EA3AD)),
              )
            else ...const [
              Icon(Icons.mic_none_rounded, size: 21, color: Color(0xFF9EA3AD)),
              SizedBox(width: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: const [
          _TabText(label: 'For you', selected: true),
          _TabText(label: 'Top charts'),
          _TabText(label: 'Categories'),
          _TabText(label: 'Reviewed'),
        ],
      ),
    );
  }
}

class _TabText extends StatelessWidget {
  const _TabText({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : const Color(0xFF9EA3AD),
            ),
          ),
          const SizedBox(height: 7),
          Container(
            height: 2,
            width: selected ? 24 : 0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
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
              itemBuilder: (context, index) => _AppSmallTile(app: apps[index]),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, size: 20, color: Color(0xFFD5D8DF)),
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
    return SizedBox(
      width: 96,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => AppScreen(app: app)));
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
              style: const TextStyle(fontSize: 12.5, height: 1.15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              app.trustLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFFD5D8DF)),
            ),
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
    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => AppScreen(app: app)));
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
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${app.packageName} · ${app.trustLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFFD5D8DF), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    app.displayVersion,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9EA3AD)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF9EA3AD)),
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF151820),
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: const Color(0xFF242934)),
      ),
      child: const SizedBox.shrink(),
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
          const Icon(Icons.cloud_off_rounded, color: Color(0xFF9EA3AD), size: 34),
          const SizedBox(height: 14),
          const Text(
            'Could not load catalogue',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF9EA3AD), height: 1.35),
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
          query.isEmpty ? 'No apps are live yet.' : 'No apps matched your search.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF9EA3AD), height: 1.45),
        ),
      ),
    );
  }
}
