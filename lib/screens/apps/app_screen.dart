import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/history_service.dart';
import '../../services/installer/apk_install_service.dart';
import '../../services/store_service.dart';
import '../../services/theme/theme_manager.dart';
import '../../widgets/ratings/rating_sheet.dart';

class AppScreen extends StatefulWidget {
  const AppScreen({super.key, required this.app});

  final PublicStoreApp app;

  @override
  State<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> {
  Color _iconColor = const Color(0xFF161A24);

  @override
  void initState() {
    super.initState();
    HistoryService.instance.recordView(widget.app.packageName);
    _loadIconColor();
  }

  @override
  void didUpdateWidget(covariant AppScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.app.iconUrl != widget.app.iconUrl) {
      _iconColor = const Color(0xFF161A24);
      _loadIconColor();
    }
  }

  Future<void> _loadIconColor() async {
    final color = await _extractImageColor(widget.app.iconUrl);
    if (!mounted || color == null) return;

    setState(() {
      _iconColor = color;
    });
  }

  void _showActionsSheet() {
    final colors = SafeHavenTheme.of(context);
    final repoUrl = widget.app.repoUrl.trim();

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
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
                const SizedBox(height: 12),
                _ActionSheetItem(
                  icon: Icons.link_rounded,
                  title: 'Copy repo link',
                  subtitle: repoUrl.isEmpty
                      ? 'No repository link is available yet.'
                      : repoUrl,
                  enabled: repoUrl.isNotEmpty,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: repoUrl));
                    if (!mounted) return;
                    Navigator.of(sheetContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Repo link copied')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);
    final accent = _polishAccentColor(_iconColor);
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
              SliverToBoxAdapter(child: _Header(app: widget.app)),
              SliverToBoxAdapter(child: _MetadataRow(app: widget.app)),
              SliverToBoxAdapter(child: _InstallButton(app: widget.app)),
              SliverToBoxAdapter(child: _RateButton(app: widget.app)),
              SliverToBoxAdapter(child: _PreviewSection(app: widget.app)),
              SliverToBoxAdapter(child: _AboutSection(app: widget.app)),
              SliverToBoxAdapter(child: _TrustSection(app: widget.app)),
              SliverToBoxAdapter(child: _TechnicalSection(app: widget.app)),
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
          color: colors.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
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

class _Header extends StatelessWidget {
  const _Header({required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LargeIcon(iconUrl: app.iconUrl),
          const SizedBox(width: 18),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      height: 1.08,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    app.packageName,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: colors.textSoft,
                    ),
                  ),
                  const SizedBox(height: 4),
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
          ),
        ],
      ),
    );
  }
}

class _LargeIcon extends StatelessWidget {
  const _LargeIcon({required this.iconUrl});

  final String iconUrl;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        color: colors.iconBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: iconUrl.isEmpty
          ? null
          : Image.network(
              iconUrl,
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

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);
    final version = app.latestVersion;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      child: Row(
        children: [
          Expanded(
            child: _MetaItem(
              top: app.ratingCount > 0 ? '${app.displayRating} ★' : '—',
              bottom: 'Rating',
            ),
          ),
          const _DividerLine(),
          Expanded(
            child: _MetaItem(
              top: version?.versionName ?? 'None',
              bottom: 'Version',
            ),
          ),
          const _DividerLine(),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: app.repoUrl.isEmpty
                  ? null
                  : () async {
                      final uri = Uri.tryParse(app.repoUrl);
                      if (uri == null) return;
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
              child: SizedBox(
                height: 48,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.code_rounded,
                      size: 22,
                      color: colors.text,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Repo',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.top, required this.bottom});

  final String top;
  final String bottom;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return SizedBox(
      height: 48,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            top,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bottom,
            style: TextStyle(
              fontSize: 11,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Container(
      width: 1,
      height: 30,
      color: colors.border,
    );
  }
}

class _InstallButton extends StatefulWidget {
  const _InstallButton({required this.app});

  final PublicStoreApp app;

  @override
  State<_InstallButton> createState() => _InstallButtonState();
}

class _InstallButtonState extends State<_InstallButton> {
  bool _installing = false;
  double _progress = 0;

  Future<void> _install() async {
    if (_installing) return;

    setState(() {
      _installing = true;
      _progress = 0;
    });

    try {
      await ApkInstallService.instance.downloadAndInstall(
        app: widget.app,
        onProgress: (value) {
          if (!mounted) return;
          setState(() => _progress = value.clamp(0, 1));
        },
      );
    } on PlatformException catch (e) {
      if (!mounted) return;

      final message = e.code == 'install_permission_required'
          ? 'Allow SafeHaven to install apps, then tap Install again.'
          : 'Could not start the installer.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Install failed: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);
    final hasVersion = widget.app.latestVersion != null;
    final percent = (_progress * 100).clamp(0, 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: hasVersion ? colors.accentGradient : null,
            color: hasVersion ? null : colors.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasVersion ? Colors.transparent : colors.border,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: hasVersion && !_installing ? _install : null,
              child: Center(
                child: Text(
                  !hasVersion
                      ? 'No live APK yet'
                      : _installing
                          ? 'Downloading $percent%'
                          : 'Install',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: hasVersion ? colors.buttonText : colors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RateButton extends StatelessWidget {
  const _RateButton({required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton(
          onPressed: () => RatingSheet.show(context, app),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.text,
            side: BorderSide(color: colors.border),
            backgroundColor: colors.surface.withOpacity(
              SafeHavenThemeManager.instance.isDark ? 0.55 : 0.72,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.star_outline_rounded,
                size: 18,
                color: colors.accentEnd,
              ),
              const SizedBox(width: 8),
              Text(
                app.ratingCount > 0
                    ? 'Rate · ${app.displayRating} ★'
                    : 'Rate this app',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);
    final shots = app.screenshots
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (shots.isEmpty) {
      return const SizedBox.shrink();
    }

    return _Section(
      title: 'Preview',
      child: SizedBox(
        height: 220,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          itemCount: shots.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            return Container(
              width: 118,
              decoration: BoxDecoration(
                color: colors.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                shots[index],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                loadingBuilder: (_, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.app});

  final PublicStoreApp app;

  String get _aboutText {
    final description = app.description.trim();
    if (description.isNotEmpty) return description;
    return app.displaySummary.trim();
  }

  void _showFull(BuildContext context) {
    final colors = SafeHavenTheme.of(context);
    final aboutText = _aboutText;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.35,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'About this app',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 16),
            MarkdownBody(
              data: aboutText.isNotEmpty
                  ? aboutText
                  : 'No description provided.',
              selectable: true,
              styleSheet: _markdownStyle(context),
              onTapLink: (_, href, __) async {
                if (href == null || href.trim().isEmpty) return;
                final uri = Uri.tryParse(href.trim());
                if (uri == null) return;
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);
    final aboutText = _aboutText;

    return _Section(
      title: 'About this app',
      onHeaderTap: () => _showFull(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Text(
          aboutText.isNotEmpty ? aboutText : 'No description provided.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: colors.textSoft,
          ),
        ),
      ),
    );
  }
}

class _TrustSection extends StatelessWidget {
  const _TrustSection({required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return _Section(
      title: 'Security signals',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          children: [
            _SignalRow(
              icon: app.hasTrustBadge
                  ? Icons.verified_rounded
                  : Icons.info_outline_rounded,
              title: app.trustLabel,
              body: app.trustDescription,
              color: app.hasTrustBadge ? colors.accentEnd : colors.textMuted,
            ),
            _SignalRow(
              icon: Icons.fingerprint_rounded,
              title: 'Verified signature',
              body: 'Updates are verified against the original developer signature.',
              color: colors.textMuted,
            ),
            _SignalRow(
              icon: Icons.manage_search_rounded,
              title: 'Latest scan',
              body: app.latestVersion == null || app.latestVersion!.scannedAt == 0
                  ? 'No completed scan timestamp is available yet.'
                  : 'No threats detected. Last scanned ${_formatScannedAt(app.latestVersion!.scannedAt)}.',
              color: colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _TechnicalSection extends StatelessWidget {
  const _TechnicalSection({required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    final version = app.latestVersion;

    return _Section(
      title: 'App info',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          children: [
            _InfoRow(label: 'Package', value: app.packageName),
            _InfoRow(
              label: 'Repository',
              value: app.repoUrl.isEmpty ? 'Not provided' : app.repoUrl,
            ),
            _InfoRow(
              label: 'SHA-256',
              value: version == null || version.sha256.isEmpty
                  ? 'Not available'
                  : version.sha256,
            ),
            _InfoRow(
              label: 'APK size',
              value: version == null || version.apkSize == 0
                  ? 'Not available'
                  : _formatBytes(version.apkSize),
            ),
            _InfoRow(
              label: 'Last scanned',
              value: version == null || version.scannedAt == 0
                  ? 'Not available'
                  : _formatScannedAt(version.scannedAt),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: colors.textSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: colors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: colors.textSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.onHeaderTap,
  });

  final String title;
  final Widget child;
  final VoidCallback? onHeaderTap;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onHeaderTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
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
                    color: onHeaderTap != null
                        ? colors.textSoft
                        : colors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

LinearGradient _screenGradient(Color iconColor) {
  final accent = _polishAccentColor(iconColor);
  final glow = _shiftHue(accent, 10);

  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      glow.withOpacity(0.58),
      accent.withOpacity(0.26),
      const Color(0xFF08090C),
      const Color(0xFF0A0D14),
      accent.withOpacity(0.16),
    ],
    stops: const [0.0, 0.22, 0.48, 0.74, 1.0],
  );
}

Color _polishAccentColor(Color color) {
  final hsl = HSLColor.fromColor(color);

  final saturation = hsl.saturation < 0.18
      ? 0.34
      : hsl.saturation.clamp(0.34, 0.72);

  final lightness = hsl.lightness.clamp(0.22, 0.42);

  return hsl
      .withSaturation(saturation)
      .withLightness(lightness)
      .toColor();
}

Color _shiftHue(Color color, double degrees) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withHue((hsl.hue + degrees) % 360).toColor();
}

Future<Color?> _extractImageColor(String iconUrl) async {
  if (iconUrl.isEmpty) return null;

  try {
    final image = await _loadUiImage(iconUrl);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      image.dispose();
      return null;
    }

    final bytes = byteData.buffer.asUint8List();
    final pixelCount = image.width * image.height;

    if (pixelCount == 0) {
      image.dispose();
      return null;
    }

    final buckets = <int, double>{};

    for (var i = 0; i < pixelCount; i += 8) {
      final offset = i * 4;
      if (offset + 3 >= bytes.length) continue;

      final alpha = bytes[offset + 3];
      if (alpha < 180) continue;

      final r = bytes[offset];
      final g = bytes[offset + 1];
      final b = bytes[offset + 2];

      final hsl = HSLColor.fromColor(Color.fromARGB(255, r, g, b));
      final saturation = hsl.saturation;
      final lightness = hsl.lightness;

      if (lightness < 0.08 || lightness > 0.92) continue;

      final vividness = saturation * (1 - (lightness - 0.5).abs());
      if (vividness < 0.08) continue;

      final qr = (r ~/ 24) * 24;
      final qg = (g ~/ 24) * 24;
      final qb = (b ~/ 24) * 24;
      final key = (qr << 16) | (qg << 8) | qb;

      final weight = 1 + vividness * 4;
      buckets[key] = (buckets[key] ?? 0) + weight;
    }

    image.dispose();

    if (buckets.isEmpty) return null;

    final best = buckets.entries.reduce(
          (a, b) => a.value >= b.value ? a : b,
    );

    return Color.fromARGB(
      255,
      (best.key >> 16) & 0xFF,
      (best.key >> 8) & 0xFF,
      best.key & 0xFF,
    );
  } catch (_) {
    return null;
  }
}

Future<ui.Image> _loadUiImage(String url) {
  final completer = Completer<ui.Image>();
  final provider = NetworkImage(url);
  late final ImageStreamListener listener;
  final stream = provider.resolve(ImageConfiguration.empty);

  listener = ImageStreamListener(
        (imageInfo, _) {
      stream.removeListener(listener);
      completer.complete(imageInfo.image);
    },
    onError: (Object error, StackTrace? stackTrace) {
      stream.removeListener(listener);
      completer.completeError(error, stackTrace);
    },
  );

  stream.addListener(listener);
  return completer.future;
}

MarkdownStyleSheet _markdownStyle(BuildContext context) {
  final colors = SafeHavenTheme.of(context);

  return MarkdownStyleSheet(
    p: TextStyle(
      fontSize: 14,
      height: 1.55,
      color: colors.textSoft,
    ),
    h1: TextStyle(
      fontSize: 22,
      height: 1.2,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      color: colors.text,
    ),
    h2: TextStyle(
      fontSize: 19,
      height: 1.25,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      color: colors.text,
    ),
    h3: TextStyle(
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w800,
      color: colors.text,
    ),
    strong: TextStyle(
      fontWeight: FontWeight.w800,
      color: colors.text,
    ),
    em: TextStyle(
      fontStyle: FontStyle.italic,
      color: colors.textSoft,
    ),
    a: TextStyle(
      fontWeight: FontWeight.w700,
      color: colors.accentEnd,
    ),
    code: TextStyle(
      fontSize: 13,
      color: colors.text,
      backgroundColor: colors.surfaceSoft,
    ),
    blockquote: TextStyle(
      fontSize: 14,
      height: 1.5,
      color: colors.textSoft,
    ),
    listBullet: TextStyle(
      fontSize: 14,
      color: colors.textSoft,
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: colors.border),
      ),
    ),
  );
}

String _formatScannedAt(int value) {
  if (value <= 0) return 'Not available';

  final scannedAt = DateTime.fromMillisecondsSinceEpoch(value * 1000);
  final diff = DateTime.now().difference(scannedAt);

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  return '${scannedAt.day.toString().padLeft(2, '0')}/'
      '${scannedAt.month.toString().padLeft(2, '0')}/'
      '${scannedAt.year}';
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return 'Not available';
  const kb = 1024;
  const mb = kb * 1024;
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
  return '$bytes B';
}
