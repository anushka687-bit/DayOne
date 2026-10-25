import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_tutor_settings.dart';

/// Persistence for the one global AI-tutor prompt. Local-only, same as
/// everything else DayOne stores.
class AiTutorStore {
  static const _key = 'dayone_ai_tutor_v1';

  Future<AiTutorSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return AiTutorSettings.initial;
    try {
      return AiTutorSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AiTutorSettings.initial;
    }
  }

  Future<void> save(AiTutorSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }

  Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
