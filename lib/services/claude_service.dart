import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thrown whenever the Claude call can't be completed — bad/missing key,
/// network error, or a non-200 response. Carries a message that's already
/// safe to show directly in the AI Mode panel.
class ClaudeServiceException implements Exception {
  final String message;
  ClaudeServiceException(this.message);
  @override
  String toString() => message;
}

/// The one thing AI Mode adds beyond every other mode: an actual network
/// call. Everywhere else in DayOne, "AI" means an on-device scoring/learning
/// model — see the Edge AI Evidence slides. AI Mode is explicitly the
/// exception, by design: the user asked for real Claude, so this is a real
/// API call, clearly separated into its own service so it's obvious (in
/// code and in the demo) that nothing else in the app touches the network
/// this way.
class ClaudeService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-5';
  static const _anthropicVersion = '2023-06-01';

  /// [stylePrompt] is built from the user's onboarding `PreferenceProfile`
  /// plus their saved `AiTutorSettings` template (see
  /// `AppState.askAi`) — it's the "explain it my way" instruction, sent as
  /// the system prompt. [topic] is whatever the user typed in AI Mode.
  Future<String> explain({
    required String apiKey,
    required String topic,
    required String stylePrompt,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw ClaudeServiceException('No Claude API key saved yet — add one to use AI Mode.');
    }
    if (topic.trim().isEmpty) {
      throw ClaudeServiceException('Type something to ask first.');
    }

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'content-type': 'application/json',
              'x-api-key': apiKey.trim(),
              'anthropic-version': _anthropicVersion,
            },
            body: jsonEncode({
              'model': _model,
              'max_tokens': 1024,
              'system': stylePrompt,
              'messages': [
                {'role': 'user', 'content': topic.trim()},
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw ClaudeServiceException('Couldn\'t reach Claude — check your internet connection. ($e)');
    }

    if (response.statusCode != 200) {
      String detail = response.body;
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        detail = (decoded['error'] as Map<String, dynamic>?)?['message'] as String? ?? detail;
      } catch (_) {
        // keep the raw body if it isn't the expected error shape
      }
      throw ClaudeServiceException('Claude API error ${response.statusCode}: $detail');
    }

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final blocks = decoded['content'] as List? ?? [];
      final text = blocks
          .whereType<Map<String, dynamic>>()
          .where((b) => b['type'] == 'text')
          .map((b) => b['text'] as String? ?? '')
          .join();
      if (text.trim().isEmpty) {
        throw ClaudeServiceException('Claude returned an empty response.');
      }
      return text;
    } on ClaudeServiceException {
      rethrow;
    } catch (e) {
      throw ClaudeServiceException('Couldn\'t read Claude\'s response. ($e)');
    }
  }
}
