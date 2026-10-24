/// Learns "at this time, on this day, this mode usually wins" purely from
/// local history — no cloud, no account, just a tally kept on the device.
///
/// Every time a mode becomes active (picked by the engine and accepted, or
/// chosen directly by the user), `record()` logs which 30-minute bucket of
/// which weekday it happened in. Once the same (weekday, bucket, mode)
/// combination has been seen `confidenceThreshold` times, it counts as a
/// learned routine DayOne can act on proactively — e.g. switching to Relax
/// Mode and firing its scene triggers every day around 6:00pm, without
/// waiting for the sensors to say so first.
class RoutineLearner {
  static const int bucketMinutes = 30;
  static const int confidenceThreshold = 3;

  final Map<String, int> _counts;
  final Map<String, DateTime> _lastSeen;

  RoutineLearner({Map<String, int>? counts, Map<String, DateTime>? lastSeen})
      : _counts = counts ?? {},
        _lastSeen = lastSeen ?? {};

  static int bucketOf(DateTime t) => ((t.hour * 60 + t.minute) ~/ bucketMinutes) * bucketMinutes;

  static String _key(int weekday, int bucket, String modeId) => '$weekday|$bucket|$modeId';

  void record(DateTime at, String modeId) {
    final bucket = bucketOf(at);
    final key = _key(at.weekday, bucket, modeId);
    _counts[key] = (_counts[key] ?? 0) + 1;
    _lastSeen[key] = at;
  }

  /// A confident, learned routine for right now that isn't already the
  /// active mode — the thing that should propose a transition even though
  /// nothing in the sensor context changed.
  LearnedRoutine? dueRoutine(DateTime now, String currentModeId) {
    final bucket = bucketOf(now);
    String? bestMode;
    var bestCount = 0;
    for (final entry in _counts.entries) {
      final parts = entry.key.split('|');
      final weekday = int.parse(parts[0]);
      final b = int.parse(parts[1]);
      if (weekday != now.weekday || b != bucket) continue;
      if (entry.value > bestCount) {
        bestCount = entry.value;
        bestMode = parts[2];
      }
    }
    if (bestMode != null && bestCount >= confidenceThreshold && bestMode != currentModeId) {
      final key = _key(now.weekday, bucket, bestMode);
      return LearnedRoutine(
        weekday: now.weekday,
        bucket: bucket,
        modeId: bestMode,
        confidence: bestCount,
        lastSeen: _lastSeen[key] ?? now,
      );
    }
    return null;
  }

  /// Every learned routine confident enough to show on the Why/Privacy
  /// screens, most confident first.
  List<LearnedRoutine> allRoutines() {
    final best = <String, LearnedRoutine>{};
    for (final entry in _counts.entries) {
      final parts = entry.key.split('|');
      final weekday = int.parse(parts[0]);
      final bucket = int.parse(parts[1]);
      final modeId = parts[2];
      final groupKey = '$weekday|$bucket';
      final existing = best[groupKey];
      if (existing == null || entry.value > existing.confidence) {
        best[groupKey] = LearnedRoutine(
          weekday: weekday,
          bucket: bucket,
          modeId: modeId,
          confidence: entry.value,
          lastSeen: _lastSeen[entry.key] ?? DateTime.now(),
        );
      }
    }
    final routines = best.values.where((r) => r.confidence >= confidenceThreshold).toList();
    routines.sort((a, b) => b.confidence.compareTo(a.confidence));
    return routines;
  }

  Map<String, dynamic> toJson() => {
        'counts': _counts,
        'lastSeen': _lastSeen.map((k, v) => MapEntry(k, v.toIso8601String())),
      };

  factory RoutineLearner.fromJson(Map<String, dynamic> json) {
    final counts = (json['counts'] as Map? ?? {})
        .map((k, v) => MapEntry(k as String, (v as num).toInt()));
    final lastSeen = (json['lastSeen'] as Map? ?? {})
        .map((k, v) => MapEntry(k as String, DateTime.parse(v as String)));
    return RoutineLearner(counts: counts, lastSeen: lastSeen);
  }
}

/// One learned (weekday, time bucket) -> mode pattern, confident enough to
/// act on.
class LearnedRoutine {
  final int weekday; // DateTime.weekday: 1 = Monday ... 7 = Sunday
  final int bucket; // minutes since midnight, 30-minute resolution
  final String modeId;
  final int confidence; // how many times this combination has been seen
  final DateTime lastSeen;

  const LearnedRoutine({
    required this.weekday,
    required this.bucket,
    required this.modeId,
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
