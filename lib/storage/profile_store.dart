import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/personalization_model.dart';
import '../models/preference_profile.dart';

/// Persistence for "who this user is": the stated onboarding answers, the
/// learned weights built from everything observed since, and which mode is
/// currently in effect. Everything here is `shared_preferences` — on
/// Android/iOS that's local device storage, on web it's `localStorage`.
/// Either way it never leaves the device: no account, no server, no sync.
class ProfileStore {
  static const _profileKey = 'dayone_preference_profile_v1';
  static const _modelKey = 'dayone_personalization_model_v1';
  static const _currentModeKey = 'dayone_current_mode_v1';

  Future<PreferenceProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return null;
    try {
      return PreferenceProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupted/old-format data should never crash the app — treat it as
      // "no profile yet" and let onboarding rebuild it.
      return null;
    }
  }

  Future<void> save(PreferenceProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  Future<PersonalizationModel?> loadModel() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_modelKey);
    if (raw == null) return null;
    try {
      return PersonalizationModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveModel(PersonalizationModel model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, jsonEncode(model.toJson()));
  }

  Future<String?> loadCurrentModeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentModeKey);
  }

  Future<void> saveCurrentModeId(String modeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentModeKey, modeId);
  }

  /// The privacy guarantee, as code: this is the whole of what DayOne knows
  /// about you — stated preferences and learned weights alike — and this
  /// is the whole of what deleting it does.
  Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
    await prefs.remove(_modelKey);
    await prefs.remove(_currentModeKey);
  }
}
