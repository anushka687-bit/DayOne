import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/launch_learner.dart';

/// Persistence for `LaunchLearner`'s tallies — what's actually been
/// opened, per mode and per time of day. Local-only, same as everything
/// else DayOne stores.
class LaunchStore {
  static const _key = 'dayone_launches_v1';

  Future<LaunchLearner> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return LaunchLearner();
    try {
      return LaunchLearner.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return LaunchLearner();
    }
  }

  Future<void> save(LaunchLearner learner) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(learner.toJson()));
  }

  Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
