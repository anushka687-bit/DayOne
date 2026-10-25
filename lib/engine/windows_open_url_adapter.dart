import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'trigger_adapter.dart';

/// Opens a URL in this laptop's default browser — a real local action,
/// same family as `WindowsBrightnessAdapter` / `WindowsVolumeAdapter`, not
/// a smart-home webhook. Used for things like Study Mode opening VTOP the
/// moment the mode becomes active, instead of the user opening it by hand
/// every time.
///
/// `sceneId` here is read directly as the URL itself (not a short code —
/// there's nothing to decode on the other end, it's just what gets
/// opened). Only runs on Windows; a safe no-op everywhere else so it never
/// breaks another platform just by being registered in `AppState.adapters`.
class WindowsOpenUrlAdapter implements TriggerAdapter {
  final List<TriggerLogEntry> log = [];

  @override
  String get id => 'windows_open_url';

  @override
  String get label => 'Open a website on this laptop';

  @override
  Future<void> fire(String sceneId) async {
    final url = sceneId.trim();
    if (url.isEmpty) return;

    log.insert(0, TriggerLogEntry(at: DateTime.now(), sceneId: url, adapterLabel: label));
    if (log.length > 50) log.removeRange(50, log.length);

    if (kIsWeb || !Platform.isWindows) return;
    try {
      // `start` is a cmd.exe builtin, not an .exe — must go through cmd.exe.
      // The empty '' argument is the window-title slot `start` expects
      // before the URL; without it, a URL starting with quotes/special
      // chars can be misread as the title instead.
      await Process.run('cmd', ['/c', 'start', '', url]);
    } catch (_) {
      // Same policy as the other Windows adapters: nothing visibly opens
      // rather than crashing the UI over a trigger that couldn't fire.
    }
  }
}
