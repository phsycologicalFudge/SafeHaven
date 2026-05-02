import 'dart:math';
import 'store_service.dart';
import '/services/ratings/rating_service.dart';
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

  List<PublicStoreApp> recommended(List<PublicStoreApp> apps) {
    final shuffled = [...apps]..shuffle();
    return shuffled.take(_randomLimit()).toList();
  }

  List<PublicStoreApp> topCharts(List<PublicStoreApp> apps) {
    final rated = apps.where((a) => a.ratingCount > 0).toList();

    if (rated.isEmpty) {
      final shuffled = [...apps]..shuffle();
      return shuffled.take(_randomLimit()).toList();
    }

    final groups = <int, List<PublicStoreApp>>{};
    for (final app in rated) {
      final tier = app.ratingAvg.floor();
      groups.putIfAbsent(tier, () => []).add(app);
    }

    final maxTier = groups.keys.reduce(max);
    final top = groups[maxTier]!..shuffle();
    return top.take(_randomLimit()).toList();
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

  int _randomLimit() => 5 + Random().nextInt(6);
}
