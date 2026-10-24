/// What's happening around the user right now.
///
/// In the hackathon build these three values come from sliders (standing in
/// for the ESP32 + BH1750 + MPU6050 + sound sensor). Swap the source and
/// nothing else in the app needs to change — the engine only ever sees this
/// shape, not where it came from.
class ContextSnapshot {
  /// 0 = quiet, 1 = loud. Stands in for the sound-level sensor.
  final double noise;

  /// 0 = still, 1 = a lot of movement. Stands in for the MPU6050.
  final double movement;

  /// 0 = dim, 1 = bright. Stands in for the BH1750.
  final double light;

  const ContextSnapshot({
    required this.noise,
    required this.movement,
    required this.light,
  });

  static const ContextSnapshot initial =
      ContextSnapshot(noise: 0.2, movement: 0.15, light: 0.5);

  ContextSnapshot copyWith({double? noise, double? movement, double? light}) {
    return ContextSnapshot(
      noise: noise ?? this.noise,
      movement: movement ?? this.movement,
      light: light ?? this.light,
    );
  }
}
