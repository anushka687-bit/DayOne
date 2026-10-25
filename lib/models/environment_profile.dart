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

  /// A URL to open in this laptop's default browser the moment this mode
  /// becomes active — see `WindowsOpenUrlAdapter`. Used e.g. for Study
  /// Mode opening VTOP automatically instead of the user doing it by hand.
  final String? openUrl;

  /// If true, also opens ChatGPT (pre-filled with the one global
  /// explanation-style prompt — see `AiTutorSettings`) the moment this
  /// mode becomes active. A second, independent "open" alongside
  /// `openUrl`, not a replacement for it — Study Mode uses both: VTOP and
  /// the AI study buddy.
  final bool aiTutorEnabled;

  const EnvironmentProfile({
    this.brightness,
    this.volume,
    this.alexaSceneId,
    this.openUrl,
    this.aiTutorEnabled = false,
  });

  bool get isEmpty =>
      brightness == null &&
      volume == null &&
      alexaSceneId == null &&
      openUrl == null &&
      !aiTutorEnabled;

  /// Used by the launch learner to swap in a newly-learned `openUrl`
  /// without disturbing brightness/volume/Alexa. Pass `clearOpenUrl: true`
  /// to remove it instead of setting a new one.
  EnvironmentProfile copyWith({
    int? brightness,
    int? volume,
    String? alexaSceneId,
    String? openUrl,
    bool clearOpenUrl = false,
    bool? aiTutorEnabled,
  }) {
    return EnvironmentProfile(
      brightness: brightness ?? this.brightness,
      volume: volume ?? this.volume,
      alexaSceneId: alexaSceneId ?? this.alexaSceneId,
      openUrl: clearOpenUrl ? null : (openUrl ?? this.openUrl),
      aiTutorEnabled: aiTutorEnabled ?? this.aiTutorEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'brightness': brightness,
        'volume': volume,
        'alexaSceneId': alexaSceneId,
        'openUrl': openUrl,
        'aiTutorEnabled': aiTutorEnabled,
      };

  factory EnvironmentProfile.fromJson(Map<String, dynamic> json) => EnvironmentProfile(
        brightness: json['brightness'] as int?,
        volume: json['volume'] as int?,
        alexaSceneId: json['alexaSceneId'] as String?,
        openUrl: json['openUrl'] as String?,
        aiTutorEnabled: json['aiTutorEnabled'] as bool? ?? false,
      );
}
