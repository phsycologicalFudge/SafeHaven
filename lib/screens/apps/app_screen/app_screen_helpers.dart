import 'dart:async';
import 'dart:ui' as ui;
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../services/theme/theme_manager.dart';

class AppAccentDialog extends StatelessWidget {
  const AppAccentDialog({
    super.key,
    required this.child,
    this.maxWidth = 360,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface.withOpacity(0.82),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colors.border.withOpacity(0.5),
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

Color polishAccentColor(Color color) {
  final hsl = HSLColor.fromColor(color);

  final saturation = hsl.saturation < 0.18
      ? 0.34
      : hsl.saturation.clamp(0.34, 0.72);

  final lightness = hsl.lightness.clamp(0.22, 0.42);

  return hsl
      .withSaturation(saturation)
      .withLightness(lightness)
      .toColor();
}

const int _maxIconColorCacheEntries = 160;

final LinkedHashMap<String, Color> _iconColorCache =
LinkedHashMap<String, Color>();

final Map<String, Future<Color?>> _iconColorFutureCache = {};

Future<Color?> extractImageColor(String iconUrl) {
  final url = iconUrl.trim();
  if (url.isEmpty) return Future.value(null);

  final cached = _iconColorCache[url];
  if (cached != null) {
    _iconColorCache.remove(url);
    _iconColorCache[url] = cached;
    return Future.value(cached);
  }

  final pending = _iconColorFutureCache[url];
  if (pending != null) return pending;

  final future = _extractImageColorUncached(url);
  _iconColorFutureCache[url] = future;

  return future.then((color) {
    if (color != null) {
      _iconColorCache[url] = color;

      while (_iconColorCache.length > _maxIconColorCacheEntries) {
        _iconColorCache.remove(_iconColorCache.keys.first);
      }
    }

    return color;
  }).whenComplete(() {
    _iconColorFutureCache.remove(url);
  });
}

Future<Color?> _extractImageColorUncached(String iconUrl) async {
  ui.Image? image;

  try {
    image = await _loadUiImage(iconUrl);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData == null) return null;

    final bytes = byteData.buffer.asUint8List();
    final width = image.width;
    final height = image.height;

    if (width * height == 0) return null;

    final bestColorInt = await compute(_findDominantColorInt, {
      'bytes': bytes,
      'pixelCount': width * height,
    });

    if (bestColorInt == null) return null;

    return Color.fromARGB(
      255,
      (bestColorInt >> 16) & 0xFF,
      (bestColorInt >> 8) & 0xFF,
      bestColorInt & 0xFF,
    );
  } catch (_) {
    return null;
  } finally {
    image?.dispose();
  }
}

int? _findDominantColorInt(Map<String, dynamic> data) {
  final Uint8List bytes = data['bytes'];
  final int pixelCount = data['pixelCount'];

  final buckets = <int, double>{};

  for (var i = 0; i < pixelCount; i += 8) {
    final offset = i * 4;
    if (offset + 3 >= bytes.length) continue;

    final alpha = bytes[offset + 3];
    if (alpha < 180) continue;

    final r = bytes[offset];
    final g = bytes[offset + 1];
    final b = bytes[offset + 2];

    final hsl = HSLColor.fromColor(Color.fromARGB(255, r, g, b));
    final saturation = hsl.saturation;
    final lightness = hsl.lightness;

    if (lightness < 0.08 || lightness > 0.92) continue;

    final vividness = saturation * (1 - (lightness - 0.5).abs());
    if (vividness < 0.08) continue;

    final qr = (r ~/ 24) * 24;
    final qg = (g ~/ 24) * 24;
    final qb = (b ~/ 24) * 24;
    final key = (qr << 16) | (qg << 8) | qb;

    final weight = 1 + vividness * 4;
    buckets[key] = (buckets[key] ?? 0) + weight;
  }

  if (buckets.isEmpty) return null;

  final best = buckets.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
  );

  return best.key;
}

Future<ui.Image> _loadUiImage(String url) {
  final completer = Completer<ui.Image>();
  final provider = ResizeImage.resizeIfNeeded(
    96,
    96,
    NetworkImage(url),
  );

  late final ImageStreamListener listener;
  final stream = provider.resolve(ImageConfiguration.empty);

  listener = ImageStreamListener(
        (imageInfo, _) {
      stream.removeListener(listener);
      completer.complete(imageInfo.image);
    },
    onError: (Object error, StackTrace? stackTrace) {
      stream.removeListener(listener);
      completer.completeError(error, stackTrace);
    },
  );

  stream.addListener(listener);
  return completer.future;
}

String stripMarkdown(String text) {
  return text
      .replaceAll(RegExp(r'#{1,6}\s*'), '')
      .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1] ?? '')
      .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m[1] ?? '')
      .replaceAllMapped(RegExp(r'`(.+?)`'), (m) => m[1] ?? '')
      .replaceAllMapped(RegExp(r'\[(.+?)\]\(.+?\)'), (m) => m[1] ?? '')
      .replaceAll(RegExp(r'\n{2,}'), ' ')
      .trim();
}

MarkdownStyleSheet markdownStyle(BuildContext context) {
  final colors = SafeHavenTheme.of(context);

  return MarkdownStyleSheet(
    p: TextStyle(
      fontSize: 14,
      height: 1.6,
      color: colors.textSoft,
    ),
    pPadding: const EdgeInsets.only(bottom: 12),
    blockSpacing: 14,
    h1: TextStyle(
      fontSize: 22,
      height: 1.2,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      color: colors.text,
    ),
    h2: TextStyle(
      fontSize: 19,
      height: 1.25,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      color: colors.text,
    ),
    h3: TextStyle(
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w800,
      color: colors.text,
    ),
    strong: TextStyle(
      fontWeight: FontWeight.w800,
      color: colors.text,
    ),
    em: TextStyle(
      fontStyle: FontStyle.italic,
      color: colors.textSoft,
    ),
    a: TextStyle(
      fontWeight: FontWeight.w700,
      color: colors.accentEnd,
    ),
    code: TextStyle(
      fontSize: 13,
      color: colors.text,
      backgroundColor: colors.surfaceSoft,
    ),
    blockquote: TextStyle(
      fontSize: 14,
      height: 1.5,
      color: colors.textSoft,
    ),
    listBullet: TextStyle(
      fontSize: 14,
      color: colors.textSoft,
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: colors.border),
      ),
    ),
  );
}

String formatScannedAt(int value) {
  if (value <= 0) return 'Not available';

  final scannedAt = DateTime.fromMillisecondsSinceEpoch(value * 1000);
  final diff = DateTime.now().difference(scannedAt);

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  return '${scannedAt.day.toString().padLeft(2, '0')}/'
      '${scannedAt.month.toString().padLeft(2, '0')}/'
      '${scannedAt.year}';
}

String formatBytes(int bytes) {
  if (bytes <= 0) return 'Not available';
  const kb = 1024;
  const mb = kb * 1024;
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
  return '$bytes B';
}