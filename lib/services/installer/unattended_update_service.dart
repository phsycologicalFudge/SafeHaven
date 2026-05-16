import 'package:flutter/services.dart';
import '../index_service.dart';
import '../store_service.dart';
import 'apk_install_service.dart';

class UnattendedUpdateService {
  static const _channel = MethodChannel('safehaven/installer');

  static Future<void> triggerManualBatchUpdate(List<Map<String, dynamic>> updates) async {
    try {
      await _channel.invokeMethod('startUnattendedUpdates', {'updates': updates});
    } catch (_) {}
  }

  @pragma('vm:entry-point')
  static Future<void> performBackgroundCheck() async {
    try {
      final index = await IndexService.instance.fetchIndex(forceRefresh: true);
      final updates = <Map<String, dynamic>>[];

      for (final app in index.apps) {
        final state = await ApkInstallService.instance.getPackageState(
          packageName: app.packageName,
        );

        if (state.installed && state.canUpdateTo(app.latestVersion)) {
          final downloadUrl = await StoreService.instance.getDownloadUrl(
            packageName: app.packageName,
            versionCode: app.latestVersion!.versionCode,
          );

          updates.add({
            'packageName': app.packageName,
            'downloadUrl': downloadUrl,
          });
        }
      }

      if (updates.isNotEmpty) {
        await triggerManualBatchUpdate(updates);
      }
    } catch (_) {}
  }
}