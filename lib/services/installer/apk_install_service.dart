import 'dart:async';
import 'dart:io';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../store_service.dart';

class ApkInstallService {
  ApkInstallService._();

  static final ApkInstallService instance = ApkInstallService._();

  static const MethodChannel _channel = MethodChannel('safehaven/installer');

  Future<void> downloadAndInstall({
    required PublicStoreApp app,
    required void Function(double progress) onProgress,
  }) async {
    final version = app.latestVersion;
    if (version == null) {
      throw const StoreApiException('missing_version');
    }

    final downloadUrl = await StoreService.instance.getDownloadUrl(
      packageName: app.packageName,
      versionCode: version.versionCode,
    );

    final dir = await getApplicationSupportDirectory();
    final installDir = Directory('${dir.path}/install_cache');

    if (!await installDir.exists()) {
      await installDir.create(recursive: true);
    }

    final file = File(
      '${installDir.path}/${app.packageName}-${version.versionCode}.apk',
    );

    if (await file.exists()) {
      final age = DateTime.now().difference(await file.lastModified());

      if (age.inMinutes <= 10) {
        onProgress(1);

        await _channel.invokeMethod('installApk', {
          'path': file.path,
        });

        return;
      }

      await file.delete().catchError((_) {});
    }

    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(downloadUrl));
    final response = await request.close();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      client.close(force: true);
      throw StoreApiException('download_http_${response.statusCode}');
    }

    final total = response.contentLength;
    var received = 0;

    final digestOutput = AccumulatorSink<Digest>();
    final digestInput = sha256.startChunkedConversion(digestOutput);
    final sink = file.openWrite();

    try {
      await for (final chunk in response) {
        received += chunk.length;
        digestInput.add(chunk);
        sink.add(chunk);

        if (total > 0) {
          onProgress(received / total);
        }
      }
    } finally {
      await sink.close();
      digestInput.close();
      client.close(force: true);
    }

    final actualSha256 = digestOutput.events.single.toString().toLowerCase();
    final expectedSha256 = version.sha256.trim().toLowerCase();

    if (expectedSha256.isNotEmpty && actualSha256 != expectedSha256) {
      await file.delete().catchError((_) {});
      throw const StoreApiException('sha256_mismatch');
    }

    onProgress(1);

    await _channel.invokeMethod('installApk', {
      'path': file.path,
    });
  }
}