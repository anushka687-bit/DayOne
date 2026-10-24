import '../models/mode.dart';

/// The learned state of the engine: one small weight vector per mode, plus
/// how many correction steps have been applied so far (which drives the
/// decaying learning rate in `PersonalizationEngine`). This — not a model
/// file, not a network call — is the entire "model" DayOne trains.
///
/// Feature order is fixed and shared with `PersonalizationEngine`:
/// `[bias, noise, movement, conciseness, guided, minimalNotifications]`.
class PersonalizationModel {
  final Map<String, List<double>> weights;
  int updateCount;

  PersonalizationModel({required this.weights, this.updateCount = 0});

  static const featureNames = [
    'bias',
    'noise',
    'movement',
    'conciseness',
    'guided',
    'minimalNotifications',
  ];

  /// Hand-derived starting point for the four built-in modes — the same
  /// relationships the original fixed formula used, just expressed as
  /// weights so learning has something sensible to refine. A brand-new
  /// custom mode starts near-neutral and is shaped entirely by what the
  /// user teaches it.
  static List<double> defaultWeightsFor(String modeId) {
    switch (modeId) {
      case 'quick':
        return [0.0, 0.36, 0.24, 0.4, 0.0, 0.0];
      case 'focus':
        return [0.5, -0.3, -0.2, 0.0, 0.5, 0.0];
      case 'explore':
        return [1.0, -0.3, -0.2, 0.0, -0.5, 0.0];
      case 'relax':
        return [0.5, -0.3, -0.2, 0.0, 0.0, 0.5];
      default:
        return [0.05, 0.0, 0.0, 0.0, 0.0, 0.0];
    }
  }

  factory PersonalizationModel.seed(List<Mode> modes) {
    final w = <String, List<double>>{};
    for (final m in modes) {
      w[m.id] = defaultWeightsFor(m.id);
    }
    return PersonalizationModel(weights: w);
  }

  /// Any mode not yet in the model (just created, or loaded from an older
  /// save) gets sensible neutral weights instead of crashing.
  void ensureMode(String modeId) {
    weights.putIfAbsent(modeId, () => defaultWeightsFor(modeId));
  }

  Map<String, dynamic> toJson() => {
        'updateCount': updateCount,
        'weights': weights,
      };

  factory PersonalizationModel.fromJson(Map<String, dynamic> json) {
    final raw = (json['weights'] as Map).cast<String, dynamic>();
    final weights = raw.map(
      (k, v) => MapEntry(k, (v as List).map((n) => (n as num).toDouble()).toList()),
    );
    return PersonalizationModel(
      weights: weights,
      updateCount: json['updateCount'] as int? ?? 0,
    );
  }
}
