import 'package:flutter/material.dart';
import '../../../../services/catalogue_service.dart';
import '../../../../services/store_service.dart';
import '../../../../services/theme/theme_manager.dart';

class CatalogueAppIcon extends StatelessWidget {
  const CatalogueAppIcon({required this.app, required this.size});

  final PublicStoreApp app;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);
    final iconUrl = app.iconUrl;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.iconBackground,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: iconUrl == null
          ? null
          : Image.network(
        iconUrl,
        width: size,
        height: size,
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

class CatalogueRawAppIcon extends StatelessWidget {
  const CatalogueRawAppIcon({
    required this.app,
    required this.size,
    required this.radius,
  });

  final PublicStoreApp app;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);
    final iconUrl = app.iconUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: iconUrl == null
            ? Container(
          color: colors.surfaceSoft,
          child: Icon(
            Icons.apps_rounded,
            size: size * 0.48,
            color: colors.textMuted,
          ),
        )
            : Image.network(
          iconUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: colors.surfaceSoft,
            child: Icon(
              Icons.apps_rounded,
              size: size * 0.48,
              color: colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
