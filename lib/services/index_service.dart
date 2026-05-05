import 'package:safehaven/services/ratings/ranking_service.dart';

import 'store_service.dart';

class IndexService {
  IndexService._();
  static final IndexService instance = IndexService._();

  StoreIndex? _cache;
  DateTime? _cacheTime;
  static const _ttl = Duration(minutes: 5);

  bool get _isCacheValid =>
      _cache != null &&
          _cacheTime != null &&
          DateTime.now().difference(_cacheTime!) < _ttl;

  Future<StoreIndex> fetchIndex({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid) return _cache!;
    final index = await StoreService.instance.fetchIndex();
    _cache = index;
    _cacheTime = DateTime.now();
    return index;
  }

  StoreIndex? get cached => _cache;

  Future<List<PublicStoreApp>> recommended(
      List<PublicStoreApp> apps, {
        Iterable<PublicStoreApp> exclude = const [],
      }) {
    return RankingService.instance.recommended(apps, exclude: exclude);
  }

  List<PublicStoreApp> topCharts(List<PublicStoreApp> apps) {
    return RankingService.instance.topCharts(apps);
  }

  List<PublicStoreApp> filterByCategory(
      List<PublicStoreApp> apps,
      String? category,
      ) {
    if (category == null) return apps;
    return apps.where((a) => a.category == category).toList();
  }

  List<String> shuffledCategoryKeys(Map<String, String> categories) {
    final keys = categories.keys.toList()..shuffle();
    return keys;
  }
}