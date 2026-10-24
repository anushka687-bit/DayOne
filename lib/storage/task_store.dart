import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/task_item.dart';

/// Persistence for the task list — local-only, same pattern as everything
/// else DayOne stores. Deliberately *not* touched by `AppState.deleteProfile()`:
/// your to-do list isn't personalization data, so wiping your learned
/// weights and routines doesn't have to take your tasks with it.
class TaskStore {
  static const _key = 'dayone_tasks_v1';

  Future<List<TaskItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((t) => TaskItem.fromJson(t as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<TaskItem> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(tasks.map((t) => t.toJson()).toList()));
  }
}
