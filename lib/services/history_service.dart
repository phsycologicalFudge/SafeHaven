import 'package:shared_preferences/shared_preferences.dart';

class HistoryService {
  HistoryService._();
  static final HistoryService instance = HistoryService._();

  static const _viewedKey = 'sh_viewed_apps';
  static const _installedKey = 'sh_installed_apps';
  static const _maxViewed = 50;

  Future<void> recordView(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_viewedKey) ?? [];
    list.remove(packageName);
    list.insert(0, packageName);
    if (list.length > _maxViewed) list.removeLast();
    await prefs.setStringList(_viewedKey, list);
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
}
