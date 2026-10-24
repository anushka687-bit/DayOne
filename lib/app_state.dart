import 'dart:async';

import 'package:flutter/foundation.dart';

import 'engine/mock_trigger_adapter.dart';
import 'engine/personalization_engine.dart';
import 'engine/personalization_model.dart';
import 'engine/routine_learner.dart';
import 'engine/trigger_adapter.dart';
import 'models/context_snapshot.dart';
import 'models/mode.dart';
import 'models/pending_transition.dart';
import 'models/preference_profile.dart';
import 'models/task_item.dart';
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
    TaskStore? taskStore,
    PersonalizationEngine? engine,
  })  : _profileStore = profileStore ?? ProfileStore(),
        _modeStore = modeStore ?? ModeStore(),
        _routineStore = routineStore ?? RoutineStore(),
        _taskStore = taskStore ?? TaskStore(),
        _engine = engine ?? PersonalizationEngine();

  final ProfileStore _profileStore;
  final ModeStore _modeStore;
  final RoutineStore _routineStore;
  final TaskStore _taskStore;
  final PersonalizationEngine _engine;

  /// Registered trigger adapters, by id. Only the mock/demo adapter ships
  /// in this build — see `MockTriggerAdapter` for how a real one (a
  /// Home-Assistant or IFTTT webhook) would register alongside it.
  final Map<String, TriggerAdapter> adapters = {
    'mock': MockTriggerAdapter(),
  };

  MockTriggerAdapter get mockAdapter => adapters['mock'] as MockTriggerAdapter;

  PreferenceProfile? _preference;
  List<Mode> _modes = Mode.builtIns();
  PersonalizationModel? _model;
  RoutineLearner _routines = RoutineLearner();
  ContextSnapshot _context = ContextSnapshot.initial;
  String? _currentModeId;
  ModeDecision? _decision;
  PendingTransition? _pendingTransition;
  DateTime? _simulatedNow;
  List<TaskItem> _tasks = [];
  bool _loading = true;

  Timer? _pendingTimer;
  Timer? _tickTimer;
  Timer? _routineCheckTimer;

  PreferenceProfile? get preference => _preference;
  List<Mode> get modes => List.unmodifiable(_modes);
  PersonalizationModel? get model => _model;
  RoutineLearner get routines => _routines;
  ContextSnapshot get sensorContext => _context;
  ModeDecision? get decision => _decision;
  PendingTransition? get pendingTransition => _pendingTransition;
  bool get hasProfile => _preference != null;
  bool get isLoading => _loading;
  List<TriggerLogEntry> get triggerLog => mockAdapter.log;

  /// The real content behind "Today's deep work" and its siblings.
  /// Order is priority: index 0 is the top item in Focus Mode, the one
  /// Quick Mode's "Mark done"/"Snooze" act on.
  List<TaskItem> get tasks => List.unmodifiable(_tasks);
  List<TaskItem> get pendingTasks => _tasks.where((t) => !t.done).toList();

  /// "Now," for both the countdown and the routine check — overridable via
  /// `simulateClock` so a demo can show a time-based routine firing without
  /// waiting for the real clock.
  DateTime get effectiveNow => _simulatedNow ?? DateTime.now();
  bool get isClockSimulated => _simulatedNow != null;

  Mode get currentMode =>
      _modes.firstWhere((m) => m.id == _currentModeId, orElse: () => _modes.first);

  Future<void> bootstrap() async {
    _preference = await _profileStore.load();
    _modes = await _modeStore.load();
    _model = await _profileStore.loadModel() ?? PersonalizationModel.seed(_modes);
    _routines = await _routineStore.load();
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

    _routines.record(effectiveNow, pending.to.id);
    await _routineStore.save(_routines);

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

    _routines.record(effectiveNow, newModeId);
    await _routineStore.save(_routines);

    _recompute();
    notifyListeners();
  }

  Future<void> _fireScenes(Mode mode) async {
    for (final ref in mode.sceneTriggers) {
      final adapter = adapters[ref.adapterId];
      if (adapter != null) {
        await adapter.fire(ref.sceneId);
      }
    }
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
    final due = _routines.dueRoutine(effectiveNow, _currentModeId!);
    if (due == null) return;
    _proposeTransition(
      due.modeId,
      "You're usually in ${_labelFor(due.modeId)} around "
      '${due.timeLabel} on ${due.weekdayLabel}s',
    );
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
    mockAdapter.log.clear();

    _preference = null;
    _modes = Mode.builtIns();
    _model = null;
    _routines = RoutineLearner();
    _context = ContextSnapshot.initial;
    _currentModeId = _modes.first.id;
    _decision = null;
    _pendingTransition = null;
    _simulatedNow = null;
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
