import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'trigger_adapter.dart';

/// A genuinely real local trigger, not a mock: sets *this* laptop's screen
/// brightness through Windows' own WMI brightness interface, via a
/// `dart:io` `Process` call to PowerShell. Nothing crosses a network —
/// this is a local OS call, same as the app changing its own window.
///
/// `sceneId` is read as `brightness:<0-100>`; anything else is ignored.
/// Only runs when the app is actually built/running as a Windows desktop
/// target (`flutter run -d windows` / a Windows build) — a safe no-op on
/// web, Android, iOS, macOS, and Linux, so leaving it registered in
/// `AppState.adapters` never breaks another platform.
///
/// Why PowerShell/WMI instead of a Win32 platform channel: `WmiSetBrightness`
/// is a one-line call with no native C++ plugin to write or ship, which
/// matters for how fast this needed to go from idea to demo. It only
/// affects built-in laptop panels that expose WMI brightness control
/// (the vast majority do); some external monitors don't, and on those
/// this silently does nothing rather than throwing into the UI.
class WindowsBrightnessAdapter implements TriggerAdapter {
  final List<TriggerLogEntry> log = [];
  static final _sceneIdPattern = RegExp(r'^brightness:(\d{1,3})$');

  @override
  String get id => 'windows_brightness';

  @override
  String get label => "This laptop's screen brightness";

  @override
  Future<void> fire(String sceneId) async {
    final match = _sceneIdPattern.firstMatch(sceneId.trim());
    if (match == null) return;

    log.insert(0, TriggerLogEntry(at: DateTime.now(), sceneId: sceneId, adapterLabel: label));
    if (log.length > 50) log.removeRange(50, log.length);

    if (kIsWeb || !Platform.isWindows) return; // nothing to actually dim here
    final percent = int.parse(match.group(1)!).clamp(0, 100);
    try {
      await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        '(Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods)'
            '.WmiSetBrightness(1,$percent)',
      ]);
    } catch (_) {
      // A locked-down PowerShell policy, or a panel with no WMI brightness
      // control, just means nothing visibly changes — never crash the UI
      // over a trigger that couldn't be delivered.
    }
  }

  /// Reads this laptop's *current* brightness (0–100), independent of
  /// anything DayOne set — used by Adaptive Mode to notice what brightness
  /// the user actually settles on while that mode is active, rather than
  /// only ever writing a value. Returns null on any failure (non-Windows,
  /// no WMI brightness support, locked-down PowerShell) — callers treat
  /// that as "nothing to observe right now," never an error to surface.
  Future<int?> readCurrentBrightness() async {
    if (kIsWeb || !Platform.isWindows) return null;
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        '(Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightness)'
            '.CurrentBrightness',
      ]);
      final text = (result.stdout as String?)?.trim();
      if (text == null || text.isEmpty) return null;
      final value = int.tryParse(text);
      if (value == null) return null;
      if (value < 0) return 0;
      if (value > 100) return 100;
      return value;
    } catch (_) {
      return null;
    }
  }
}
