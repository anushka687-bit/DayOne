import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/routine_learner.dart';

/// Persistence for the time-of-day habit tally behind `RoutineLearner`.
/// Just counts and timestamps, kept on-device like everything else.
class RoutineStore {
  static const _key = 'dayone_routines_v1';

  Future<RoutineLearner> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return RoutineLearner();
    try {
      return RoutineLearner.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return RoutineLearner();
    }
  }

  Future<void> save(RoutineLearner learner) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(learner.toJson()));
  }

  Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
