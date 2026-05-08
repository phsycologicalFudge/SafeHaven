import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/history_service.dart';
import '../../../services/store_service.dart';
import '../../../services/theme/theme_manager.dart';
import 'app_screen_helpers.dart';
import 'app_screen_sections.dart';

class AppScreen extends StatefulWidget {
  const AppScreen({super.key, required this.app});

  final PublicStoreApp app;

  @override
  State<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> {
  Color _iconColor = const Color(0xFF161A24);
  int _iconColorRequestId = 0;

  @override
  void initState() {
    super.initState();
    _recordHistory();
    _loadIconColor();
  }

  @override
  void didUpdateWidget(covariant AppScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.app.packageName != widget.app.packageName) {
      _recordHistory();
    }

    if (oldWidget.app.iconUrl != widget.app.iconUrl) {
      _iconColor = const Color(0xFF161A24);
      _loadIconColor();
    }
  }

  void _recordHistory() {
    HistoryService.instance.recordView(widget.app.packageName);
    HistoryService.instance.recordCategoryView(widget.app.category);
  }

  Future<void> _loadIconColor() async {
    final requestId = ++_iconColorRequestId;
    final iconUrl = widget.app.iconUrl?.trim();

    if (iconUrl == null || iconUrl.isEmpty) return;

    final color = await extractImageColor(iconUrl);

    if (!mounted || requestId != _iconColorRequestId || color == null) return;

    setState(() => _iconColor = color);
  }

  void _showActionsSheet() {
    final colors = SafeHavenTheme.of(context);
    final repoUrl = widget.app.repoUrl.trim();

    showDialog(
      context: context,
      builder: (_) => AppAccentDialog(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'App options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 16),
              _ActionSheetItem(
                icon: Icons.content_copy_rounded,
                title: 'Copy repo link',
                subtitle: repoUrl.isEmpty
                    ? 'No repository link is available yet.'
                    : repoUrl,
                enabled: repoUrl.isNotEmpty,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: repoUrl));
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Repo link copied')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);
    final accent = polishAccentColor(_iconColor);
    final glowOpacity = SafeHavenThemeManager.instance.isDark ? 0.24 : 0.13;
    final washOpacity = SafeHavenThemeManager.instance.isDark ? 0.11 : 0.055;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: colors.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colors.text,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _showActionsSheet,
            icon: Icon(
              Icons.more_vert_rounded,
              color: colors.textSoft,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.background,
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      accent.withOpacity(glowOpacity),
                      colors.accentEnd.withOpacity(washOpacity),
                      colors.background.withOpacity(0),
                      colors.background.withOpacity(0),
                    ],
                    stops: const [0.0, 0.30, 0.66, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: -90,
            right: -90,
            child: IgnorePointer(
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.08,
                    colors: [
                      accent.withOpacity(glowOpacity),
                      colors.background.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
                ),
              ),
              SliverToBoxAdapter(child: AppScreenHeader(app: widget.app)),
              SliverToBoxAdapter(child: AppScreenMetadataRow(app: widget.app)),
              SliverToBoxAdapter(child: AppScreenInstallButton(app: widget.app)),
              SliverToBoxAdapter(child: AppScreenPreviewSection(app: widget.app)),
              SliverToBoxAdapter(child: AppScreenAboutSection(app: widget.app)),
              SliverToBoxAdapter(child: AppScreenTrustSection(app: widget.app)),
              SliverToBoxAdapter(child: AppScreenTechnicalSection(app: widget.app)),
              SliverToBoxAdapter(child: AppScreenRateButton(app: widget.app)),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionSheetItem extends StatelessWidget {
  const _ActionSheetItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);
    final iconColor = enabled ? colors.accentEnd : colors.textMuted;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceSoft.withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: enabled ? colors.text : colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
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