import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/index_service.dart';
import '../../services/store_service.dart';

class DeveloperAccountScreen extends StatefulWidget {
  const DeveloperAccountScreen({super.key});

  @override
  State<DeveloperAccountScreen> createState() => _DeveloperAccountScreenState();
}

class _DeveloperAccountScreenState extends State<DeveloperAccountScreen> {
  final StoreService _service = StoreService.instance;
  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _linkSub;

  bool _loading = true;
  bool _openingLogin = false;
  bool _openingDashboard = false;
  String? _error;
  StoreAccount? _account;
  List<DeveloperStoreApp> _apps = const [];
  Map<String, PublicStoreApp> _publicApps = const {};

  @override
  void initState() {
    super.initState();
    _listenForAuthLinks();
    _load();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  void _listenForAuthLinks() {
    _linkSub = _appLinks.uriLinkStream.listen(
          (uri) async {
        if (uri.scheme != 'safehaven') return;
        if (uri.host != 'auth') return;
        setState(() { _loading = true; _error = null; });
        try {
          await _service.saveTokenFromAuthUri(uri);
          await _load();
        } catch (e) {
          setState(() { _loading = false; _error = e.toString(); });
        }
      },
      onError: (Object e) => setState(() => _error = e.toString()),
    );
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = await _service.getToken();
      if (token == null) {
        setState(() { _account = null; _apps = const []; _loading = false; });
        return;
      }

      final results = await Future.wait([
        _service.fetchMe(),
        IndexService.instance.fetchIndex(),
      ]);

      final account = results[0] as StoreAccount;
      final index = results[1] as StoreIndex;
      final apps = account.developerEnabled
          ? await _service.fetchDeveloperApps()
          : <DeveloperStoreApp>[];

      setState(() {
        _account = account;
        _apps = apps;
        _publicApps = { for (final a in index.apps) a.packageName: a };
        _loading = false;
      });
    } catch (e) {
      setState(() { _account = null; _apps = const []; _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _login() async {
    setState(() { _openingLogin = true; _error = null; });
    try {
      final ok = await launchUrl(_service.loginUri(), mode: LaunchMode.externalApplication);
      if (!ok) setState(() => _error = 'Could not open login page.');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _openingLogin = false);
    }
  }

  Future<void> _openDashboard() async {
    setState(() { _openingDashboard = true; _error = null; });
    try {
      final uri = await _service.dashboardUri();
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) setState(() => _error = 'Could not open dashboard.');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _openingDashboard = false);
    }
  }

  Future<void> _logout() async {
    await _service.clearToken();
    setState(() { _account = null; _apps = const []; _error = null; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090C),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFF08090C),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Account',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.2),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _AccountBlock(
              account: _account,
              openingLogin: _openingLogin,
              openingDashboard: _openingDashboard,
              onLogin: _login,
              onDashboard: _openDashboard,
              onLogout: _logout,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFFFCA5A5)),
                ),
              ),
            if (_account != null) ...[
              const _SectionLabel(text: 'Developer apps'),
              if (!_account!.developerEnabled)
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: Text(
                    'Developer access is not enabled. Open the dashboard to agree to the developer terms.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9EA3AD), height: 1.4),
                  ),
                )
              else if (_apps.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: Text(
                    'No apps registered yet. Open the dashboard to register your first app.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9EA3AD), height: 1.4),
                  ),
                )
              else
                ..._apps.map((app) => _AppEntry(
                  app: app,
                  publicApp: _publicApps[app.packageName],
                )),
              const SizedBox(height: 28),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountBlock extends StatelessWidget {
  const _AccountBlock({
    required this.account,
    required this.openingLogin,
    required this.openingDashboard,
    required this.onLogin,
    required this.onDashboard,
    required this.onLogout,
  });

  final StoreAccount? account;
  final bool openingLogin;
  final bool openingDashboard;
  final VoidCallback onLogin;
  final VoidCallback onDashboard;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    if (account == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 32, 18, 28),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFF1C2028),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline_rounded, size: 30, color: Color(0xFF9EA3AD)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Not signed in',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sign in with your ColourSwift account to manage your developer apps.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF9EA3AD), height: 1.4),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: openingLogin ? null : onLogin,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: const Color(0xFF252A33),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(openingLogin ? 'Opening...' : 'Sign in with browser'),
              ),
            ),
          ],
        ),
      );
    }

    final label = account!.displayName.isNotEmpty ? account!.displayName : account!.email;
    final initial = label.substring(0, 1).toUpperCase();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 32, 18, 20),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFF1C2028),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              if (account!.email.isNotEmpty && account!.displayName.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  account!.email,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF9EA3AD)),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: openingDashboard ? null : onDashboard,
                        icon: const Icon(Icons.open_in_browser_rounded, size: 17),
                        label: Text(openingDashboard ? 'Opening...' : 'Dashboard'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2A2F38)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 42,
                    child: OutlinedButton(
                      onPressed: onLogout,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2A2F38)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Sign out'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFF1C2028), height: 1),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry({required this.app, required this.publicApp});

  final DeveloperStoreApp app;
  final PublicStoreApp? publicApp;

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  final StoreService _service = StoreService.instance;

  bool _expanded = false;
  bool _loading = false;
  String? _error;
  DeveloperAppDetail? _detail;

  Future<void> _loadDetail() async {
    setState(() { _loading = true; _error = null; });
    try {
      final detail = await _service.fetchDeveloperApp(widget.app.id);
      setState(() { _detail = detail; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final pub = widget.publicApp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          onTap: () {
            setState(() => _expanded = !_expanded);
            if (_expanded && _detail == null) _loadDetail();
          },
          leading: _AppIcon(iconUrl: pub?.iconUrl ?? '', size: 42),
          title: Text(
            app.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${app.packageName} · ${app.statusLabel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9EA3AD)),
          ),
          trailing: Icon(
            _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: const Color(0xFF9EA3AD),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: _loading
                ? const LinearProgressIndicator(
              color: Colors.white,
              backgroundColor: Color(0xFF1C2028),
            )
                : _error != null
                ? Text(
              _error!,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFFCA5A5)),
            )
                : _detail != null
                ? _AppDetail(app: app, detail: _detail!, publicApp: pub)
                : const SizedBox.shrink(),
          ),
        const Divider(color: Color(0xFF1C2028), height: 1),
      ],
    );
  }
}

class _AppDetail extends StatelessWidget {
  const _AppDetail({required this.app, required this.detail, required this.publicApp});

  final DeveloperStoreApp app;
  final DeveloperAppDetail detail;
  final PublicStoreApp? publicApp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailRow(label: 'Repository', value: app.repoUrl.isEmpty ? '—' : app.repoUrl),
        _DetailRow(label: 'Repo verified', value: app.repoVerified ? 'Yes' : 'Not yet'),
        _DetailRow(
          label: 'Signing key',
          value: app.signingKeyHash.isEmpty ? 'Not locked yet' : app.signingKeyHash,
        ),
        if (publicApp != null && publicApp!.ratingCount > 0)
          _DetailRow(
            label: 'Rating',
            value: '${publicApp!.displayRating} ★ (${publicApp!.ratingCount})',
          ),
        if (detail.submissions.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Submissions',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...detail.submissions.map((s) => _SubmissionRow(submission: s)),
        ],
      ],
    );
  }
}

class _SubmissionRow extends StatelessWidget {
  const _SubmissionRow({required this.submission});

  final StoreSubmission submission;

  @override
  Widget build(BuildContext context) {
    final live = submission.status == 'live';
    final rejected = submission.status == 'rejected';

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              submission.versionName.isEmpty ? 'Version' : 'v${submission.versionName}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            submission.statusLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: live
                  ? const Color(0xFF86EFAC)
                  : rejected
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFF9EA3AD),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9EA3AD)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: Color(0xFFD5D8DF), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.iconUrl, required this.size});

  final String iconUrl;
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
      clipBehavior: Clip.antiAlias,
      child: iconUrl.isEmpty
          ? const Icon(Icons.android_rounded, size: 20, color: Color(0xFF4A4F5A))
          : Image.network(
        iconUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
        const Icon(Icons.android_rounded, size: 20, color: Color(0xFF4A4F5A)),
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const SizedBox.shrink();
        },
      ),
    );
  }
}