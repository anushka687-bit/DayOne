import 'trigger_adapter.dart';

/// The Alexa channel — built for real, running in logged/dry-run mode by
/// choice (no IFTTT account or Alexa device needed before judging).
///
/// The real path, when you're ready for it: create an IFTTT Webhooks
/// service key, add one Applet per scene ("If Webhooks event
/// `dayone_relax` is received, then Alexa: activate routine / turn on
/// device"), set `iftttKey` below, and flip `dryRun` to false. At that
/// point `fire()` would `http.post(Uri.parse(url))` to the exact URL this
/// already builds and logs — one line to uncomment, nothing else in the
/// app changes, because nothing else knows this adapter exists.
///
/// Until then, this still proves the architecture end to end: the trigger
/// log and the Why/Routines/Privacy screens show precisely the URL that
/// would have been called, with only an opaque scene id in it — never a
/// preference value or a sensor reading.
class AlexaTriggerAdapter implements TriggerAdapter {
  final List<TriggerLogEntry> log = [];

  /// Set this once you've created an IFTTT Webhooks key (Settings →
  /// Services → Webhooks → Documentation, on ifttt.com).
  String? iftttKey;

  /// Kept true until a real IFTTT key is set — see the class doc for how
  /// to flip this over to an actual HTTP call.
  final bool dryRun = true;

  @override
  String get id => 'alexa';

  @override
  String get label => 'Alexa (via IFTTT)';

  String _urlFor(String eventName) =>
      'https://maker.ifttt.com/trigger/$eventName/with/key/${iftttKey ?? "<your-ifttt-key>"}';

  @override
  Future<void> fire(String sceneId) async {
    final url = _urlFor(sceneId);
    log.insert(
      0,
      TriggerLogEntry(
        at: DateTime.now(),
        sceneId: dryRun ? 'would POST to $url' : 'POSTed to $url',
        adapterLabel: label,
      ),
    );
    if (log.length > 50) log.removeRange(50, log.length);

    if (dryRun) return;
    // Real call once an IFTTT key is set — intentionally not wired by
    // default (see class doc):
    // await http.post(Uri.parse(url));
  }
}
