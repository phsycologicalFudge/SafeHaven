import 'package:flutter/material.dart';
import '../../services/theme/theme_manager.dart';
import '../../services/index_service.dart';
import '../../services/store_service.dart';
import '../../services/installer/apk_install_service.dart';
import '../../widgets/identity_setup_dialog.dart';
import 'appScreen/app_screen.dart';
import 'search_screen.dart';

PageRouteBuilder<void> _pushRoute(Widget page) {
  return PageRouteBuilder<void>(
    pageBuilder: (_, __, ___) => page,
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
  );
}

class CatalogueScreen extends StatefulWidget {
  const CatalogueScreen({super.key});

  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  late Future<StoreIndex> _future;
  String? _selectedCategory;
  List<String> _shuffledCategoryKeys = [];
  Future<List<PublicStoreApp>>? _recommendedFuture;
  String? _recommendedKey;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      IdentitySetupDialog.showIfNeeded(context);
    });
  }

  Future<void> _reload() async {
    setState(() {
      _shuffledCategoryKeys = [];
      _recommendedFuture = null;
      _recommendedKey = null;
      _loadFuture(forceRefresh: true);
    });

    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StoreIndex>(
      future: _future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final index = snapshot.data;

        final allApps = index?.apps ?? const [];
        final filtered = IndexService.instance.filterByCategory(
          allApps,
          _selectedCategory,
        );
        final topCharts = IndexService.instance.topCharts(filtered);
        final Future<List<PublicStoreApp>>? recommendedFuture =
        filtered.isEmpty ? null : _recommendedFor(filtered, topCharts);
        final Widget? recommendedSection = recommendedFuture == null
            ? null
            : _RecommendedSection(future: recommendedFuture);

        return RefreshIndicator(
          onRefresh: _reload,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: _SearchButton()),
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
              if (!loading && !snapshot.hasError && filtered.isEmpty)
                const SliverToBoxAdapter(child: _EmptyBlock()),
              if (!loading && !snapshot.hasError && filtered.isNotEmpty)
                ...[
                  if (recommendedSection != null)
                    SliverToBoxAdapter(child: recommendedSection),
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
                      apps: filtered,
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

  Future<List<PublicStoreApp>> _recommendedFor(
      List<PublicStoreApp> apps,
      List<PublicStoreApp> topCharts,
      ) {
    final key = [
      _selectedCategory ?? '',
      apps.map((app) => app.packageName).join('|'),
      topCharts.map((app) => app.packageName).join('|'),
    ].join('::');

    if (_recommendedKey != key || _recommendedFuture == null) {
      _recommendedKey = key;
      _recommendedFuture = IndexService.instance.recommended(
        apps,
        exclude: topCharts,
      );
    }

    return _recommendedFuture!;
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton();

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(_pushRoute(const SearchScreen()));
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
        child: AbsorbPointer(
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
                  child: Text(
                    'Search apps',
                    style: TextStyle(
                      fontSize: 15,
                      color: colors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),
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

class _RecommendedSection extends StatelessWidget {
  const _RecommendedSection({required this.future});

  final Future<List<PublicStoreApp>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PublicStoreApp>>(
      future: future,
      builder: (context, snapshot) {
        final apps = snapshot.data ?? const <PublicStoreApp>[];
        if (apps.isEmpty) return const SizedBox.shrink();

        return _HorizontalSection(
          title: 'Recommended for you',
          apps: apps,
        );
      },
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
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          _SectionHeader(title: title),
          const SizedBox(height: 8),
          SizedBox(
            height: 136,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: apps.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
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
      padding: const EdgeInsets.only(top: 12),
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
  const _SectionHeader({required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
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
            if (onTap != null)
              Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: colors.textSoft,
              ),
          ],
        ),
      ),
    );
  }
}

String _compactAppName(String name) {
  final trimmed = name.trim();
  if (trimmed.length <= 6) return trimmed;
  return '${trimmed.substring(0, 6)}...';
}

class _AppSmallTile extends StatelessWidget {
  const _AppSmallTile({required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return SizedBox(
      width: 74,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(_pushRoute(AppScreen(app: app)));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AppIcon(app: app, size: 68),
            const SizedBox(height: 7),
            Text(
              _compactAppName(app.name),
              maxLines: 1,
              overflow: TextOverflow.clip,
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
        Navigator.of(context).push(_pushRoute(AppScreen(app: app)));
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
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
                  if (app.ratingCount > 0) ...[
                    const SizedBox(height: 3),
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
            ),
            _DownloadButton(app: app),
          ],
        ),
      ),
    );
  }
}

enum _DlState { checking, idle, downloading, cancelling, done }

class _DownloadButton extends StatefulWidget {
  const _DownloadButton({required this.app});

  final PublicStoreApp app;

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton>
    with WidgetsBindingObserver {
  _DlState _state = _DlState.checking;
  double _progress = 0.0;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInstalled();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _state == _DlState.done) {
      Future.delayed(const Duration(milliseconds: 600), _checkInstalled);
    }
  }

  Future<void> _checkInstalled() async {
    if (widget.app.latestVersion == null) return;
    try {
      final pkg = await ApkInstallService.instance.getPackageState(
        packageName: widget.app.packageName,
      );
      if (!mounted) return;
      setState(() {
        _state = pkg.installed ? _DlState.done : _DlState.idle;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _DlState.idle);
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _state = _DlState.downloading;
      _progress = 0.0;
      _cancelling = false;
    });
    try {
      await ApkInstallService.instance.downloadAndInstall(
        app: widget.app,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() => _state = _DlState.done);
    } catch (_) {
      if (!mounted) return;
      if (_cancelling) {
        await Future.delayed(const Duration(milliseconds: 500));
        _cancelling = false;
        if (!mounted) return;
      }
      setState(() => _state = _DlState.idle);
    }
  }

  Future<void> _cancelDownload() async {
    if (_state != _DlState.downloading) return;
    _cancelling = true;
    setState(() => _state = _DlState.cancelling);
    await ApkInstallService.instance.cancelDownload();
  }

  Future<void> _open() async {
    try {
      await ApkInstallService.instance.openApp(
        packageName: widget.app.packageName,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    if (_state == _DlState.checking) {
      return const SizedBox(width: 44);
    }

    Widget content;
    VoidCallback? onTap;

    switch (_state) {
      case _DlState.idle:
        content = Icon(
          Icons.download_rounded,
          size: 20,
          color: colors.textMuted,
        );
        onTap = _startDownload;
      case _DlState.downloading:
        content = SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            value: _progress > 0 ? _progress : null,
            strokeWidth: 1.8,
            color: colors.text,
          ),
        );
        onTap = _cancelDownload;
      case _DlState.cancelling:
        content = SizedBox(
          width: 22,
          height: 22,
          child: Transform.scale(
            scaleX: -1,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: colors.textMuted,
            ),
          ),
        );
        onTap = null;
      case _DlState.done:
        content = Text(
          'Open',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        );
        onTap = _open;
      case _DlState.checking:
        content = const SizedBox.shrink();
        onTap = null;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.7, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                ),
                child: child,
              ),
            );
          },
          child: Center(
            key: ValueKey(_state),
            child: content,
          ),
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
    final colors = SafeHavenTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 44, 18, 44),
      child: Center(child: CircularProgressIndicator(color: colors.accentEnd)),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 44, 18, 44),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: colors.textMuted,
            size: 34,
          ),
          const SizedBox(height: 14),
          Text(
            'Could not load catalogue',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: colors.textSoft,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 42,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: colors.accentGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onRetry,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Center(
                      child: Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: colors.buttonText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock();

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 54, 18, 54),
      child: Center(
        child: Text(
          'No apps are live yet.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: colors.textSoft,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}