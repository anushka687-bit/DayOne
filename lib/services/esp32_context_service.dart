import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/context_snapshot.dart';

/// Polls the DayOne ESP32 node (see firmware/dayone_esp32) over its local
/// WiFi access point and turns each reply into a [ContextSnapshot].
///
/// The ESP32 runs as its own AP ("DayOne-ESP32"), so the phone must be
/// connected to that network — not the venue WiFi — for this to reach it.
/// Everything stays on-device-to-device; nothing here goes to the internet.
class Esp32ContextService {
  Esp32ContextService({this.baseUrl = 'http://192.168.4.1'});

  final String baseUrl;

  Timer? _timer;
  http.Client? _client;

  bool get isPolling => _timer != null;

  /// Starts polling `/context` every [interval] and calling [onUpdate]
  /// with the parsed snapshot. [onError] is called (without stopping the
  /// poll) whenever a single request fails — e.g. phone not yet on the
  /// ESP32's WiFi — so the UI can show a "not connected" state.
  void start({
    required void Function(ContextSnapshot snapshot) onUpdate,
    void Function(Object error)? onError,
    Duration interval = const Duration(seconds: 1),
  }) {
    stop();
    _client = http.Client();
    _timer = Timer.periodic(interval, (_) async {
      try {
        final snapshot = await _fetchOnce();
        onUpdate(snapshot);
      } catch (e) {
        onError?.call(e);
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _client?.close();
    _client = null;
  }

  Future<ContextSnapshot> _fetchOnce() async {
    final client = _client ?? http.Client();
    final response = await client
        .get(Uri.parse('$baseUrl/context'))
        .timeout(const Duration(seconds: 2));
    if (response.statusCode != 200) {
      throw Exception('ESP32 returned ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ContextSnapshot(
      noise: (body['noise'] as num).toDouble(),
      movement: (body['movement'] as num).toDouble(),
      light: (body['light'] as num).toDouble(),
    );
  }

  void dispose() => stop();
}
