import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'store_service.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const String _localIndexKey = 'safehaven_local_index_raw';

  Future<StoreIndex> syncStore() async {
    final prefs = await SharedPreferences.getInstance();
    final localRaw = prefs.getString(_localIndexKey);

    Map<String, dynamic>? localData;
    int since = 0;

    if (localRaw != null) {
      try {
        localData = jsonDecode(localRaw) as Map<String, dynamic>;
        since = localData['timestamp'] as int? ?? 0;
      } catch (_) {}
    }

    final uri = Uri.parse('${StoreService.defaultBaseUrl}/store/sync?since=$since');
    final res = await http.get(uri);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (localData != null) return StoreIndex.fromJson(localData);
      throw const StoreApiException('sync_failed');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final action = body['action'] as String?;

    if (action == 'full') {
      final fullUri = Uri.parse('${StoreService.defaultBaseUrl}/store/index.json');
      final fullRes = await http.get(fullUri);

      if (fullRes.statusCode < 200 || fullRes.statusCode >= 300) {
        if (localData != null) return StoreIndex.fromJson(localData);
        throw const StoreApiException('full_fetch_failed');
      }

      await prefs.setString(_localIndexKey, fullRes.body);
      return StoreIndex.fromJson(jsonDecode(fullRes.body));
    }

    if (action == 'patch' && localData != null) {
      final newTimestamp = body['timestamp'] as int;
      final updates = body['updates'] as List? ?? [];
      final removes = body['removes'] as List? ?? [];

      final appsList = List<Map<String, dynamic>>.from(localData['apps'] ?? []);

      for (final pkg in removes) {
        appsList.removeWhere((a) => a['packageName'] == pkg);
      }

      for (final update in updates) {
        final pkg = update['packageName'];
        final idx = appsList.indexWhere((a) => a['packageName'] == pkg);

        if (idx != -1) {
          appsList[idx] = update as Map<String, dynamic>;
        } else {
          appsList.add(update as Map<String, dynamic>);
        }
      }

      localData['timestamp'] = newTimestamp;
      localData['apps'] = appsList;

      final updatedRaw = jsonEncode(localData);
      await prefs.setString(_localIndexKey, updatedRaw);
      return StoreIndex.fromJson(localData);
    }

    if (localData != null) return StoreIndex.fromJson(localData);
    throw const StoreApiException('sync_invalid_state');
  }
}