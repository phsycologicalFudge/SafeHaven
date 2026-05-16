import 'package:flutter/material.dart';
import '../../../../services/theme/theme_manager.dart';
import '../../../../widgets/animated_tap.dart';


String compactAppName(String name) {
  final trimmed = name.trim();
  if (trimmed.length <= 6) return trimmed;
  return '${trimmed.substring(0, 6)}...';
}

class CatalogueSectionHeader extends StatelessWidget {
  const CatalogueSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
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
        ],
      ),
    );
  }
}

class CatalogueAllAppsTextButton extends StatelessWidget {
  const CatalogueAllAppsTextButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return AnimatedTap(
      borderRadius: 14,
      scale: 0.96,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
        child: Row(
          children: [
            Text(
              'All apps',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: colors.accentStart,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: colors.accentStart,
            ),
          ],
        ),
      ),
    );
  }
}

class CatalogueLoadingBlock extends StatelessWidget {
  const CatalogueLoadingBlock();

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 44, 18, 44),
      child: Center(child: CircularProgressIndicator(color: colors.accentEnd)),
    );
  }
}

class CatalogueErrorBlock extends StatelessWidget {
  const CatalogueErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 44, 18, 44),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: colors.textMuted,
            size: 34,
          ),
          const SizedBox(height: 14),
          Text(
            'Could not load catalogue',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: colors.textSoft,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 42,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: colors.accentGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: AnimatedTap(
                borderRadius: 10,
                onTap: onRetry,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Center(
                    child: Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: colors.buttonText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CatalogueEmptyBlock extends StatelessWidget {
  const CatalogueEmptyBlock();

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 54, 18, 54),
      child: Center(
        child: Text(
          'No apps are live yet.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: colors.textSoft,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}
