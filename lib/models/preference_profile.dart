/// What the user told us about themselves, once, during onboarding.
///
/// Every field is a 0.0–1.0 score from a single slider question. This is the
/// ENTIRE "preference" half of the personalization system — nothing here
/// comes from watching the user over time, only from what they stated.
class PreferenceProfile {
  /// 0 = likes detailed information, 1 = likes concise information.
  final double conciseness;

  /// 0 = likes text-heavy content, 1 = likes visual content.
  final double visual;

  /// 0 = prefers independent exploration, 1 = prefers guided step-by-step.
  final double guided;

  /// 0 = fine with frequent notifications, 1 = wants minimal notifications.
  final double minimalNotifications;

  const PreferenceProfile({
    required this.conciseness,
    required this.visual,
    required this.guided,
    required this.minimalNotifications,
  });

  Map<String, dynamic> toJson() => {
        'conciseness': conciseness,
        'visual': visual,
        'guided': guided,
        'minimalNotifications': minimalNotifications,
      };

  factory PreferenceProfile.fromJson(Map<String, dynamic> json) {
    return PreferenceProfile(
      conciseness: (json['conciseness'] as num).toDouble(),
      visual: (json['visual'] as num).toDouble(),
      guided: (json['guided'] as num).toDouble(),
      minimalNotifications: (json['minimalNotifications'] as num).toDouble(),
    );
  }
}
