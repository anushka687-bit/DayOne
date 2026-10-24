/// The entire contract for "make something outside DayOne happen."
///
/// This is deliberately the thinnest possible interface: one opaque string
/// in, nothing meaningful out. A real adapter (Home Assistant automation
/// webhook, an IFTTT/SmartThings Maker webhook, or a virtual device an
/// Alexa Routine watches) receives only `sceneId` — never a preference
/// value, a sensor reading, or anything else about the user. Whatever that
/// scene does on the other end (dim the lights, change a thermostat, mute
/// notifications on another app) is entirely that system's business; DayOne
/// never finds out.
///
/// Any other app or device that wants to be "personalized along with"
/// DayOne implements this same interface — a local webhook, an OS-level
/// Intent/App Shortcut/App Intent, or a tiny local socket. DayOne doesn't
/// need to know anything about it beyond `id`, `label`, and `fire`.
abstract class TriggerAdapter {
  /// Stable id stored on a `SceneTriggerRef` — e.g. "mock", "webhook",
  /// "home_assistant", "windows_brightness".
  String get id;

  /// Human-readable name for the Modes/Integrations UI.
  String get label;

  /// Fires one scene. No await on a result beyond success/failure; nothing
  /// is read back from the other side.
  Future<void> fire(String sceneId);
}

/// One fired scene, kept so the Privacy/Why screens can show exactly what
/// DayOne sent out — an opaque id and a timestamp, nothing else. Shared
/// across every `TriggerAdapter` so their logs can be merged into one
/// timeline.
class TriggerLogEntry {
  final DateTime at;
  final String sceneId;
  final String adapterLabel;

  const TriggerLogEntry({
    required this.at,
    required this.sceneId,
    required this.adapterLabel,
  });
}
