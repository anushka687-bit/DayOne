import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/claude_settings.dart';

/// Persistence for the Claude API key used by AI Mode. Local-only, same
/// pattern as `AiTutorStore` — nothing here ever leaves this device except
/// as the one API call AI Mode makes.
class ClaudeSettingsStore {
  static const _key = 'dayone_claude_settings_v1';

  Future<ClaudeSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return ClaudeSettings.initial;
    try {
      return ClaudeSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return ClaudeSettings.initial;
    }
  }

  Future<void> save(ClaudeSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }

  Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
