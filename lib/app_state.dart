import 'dart:async';

import 'package:flutter/foundation.dart';

import 'engine/alexa_trigger_adapter.dart';
import 'engine/launch_learner.dart';
import 'engine/mock_trigger_adapter.dart';
import 'engine/personalization_engine.dart';
import 'engine/personalization_model.dart';
import 'engine/routine_learner.dart';
import 'engine/trigger_adapter.dart';
import 'engine/windows_brightness_adapter.dart';
import 'engine/windows_open_url_adapter.dart';
import 'engine/windows_volume_adapter.dart';
import 'models/ai_tutor_settings.dart';
import 'models/context_snapshot.dart';
import 'models/environment_profile.dart';
import 'models/mode.dart';
import 'models/pending_transition.dart';
import 'models/preference_profile.dart';
import 'models/task_item.dart';
import 'services/notification_service.dart';
import 'storage/ai_tutor_store.dart';
import 'storage/launch_store.dart';
import 'storage/mode_store.dart';
import 'storage/profile_store.dart';
import 'storage/routine_store.dart';
import 'storage/task_store.dart';

/// The one piece of shared state in the app. It holds:
///  - the user's preference profile (null until onboarding finishes)
///  - the mode list (4 built-ins + anything the user added)
///  - the learned weight model and the time-of-day routine tally
///  - the current simulated/real context snapshot, and which mode is
///    actually in effect right now
///  - any pending transition waiting out its 5-minute cancel window
///
/// Nothing here reaches a network. The `*Store` classes are the only things
/// that touch disk, and they only ever touch this device's own local
/// storage. `TriggerAdapter`s are the only things that reach *outside* the
/// device, and even then only with an opaque scene id — never anything
/// from `preference`, `context`, or the learned model.
class AppState extends ChangeNotifier {
  AppState({
    ProfileStore? profileStore,
    ModeStore? modeStore,
    RoutineStore? routineStore,
    LaunchStore? launchStore,
    AiTutorStore? aiTutorStore,
    TaskStore? taskStore,
    PersonalizationEngine? engine,
  })  : _profileStore = profileStore ?? ProfileStore(),
        _modeStore = modeStore ?? ModeStore(),
        _routineStore = routineStore ?? RoutineStore(),
        _launchStore = launchStore ?? LaunchStore(),
        _aiTutorStore = aiTutorStore ?? AiTutorStore(),
        _taskStore = taskStore ?? TaskStore(),
        _engine = engine ?? PersonalizationEngine();

  final ProfileStore _profileStore;
  final ModeStore _modeStore;
  final RoutineStore _routineStore;
  final LaunchStore _launchStore;
  final AiTutorStore _aiTutorStore;
  final TaskStore _taskStore;
  final PersonalizationEngine _engine;

  /// Registered trigger adapters, by id. Only the mock/demo adapter ships
  /// in this build — see `MockTriggerAdapter` for how a real one (a
  /// Home-Assistant or IFTTT webhook) would register alongside it.
  final Map<String, TriggerAdapter> adapters = {
    'mock': MockTriggerAdapter(),
    'windows_brightness': WindowsBrightnessAdapter(),
    'windows_volume': WindowsVolumeAdapter(),
    'windows_open_url': WindowsOpenUrlAdapter(),
    'alexa': AlexaTriggerAdapter(),
  };

  MockTriggerAdapter get mockAdapter => adapters['mock'] as MockTriggerAdapter;
  WindowsBrightnessAdapter get windowsBrightnessAdapter =>
      adapters['windows_brightness'] as WindowsBrightnessAdapter;
  WindowsVolumeAdapter get windowsVolumeAdapter =>
      adapters['windows_volume'] as WindowsVolumeAdapter;
  WindowsOpenUrlAdapter get windowsOpenUrlAdapter =>
      adapters['windows_open_url'] as WindowsOpenUrlAdapter;
  AlexaTriggerAdapter get alexaAdapter => adapters['alexa'] as AlexaTriggerAdapter;

  /// A date string per mode id — guards a scheduled mode from re-firing
  /// every ~20 seconds for as long as the clock sits on its scheduled
  /// minute. Ephemeral (not persisted): a restart mid-day can refire a
  /// schedule once more that day, which is a fine trade for the simplicity.
  final Map<String, String> _scheduledFiredToday = {};

  /// Same guard, for learned time-of-day launches (see `_checkTimeLaunches`)
  /// — keyed by "weekday|bucket" instead of mode id.
  final Map<String, String> _timeLaunchFiredToday = {};

  PreferenceProfile? _preference;
  List<Mode> _modes = Mode.builtIns();
  PersonalizationModel? _model;
  RoutineLearner _routines = RoutineLearner();
  LaunchLearner _launches = LaunchLearner();
  AiTutorSettings _aiTutor = AiTutorSettings.initial;
  ContextSnapshot _context = ContextSnapshot.initial;
  String? _currentModeId;
  ModeDecision? _decision;
  PendingTransition? _pendingTransition;
  DateTime? _simulatedNow;
  List<TaskItem> _tasks = [];
  final List<TransitionLogEntry> _transitionLog = [];
  bool _loading = true;

  Timer? _pendingTimer;
  Timer? _tickTimer;
  Timer? _routineCheckTimer;

  PreferenceProfile? get preference => _preference;
  List<Mode> get modes => List.unmodifiable(_modes);
  PersonalizationModel? get model => _model;
  RoutineLearner get routines => _routines;
  LaunchLearner get launches => _launches;
  AiTutorSettings get aiTutor => _aiTutor;

  Future<void> updateAiTutorSettings(AiTutorSettings settings) async {
    _aiTutor = settings;
    await _aiTutorStore.save(_aiTutor);
    notifyListeners();
  }
  ContextSnapshot get sensorContext => _context;
  ModeDecision? get decision => _decision;
  PendingTransition? get pendingTransition => _pendingTransition;
  bool get hasProfile => _preference != null;
  bool get isLoading => _loading;
  /// Every adapter's fired scenes, merged and newest first — what "no info
  /// shared, only the trigger" actually looks like in this build.
  List<TriggerLogEntry> get triggerLog {
    final all = [
      ...mockAdapter.log,
      ...windowsBrightnessAdapter.log,
      ...windowsVolumeAdapter.log,
      ...alexaAdapter.log,
    ];
    all.sort((a, b) => b.at.compareTo(a.at));
    return all;
  }

  /// The real content behind "Today's deep work" and its siblings.
  /// Order is priority: index 0 is the top item in Focus Mode, the one
  /// Quick Mode's "Mark done"/"Snooze" act on.
  List<TaskItem> get tasks => List.unmodifiable(_tasks);
  List<TaskItem> get pendingTasks => _tasks.where((t) => !t.done).toList();

  /// Every applied/cancelled/override decision, newest first — the
  /// "Recent decisions" trail on the Routines screen.
  List<TransitionLogEntry> get transitionLog => List.unmodifiable(_transitionLog);

  /// "Now," for both the countdown and the routine check — overridable via
  /// `simulateClock` so a demo can show a time-based routine firing without
  /// waiting for the real clock.
  DateTime get effectiveNow => _simulatedNow ?? DateTime.now();
  bool get isClockSimulated => _simulatedNow != null;

  Mode get currentMode =>
      _modes.firstWhere((m) => m.id == _currentModeId, orElse: () => _modes.first);

  Future<void> bootstrap() async {
    await NotificationService.instance.init(onCancelAction: cancelPendingTransition);
    _preference = await _profileStore.load();
    _modes = await _modeStore.load();
    _model = await _profileStore.loadModel() ?? PersonalizationModel.seed(_modes);
    _routines = await _routineStore.load();
    _launches = await _launchStore.load();
    _aiTutor = await _aiTutorStore.load();
    _currentModeId = await _profileStore.loadCurrentModeId();
    _currentModeId ??= _modes.isNotEmpty ? _modes.first.id : null;
    _tasks = await _taskStore.load();

    if (_preference != null) {
      _recompute();
      _startRoutineCheck();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> completeOnboarding(PreferenceProfile profile) async {
    _preference = profile;
    _modes = Mode.builtIns();
    _model = PersonalizationModel.seed(_modes);
    await _profileStore.save(profile);
    await _modeStore.save(_modes);
    await _profileStore.saveModel(_model!);

    _recompute();
    // First session: apply the engine's pick immediately, no 5-minute
    // wait — there's nothing to transition *from* yet, and this is the
    // moment the pitch calls "learn the max in session one."
    if (_decision != null) {
      _currentModeId = _decision!.modeId;
      await _profileStore.saveCurrentModeId(_currentModeId!);
      _routines.record(effectiveNow, _currentModeId!);
      await _routineStore.save(_routines);
      await _applyEnvironment(currentMode);
    }
    _startRoutineCheck();
    notifyListeners();
  }

  void updateContext(ContextSnapshot next) {
    _context = next;
    _recompute();
    if (_decision != null && _decision!.modeId != _currentModeId) {
      _proposeTransition(_decision!.modeId, 'Context changed');
    }
    notifyListeners();
  }

  void _recompute() {
    final p = _preference;
    final m = _model;
    if (p == null || m == null || _modes.isEmpty) {
      _decision = null;
      return;
    }
    _decision = _engine.decide(modes: _modes, preference: p, context: _context, model: m);
  }

  // ---------------------------------------------------------------------
  // Pending transitions — nothing applies instantly.
  // ---------------------------------------------------------------------

  void _proposeTransition(String targetModeId, String reason) {
    if (targetModeId == _currentModeId) return;
    if (_pendingTransition?.to.id == targetModeId) return; // already proposed

    final target = _modes.firstWhere((m) => m.id == targetModeId, orElse: () => currentMode);
    _pendingTimer?.cancel();
    _tickTimer?.cancel();

    final now = effectiveNow;
    _pendingTransition = PendingTransition(
      from: currentMode,
      to: target,
      reason: reason,
      proposedAt: now,
      firesAt: now.add(const Duration(minutes: 5)),
    );
    _pendingTimer = Timer(const Duration(minutes: 5), _applyPendingTransition);
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    NotificationService.instance.notifyPendingTransition(toLabel: target.label, reason: reason);
    notifyListeners();
  }

  /// The Cancel button. Declining a proposal is itself a correction: it
  /// means the engine's pick was wrong for this context, so the model
  /// learns to favor staying on the current mode instead.
  Future<void> cancelPendingTransition() async {
    final pending = _pendingTransition;
    if (pending == null) return;
    _pendingTimer?.cancel();
    _tickTimer?.cancel();
    _pendingTransition = null;
    await NotificationService.instance.cancelPendingNotification();

    if (_preference != null && _model != null) {
      _engine.learnFromCorrection(
        model: _model!,
        preference: _preference!,
        context: _context,
        targetModeId: pending.from.id,
        awayFromModeId: pending.to.id,
      );
      await _profileStore.saveModel(_model!);
    }
    _logTransition(
      from: pending.from.label,
      to: pending.to.label,
      reason: pending.reason,
      outcome: 'cancelled',
    );
    notifyListeners();
  }

  /// Demo convenience: skip the wait and apply right now instead of
  /// cancelling — the countdown still exists for the real 5-minute flow,
  /// this just doesn't require a judge to watch a clock.
  Future<void> applyPendingTransitionNow() async {
    if (_pendingTransition == null) return;
    _pendingTimer?.cancel();
    await _applyPendingTransition();
  }

  Future<void> _applyPendingTransition() async {
    final pending = _pendingTransition;
    if (pending == null) return;
    _tickTimer?.cancel();
    _pendingTransition = null;
    _pendingTimer = null;

    _currentModeId = pending.to.id;
    await _profileStore.saveCurrentModeId(_currentModeId!);
    await _fireScenes(pending.to);
    await _applyEnvironment(pending.to);
    await NotificationService.instance.notifyApplied(pending.to.label);

    _routines.record(effectiveNow, pending.to.id);
    await _routineStore.save(_routines);
    _logTransition(
      from: pending.from.label,
      to: pending.to.label,
      reason: pending.reason,
      outcome: 'applied',
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Explicit overrides — the strongest training signal there is.
  // ---------------------------------------------------------------------

  /// The user picks a mode directly (e.g. from a "switch mode" sheet on
  /// the dashboard). This applies immediately — no 5-minute window, since
  /// the user is already looking right at it — and is the strongest
  /// correction signal the engine gets.
  Future<void> recordOverride(String newModeId) async {
    if (_preference == null || _model == null) return;
    final awayFrom = _decision?.modeId ?? _currentModeId;
    final previousLabel = currentMode.label;

    _engine.learnFromCorrection(
      model: _model!,
      preference: _preference!,
      context: _context,
      targetModeId: newModeId,
      awayFromModeId: awayFrom,
    );
    await _profileStore.saveModel(_model!);

    _pendingTimer?.cancel();
    _tickTimer?.cancel();
    _pendingTransition = null;

    _currentModeId = newModeId;
    await _profileStore.saveCurrentModeId(newModeId);
    final mode = _modes.firstWhere((m) => m.id == newModeId, orElse: () => currentMode);
    await _fireScenes(mode);
    await _applyEnvironment(mode);

    _routines.record(effectiveNow, newModeId);
    await _routineStore.save(_routines);
    _logTransition(from: previousLabel, to: mode.label, reason: 'Manual override', outcome: 'override');

    _recompute();
    notifyListeners();
  }

  void _logTransition({
    required String from,
    required String to,
    required String reason,
    required String outcome,
  }) {
    _transitionLog.insert(
      0,
      TransitionLogEntry(at: effectiveNow, fromLabel: from, toLabel: to, reason: reason, outcome: outcome),
    );
    if (_transitionLog.length > 30) {
      _transitionLog.removeRange(30, _transitionLog.length);
    }
  }

  Future<void> _fireScenes(Mode mode) async {
    for (final ref in mode.sceneTriggers) {
      final adapter = adapters[ref.adapterId];
      if (adapter != null) {
        await adapter.fire(ref.sceneId);
      }
    }
  }

  /// The "every mode has a default environment" piece: whenever a mode
  /// becomes active, apply its whole `EnvironmentProfile` at once —
  /// brightness, volume, and Alexa scene together — not just whatever
  /// scene triggers happen to be attached. Each piece no-ops safely if the
  /// mode didn't set it.
  Future<void> _applyEnvironment(Mode mode) async {
    final env = mode.environment;
    if (env == null || env.isEmpty) return;
    if (env.brightness != null) {
      await windowsBrightnessAdapter.fire('brightness:${env.brightness}');
    }
    if (env.volume != null) {
      await windowsVolumeAdapter.fire('volume:${env.volume}');
    }
    if (env.alexaSceneId != null) {
      await alexaAdapter.fire(env.alexaSceneId!);
    }
    if (env.openUrl != null) {
      await windowsOpenUrlAdapter.fire(env.openUrl!);
      await _recordLaunchObservation(mode.id, env.openUrl!);
    }
    if (env.aiTutorEnabled && _aiTutor.enabled) {
      // A second, independent "open" — not learned, not overridden by the
      // per-mode launch learner, just the one global prompt applied
      // wherever a mode opts in.
      await windowsOpenUrlAdapter.fire(_aiTutor.buildUrl());
    }
  }

  /// Everything `_applyEnvironment` would fire for this mode, in plain
  /// words — what the Switch-mode sheet and the post-switch confirmation
  /// show, so picking a mode visibly shows what it actually does instead
  /// of a silent change.
  List<String> describeEnvironment(Mode mode) {
    final env = mode.environment;
    if (env == null || env.isEmpty) return const [];
    return [
      if (env.brightness != null) 'brightness ${env.brightness}%',
      if (env.volume != null) 'volume ${env.volume}%',
      if (env.openUrl != null) 'opens ${env.openUrl}',
      if (env.aiTutorEnabled && _aiTutor.enabled) 'opens ChatGPT (study prompt)',
      if (env.alexaSceneId != null) 'Alexa "${env.alexaSceneId}"',
    ];
  }

  // ---------------------------------------------------------------------
  // Launch learning — what actually gets opened, per mode and per time of
  // day (see `LaunchLearner`). Firing a mode's *configured* default (above)
  // counts as an observation too, same as any other; this is also where a
  // manually-logged "I actually opened something else" feeds in, and
  // where it gets promoted into the mode's new default once confident.
  // ---------------------------------------------------------------------

  Future<void> _recordLaunchObservation(String modeId, String target) async {
    final trimmed = target.trim();
    if (trimmed.isEmpty) return;
    _launches.recordModeLaunch(modeId, trimmed);
    _launches.recordTimeLaunch(effectiveNow, trimmed);
    await _launchStore.save(_launches);
  }

  /// "If a particular website is opened [for a mode], set it as default
  /// and open it." The user tells DayOne what they actually opened while
  /// in `modeId` — this logs it, and if the same target has now been seen
  /// `LaunchLearner.confidenceThreshold`+ times for this mode (and isn't
  /// already the configured default), that mode's `environment.openUrl`
  /// is updated to match and saved — the learned default takes over from
  /// here on, no manual edit needed. Also opens it immediately, same as
  /// the spec asks.
  Future<void> recordLaunch({required String modeId, required String target}) async {
    final trimmed = target.trim();
    if (trimmed.isEmpty) return;

    await _recordLaunchObservation(modeId, trimmed);
    await _promoteLearnedDefaultIfConfident(modeId);

    await windowsOpenUrlAdapter.fire(trimmed);
    notifyListeners();
  }

  /// Checks whether `modeId` now has a confident learned target (see
  /// `LaunchLearner.learnedForMode`) and, if so, writes it into that
  /// mode's `EnvironmentProfile`. Shared by `recordLaunch` (learned
  /// launch targets, prefixed as plain URLs) and
  /// `_pollAdaptiveBrightness` (learned brightness, prefixed `brightness:`
  /// so it lands on `environment.brightness` instead of `environment.openUrl`).
  Future<void> _promoteLearnedDefaultIfConfident(String modeId) async {
    final learned = _launches.learnedForMode(modeId);
    if (learned == null) return;

    final index = _modes.indexWhere((m) => m.id == modeId);
    if (index == -1) return;
    final mode = _modes[index];

    const brightnessPrefix = 'brightness:';
    if (learned.target.startsWith(brightnessPrefix)) {
      final value = int.tryParse(learned.target.substring(brightnessPrefix.length));
      if (value == null || mode.environment?.brightness == value) return;
      mode.environment = (mode.environment ?? const EnvironmentProfile()).copyWith(brightness: value);
    } else {
      if (mode.environment?.openUrl == learned.target) return;
      mode.environment = (mode.environment ?? const EnvironmentProfile()).copyWith(openUrl: learned.target);
    }
    await updateMode(mode);
  }

  /// The time-of-day counterpart, independent of any mode — "around
  /// 6:00pm I open Spotify" — logged directly rather than inferred from a
  /// mode firing. Feeds `_checkTimeLaunches` below.
  Future<void> logTimedLaunch(String target) async {
    final trimmed = target.trim();
    if (trimmed.isEmpty) return;
    _launches.recordTimeLaunch(effectiveNow, trimmed);
    await _launchStore.save(_launches);
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Modes — the fixed four, plus whatever the user adds.
  // ---------------------------------------------------------------------

  Future<void> addMode(Mode mode) async {
    _modes = [..._modes, mode];
    _model?.ensureMode(mode.id);
    await _modeStore.save(_modes);
    if (_model != null) await _profileStore.saveModel(_model!);
    notifyListeners();
  }

  Future<void> updateMode(Mode updated) async {
    _modes = _modes.map((m) => m.id == updated.id ? updated : m).toList();
    await _modeStore.save(_modes);
    notifyListeners();
  }

  Future<void> removeMode(String modeId) async {
    final mode = _modes.firstWhere((m) => m.id == modeId, orElse: () => _modes.first);
    if (mode.builtIn) return; // the four built-ins are always available
    _modes = _modes.where((m) => m.id != modeId).toList();
    if (_currentModeId == modeId && _modes.isNotEmpty) {
      _currentModeId = _modes.first.id;
      await _profileStore.saveCurrentModeId(_currentModeId!);
    }
    await _modeStore.save(_modes);
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Tasks — the real content behind "Today's deep work" / Quick / Browse.
  // ---------------------------------------------------------------------

  Future<void> addTask(String title, {String note = ''}) async {
    if (title.trim().isEmpty) return;
    _tasks = [
      ..._tasks,
      TaskItem(id: DateTime.now().millisecondsSinceEpoch.toString(), title: title.trim(), note: note.trim()),
    ];
    await _taskStore.save(_tasks);
    notifyListeners();
  }

  Future<void> toggleTask(String id) async {
    _tasks = _tasks.map((t) {
      if (t.id != id) return t;
      return TaskItem(id: t.id, title: t.title, note: t.note, done: !t.done, createdAt: t.createdAt);
    }).toList();
    await _taskStore.save(_tasks);
    notifyListeners();
  }

  Future<void> removeTask(String id) async {
    _tasks = _tasks.where((t) => t.id != id).toList();
    await _taskStore.save(_tasks);
    notifyListeners();
  }

  /// Moves a task to the back of the (pending) queue instead of marking it
  /// done — what Quick Mode's "Snooze" tile does to the current top task.
  Future<void> snoozeTask(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final task = _tasks.removeAt(index);
    _tasks = [..._tasks, task];
    await _taskStore.save(_tasks);
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Time-based routines.
  // ---------------------------------------------------------------------

  void _startRoutineCheck() {
    _routineCheckTimer?.cancel();
    _routineCheckTimer = Timer.periodic(const Duration(seconds: 20), (_) => _checkRoutines());
  }

  void _checkRoutines() {
    if (_preference == null || _currentModeId == null) return;
    final now = effectiveNow;
    _checkScheduledModes(now);
    _checkTimeLaunches(now);
    _pollAdaptiveBrightness();

    final due = _routines.dueRoutine(now, _currentModeId!);
    if (due == null) return;
    _proposeTransition(
      due.modeId,
      "You're usually in ${_labelFor(due.modeId)} around "
      '${due.timeLabel} on ${due.weekdayLabel}s',
    );
  }

  /// "If at a particular time the same [thing] is used every day, open
  /// that when the time comes" — independent of mode. Fires at most once
  /// per (weekday, 30-minute bucket) per day, same guard pattern as
  /// `_checkScheduledModes`.
  Future<void> _checkTimeLaunches(DateTime now) async {
    final due = _launches.dueTimeLaunch(now);
    if (due == null) return;
    final todayKey = '${now.year}-${now.month}-${now.day}';
    final fireKey = '${due.weekday}|${due.bucket}';
    if (_timeLaunchFiredToday[fireKey] == todayKey) return;
    _timeLaunchFiredToday[fireKey] = todayKey;
    await windowsOpenUrlAdapter.fire(due.target);
  }

  /// Adaptive Mode's whole trick: while it's the active mode, notice what
  /// brightness the user actually settles the laptop at (not what DayOne
  /// last set — the real current value, read back via WMI) and log it as
  /// an observation, same tally/threshold machinery as a learned launch.
  /// No-ops entirely for any mode without `adaptsBrightness` set.
  Future<void> _pollAdaptiveBrightness() async {
    final mode = currentMode;
    if (!mode.adaptsBrightness) return;
    final current = await windowsBrightnessAdapter.readCurrentBrightness();
    if (current == null) return;
    final bucket = ((current / 10).round() * 10).clamp(0, 100);
    _launches.recordModeLaunch(mode.id, 'brightness:$bucket');
    await _launchStore.save(_launches);
    await _promoteLearnedDefaultIfConfident(mode.id);
  }

  /// The deterministic counterpart to learned routines: a mode with
  /// `scheduledMinuteOfDay` set switches every day at that exact time,
  /// starting the very first day — no history needed, unlike a learned
  /// routine which needs to be *seen* a few times first.
  void _checkScheduledModes(DateTime now) {
    final todayKey = '${now.year}-${now.month}-${now.day}';
    final nowMinute = now.hour * 60 + now.minute;

    for (final mode in _modes) {
      final scheduled = mode.scheduledMinuteOfDay;
      if (scheduled == null || scheduled != nowMinute) continue;
      if (_scheduledFiredToday[mode.id] == todayKey) continue;

      _scheduledFiredToday[mode.id] = todayKey;
      if (mode.id == _currentModeId) continue; // already there — nothing to propose

      _proposeTransition(mode.id, 'Scheduled for ${Mode.formatMinuteOfDay(scheduled)} every day');
    }
  }

  String _labelFor(String modeId) =>
      _modes.firstWhere((m) => m.id == modeId, orElse: () => currentMode).label;

  /// Demo-only: pretend it's a different time, so a learned routine can be
  /// shown firing without waiting for the real clock to reach it.
  void simulateClock(DateTime? fakeNow) {
    _simulatedNow = fakeNow;
    _checkRoutines();
    notifyListeners();
  }

  // ---------------------------------------------------------------------

  Future<void> deleteProfile() async {
    _pendingTimer?.cancel();
    _tickTimer?.cancel();
    _routineCheckTimer?.cancel();

    await _profileStore.deleteAll();
    await _modeStore.deleteAll();
    await _routineStore.deleteAll();
    await _launchStore.deleteAll();
    await _aiTutorStore.deleteAll();
    await NotificationService.instance.cancelPendingNotification();
    mockAdapter.log.clear();

    _preference = null;
    _modes = Mode.builtIns();
    _model = null;
    _routines = RoutineLearner();
    _launches = LaunchLearner();
    _aiTutor = AiTutorSettings.initial;
    _timeLaunchFiredToday.clear();
    _context = ContextSnapshot.initial;
    _currentModeId = _modes.first.id;
    _decision = null;
    _pendingTransition = null;
    _simulatedNow = null;
    _transitionLog.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _pendingTimer?.cancel();
    _tickTimer?.cancel();
    _routineCheckTimer?.cancel();
    super.dispose();
  }
}
