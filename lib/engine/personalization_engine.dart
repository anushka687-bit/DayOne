import 'dart:math' as math;

import '../models/context_snapshot.dart';
import '../models/mode.dart';
import '../models/preference_profile.dart';
import 'personalization_model.dart';

/// The result of one personalization decision: which mode won, the raw
/// score and a normalized confidence for every mode (so "Why this mode?"
/// can show its work), and a plain-language reasoning trail.
class ModeDecision {
  final String modeId;
  final Map<String, double> rawScores;
  final Map<String, double> confidences;
  final List<String> reasons;

  const ModeDecision({
    required this.modeId,
    required this.rawScores,
    required this.confidences,
    required this.reasons,
  });
}

/// DayOne's on-device personalization engine.
///
/// This is still the entire "AI" in the product, but it is no longer a
/// fixed formula: each mode has its own small weight vector, and every
/// explicit correction (an override, a cancelled transition, a confirmed
/// routine) takes one online-learning step that nudges those weights —
/// no model file, no network call, no training *run*, just continuous
/// on-device adjustment. The learning rate decays as more corrections
/// arrive, so the biggest personalization happens right after onboarding
/// (when `updateCount` is still 0) and later feedback only fine-tunes.
///
/// Preference answers "what does this user generally like," context
/// answers "what's happening right now," and this is still the only place
/// the two combine.
class PersonalizationEngine {
  /// Learning rate before any decay — the size of the very first
  /// correction's nudge.
  static const double baseLearningRate = 0.6;
  static const double _minWeight = -5.0;
  static const double _maxWeight = 5.0;

  List<double> _features(PreferenceProfile preference, ContextSnapshot context) => [
        1.0, // bias
        context.noise,
        context.movement,
        preference.conciseness,
        preference.guided,
        preference.minimalNotifications,
      ];

  ModeDecision decide({
    required List<Mode> modes,
    required PreferenceProfile preference,
    required ContextSnapshot context,
    required PersonalizationModel model,
  }) {
    final features = _features(preference, context);
    final scores = <String, double>{};

    for (final mode in modes) {
      model.ensureMode(mode.id);
      final w = model.weights[mode.id]!;
      double s = 0;
      for (var i = 0; i < features.length && i < w.length; i++) {
        s += w[i] * features[i];
      }
      scores[mode.id] = s;
    }

    final winnerId = scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final confidences = _softmax(scores);
    final winnerLabel = modes.firstWhere((m) => m.id == winnerId).label;

    final busy = context.noise * 0.6 + context.movement * 0.4;
    final reasons = <String>[
      'Environment: ${(busy * 100).round()}% busy '
          '(noise ${(context.noise * 100).round()}%, '
          'movement ${(context.movement * 100).round()}%)',
      'Preferences: conciseness ${(preference.conciseness * 100).round()}%, '
          'guided ${(preference.guided * 100).round()}%, '
          'minimal notifications ${(preference.minimalNotifications * 100).round()}%',
      '$winnerLabel scored highest '
          '(${((confidences[winnerId] ?? 0) * 100).round()}% confidence) — '
          'weights learned from your corrections, not a fixed formula '
          '(${model.updateCount} correction${model.updateCount == 1 ? '' : 's'} so far).',
    ];

    return ModeDecision(
      modeId: winnerId,
      rawScores: scores,
      confidences: confidences,
      reasons: reasons,
    );
  }

  Map<String, double> _softmax(Map<String, double> scores) {
    if (scores.isEmpty) return {};
    final maxV = scores.values.reduce((a, b) => a > b ? a : b);
    final exps = scores.map((k, v) => MapEntry(k, math.exp(v - maxV)));
    final sum = exps.values.fold(0.0, (a, b) => a + b);
    if (sum == 0) return scores.map((k, _) => MapEntry(k, 0.0));
    return exps.map((k, v) => MapEntry(k, v / sum));
  }

  /// One online-learning step. `targetModeId` is nudged up for this exact
  /// context; `awayFromModeId` (what DayOne had actually picked, if
  /// different) is nudged down by the same amount. Returns the learning
  /// rate actually used, purely so the UI can show it shrinking over time.
  double learnFromCorrection({
    required PersonalizationModel model,
    required PreferenceProfile preference,
    required ContextSnapshot context,
    required String targetModeId,
    String? awayFromModeId,
  }) {
    model.ensureMode(targetModeId);
    if (awayFromModeId != null) model.ensureMode(awayFromModeId);

    final features = _features(preference, context);
    final lr = baseLearningRate / math.sqrt(1 + model.updateCount);

    _nudge(model.weights[targetModeId]!, features, lr);
    if (awayFromModeId != null && awayFromModeId != targetModeId) {
      _nudge(model.weights[awayFromModeId]!, features, -lr);
    }
    model.updateCount += 1;
    return lr;
  }

  void _nudge(List<double> weights, List<double> features, double lr) {
    for (var i = 0; i < weights.length && i < features.length; i++) {
      weights[i] = (weights[i] + lr * features[i]).clamp(_minWeight, _maxWeight);
    }
  }
}
