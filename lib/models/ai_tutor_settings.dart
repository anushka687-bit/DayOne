/// A single, global "how I like things explained" prompt, used to open
/// ChatGPT pre-filled whenever a mode with `aiTutorEnabled` becomes
/// active (see `EnvironmentProfile.aiTutorEnabled` and
/// `AppState._applyEnvironment`). One setting, reused by any mode that
/// opts in — Study Mode by default, but any custom mode can turn it on
/// too.
///
/// Nothing here is sent to DayOne's own storage beyond this device, and
/// nothing about the user's sensors/preferences is included — the prompt
/// is exactly what's typed here, opened as a ChatGPT URL, same as any
/// other `windows_open_url` trigger.
class AiTutorSettings {
  final bool enabled;
  final String promptTemplate;

  const AiTutorSettings({required this.enabled, required this.promptTemplate});

  static const defaultPromptTemplate =
      "Explain this completely basic, like I'm 5 years old. Use more "
      'diagrams and flow charts. Keep the language simple but technical '
      "enough — don't give too many examples.";

  static const AiTutorSettings initial = AiTutorSettings(
    enabled: true,
    promptTemplate: defaultPromptTemplate,
  );

  /// ChatGPT's web app accepts a `q` query param to pre-fill the first
  /// message of a new chat. Best-effort: if ChatGPT changes this URL
  /// behavior, it still opens a normal new chat — never a broken link.
  String buildUrl() => 'https://chatgpt.com/?q=${Uri.encodeQueryComponent(promptTemplate)}';

  AiTutorSettings copyWith({bool? enabled, String? promptTemplate}) => AiTutorSettings(
        enabled: enabled ?? this.enabled,
        promptTemplate: promptTemplate ?? this.promptTemplate,
      );

  Map<String, dynamic> toJson() => {'enabled': enabled, 'promptTemplate': promptTemplate};

  factory AiTutorSettings.fromJson(Map<String, dynamic> json) => AiTutorSettings(
        enabled: json['enabled'] as bool? ?? true,
        promptTemplate: json['promptTemplate'] as String? ?? defaultPromptTemplate,
      );
}
