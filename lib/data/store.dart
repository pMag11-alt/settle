import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Where group logs live. Each group is one JSON array of events.
abstract class Store {
  Future<List<String>> loadIndex();
  Future<void> saveIndex(List<String> ids);
  Future<List<Object?>?> loadLog(String id);
  Future<void> saveLog(String id, List<Object?> events);
  Future<void> deleteLog(String id);
}

/// SharedPreferences: NSUserDefaults on iOS, SharedPreferences on Android
/// and localStorage on the web.
class PrefsStore implements Store {
  PrefsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _indexKey = 'settle.groups';
  static String _logKey(String id) => 'settle.group.$id';

  static Future<PrefsStore> open() async => PrefsStore(await SharedPreferences.getInstance());

  @override
  Future<List<String>> loadIndex() async => _prefs.getStringList(_indexKey) ?? [];

  @override
  Future<void> saveIndex(List<String> ids) => _prefs.setStringList(_indexKey, ids);

  @override
  Future<List<Object?>?> loadLog(String id) async {
    final raw = _prefs.getString(_logKey(id));
    return raw == null ? null : jsonDecode(raw) as List<Object?>;
  }

  @override
  Future<void> saveLog(String id, List<Object?> events) => _prefs.setString(_logKey(id), jsonEncode(events));

  @override
  Future<void> deleteLog(String id) => _prefs.remove(_logKey(id));
}

/// In-memory store for tests. It round-trips through JSON text like the
/// real one, so serialization bugs still show up.
class MemoryStore implements Store {
  final Map<String, String> data = {};
  List<String> index = [];

  @override
  Future<List<String>> loadIndex() async => List.of(index);

  @override
  Future<void> saveIndex(List<String> ids) async => index = List.of(ids);

  @override
  Future<List<Object?>?> loadLog(String id) async => data[id] == null ? null : jsonDecode(data[id]!) as List<Object?>;

  @override
  Future<void> saveLog(String id, List<Object?> events) async => data[id] = jsonEncode(events);

  @override
  Future<void> deleteLog(String id) async => data.remove(id);
}
