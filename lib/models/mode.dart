import 'environment_profile.dart';

/// A mode is no longer a fixed choice of four — it's data, so the user can
/// add their own. Every mode still has to render as *something*, so each
/// one picks one of four reusable content shapes (`LayoutArchetype`) rather
/// than needing a bespoke screen per mode.
enum LayoutArchetype {
  /// Long-form, step-by-step. (Previously "Focus".)
  guided,

  /// Big icon buttons, almost no text. (Previously "Quick".)
  quick,

  /// A browsable grid, no hand-holding. (Previously "Explore".)
  browse,

  /// As few elements as possible. (Previously "Relax".)
  minimal,
}

extension LayoutArchetypeLabel on LayoutArchetype {
  String get label {
    switch (this) {
      case LayoutArchetype.guided:
        return 'Guided, detailed';
      case LayoutArchetype.quick:
        return 'Quick, visual';
      case LayoutArchetype.browse:
        return 'Browsable grid';
      case LayoutArchetype.minimal:
        return 'Minimal';
    }
  }
}

/// One personalization mode: a label, a tagline, a content shape, and
/// (optionally) a list of environment scenes to fire when this mode becomes
/// active. `builtIn` modes ship with the app; anything else was created by
/// the user in the Modes screen.
class Mode {
  final String id;
  String label;
  String tagline;
  LayoutArchetype layout;
  final bool builtIn;

  /// Opaque trigger targets — see `SceneTrigger`. DayOne only ever sends the
  /// `sceneId` through a `TriggerAdapter`, never any preference or sensor
  /// data, so this list is the entire "integration" surface of a mode.
  List<SceneTriggerRef> sceneTriggers;

  /// Minutes since midnight (0–1439), or null for no fixed schedule. A
  /// mode with this set switches to deterministically every day at that
  /// time — the direct complement to `RoutineLearner`'s organic, "seen it
  /// 3+ times" learning: this fires from day one, with no history needed.
  int? scheduledMinuteOfDay;

  /// What should actually be true in the room/on the device when this
  /// mode is active — applied in full every time the mode changes, not
  /// just on a manual trigger. See `AppState._applyEnvironment`.
  EnvironmentProfile? environment;

  Mode({
    required this.id,
    required this.label,
    required this.tagline,
    required this.layout,
    this.builtIn = false,
    List<SceneTriggerRef>? sceneTriggers,
    this.scheduledMinuteOfDay,
    this.environment,
  }) : sceneTriggers = sceneTriggers ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'tagline': tagline,
        'layout': layout.name,
        'builtIn': builtIn,
        'sceneTriggers': sceneTriggers.map((s) => s.toJson()).toList(),
        'scheduledMinuteOfDay': scheduledMinuteOfDay,
        'environment': environment?.toJson(),
      };

  factory Mode.fromJson(Map<String, dynamic> json) => Mode(
        id: json['id'] as String,
        label: json['label'] as String,
        tagline: json['tagline'] as String,
        layout: LayoutArchetype.values.firstWhere(
          (l) => l.name == json['layout'],
          orElse: () => LayoutArchetype.minimal,
        ),
        builtIn: json['builtIn'] as bool? ?? false,
        sceneTriggers: (json['sceneTriggers'] as List? ?? [])
            .map((s) => SceneTriggerRef.fromJson(s as Map<String, dynamic>))
            .toList(),
        scheduledMinuteOfDay: json['scheduledMinuteOfDay'] as int?,
        environment: json['environment'] == null
            ? null
            : EnvironmentProfile.fromJson(json['environment'] as Map<String, dynamic>),
      );

  static String formatMinuteOfDay(int minute) {
    final h = minute ~/ 60;
    final m = minute % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = (h % 12 == 0) ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  /// The four modes DayOne ships with. A fresh profile always starts from
  /// exactly these; anything else the user adds is appended alongside them.
  static List<Mode> builtIns() => [
        Mode(
          id: 'focus',
          label: 'Focus Mode',
          tagline: 'Calm surroundings, guided and detailed.',
          layout: LayoutArchetype.guided,
          builtIn: true,
          environment: const EnvironmentProfile(
            brightness: 90,
            volume: 40,
            alexaSceneId: 'dayone_focus',
          ),
        ),
        Mode(
          id: 'quick',
          label: 'Quick Mode',
          tagline: 'Busy surroundings — short, visual, low-friction.',
          layout: LayoutArchetype.quick,
          builtIn: true,
          environment: const EnvironmentProfile(
            brightness: 80,
            volume: 60,
            alexaSceneId: 'dayone_quick',
          ),
        ),
        Mode(
          id: 'explore',
          label: 'Explore Mode',
          tagline: 'Calm surroundings, exploring independently.',
          layout: LayoutArchetype.browse,
          builtIn: true,
          environment: const EnvironmentProfile(
            brightness: 70,
            volume: 50,
            alexaSceneId: 'dayone_explore',
          ),
        ),
        Mode(
          id: 'relax',
          label: 'Relax Mode',
          tagline: 'Calm and quiet — minimal interruptions.',
          layout: LayoutArchetype.minimal,
          builtIn: true,
          environment: const EnvironmentProfile(
            brightness: 25,
            volume: 10,
            alexaSceneId: 'dayone_relax',
          ),
        ),
      ];
}

/// A pointer to one scene on one adapter — e.g. "fire scene `evening-wind-down`
/// on the `mock` adapter". DayOne stores only this pointer, never anything
/// about what that scene actually does on the other end.
class SceneTriggerRef {
  final String adapterId;
  final String sceneId;
  final String label;

  const SceneTriggerRef({
    required this.adapterId,
    required this.sceneId,
    required this.label,
  });

  Map<String, dynamic> toJson() => {
        'adapterId': adapterId,
        'sceneId': sceneId,
        'label': label,
      };

  factory SceneTriggerRef.fromJson(Map<String, dynamic> json) =>
      SceneTriggerRef(
        adapterId: json['adapterId'] as String,
        sceneId: json['sceneId'] as String,
        label: json['label'] as String,
      );
}
