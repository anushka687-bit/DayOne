import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/mode.dart';
import '../models/pending_transition.dart';
import '../models/task_item.dart';
import '../theme/app_theme.dart';
import 'why_this_mode_screen.dart';

/// The screen judges actually watch change. Same data, same user — the
/// LAYOUT, content length, and interaction style change based on the
/// engine's mode, not the content itself. Modes are no longer a fixed
/// four: any mode the user adds renders here too, through whichever of the
/// four content shapes it was given. The content itself ("Today's deep
/// work" and friends) is real now too — it comes from `AppState.tasks`,
/// not a hardcoded string.
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.pendingTransition != null) ...[
                _PendingTransitionBanner(pending: state.pendingTransition!),
                const SizedBox(height: 16),
              ],
              _ModeBanner(mode: mode),
              const SizedBox(height: 24),
              Expanded(child: _ModeContent(mode: mode)),
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

class _ModeBanner extends StatelessWidget {
  final Mode mode;
  const _ModeBanner({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode.label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mode.tagline,
                  style: const TextStyle(color: AppColors.paper, fontSize: 14),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showSwitchSheet(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.paper),
            child: const Text('Switch'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WhyThisModeScreen()),
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Why?'),
          ),
        ],
      ),
    );
  }

  void _showSwitchSheet(BuildContext context) {
    final state = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            ...state.modes.map((m) => ListTile(
                  title: Text(m.label),
                  subtitle: Text(m.tagline, style: const TextStyle(color: AppColors.inkSoft)),
                  trailing: m.id == state.currentMode.id
                      ? const Icon(Icons.check, color: AppColors.accent)
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    state.recordOverride(m.id);
                  },
                )),
            const SizedBox(height: 12),
          ],
        ),
      ),
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

    return ListView(
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }
}
