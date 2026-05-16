import 'package:flutter/material.dart';
import '../../../../services/store_service.dart';
import '../../../../services/theme/theme_manager.dart';
import '../../../../widgets/animated_tap.dart';
import '../../app_screen/app_screen.dart';
import '../catalogue_navigation.dart';
import '../widgets/catalogue_app_icons.dart';
import '../widgets/catalogue_download_button.dart';
import '../widgets/catalogue_shared_widgets.dart';

class CatalogueTopChartsSection extends StatelessWidget {
  const CatalogueTopChartsSection({
    required this.apps,
    required this.onAllApps,
  });

  final List<PublicStoreApp> apps;
  final VoidCallback onAllApps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          const CatalogueSectionHeader(title: 'Top charts'),
          const SizedBox(height: 8),
          ...apps.map((app) => _TopChartWideRow(app: app)),
          CatalogueAllAppsTextButton(onTap: onAllApps),
        ],
      ),
    );
  }
}

class _TopChartWideRow extends StatelessWidget {
  const _TopChartWideRow({required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return AnimatedTap(
      borderRadius: 18,
      onTap: () {
        Navigator.of(context).push(pushRoute(AppScreen(app: app)));
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
        child: Row(
          children: [
            CatalogueAppIcon(app: app, size: 66),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.5,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.25,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (app.ratingCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          app.displayRating,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textMuted,
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -2),
                          child: Text(
                            '★',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      app.developerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            CatalogueDownloadButton(app: app),
          ],
        ),
      ),
    );
  }
}
