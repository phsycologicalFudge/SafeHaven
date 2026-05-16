import 'package:flutter/material.dart';
import '../../../../services/store_service.dart';
import '../../../../services/theme/theme_manager.dart';
import '../app_screen_helpers.dart';
import 'app_screen_layout.dart';

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