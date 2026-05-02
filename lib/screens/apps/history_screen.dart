import 'package:flutter/material.dart';

import '../../services/history_service.dart';
import '../../services/index_service.dart';
import '../../services/store_service.dart';
import '../../services/theme/theme_manager.dart';
import 'app_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<_HistoryData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HistoryData> _load() async {
    final results = await Future.wait([
      IndexService.instance.fetchIndex(),
      HistoryService.instance.getViewed(),
      HistoryService.instance.getInstalled(),
    ]);

    final index = results[0] as StoreIndex;
    final viewedPackages = results[1] as List<String>;
    final installedPackages = results[2] as List<String>;

    final appMap = {for (final a in index.apps) a.packageName: a};

    final viewed = viewedPackages
        .map((p) => appMap[p])
        .whereType<PublicStoreApp>()
        .toList();

    final installed = installedPackages
        .map((p) => appMap[p])
        .whereType<PublicStoreApp>()
        .toList();

    return _HistoryData(viewed: viewed, installed: installed);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return FutureBuilder<_HistoryData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: colors.accentEnd),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    color: colors.textMuted,
                    size: 34,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: _reload,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.text,
                      side: BorderSide(color: colors.border),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final isEmpty = data.viewed.isEmpty && data.installed.isEmpty;

        if (isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'Apps you view or install will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: colors.textMuted,
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: colors.accentEnd,
          onRefresh: () async => _reload(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 18),
            children: [
              if (data.installed.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Installed',
                  count: data.installed.length,
                ),
                ...data.installed.map((app) => _AppRow(app: app)),
                const SizedBox(height: 8),
              ],
              if (data.viewed.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Recently viewed',
                  count: data.viewed.length,
                ),
                ...data.viewed.map((app) => _AppRow(app: app)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HistoryData {
  const _HistoryData({required this.viewed, required this.installed});

  final List<PublicStoreApp> viewed;
  final List<PublicStoreApp> installed;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: colors.text,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app});

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
            _AppIcon(app: app, size: 52),
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
                    app.displayVersion,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: colors.textMuted,
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
