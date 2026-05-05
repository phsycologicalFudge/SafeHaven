import 'package:flutter/material.dart';

import '../../services/index_service.dart';
import '../../services/installer/apk_install_service.dart';
import '../../services/store_service.dart';
import '../../services/theme/theme_manager.dart';
import 'appScreen/app_screen.dart';

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

class MyAppsScreen extends StatefulWidget {
  const MyAppsScreen({super.key});

  @override
  State<MyAppsScreen> createState() => _MyAppsScreenState();
}

class _MyAppsScreenState extends State<MyAppsScreen> {
  late Future<List<PublicStoreApp>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadInstalledStoreApps();
  }

  Future<List<PublicStoreApp>> _loadInstalledStoreApps({
    bool forceRefresh = false,
  }) async {
    final index = await IndexService.instance.fetchIndex(
      forceRefresh: forceRefresh,
    );

    final installedApps = <PublicStoreApp>[];

    for (final app in index.apps) {
      try {
        final state = await ApkInstallService.instance.getPackageState(
          packageName: app.packageName,
        );

        if (state.installed) {
          installedApps.add(app);
        }
      } catch (_) {}
    }

    installedApps.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return installedApps;
  }

  Future<void> _reload() async {
    setState(() {
      _future = _loadInstalledStoreApps(forceRefresh: true);
    });

    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return FutureBuilder<List<PublicStoreApp>>(
      future: _future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final apps = snapshot.data ?? const <PublicStoreApp>[];

        return RefreshIndicator(
          onRefresh: _reload,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (loading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 54, 18, 54),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: colors.accentEnd,
                      ),
                    ),
                  ),
                ),
              if (snapshot.hasError)
                SliverToBoxAdapter(
                  child: _ErrorBlock(
                    message: snapshot.error.toString(),
                    onRetry: _reload,
                  ),
                ),
              if (!loading && !snapshot.hasError && apps.isEmpty)
                const SliverToBoxAdapter(child: _EmptyBlock()),
              if (!loading && !snapshot.hasError && apps.isNotEmpty)
                SliverToBoxAdapter(
                  child: _InstalledSection(apps: apps),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
            ],
          ),
        );
      },
    );
  }
}

class _InstalledSection extends StatelessWidget {
  const _InstalledSection({required this.apps});

  final List<PublicStoreApp> apps;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
          child: Text(
            'Installed [W.I.P]',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: colors.text,
            ),
          ),
        ),
        const SizedBox(height: 2),
        ...apps.map((app) => _InstalledAppRow(app: app)),
      ],
    );
  }
}

class _InstalledAppRow extends StatelessWidget {
  const _InstalledAppRow({required this.app});

  final PublicStoreApp app;

  Future<void> _openApp() async {
    try {
      await ApkInstallService.instance.openApp(
        packageName: app.packageName,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(_pushRoute(AppScreen(app: app)));
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
        child: Row(
          children: [
            _AppIcon(app: app, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 56,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    if (app.developerName.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        app.developerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openApp,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Text(
                    'Open',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                ),
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

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock();

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 64),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.apps_rounded,
              size: 38,
              color: colors.textMuted,
            ),
            const SizedBox(height: 14),
            Text(
              'No installed store apps found.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Apps only appear here when their package name matches an app in the catalogue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 54, 24, 54),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 36,
              color: colors.textMuted,
            ),
            const SizedBox(height: 14),
            Text(
              'Could not load your apps',
              textAlign: TextAlign.center,
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
                height: 1.35,
                color: colors.textSoft,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 42,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: colors.accentGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }
}