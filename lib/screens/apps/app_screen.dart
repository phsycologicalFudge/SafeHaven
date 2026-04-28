import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/store_service.dart';

class AppScreen extends StatelessWidget {
  const AppScreen({super.key, required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090C),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFF08090C),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert_rounded)),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header(app: app)),
          SliverToBoxAdapter(child: _MetadataRow(app: app)),
          SliverToBoxAdapter(child: _InstallButton(app: app)),
          SliverToBoxAdapter(child: _PreviewSection(app: app)),
          SliverToBoxAdapter(child: _AboutSection(app: app)),
          SliverToBoxAdapter(child: _TrustSection(app: app)),
          SliverToBoxAdapter(child: _TechnicalSection(app: app)),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: app.securityReviewed
            ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x1AFFFFFF), Color(0xFF08090C), Color(0xFF08090C)],
        )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _LargeIcon(),
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
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      app.packageName,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFFD5D8DF)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${app.displayVersion} · ${app.trustLabel}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9EA3AD)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LargeIcon extends StatelessWidget {
  const _LargeIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        color: const Color(0xFF151820),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF242934)),
      ),
      child: const SizedBox.shrink(),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    final version = app.latestVersion;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      child: Row(
        children: [
          Expanded(child: _MetaItem(top: version == null ? 'None' : version.versionName, bottom: 'Version')),
          const _DividerLine(),
          Expanded(child: _MetaItem(top: version == null ? '0' : version.versionCode.toString(), bottom: 'Code')),
          const _DividerLine(),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: app.repoUrl.isEmpty
                  ? null
                  : () async {
                await Clipboard.setData(ClipboardData(text: app.repoUrl));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Repo link copied')));
                }
              },
              child: const SizedBox(
                height: 48,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.code_rounded, size: 22, color: Colors.white),
                    SizedBox(height: 4),
                    Text('Source', style: TextStyle(fontSize: 11, color: Color(0xFF9EA3AD))),
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
    return SizedBox(
      height: 48,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(top, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(bottom, style: const TextStyle(fontSize: 11, color: Color(0xFF9EA3AD))),
        ],
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: const Color(0xFF2A2F38));
  }
}

class _InstallButton extends StatelessWidget {
  const _InstallButton({required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    final hasVersion = app.latestVersion != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: FilledButton(
          onPressed: hasVersion ? () {} : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF1C2028),
            foregroundColor: Colors.black,
            disabledForegroundColor: const Color(0xFF8B909B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            hasVersion ? 'Install' : 'No live APK yet',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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
    return _Section(
      title: 'Preview',
      child: SizedBox(
        height: 220,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            return Container(
              width: 118,
              decoration: BoxDecoration(
                color: const Color(0xFF11141A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF242934)),
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

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'About this app',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Text(
          app.displaySummary,
          style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFFD8DBE2)),
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
    return _Section(
      title: 'Security signals',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          children: [
            _SignalRow(
              icon: Icons.verified_rounded,
              title: app.trustLabel,
              body: app.securityReviewed ? 'Manual security review is attached to this listing.' : 'Source ownership has been verified for this listing.',
              color: Colors.white,
            ),
            const _SignalRow(
              icon: Icons.fingerprint_rounded,
              title: 'Signer continuity',
              body: 'Future updates are checked against the stored signing identity.',
              color: Color(0xFF9EA3AD),
            ),
            _SignalRow(
              icon: Icons.manage_search_rounded,
              title: 'Latest scan',
              body: app.latestVersion?.scannedAt == 0 ? 'No completed scan timestamp is available yet.' : 'No known threat detected in the latest scan.',
              color: const Color(0xFF9EA3AD),
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
            _InfoRow(label: 'Repository', value: app.repoUrl.isEmpty ? 'Not provided' : app.repoUrl),
            _InfoRow(label: 'SHA-256', value: version == null || version.sha256.isEmpty ? 'Not available' : version.sha256),
            _InfoRow(label: 'APK size', value: version == null || version.apkSize == 0 ? 'Not available' : _formatBytes(version.apkSize)),
          ],
        ),
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.icon, required this.title, required this.body, required this.color});

  final IconData icon;
  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(body, style: const TextStyle(fontSize: 12.5, height: 1.35, color: Color(0xFF9EA3AD))),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF9EA3AD))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12.5, height: 1.35, color: Color(0xFFD8DBE2))),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 20, color: Color(0xFFD5D8DF)),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return 'Not available';
  const kb = 1024;
  const mb = kb * 1024;
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
  return '$bytes B';
}
