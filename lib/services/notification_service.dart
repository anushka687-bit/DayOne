import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The real, OS-level half of the "notify 5 minutes before changing
/// anything" promise. The in-app countdown banner (see `AppState` /
/// `DashboardScreen`) still exists and still does the actual cancel/apply
/// logic — this just makes sure a notification reaches the user even when
/// DayOne isn't the app in front of them, with a Cancel action right on
/// the notification (Android; iOS gets a tap-to-open notification, since
/// wiring an action button there needs a notification category registered
/// up front and isn't worth the risk for this build).
///
/// Deliberately *not* a scheduled/zoned notification: DayOne decides a
/// change is coming and tells the user about it right away, with "in 5
/// minutes" in the text — not a notification timed to arrive later. That
/// keeps this to local, immediate notifications only; no timezone
/// database, no exact-alarm permission, no background isolate.
///
/// Not available on web, and not available on Windows either —
/// `flutter_local_notifications` ships platform implementations for
/// Android, iOS, macOS and Linux only; there is no Windows plugin
/// registered for its method channel at all. Calling it unguarded on
/// Windows (this app's actual target platform) throws
/// `MissingPluginException` on the very first call. Every method here is
/// therefore a no-op on both `kIsWeb` and `Platform.isWindows` — the
/// in-app banner (`AppState.pendingTransition` / `DashboardScreen`'s
/// `_PendingTransitionBanner`) is already a complete fallback on any
/// platform this can't reach, same as the Windows brightness/volume
/// adapters' own "never crash the UI over a trigger that couldn't be
/// delivered" rule.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// True only on platforms this plugin actually ships a native
  /// implementation for.
  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isLinux);

  static const _pendingId = 1001;
  static const _appliedId = 1002;
  static const _channelId = 'dayone_transitions';

  /// `onCancelAction` is called when the user taps the notification's
  /// Cancel action while the app process is still alive (foreground or
  /// backgrounded) — the common case during normal use and any live demo.
  /// If Android/iOS has fully killed the app process, tapping the
  /// notification just reopens DayOne to the same in-app banner instead.
  Future<void> init({required void Function() onCancelAction}) async {
    if (!_supported || _initialized) return;

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const settings = InitializationSettings(android: androidInit, iOS: iosInit, macOS: iosInit);

      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          if (response.actionId == 'cancel') onCancelAction();
        },
      );

      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await android?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        await ios?.requestPermissions(alert: true, badge: true, sound: true);
      }

      _initialized = true;
    } catch (_) {
      // A platform without a real implementation, or one that refuses
      // permission, just means no OS-level notification — the in-app
      // banner is still the complete experience. Never let this stop
      // AppState.bootstrap() from reaching `_loading = false`.
    }
  }

  Future<void> notifyPendingTransition({required String toLabel, required String reason}) async {
    if (!_supported || !_initialized) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Mode changes',
        channelDescription: 'DayOne is about to switch modes',
        importance: Importance.high,
        priority: Priority.high,
        actions: [AndroidNotificationAction('cancel', 'Cancel')],
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _plugin.show(_pendingId, 'Switching to $toLabel in 5 minutes', reason, details);
    } catch (_) {
      // Same policy throughout this file: a notification that couldn't be
      // delivered never breaks the in-app flow that triggered it.
    }
  }

  Future<void> cancelPendingNotification() async {
    if (!_supported || !_initialized) return;
    try {
      await _plugin.cancel(_pendingId);
    } catch (_) {}
  }

  Future<void> notifyApplied(String label) async {
    if (!_supported || !_initialized) return;
    await cancelPendingNotification();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Mode changes',
        channelDescription: 'DayOne is about to switch modes',
        importance: Importance.defaultImportance,
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _plugin.show(_appliedId, 'Switched to $label', 'DayOne applied the change.', details);
    } catch (_) {}
  }
}
