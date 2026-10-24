import 'trigger_adapter.dart';

/// One fired scene, kept only so the Privacy/Why screens can show the user
/// exactly what DayOne would have sent out — the whole point being that the
/// log is as boring as it looks: a timestamp and an opaque id, nothing else.
class TriggerLogEntry {
  final DateTime at;
  final String sceneId;

  const TriggerLogEntry({required this.at, required this.sceneId});
}

/// The hackathon-safe stand-in for a real smart-home adapter. Instead of
/// calling out to a webhook, it just records that it *would* have — which
/// is also exactly how you'd unit-test a real adapter without hammering
/// someone's actual lights.
///
/// Swapping this for something real later means writing one class that
/// implements `TriggerAdapter.fire` as, say, an HTTP POST to a
/// Home-Assistant automation URL or an IFTTT Maker webhook with the scene
/// id as the only body — and registering it in `AppState` instead of (or
/// alongside) this one. Nothing else in the app changes, because nothing
/// else knows adapters exist.
class MockTriggerAdapter implements TriggerAdapter {
  final List<TriggerLogEntry> log = [];

  @override
  String get id => 'mock';

  @override
  String get label => 'Simulated smart-home link';

  @override
  Future<void> fire(String sceneId) async {
    log.insert(0, TriggerLogEntry(at: DateTime.now(), sceneId: sceneId));
    if (log.length > 50) log.removeRange(50, log.length);
  }
}
