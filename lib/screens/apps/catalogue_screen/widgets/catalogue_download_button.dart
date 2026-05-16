import 'package:flutter/material.dart';
import '../../../../services/store_service.dart';
import '../../../../services/theme/theme_manager.dart';
import '../../../../services/installer/apk_install_service.dart';
import '../../../../widgets/animated_tap.dart';

enum CatalogueDlState { checking, idle, downloading, cancelling, done }

class CatalogueDownloadButton extends StatefulWidget {
  const CatalogueDownloadButton({required this.app});

  final PublicStoreApp app;

  @override
  State<CatalogueDownloadButton> createState() => _CatalogueDownloadButtonState();
}

class _CatalogueDownloadButtonState extends State<CatalogueDownloadButton>
    with WidgetsBindingObserver {
  CatalogueDlState _state = CatalogueDlState.checking;
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
    if (state == AppLifecycleState.resumed && _state == CatalogueDlState.done) {
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
        _state = pkg.installed ? CatalogueDlState.done : CatalogueDlState.idle;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = CatalogueDlState.idle);
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _state = CatalogueDlState.downloading;
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
      setState(() => _state = CatalogueDlState.done);
    } catch (_) {
      if (!mounted) return;
      if (_cancelling) {
        await Future.delayed(const Duration(milliseconds: 500));
        _cancelling = false;
        if (!mounted) return;
      }
      setState(() => _state = CatalogueDlState.idle);
    }
  }

  Future<void> _cancelDownload() async {
    if (_state != CatalogueDlState.downloading) return;
    _cancelling = true;
    setState(() => _state = CatalogueDlState.cancelling);
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

    if (_state == CatalogueDlState.checking) {
      return const SizedBox(width: 44);
    }

    Widget content;
    VoidCallback? onTap;

    switch (_state) {
      case CatalogueDlState.idle:
        content = Icon(
          Icons.download_rounded,
          size: 20,
          color: colors.textMuted,
        );
        onTap = _startDownload;
      case CatalogueDlState.downloading:
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
      case CatalogueDlState.cancelling:
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
      case CatalogueDlState.done:
        content = Text(
          'Open',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        );
        onTap = _open;
      case CatalogueDlState.checking:
        content = const SizedBox.shrink();
        onTap = null;
    }

    return AnimatedTap(
      borderRadius: 12,
      scale: 0.94,
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
