import 'dart:math';

import '../history_service.dart';
import '../store_service.dart';

class RankingService {
  RankingService._();
  static final RankingService instance = RankingService._();

  static const _maxRecencyBoost = 1.5;
  static const _recencyWindow = Duration(days: 30);

  final Random _random = Random();

  List<PublicStoreApp> topCharts(
    List<PublicStoreApp> apps, {
    int? limit,
  }) {
    final sorted = [...apps]
      ..sort((a, b) {
        final scoreCompare = _score(b).compareTo(_score(a));
        if (scoreCompare != 0) return scoreCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return sorted.take(limit ?? _randomLimit()).toList();
  }

  Future<List<PublicStoreApp>> recommended(
    List<PublicStoreApp> apps, {
    Iterable<PublicStoreApp> exclude = const [],
    int? limit,
  }) async {
    final targetLimit = limit ?? _randomLimit();
    final excludedPackages = exclude.map((a) => a.packageName).toSet();
    final pool = apps
        .where((app) => !excludedPackages.contains(app.packageName))
        .toList();

    if (pool.isEmpty) return const [];

    final selected = <PublicStoreApp>[];
    final dominantCategory = await HistoryService.instance.getDominantCategory();

    if (dominantCategory != null) {
      final categoryPool = pool
          .where((app) => _normalizeCategory(app.category) == dominantCategory)
          .toList()
        ..sort((a, b) => _score(b).compareTo(_score(a)));

      final categoryLimit = min(2, targetLimit);
      final samplePool = categoryPool.take(3).toList()..shuffle(_random);
      selected.addAll(samplePool.take(categoryLimit));
    }

    final selectedPackages = selected.map((a) => a.packageName).toSet();
    final fill = pool
        .where((app) => !selectedPackages.contains(app.packageName))
        .toList()
      ..sort((a, b) {
        final scoreA = _score(a) + _recencyBoost(a);
        final scoreB = _score(b) + _recencyBoost(b);
        final scoreCompare = scoreB.compareTo(scoreA);
        if (scoreCompare != 0) return scoreCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final topTierSize = min(fill.length, max(targetLimit * 2, targetLimit));
    final topTier = fill.take(topTierSize).toList()..shuffle(_random);
    final fallback = fill.skip(topTierSize).toList();

    selected.addAll(topTier);
    selected.addAll(fallback);

    return selected.take(targetLimit).toList();
  }

  double _score(PublicStoreApp app) {
    if (app.ratingCount <= 0 || app.ratingAvg <= 0) return 0;
    return app.ratingAvg * log(app.ratingCount + 1) / ln10;
  }

  double _recencyBoost(PublicStoreApp app) {
    final added = app.latestVersion?.added;
    if (added == null || added <= 0) return 0;

    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final ageSeconds = nowSeconds - added;
    if (ageSeconds <= 0) return _maxRecencyBoost;
    if (ageSeconds >= _recencyWindow.inSeconds) return 0;

    final remaining = 1 - (ageSeconds / _recencyWindow.inSeconds);
    return _maxRecencyBoost * remaining;
  }

  String _normalizeCategory(String value) {
    return value.trim().toLowerCase();
  }

  int _randomLimit() => 5 + _random.nextInt(6);
}
