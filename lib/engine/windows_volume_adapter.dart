import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'trigger_adapter.dart';

/// Approximates an absolute system volume level on this laptop. Windows
/// has no one-line WMI call for volume the way it does for brightness, but
/// PowerShell can simulate the physical hardware volume keys via a tiny
/// inline `user32.dll` `keybd_event` call — no external tool, no extra
/// install. It presses volume-down enough times to guarantee the level is
/// at (or past) zero regardless of where it started, then presses
/// volume-up a calculated number of times to approximate the target.
///
/// Each press is roughly a 2% step on most drivers, so this lands *close*
/// to the target, not laboratory-exact — worth saying plainly rather than
/// overselling it in a demo.
///
/// `sceneId` is read as `volume:<0-100>`. A safe no-op on web and any
/// platform that isn't Windows.
class WindowsVolumeAdapter implements TriggerAdapter {
  final List<TriggerLogEntry> log = [];
  static final _sceneIdPattern = RegExp(r'^volume:(\d{1,3})$');
  static const _approxStepPercent = 2;
  static const _resetPresses = 50; // 50 * 2% = 100% of headroom, guarantees zero

  @override
  String get id => 'windows_volume';

  @override
  String get label => "This laptop's volume";

  @override
  Future<void> fire(String sceneId) async {
    final match = _sceneIdPattern.firstMatch(sceneId.trim());
    if (match == null) return;

    log.insert(0, TriggerLogEntry(at: DateTime.now(), sceneId: sceneId, adapterLabel: label));
    if (log.length > 50) log.removeRange(50, log.length);

    if (kIsWeb || !Platform.isWindows) return;
    final target = int.parse(match.group(1)!).clamp(0, 100);
    final presses = (target / _approxStepPercent).round();

    final script = '''
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class DayOneVolumeKeys {
  [DllImport("user32.dll")]
  public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
  public const byte VK_VOLUME_DOWN = 0xAE;
  public const byte VK_VOLUME_UP = 0xAF;
  public static void Down() { keybd_event(VK_VOLUME_DOWN, 0, 0, UIntPtr.Zero); keybd_event(VK_VOLUME_DOWN, 0, 2, UIntPtr.Zero); }
  public static void Up() { keybd_event(VK_VOLUME_UP, 0, 0, UIntPtr.Zero); keybd_event(VK_VOLUME_UP, 0, 2, UIntPtr.Zero); }
}
"@
for (\$i = 0; \$i -lt $_resetPresses; \$i++) { [DayOneVolumeKeys]::Down(); Start-Sleep -Milliseconds 15 }
Start-Sleep -Milliseconds 100
for (\$i = 0; \$i -lt $presses; \$i++) { [DayOneVolumeKeys]::Up(); Start-Sleep -Milliseconds 40 }
''';

    try {
      await Process.run('powershell', ['-NoProfile', '-Command', script]);
    } catch (_) {
      // Same policy as brightness: a locked-down PowerShell execution
      // policy just means nothing audibly changes, never a crash.
    }
  }
}
