/// A mode's default environment — what should actually be true in the
/// room/device when this mode is active. This is the thing that applies
/// automatically, in full, every time the mode changes: not one optional
/// scene, but the whole picture for that mode.
class EnvironmentProfile {
  /// 0–100, this laptop's screen brightness (real — see
  /// `WindowsBrightnessAdapter`).
  final int? brightness;

  /// 0–100, this laptop's system volume (real but approximate — see
  /// `WindowsVolumeAdapter`).
  final int? volume;

  /// An opaque event name sent to Alexa (via an IFTTT Webhooks → Alexa
  /// Applet) — see `AlexaTriggerAdapter`. Never anything about the user,
  /// just this one string.
  final String? alexaSceneId;

  const EnvironmentProfile({this.brightness, this.volume, this.alexaSceneId});

  bool get isEmpty => brightness == null && volume == null && alexaSceneId == null;

  Map<String, dynamic> toJson() => {
        'brightness': brightness,
        'volume': volume,
        'alexaSceneId': alexaSceneId,
      };

  factory EnvironmentProfile.fromJson(Map<String, dynamic> json) => EnvironmentProfile(
        brightness: json['brightness'] as int?,
        volume: json['volume'] as int?,
        alexaSceneId: json['alexaSceneId'] as String?,
      );
}
