import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/claude_settings.dart';
import '../models/environment_profile.dart';
import '../models/mode.dart';
import '../models/pending_transition.dart';
import '../models/task_item.dart';
import '../theme/app_theme.dart';
import '../widgets/panel.dart';
import 'why_this_mode_screen.dart';

/// The screen judges actually watch change. Same data, same user — the
/// LAYOUT, content length, and interaction style change based on the
/// engine's mode, not the content itself. Modes are no longer a fixed
/// four: any mode the user adds renders here too, through whichever of the
/// four content shapes it was given. The content itself ("Today's deep
/// work" and friends) is real now too — it comes from `AppState.tasks`,
/// not a hardcoded string.
///
/// The hero card and metrics strip below the app bar follow the same
/// layout language as the DayOne_Review2_Demo browser prototype — an
/// eyebrow label, a big heading, a bordered "currently active" panel, and
/// a row of stat tiles — but every number in them is real: the mode's
/// actual environment targets, the real pending-task count, the real
/// count of learned corrections.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final mode = state.currentMode;
    final notifCount = state.preference == null
        ? 0
        : (6 * (1 - state.preference!.minimalNotifications)).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('DayOne'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task_outlined),
            tooltip: 'Add something to work on',
            onPressed: () => _promptAddTask(context),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              if (notifCount > 0)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$notifCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.pendingTransition != null) ...[
                _PendingTransitionBanner(pending: state.pendingTransition!),
                const SizedBox(height: 16),
              ],
              _ModeBanner(mode: mode),
              const SizedBox(height: 16),
              _MetricsStrip(mode: mode),
              const SizedBox(height: 24),
              _ModeContent(mode: mode),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared "add a task" sheet — the one entry point for real content,
/// reachable from every mode's app bar.
void _promptAddTask(BuildContext context) {
  final titleController = TextEditingController();
  final noteController = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What are you working on?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 16),
          TextField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                sheetContext.read<AppState>().addTask(titleController.text, note: noteController.text);
                Navigator.of(sheetContext).pop();
              },
              child: const Text('Add'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PendingTransitionBanner extends StatelessWidget {
  final PendingTransition pending;
  const _PendingTransitionBanner({required this.pending});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final remaining = pending.remaining(state.effectiveNow);
    final mm = remaining.inMinutes.toString().padLeft(1, '0');
    final ss = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Switching to ${pending.to.label} in $mm:$ss',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(pending.reason, style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: () => state.cancelPendingTransition(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () => state.applyPendingTransitionNow(),
                child: const Text('Apply now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The "hero" card: an eyebrow label, a heading, a short explanation, and
/// the Switch/Why actions on the left; a bordered "currently active" panel
/// with the mode name, tagline and the engine's confidence score on the
/// right. Collapses to a single column on narrow windows — the same
/// breakpoint behaviour as the demo's `.hero-grid`.
class _ModeBanner extends StatelessWidget {
  final Mode mode;
  const _ModeBanner({required this.mode});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final confidence = state.decision?.confidences[mode.id];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 620;

          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const EyebrowLabel('Your local personalization layer'),
              const SizedBox(height: 8),
              const Text(
                'Your day, shaped by you.',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'DayOne combined your preferences with the current context to pick '
                '${mode.label} — adjust it any time, or see why it was picked.',
                style: const TextStyle(color: AppColors.inkSoft, height: 1.45),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton(
                    onPressed: () => _showSwitchSheet(context),
                    child: const Text('Switch mode'),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WhyThisModeScreen()),
                    ),
                    child: const Text('Why this mode?'),
                  ),
                ],
              ),
            ],
          );

          final right = Container(
            width: stacked ? double.infinity : 230,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'CURRENTLY ACTIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  mode.label,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  mode.tagline,
                  style: const TextStyle(color: AppColors.inkSoft, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Confidence', style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                    Text(
                      confidence == null ? '—' : '${(confidence * 100).round()}% score share',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent),
                    ),
                  ],
                ),
              ],
            ),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [left, const SizedBox(height: 16), right],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 20),
              right,
            ],
          );
        },
      ),
    );
  }

  void _showSwitchSheet(BuildContext context) {
    final state = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // DraggableScrollableSheet instead of a plain Column: the mode list
      // (now 7, not the original 4) can be taller than the default bottom
      // sheet height, and a non-scrollable Column just overflows off the
      // bottom instead of scrolling. This lets the sheet open tall and
      // scroll the rest, and the user can still drag it further open.
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) => SafeArea(
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Not quite right? Pick a mode — DayOne learns from this.',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
              ),
            ),
            ...state.modes.map((m) {
              final applied = state.describeEnvironment(m);
              return ListTile(
                title: Text(m.label),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.tagline, style: const TextStyle(color: AppColors.inkSoft)),
                      if (applied.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            applied.join(' · '),
                            style: const TextStyle(color: AppColors.accent, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
                isThreeLine: applied.isNotEmpty,
                trailing: m.id == state.currentMode.id
                    ? const Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  state.recordOverride(m.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        applied.isEmpty
                            ? 'Switched to ${m.label}.'
                            : 'Switched to ${m.label} — ${applied.join(', ')}.',
                      ),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// The metrics strip under the hero — mirrors the demo dashboard's
/// `.metrics` row of four tiles, but every value here is a real number
/// pulled from `AppState` and the active mode's `EnvironmentProfile`,
/// not a simulated one.
class _MetricsStrip extends StatelessWidget {
  final Mode mode;
  const _MetricsStrip({required this.mode});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final env = mode.environment;
    final pendingCount = state.pendingTasks.length;
    final updateCount = state.model?.updateCount ?? 0;
    final opens = [
      if (env?.openUrl != null) env!.openUrl!,
      if (env?.aiTutorEnabled == true && state.aiTutor.enabled) 'ChatGPT',
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        MetricTile(
          icon: Icons.brightness_6_outlined,
          label: 'Target brightness',
          value: env?.brightness != null
              ? '${env!.brightness}%'
              : (mode.adaptsBrightness ? 'Learning…' : '—'),
          note: mode.adaptsBrightness ? 'Learned from habit' : 'Applied to this laptop',
        ),
        MetricTile(
          icon: Icons.volume_up_outlined,
          label: 'Target volume',
          value: env?.volume != null ? '${env!.volume}%' : '—',
          note: 'Applied to this laptop',
        ),
        MetricTile(
          icon: Icons.open_in_new,
          label: 'Opens',
          value: opens.isEmpty ? '—' : '${opens.length}',
          note: opens.isEmpty ? 'Nothing configured' : opens.join(', '),
        ),
        MetricTile(
          icon: Icons.checklist_outlined,
          label: 'Tasks waiting',
          value: '$pendingCount',
          note: "In this mode's queue",
        ),
        MetricTile(
          icon: Icons.auto_graph_outlined,
          label: 'Learned corrections',
          value: '$updateCount',
          note: 'Shaping the model',
        ),
      ],
    );
  }
}

/// The actual adaptive content. Dispatches on the mode's *layout*, not its
/// identity, so a custom mode renders using whichever of the four content
/// shapes it was assigned.
class _ModeContent extends StatelessWidget {
  final Mode mode;
  const _ModeContent({required this.mode});

  @override
  Widget build(BuildContext context) {
    // AI Mode is dispatched on identity, not layout — same special-case
    // pattern as Study Mode's `aiTutorEnabled` side-effect, just with its
    // own full panel instead of a background URL launch. See `AppState.askAi`.
    if (mode.id == 'ai') return const _AiModeLayout();
    switch (mode.layout) {
      case LayoutArchetype.quick:
        return const _QuickLayout();
      case LayoutArchetype.guided:
        return const _GuidedLayout();
      case LayoutArchetype.browse:
        return const _BrowseLayout();
      case LayoutArchetype.minimal:
        return const _MinimalLayout();
    }
  }
}

/// AI MODE — the one mode that asks a real cloud AI something, instead of
/// just reflecting local state. Builds its "explain it my way" instruction
/// from the user's own onboarding answers (see `AppState.askAi`), so two
/// different users typing the exact same question here get differently
/// written answers — one maybe concise and plain, another detailed and
/// descriptive — without either of them having to say so again.
class _AiModeLayout extends StatefulWidget {
  const _AiModeLayout();

  @override
  State<_AiModeLayout> createState() => _AiModeLayoutState();
}

class _AiModeLayoutState extends State<_AiModeLayout> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _answer;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask(AppState state) async {
    final topic = _controller.text.trim();
    if (topic.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _answer = null;
    });
    try {
      final result = await state.askAi(topic);
      if (!mounted) return;
      setState(() => _answer = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _stylePreview(AppState state) {
    final p = state.preference;
    if (p == null) return 'default style';
    final bits = <String>[
      p.conciseness > 0.5 ? 'concise' : 'detailed',
      p.visual > 0.5 ? 'visual' : 'plain',
      p.guided > 0.5 ? 'step-by-step' : 'exploratory',
    ];
    return bits.join(', ');
  }

  void _promptApiKey(BuildContext context, AppState state) {
    final keyController = TextEditingController(text: state.claudeSettings.apiKey);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Claude API key',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 6),
            const Text(
              'Stored only on this device — never bundled into the app, never '
              'sent anywhere except straight to Anthropic’s API.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: keyController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'sk-ant-...'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  state.updateClaudeSettings(ClaudeSettings(apiKey: keyController.text.trim()));
                  Navigator.of(sheetContext).pop();
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hasKey = state.claudeSettings.hasKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Ask DayOne's AI",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Explained your way — built from your onboarding preferences '
                  '(${_stylePreview(state)}), sent to Claude as a system prompt.',
                  style: const TextStyle(color: AppColors.inkSoft, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                if (!hasKey) ...[
                  const Text(
                    'Add your Claude API key to turn this on.',
                    style: TextStyle(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _promptApiKey(context, state),
                    child: const Text('Add API key'),
                  ),
                ] else ...[
                  TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'What do you want explained?',
                      hintText: 'e.g. how does a TCP handshake work?',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _loading ? null : () => _ask(state),
                        child: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Explain this'),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () => _promptApiKey(context, state),
                        child: const Text('Change key'),
                      ),
                    ],
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
        if (_answer != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                _answer!,
                style: const TextStyle(color: AppColors.ink, height: 1.5),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// GUIDED — detailed, step-by-step. Longest content of the four. "Today's
/// deep work" is the top pending task; the numbered steps below it are the
/// next couple behind it — real content, not placeholder copy.
class _GuidedLayout extends StatelessWidget {
  const _GuidedLayout();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pending = state.pendingTasks;
    final top = pending.isNotEmpty ? pending.first : null;
    final steps = pending.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Today\'s deep work',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text(
                  top == null
                      ? 'Nothing queued yet. Add what you\'re working on and '
                          'this mode will walk you through it one step at a '
                          'time instead of rushing you.'
                      : (top.note.isEmpty ? top.title : '${top.title} — ${top.note}'),
                  style: const TextStyle(color: AppColors.inkSoft, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...steps.asMap().entries.map((e) => _GuidedStep(task: e.value, index: e.key + 1)),
        if (pending.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: () => _promptAddTask(context),
              icon: const Icon(Icons.add),
              label: const Text('Add something to work on'),
            ),
          ),
      ],
    );
  }
}

class _GuidedStep extends StatelessWidget {
  final TaskItem task;
  final int index;
  const _GuidedStep({required this.task, required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: AppColors.accentLight,
          foregroundColor: AppColors.ink,
          child: Text('$index'),
        ),
        title: Text(task.title),
        subtitle: Text(
          task.note.isEmpty ? 'Guided step — take your time' : task.note,
          style: const TextStyle(color: AppColors.inkSoft),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.check_circle_outline),
          color: AppColors.accent,
          onPressed: () => context.read<AppState>().toggleTask(task.id),
        ),
      ),
    );
  }
}

/// QUICK — short, visual, low-friction. Acts on the same task queue, just
/// through three big buttons instead of a detailed list.
class _QuickLayout extends StatelessWidget {
  const _QuickLayout();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pending = state.pendingTasks;
    final top = pending.isNotEmpty ? pending.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pending.isEmpty
              ? 'All caught up.'
              : '${pending.length} thing${pending.length == 1 ? '' : 's'} waiting — kept this short.',
          style: const TextStyle(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _QuickTile(
              icon: Icons.bolt,
              label: 'Catch up',
              onTap: () => _showCatchUpSheet(context, pending),
            ),
            _QuickTile(
              icon: Icons.check_circle_outline,
              label: 'Mark done',
              onTap: top == null ? null : () => state.toggleTask(top.id),
            ),
            _QuickTile(
              icon: Icons.schedule,
              label: 'Snooze',
              onTap: top == null ? null : () => state.snoozeTask(top.id),
            ),
          ],
        ),
      ],
    );
  }

  void _showCatchUpSheet(BuildContext context, List<TaskItem> pending) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: pending.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Text('Nothing waiting.', style: TextStyle(color: AppColors.inkSoft)),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: pending
                    .map((t) => ListTile(
                          title: Text(t.title),
                          subtitle: t.note.isEmpty ? null : Text(t.note),
                          trailing: IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            onPressed: () => sheetContext.read<AppState>().toggleTask(t.id),
                          ),
                        ))
                    .toList(),
              ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _QuickTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Opacity(
          opacity: disabled ? 0.4 : 1.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30, color: AppColors.accent),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

/// BROWSE — calm, but independent. Every task as a browsable tile, no
/// hand-holding, plus a tile to add more.
class _BrowseLayout extends StatelessWidget {
  const _BrowseLayout();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tasks = state.tasks;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.6,
      children: [
        ...tasks.map((t) => Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => state.toggleTask(t.id),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      t.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: t.done ? AppColors.inkSoft : AppColors.ink,
                        decoration: t.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ),
              ),
            )),
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _promptAddTask(context),
            child: const Center(
              child: Icon(Icons.add, color: AppColors.accent, size: 28),
            ),
          ),
        ),
      ],
    );
  }
}

/// MINIMAL — calm and quiet, as few elements as possible.
class _MinimalLayout extends StatelessWidget {
  const _MinimalLayout();

  @override
  Widget build(BuildContext context) {
    final pendingCount = context.watch<AppState>().pendingTasks.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.spa_outlined, size: 56, color: AppColors.accent),
            const SizedBox(height: 16),
            const Text(
              'Nothing urgent.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              pendingCount == 0
                  ? 'Notifications held back until you open the app again.'
                  : '$pendingCount thing${pendingCount == 1 ? '' : 's'} waiting, '
                      'but held back until you open the app again.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
