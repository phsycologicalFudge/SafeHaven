import 'package:shared_preferences/shared_preferences.dart';

class HistoryService {
  HistoryService._();
  static final HistoryService instance = HistoryService._();

  static const _viewedKey = 'sh_viewed_apps';
  static const _installedKey = 'sh_installed_apps';
  static const _categoryViewsKey = 'sh_category_views';
  static const _maxViewed = 50;
  static const _categoryWindow = Duration(days: 30);

  Future<void> recordView(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_viewedKey) ?? [];
    list.remove(packageName);
    list.insert(0, packageName);
    if (list.length > _maxViewed) list.removeLast();
    await prefs.setStringList(_viewedKey, list);
  }

  Future<void> recordCategoryView(String category) async {
    final normalized = _normalizeCategory(category);
    if (normalized == null) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final list = _prunedCategoryViews(
      prefs.getStringList(_categoryViewsKey) ?? [],
      now,
    );

    list.add('$normalized|$now');
    await prefs.setStringList(_categoryViewsKey, list);
  }

  Future<void> recordInstall(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_installedKey) ?? [];
    if (!list.contains(packageName)) list.add(packageName);
    await prefs.setStringList(_installedKey, list);
  }

  Future<List<String>> getViewed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_viewedKey) ?? [];
  }

  Future<List<String>> getInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_installedKey) ?? [];
  }

  Future<String?> getDominantCategory() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final list = _prunedCategoryViews(
      prefs.getStringList(_categoryViewsKey) ?? [],
      now,
    );

    await prefs.setStringList(_categoryViewsKey, list);
    if (list.isEmpty) return null;

    final counts = <String, int>{};
    for (final entry in list) {
      final category = _normalizeCategory(entry.split('|').first);
      if (category == null) continue;
      counts[category] = (counts[category] ?? 0) + 1;
    }

    if (counts.isEmpty) return null;

    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;
        return a.key.compareTo(b.key);
      });

    return sorted.first.key;
  }

  List<String> _prunedCategoryViews(List<String> entries, int nowSeconds) {
    final cutoff = nowSeconds - _categoryWindow.inSeconds;

    return entries.where((entry) {
      final parts = entry.split('|');
      if (parts.length != 2) return false;
      final category = _normalizeCategory(parts[0]);
      final timestamp = int.tryParse(parts[1]);
      if (category == null || timestamp == null) return false;
      return timestamp >= cutoff;
    }).toList();
  }

  String? _normalizeCategory(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return normalized;
  }
}
