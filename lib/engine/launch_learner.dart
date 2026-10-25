/// Learns what actually gets opened — purely from local history, same
/// spirit as `RoutineLearner` (which learns "this mode, this time of
/// day") but for launch targets (a website URL, or anything `start` can
/// open — an app name, a protocol like `spotify:`).
///
/// Two independent tallies:
///  - per-mode: "while in Study Mode, this URL gets opened" — once the
///    same target has been logged `confidenceThreshold` times for a mode,
///    it's confident enough to become that mode's new default, even if it
///    differs from whatever was manually configured.
///  - per time-of-day: "around 6:00pm, this gets opened" — independent of
///    which mode is active, the same idea `RoutineLearner` applies to
///    modes, applied to launch targets instead (e.g. "6:00pm → Spotify").
class LaunchLearner {
  static const int confidenceThreshold = 3;
  static const int bucketMinutes = 30;

  final Map<String, int> _modeCounts;
  final Map<String, DateTime> _modeLastSeen;
  final Map<String, int> _timeCounts;
  final Map<String, DateTime> _timeLastSeen;

  LaunchLearner({
    Map<String, int>? modeCounts,
    Map<String, DateTime>? modeLastSeen,
    Map<String, int>? timeCounts,
    Map<String, DateTime>? timeLastSeen,
  })  : _modeCounts = modeCounts ?? {},
        _modeLastSeen = modeLastSeen ?? {},
        _timeCounts = timeCounts ?? {},
        _timeLastSeen = timeLastSeen ?? {};

  static int bucketOf(DateTime t) => ((t.hour * 60 + t.minute) ~/ bucketMinutes) * bucketMinutes;

  static String _modeKey(String modeId, String target) => '$modeId|$target';
  static String _timeKey(int weekday, int bucket, String target) => '$weekday|$bucket|$target';

  // ---------------------------------------------------------------------
  // Recording.
  // ---------------------------------------------------------------------

  void recordModeLaunch(String modeId, String target) {
    final key = _modeKey(modeId, target);
    _modeCounts[key] = (_modeCounts[key] ?? 0) + 1;
    _modeLastSeen[key] = DateTime.now();
  }

  void recordTimeLaunch(DateTime at, String target) {
    final bucket = bucketOf(at);
    final key = _timeKey(at.weekday, bucket, target);
    _timeCounts[key] = (_timeCounts[key] ?? 0) + 1;
    _timeLastSeen[key] = at;
  }

  // ---------------------------------------------------------------------
  // Per-mode.
  // ---------------------------------------------------------------------

  /// The most-observed launch target for this mode, regardless of whether
  /// it's confident yet — used to show "learning, N more to go" progress.
  LearnedModeLaunch? topObservationForMode(String modeId) {
    String? bestTarget;
    var bestCount = 0;
    for (final entry in _modeCounts.entries) {
      final sep = entry.key.indexOf('|');
      if (sep == -1) continue;
      final id = entry.key.substring(0, sep);
      if (id != modeId) continue;
      if (entry.value > bestCount) {
        bestCount = entry.value;
        bestTarget = entry.key.substring(sep + 1);
      }
    }
    if (bestTarget == null) return null;
    final key = _modeKey(modeId, bestTarget);
    return LearnedModeLaunch(
      modeId: modeId,
      target: bestTarget,
      confidence: bestCount,
      lastSeen: _modeLastSeen[key] ?? DateTime.now(),
    );
  }

  /// The most-observed launch target for this mode, if it's been seen
  /// `confidenceThreshold`+ times — the thing that should override
  /// whatever default is currently configured.
  LearnedModeLaunch? learnedForMode(String modeId) {
    final top = topObservationForMode(modeId);
    if (top == null || top.confidence < confidenceThreshold) return null;
    return top;
  }

  /// Every (mode, target) combination ever logged, most recent first — the
  /// raw history behind a "what have I opened in this mode" view.
  List<LearnedModeLaunch> allModeObservations() {
    final list = _modeCounts.entries.map((entry) {
      final sep = entry.key.indexOf('|');
      return LearnedModeLaunch(
        modeId: entry.key.substring(0, sep),
        target: entry.key.substring(sep + 1),
        confidence: entry.value,
        lastSeen: _modeLastSeen[entry.key] ?? DateTime.now(),
      );
    }).toList();
    list.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    return list;
  }

  // ---------------------------------------------------------------------
  // Time-of-day.
  // ---------------------------------------------------------------------

  /// A confident "this is usually opened right now" target, independent of
  /// mode — the "6:00pm → Spotify, every day" case.
  LearnedTimeLaunch? dueTimeLaunch(DateTime now) {
    final bucket = bucketOf(now);
    String? bestTarget;
    var bestCount = 0;
    for (final entry in _timeCounts.entries) {
      final parts = entry.key.split('|');
      final weekday = int.parse(parts[0]);
      final b = int.parse(parts[1]);
      if (weekday != now.weekday || b != bucket) continue;
      if (entry.value > bestCount) {
        bestCount = entry.value;
        bestTarget = parts.sublist(2).join('|');
      }
    }
    if (bestTarget == null || bestCount < confidenceThreshold) return null;
    final key = _timeKey(now.weekday, bucket, bestTarget);
    return LearnedTimeLaunch(
      weekday: now.weekday,
      bucket: bucket,
      target: bestTarget,
      confidence: bestCount,
      lastSeen: _timeLastSeen[key] ?? now,
    );
  }

  /// Every learned (time of day → target) pattern confident enough to act
  /// on, most confident first.
  List<LearnedTimeLaunch> allTimeLaunches() {
    final best = <String, LearnedTimeLaunch>{};
    for (final entry in _timeCounts.entries) {
      final parts = entry.key.split('|');
      final weekday = int.parse(parts[0]);
      final bucket = int.parse(parts[1]);
      final target = parts.sublist(2).join('|');
      final groupKey = '$weekday|$bucket';
      final existing = best[groupKey];
      if (existing == null || entry.value > existing.confidence) {
        best[groupKey] = LearnedTimeLaunch(
          weekday: weekday,
          bucket: bucket,
          target: target,
          confidence: entry.value,
          lastSeen: _timeLastSeen[entry.key] ?? DateTime.now(),
        );
      }
    }
    final launches = best.values.where((l) => l.confidence >= confidenceThreshold).toList();
    launches.sort((a, b) => b.confidence.compareTo(a.confidence));
    return launches;
  }

  /// Every (weekday, bucket, target) combination ever logged, including
  /// ones not yet confident enough to act on — most recent first.
  List<LearnedTimeLaunch> allTimeObservations() {
    final list = _timeCounts.entries.map((entry) {
      final parts = entry.key.split('|');
      return LearnedTimeLaunch(
        weekday: int.parse(parts[0]),
        bucket: int.parse(parts[1]),
        target: parts.sublist(2).join('|'),
        confidence: entry.value,
        lastSeen: _timeLastSeen[entry.key] ?? DateTime.now(),
      );
    }).toList();
    list.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    return list;
  }

  // ---------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'modeCounts': _modeCounts,
        'modeLastSeen': _modeLastSeen.map((k, v) => MapEntry(k, v.toIso8601String())),
        'timeCounts': _timeCounts,
        'timeLastSeen': _timeLastSeen.map((k, v) => MapEntry(k, v.toIso8601String())),
      };

  factory LaunchLearner.fromJson(Map<String, dynamic> json) {
    Map<String, int> ints(String key) => (json[key] as Map? ?? {})
        .map((k, v) => MapEntry(k as String, (v as num).toInt()));
    Map<String, DateTime> dates(String key) => (json[key] as Map? ?? {})
        .map((k, v) => MapEntry(k as String, DateTime.parse(v as String)));
    return LaunchLearner(
      modeCounts: ints('modeCounts'),
      modeLastSeen: dates('modeLastSeen'),
      timeCounts: ints('timeCounts'),
      timeLastSeen: dates('timeLastSeen'),
    );
  }
}

/// One learned (mode → launch target) pattern.
class LearnedModeLaunch {
  final String modeId;
  final String target;
  final int confidence;
  final DateTime lastSeen;

  const LearnedModeLaunch({
    required this.modeId,
    required this.target,
    required this.confidence,
    required this.lastSeen,
  });
}

/// One learned (weekday, time bucket → launch target) pattern.
class LearnedTimeLaunch {
  final int weekday; // DateTime.weekday: 1 = Monday ... 7 = Sunday
  final int bucket; // minutes since midnight, 30-minute resolution
  final String target;
  final int confidence;
  final DateTime lastSeen;

  const LearnedTimeLaunch({
    required this.weekday,
    required this.bucket,
    required this.target,
    required this.confidence,
    required this.lastSeen,
  });

  static const _weekdayNames = [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String get weekdayLabel => _weekdayNames[weekday];

  String get timeLabel {
    final h = bucket ~/ 60;
    final m = bucket % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = (h % 12 == 0) ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }
}
