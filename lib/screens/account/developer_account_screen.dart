import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

        setState(() {
          _loading = true;
          _error = null;
        });

        try {
          await _service.saveTokenFromAuthUri(uri);
          await _load();
        } catch (e) {
          setState(() {
            _loading = false;
            _error = e.toString();
          });
        }
      },
      onError: (Object e) {
        setState(() => _error = e.toString());
      },
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _service.getToken();
      if (token == null) {
        setState(() {
          _account = null;
          _apps = const [];
          _loading = false;
        });
        return;
      }

      final account = await _service.fetchMe();
      final apps = account.developerEnabled
          ? await _service.fetchDeveloperApps()
          : <DeveloperStoreApp>[];

      setState(() {
        _account = account;
        _apps = apps;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _account = null;
        _apps = const [];
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _login() async {
    setState(() {
      _openingLogin = true;
      _error = null;
    });

    try {
      final ok = await launchUrl(
        _service.loginUri(),
        mode: LaunchMode.externalApplication,
      );

      if (!ok) {
        setState(() => _error = 'Could not open login page.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _openingLogin = false);
      }
    }
  }

  Future<void> _openDashboard() async {
    setState(() {
      _openingDashboard = true;
      _error = null;
    });

    try {
      final uri = await _service.dashboardUri();
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!ok) {
        setState(() => _error = 'Could not open dashboard.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _openingDashboard = false);
      }
    }
  }

  Future<void> _logout() async {
    await _service.clearToken();
    setState(() {
      _account = null;
      _apps = const [];
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final loggedIn = _account != null;
    final developerEnabled = _account?.developerEnabled == true;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          _DeveloperHeader(
            account: _account,
            openingLogin: _openingLogin,
            openingDashboard: _openingDashboard,
            onLogin: _login,
            onDashboard: loggedIn ? _openDashboard : null,
            onLogout: loggedIn ? _logout : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _MessagePanel(message: _error!, error: true),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Developer apps',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              IconButton(
                onPressed: loggedIn ? _load : null,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!loggedIn)
            const _EmptyDeveloperState(
              text: 'Sign in to view developer apps.',
            )
          else if (!developerEnabled)
            _DashboardOnlyState(
              title: 'Developer access is not enabled',
              text: 'Open the dashboard, agree to the developer terms, then refresh this page.',
              onOpenDashboard: _openDashboard,
            )
          else if (_apps.isEmpty)
              _DashboardOnlyState(
                title: 'No apps registered yet',
                text: 'Open the dashboard to register your first app.',
                onOpenDashboard: _openDashboard,
              )
            else
              ..._apps.map((app) => _DeveloperAppCard(app: app)),
        ],
      ),
    );
  }
}

class _DeveloperHeader extends StatelessWidget {
  const _DeveloperHeader({
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
  final VoidCallback? onDashboard;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final loggedIn = account != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF11141A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF222734)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Developer account',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            loggedIn
                ? account!.email.isEmpty
                ? account!.displayName
                : account!.email
                : 'Sign in with your ColourSwift account to view your developer apps.',
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF9EA3AD),
              height: 1.35,
            ),
          ),
          if (loggedIn) ...[
            const SizedBox(height: 10),
            _StatusLine(
              label: account!.developerEnabled ? 'Developer enabled' : 'Developer not enabled',
              good: account!.developerEnabled,
            ),
          ],
          const SizedBox(height: 16),
          if (!loggedIn)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: openingLogin ? null : onLogin,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: const Color(0xFF252A33),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(openingLogin ? 'Opening...' : 'Sign in with browser'),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: openingDashboard ? null : onDashboard,
                    icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                    label: Text(openingDashboard ? 'Opening...' : 'Open dashboard'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: const Color(0xFF252A33),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: onLogout,
                  child: const Text('Logout'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DeveloperAppCard extends StatefulWidget {
  const _DeveloperAppCard({required this.app});

  final DeveloperStoreApp app;

  @override
  State<_DeveloperAppCard> createState() => _DeveloperAppCardState();
}

class _DeveloperAppCardState extends State<_DeveloperAppCard> {
  final StoreService _service = StoreService.instance;

  bool _expanded = false;
  bool _loading = false;
  String? _message;
  DeveloperAppDetail? _detail;

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final detail = await _service.fetchDeveloperApp(widget.app.id);
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _message = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF11141A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF222734)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() => _expanded = !_expanded);
              if (!_expanded || _detail != null) return;
              _loadDetail();
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF151820),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF242934)),
                    ),
                    child: const Icon(
                      Icons.android_rounded,
                      color: Color(0xFF9EA3AD),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          app.packageName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF9EA3AD),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _SmallBadge(
                              text: app.repoVerified ? 'Repo verified' : 'Repo pending',
                              good: app.repoVerified,
                            ),
                            _SmallBadge(text: app.trustLabel),
                            _SmallBadge(text: app.statusLabel),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF9EA3AD),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Color(0xFF222734), height: 1),
                  const SizedBox(height: 14),
                  _InfoRow(label: 'Repository', value: app.repoUrl),
                  const SizedBox(height: 10),
                  _InfoRow(
                    label: 'Signing key',
                    value: app.signingKeyHash.isEmpty ? 'Not locked yet' : app.signingKeyHash,
                  ),
                  if (_loading) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(color: Colors.white),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    _MessagePanel(message: _message!, error: true),
                  ],
                  if (_detail != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Submissions',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_detail!.submissions.isEmpty)
                      const Text(
                        'No submissions yet.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF9EA3AD),
                        ),
                      )
                    else
                      ..._detail!.submissions.map(_SubmissionRow.new),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SubmissionRow extends StatelessWidget {
  const _SubmissionRow(this.submission);

  final StoreSubmission submission;

  @override
  Widget build(BuildContext context) {
    final rejected = submission.status == 'rejected';
    final live = submission.status == 'live';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF222734)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  submission.versionName.isEmpty ? 'Version' : 'v${submission.versionName}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Code ${submission.versionCode}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9EA3AD),
                  ),
                ),
              ],
            ),
          ),
          _SmallBadge(
            text: submission.statusLabel,
            good: live,
            bad: rejected,
          ),
        ],
      ),
    );
  }
}

class _DashboardOnlyState extends StatelessWidget {
  const _DashboardOnlyState({
    required this.title,
    required this.text,
    required this.onOpenDashboard,
  });

  final String title;
  final String text;
  final VoidCallback onOpenDashboard;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF11141A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF222734)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF9EA3AD),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenDashboard,
              icon: const Icon(Icons.open_in_browser_rounded, size: 18),
              label: const Text('Open dashboard'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDeveloperState extends StatelessWidget {
  const _EmptyDeveloperState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF11141A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF222734)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF9EA3AD),
          height: 1.35,
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.label,
    this.good = false,
    this.bad = false,
  });

  final String label;
  final bool good;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    final color = bad
        ? const Color(0xFFFCA5A5)
        : good
        ? const Color(0xFF86EFAC)
        : const Color(0xFF9EA3AD);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({
    required this.text,
    this.good = false,
    this.bad = false,
  });

  final String text;
  final bool good;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    final fg = bad
        ? const Color(0xFFFCA5A5)
        : good
        ? const Color(0xFF86EFAC)
        : const Color(0xFFD5D8DF);

    final bg = bad
        ? const Color(0x1AFCA5A5)
        : good
        ? const Color(0x1A86EFAC)
        : const Color(0x10141820);

    final border = bad
        ? const Color(0x33FCA5A5)
        : good
        ? const Color(0x3386EFAC)
        : const Color(0xFF2A303B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: fg,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final shown = value.trim().isEmpty ? '-' : value.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            color: Color(0xFF737A86),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          shown,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFFD5D8DF),
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.message,
    required this.error,
  });

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? const Color(0x1AFCA5A5) : const Color(0x1A86EFAC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: error ? const Color(0x33FCA5A5) : const Color(0x3386EFAC),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12.5,
          color: error ? const Color(0xFFFFD9D9) : const Color(0xFFD9FFE5),
          height: 1.35,
        ),
      ),
    );
  }
}