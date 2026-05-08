import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/installer/apk_install_service.dart';
import '../../../services/store_service.dart';
import '../../../services/theme/theme_manager.dart';
import '../../../widgets/ratings/rating_sheet.dart';
import 'app_screen_helpers.dart';
import '../../../services/installer/store_update_service.dart';

class AppScreenHeader extends StatelessWidget {
  const AppScreenHeader({super.key, required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppScreenLargeIcon(iconUrl: app.iconUrl),
          const SizedBox(width: 18),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      height: 1.08,
                      color: colors.text,
                    ),
                  ),
                  if (app.developerName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      app.developerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colors.accentEnd,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppScreenLargeIcon extends StatelessWidget {
  const AppScreenLargeIcon({super.key, required this.iconUrl});

  final String? iconUrl;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);
    final url = iconUrl?.trim();

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: colors.iconBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url.isEmpty
          ? null
          : Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: 240,
        cacheHeight: 240,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class AppScreenMetadataRow extends StatelessWidget {
  const AppScreenMetadataRow({super.key, required this.app});

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
                height: 56,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.code_rounded,
                      size: 24,
                      color: colors.text,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Repo',
                      style: TextStyle(
                        fontSize: 12,
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
      height: 56,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            top,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bottom,
            style: TextStyle(
              fontSize: 12,
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

class AppScreenInstallButton extends StatefulWidget {
  const AppScreenInstallButton({super.key, required this.app});

  final PublicStoreApp app;

  @override
  State<AppScreenInstallButton> createState() => _AppScreenInstallButtonState();
}

class _AppScreenInstallButtonState extends State<AppScreenInstallButton>
    with WidgetsBindingObserver {
  bool _installing = false;
  bool _paused = false;
  bool _checkingPackage = true;
  double _progress = 0;
  double _lastPaintedProgress = -1;
  int _packageCheckRequestId = 0;
  StoreUpdateCheck? _updateCheck;

  bool get _hasVersion => widget.app.versions.isNotEmpty;

  bool get _installed => _updateCheck?.installed ?? false;

  bool get _hasUpdate => _updateCheck?.canUpdate ?? false;

  StoreVersion? get _latestVersion => _updateCheck?.latestVersion;

  String get _primaryLabel {
    if (!_hasVersion) return 'No live APK yet';
    if (_installing) return _paused ? 'Paused' : 'Downloading $_percent%';
    if (_checkingPackage) return 'Checking';

    switch (_updateCheck?.status) {
      case StoreUpdateStatus.notInstalled:
        return 'Install';
      case StoreUpdateStatus.updateAvailable:
        return 'Update';
      case StoreUpdateStatus.current:
      case StoreUpdateStatus.installedNewerThanStore:
        return 'Open';
      case StoreUpdateStatus.missingStoreVersion:
      case null:
        return 'Unavailable';
    }
  }

  int get _percent => (_progress * 100).clamp(0, 100).round();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPackageState(showChecking: true);
  }

  @override
  void didUpdateWidget(covariant AppScreenInstallButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.app.packageName != widget.app.packageName ||
        oldWidget.app.latestVersion?.versionCode !=
            widget.app.latestVersion?.versionCode) {
      _loadPackageState();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPackageState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadPackageState({bool showChecking = false}) async {
    final requestId = ++_packageCheckRequestId;

    if (showChecking && mounted) {
      setState(() => _checkingPackage = true);
    }

    try {
      final check = await StoreUpdateService.instance.checkApp(widget.app);

      if (!mounted || requestId != _packageCheckRequestId) return;

      final oldCheck = _updateCheck;
      final changed = oldCheck == null ||
          oldCheck.status != check.status ||
          oldCheck.installedVersionCode != check.installedVersionCode ||
          oldCheck.installedVersionName != check.installedVersionName ||
          oldCheck.latestVersionCode != check.latestVersionCode ||
          _checkingPackage;

      if (!changed) return;

      setState(() {
        _updateCheck = check;
        _checkingPackage = false;
      });
    } catch (_) {
      if (!mounted || requestId != _packageCheckRequestId) return;

      if (_checkingPackage) {
        setState(() => _checkingPackage = false);
      }
    }
  }

  Future<void> _primaryAction() async {
    if (!_hasVersion || _installing || _checkingPackage) return;

    final status = _updateCheck?.status;

    if (status == StoreUpdateStatus.current ||
        status == StoreUpdateStatus.installedNewerThanStore) {
      await _openInstalledApp();
      return;
    }

    if (status == StoreUpdateStatus.notInstalled ||
        status == StoreUpdateStatus.updateAvailable) {
      await _install();
    }
  }

  Future<void> _openInstalledApp() async {
    try {
      await ApkInstallService.instance.openApp(
        packageName: widget.app.packageName,
      );
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this app.')),
      );
    }
  }

  Future<void> _uninstall() async {
    try {
      await ApkInstallService.instance.uninstallApp(
        packageName: widget.app.packageName,
      );

      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        _loadPackageState();
      });

      Future<void>.delayed(const Duration(milliseconds: 1600), () {
        if (!mounted) return;
        _loadPackageState();
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
    }
  }

  Future<void> _install() async {
    final version = _latestVersion ?? widget.app.latestVersion;
    if (version == null) return;

    setState(() {
      _installing = true;
      _paused = false;
      _progress = 0;
      _lastPaintedProgress = -1;
    });

    try {
      await ApkInstallService.instance.downloadAndInstall(
        app: widget.app,
        onProgress: (value) {
          if (!mounted) return;

          final nextProgress = value.clamp(0, 1).toDouble();
          final changedEnough =
              (nextProgress - _lastPaintedProgress).abs() >= 0.01 ||
                  nextProgress == 0 ||
                  nextProgress == 1;

          if (!changedEnough) return;

          _lastPaintedProgress = nextProgress;
          setState(() => _progress = nextProgress);
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

      final errorText = e.toString();
      if (errorText.contains('download_cancelled')) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Install failed: $e')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _installing = false;
        _paused = false;
      });

      await _loadPackageState();
    }
  }

  Future<void> _togglePause() async {
    if (!_installing) return;

    if (_paused) {
      await ApkInstallService.instance.resumeDownload();
      if (!mounted) return;
      setState(() => _paused = false);
    } else {
      await ApkInstallService.instance.pauseDownload();
      if (!mounted) return;
      setState(() => _paused = true);
    }
  }

  Future<void> _cancelDownload() async {
    if (!_installing) return;

    setState(() {
      _installing = false;
      _paused = false;
      _progress = 0;
      _lastPaintedProgress = -1;
    });

    try {
      await ApkInstallService.instance.cancelDownload();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);
    final primaryEnabled = _hasVersion && !_installing && !_checkingPackage;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _hasVersion ? colors.accentGradient : null,
                      color: _hasVersion ? null : colors.surfaceSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hasVersion ? Colors.transparent : colors.border,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: primaryEnabled ? _primaryAction : null,
                        child: Center(
                          child: Text(
                            _primaryLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _hasVersion
                                  ? colors.buttonText
                                  : colors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_installed && !_installing) ...[
                const SizedBox(width: 10),
                _InstallIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Uninstall',
                  onTap: _uninstall,
                ),
              ],
            ],
          ),
          if (_installing) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 3,
                      backgroundColor: colors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.accentEnd,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _InstallMiniButton(
                  icon: _paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  tooltip: _paused ? 'Resume' : 'Pause',
                  onTap: _togglePause,
                ),
                const SizedBox(width: 4),
                _InstallMiniButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Cancel',
                  onTap: _cancelDownload,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InstallIconButton extends StatelessWidget {
  const _InstallIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);
    const danger = Color(0xFFE85D75);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: danger.withOpacity(
              SafeHavenThemeManager.instance.isDark ? 0.13 : 0.09,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: danger.withOpacity(
                SafeHavenThemeManager.instance.isDark ? 0.24 : 0.18,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: danger.withOpacity(
                  SafeHavenThemeManager.instance.isDark ? 0.12 : 0.08,
                ),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 22,
            color: danger.withOpacity(0.92),
          ),
        ),
      ),
    );
  }
}

class _InstallMiniButton extends StatelessWidget {
  const _InstallMiniButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: 18,
          containedInkWell: false,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: Icon(
                icon,
                size: 20,
                color: colors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppScreenRateButton extends StatelessWidget {
  const AppScreenRateButton({super.key, required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Column(
        children: [
          Text(
            'Rate this app',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tell others what you think',
            style: TextStyle(
              fontSize: 13,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => AppAccentDialog(
                    child: RatingSheet(app: app),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.star_outline_rounded,
                    size: 38,
                    color: colors.textMuted,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class AppScreenPreviewSection extends StatelessWidget {
  const AppScreenPreviewSection({super.key, required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);
    final shots = app.screenshots
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);

    if (shots.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppScreenSection(
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
                cacheWidth: 360,
                cacheHeight: 680,
                filterQuality: FilterQuality.medium,
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

class AppScreenAboutSection extends StatelessWidget {
  const AppScreenAboutSection({super.key, required this.app});

  final PublicStoreApp app;

  String _normalize(String s) => s
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\r', '')
      .trim();

  String get _shortText {
    final summary = _normalize(app.summary);
    if (summary.isNotEmpty) return summary;

    return 'No short description provided.';
  }

  String get _fullText {
    final description = _normalize(app.description);
    if (description.isNotEmpty) return description;

    final summary = _normalize(app.summary);
    if (summary.isNotEmpty) return summary;

    return '';
  }

  void _showFull(BuildContext context) {
    final colors = SafeHavenTheme.of(context);
    final fullText = _fullText;

    showDialog(
      context: context,
      builder: (_) => AppAccentDialog(
        maxWidth: 400,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Text(
                  'About this app',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: colors.text,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: MarkdownBody(
                    data: fullText.isNotEmpty
                        ? fullText
                        : 'No description provided.',
                    selectable: true,
                    softLineBreak: true,
                    styleSheet: markdownStyle(context),
                    onTapLink: (_, href, __) async {
                      if (href == null || href.trim().isEmpty) return;

                      final uri = Uri.tryParse(href.trim());
                      if (uri == null) return;

                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                ),
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
    final shortText = _shortText;

    return AppScreenSection(
      title: 'About this app',
      onHeaderTap: () => _showFull(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Text(
          shortText,
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

class AppScreenTrustSection extends StatelessWidget {
  const AppScreenTrustSection({super.key, required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return AppScreenSection(
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
            const _SignalRow(
              icon: Icons.fingerprint_rounded,
              title: 'Verified signature',
              body: 'Updates are verified against the original developer signature.',
              color: null,
            ),
            _SignalRow(
              icon: Icons.manage_search_rounded,
              title: 'Latest scan',
              body: app.latestVersion == null || app.latestVersion!.scannedAt == 0
                  ? 'No completed scan timestamp is available yet.'
                  : 'No threats detected. Last scanned ${formatScannedAt(app.latestVersion!.scannedAt)}.',
              color: null,
            ),
          ],
        ),
      ),
    );
  }
}

class AppScreenTechnicalSection extends StatelessWidget {
  const AppScreenTechnicalSection({super.key, required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    final version = app.latestVersion;

    return AppScreenExpandableSection(
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
                  : formatBytes(version.apkSize),
            ),
            _InfoRow(
              label: 'Last scanned',
              value: version == null || version.scannedAt == 0
                  ? 'Not available'
                  : formatScannedAt(version.scannedAt),
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
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color ?? colors.textMuted),
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

class AppScreenExpandableSection extends StatefulWidget {
  const AppScreenExpandableSection({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<AppScreenExpandableSection> createState() =>
      _AppScreenExpandableSectionState();
}

class _AppScreenExpandableSectionState extends State<AppScreenExpandableSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant AppScreenExpandableSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      _expanded = widget.initiallyExpanded;
    }
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: colors.text,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: colors.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class AppScreenSection extends StatelessWidget {
  const AppScreenSection({
    super.key,
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
                  if (onHeaderTap != null)
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: colors.textSoft,
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