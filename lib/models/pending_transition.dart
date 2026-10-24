import 'mode.dart';

/// A mode/environment change that hasn't happened yet. DayOne never applies
/// a change the instant it decides on one — it proposes it, waits 5
/// minutes, and only acts if nobody cancels. This is the in-flight state of
/// that wait.
class PendingTransition {
  final Mode from;
  final Mode to;

  /// Plain-language reason, shown on the banner: "Context changed" or
  /// "You're usually in Relax Mode around this time".
  final String reason;

  final DateTime proposedAt;
  final DateTime firesAt;

  const PendingTransition({
    required this.from,
    required this.to,
    required this.reason,
    required this.proposedAt,
    required this.firesAt,
  });

  Duration remaining(DateTime now) {
    final d = firesAt.difference(now);
    return d.isNegative ? Duration.zero : d;
  }
}
