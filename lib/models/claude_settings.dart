/// Settings for AI Mode's live Claude calls — just the one thing it needs
/// beyond what's already in `PreferenceProfile`/`AiTutorSettings`: the
/// user's own Anthropic API key. Stored locally only (see
/// `ClaudeSettingsStore`), never bundled into the app and never sent
/// anywhere except straight to Anthropic's API as the request header.
class ClaudeSettings {
  final String apiKey;

  const ClaudeSettings({this.apiKey = ''});

  bool get hasKey => apiKey.trim().isNotEmpty;

  static const ClaudeSettings initial = ClaudeSettings();

  ClaudeSettings copyWith({String? apiKey}) => ClaudeSettings(apiKey: apiKey ?? this.apiKey);

  Map<String, dynamic> toJson() => {'apiKey': apiKey};

  factory ClaudeSettings.fromJson(Map<String, dynamic> json) =>
      ClaudeSettings(apiKey: json['apiKey'] as String? ?? '');
}
