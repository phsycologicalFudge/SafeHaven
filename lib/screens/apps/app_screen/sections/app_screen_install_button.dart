import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../services/installer/apk_install_service.dart';
import '../../../../services/installer/store_update_service.dart';
import '../../../../services/store_service.dart';
import '../../../../services/theme/theme_manager.dart';

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

      print('[DEBUG] ${widget.app.packageName} | '
          'installed: ${check.installed} | '
          'deviceVC: ${check.installedVersionCode} | '
          'storeVC: ${check.latestVersionCode} | '
          'status: ${check.status}');

      final oldCheck = _updateCheck;

      final installedChanged = (oldCheck?.installed ?? false) != check.installed;

      final changed = installedChanged ||
          oldCheck == null ||
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

      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        await _loadPackageState();
      }
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
    final isDark = SafeHavenThemeManager.instance.isDark;
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
                  child: Opacity(

                    opacity: isDark && _hasVersion ? 0.82 : 1.0,
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
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
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
    final isDark = SafeHavenThemeManager.instance.isDark;
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
            color: isDark ? Colors.transparent : danger.withOpacity(0.09),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: danger.withOpacity(isDark ? 0.15 : 0.18),
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: danger.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Icon(
            icon,
            size: 22,
            color: danger.withOpacity(isDark ? 0.75 : 0.92),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surfaceSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: colors.textMuted,
          ),
        ),
      ),
    );
  }
}