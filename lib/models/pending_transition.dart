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

/// A record of what actually happened to a proposed (or user-driven) mode
/// change — the human-readable trail behind the Routines screen's "Recent
/// decisions" section. `outcome` is one of `'applied'`, `'cancelled'`, or
/// `'override'`.
class TransitionLogEntry {
  final DateTime at;
  final String fromLabel;
  final String toLabel;
  final String reason;
  final String outcome;

  const TransitionLogEntry({
    required this.at,
    required this.fromLabel,
    required this.toLabel,
    required this.reason,
    required this.outcome,
  });
}
