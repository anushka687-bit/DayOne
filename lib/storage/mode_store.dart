import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/mode.dart';

/// Persistence for the mode list — the four built-ins plus anything the
/// user has added in the Modes screen. Local-only, same as everything
/// else DayOne stores.
class ModeStore {
  static const _key = 'dayone_modes_v1';

  Future<List<Mode>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return Mode.builtIns();
    try {
      final list = jsonDecode(raw) as List;
      final modes = list.map((m) => Mode.fromJson(m as Map<String, dynamic>)).toList();
      return modes.isEmpty ? Mode.builtIns() : modes;
    } catch (_) {
      return Mode.builtIns();
    }
  }

  Future<void> save(List<Mode> modes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(modes.map((m) => m.toJson()).toList()));
  }

  Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
