import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../engine/launch_learner.dart';
import '../engine/routine_learner.dart';
import '../models/pending_transition.dart';
import '../theme/app_theme.dart';

/// Full transparency on the time-based side of the engine: every raw
/// observation DayOne has logged, which of those have been promoted into
/// an actual routine, and what actually happened each time a change was
/// proposed or made. "Why this mode?" shows a short version of the first
/// two; this is the whole thing.
///
/// Also where the time-of-day *launch* learning lives — "around 6:00pm,
/// Spotify usually opens" — a companion to mode routines above, built on
/// the same "seen it enough times" idea but for launch targets instead of
/// modes.
class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  final _logController = TextEditingController();

  @override
  void dispose() {
    _logController.dispose();
    super.dispose();
  }

  Future<void> _logNow() async {
    final target = _logController.text.trim();
    if (target.isEmpty) return;
    await context.read<AppState>().logTimedLaunch(target);
    _logController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged "$target" for right now.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final decided = state.routines.allRoutines();
    final observations = state.routines.allObservations();
    final log = state.transitionLog;
    final learnedLaunches = state.launches.allTimeLaunches();
    final launchObservations = state.launches.allTimeObservations();

    String labelFor(String modeId) {
      final matches = state.modes.where((m) => m.id == modeId);
      return matches.isNotEmpty ? matches.first.label : modeId;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Routines')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _SectionHeader('LEARNED ROUTINES'),
          const SizedBox(height: 8),
          Text(
            'Confident enough (seen ${RoutineLearner.confidenceThreshold}+ times at the same '
            'day and time) that DayOne will propose switching to these on its own, even with '
            'no sensor change.',
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (decided.isEmpty)
            const _EmptyNote('None yet.')
          else
            ...decided.map((r) => _ObservationCard(label: labelFor(r.modeId), routine: r, active: true)),

          const SizedBox(height: 28),
          const _SectionHeader('ALL OBSERVATIONS'),
          const SizedBox(height: 8),
          const Text(
            'Every (day, time, mode) combination DayOne has ever seen — including the ones '
            'still below the confidence bar above.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (observations.isEmpty)
            const _EmptyNote(
              'Nothing recorded yet. Accept a mode change, or use "Simulate a moment" on '
              'the Context tab, to start building history.',
            )
          else
            ...observations.map((r) => _ObservationCard(
                  label: labelFor(r.modeId),
                  routine: r,
                  active: r.confidence >= RoutineLearner.confidenceThreshold,
                )),

          const SizedBox(height: 28),
          const _SectionHeader('LEARNED LAUNCHES (TIME-BASED)'),
          const SizedBox(height: 8),
          Text(
            'Same idea, for what gets opened instead of which mode — seen '
            '${LaunchLearner.confidenceThreshold}+ times around the same time of day, '
            'independent of mode. E.g. "6:00pm → open Spotify."',
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _logController,
                  decoration: const InputDecoration(
                    labelText: 'I just opened…',
                    hintText: 'spotify: or a URL',
                  ),
                  onSubmitted: (_) => _logNow(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _logNow, child: const Text('Log now')),
            ],
          ),
          const SizedBox(height: 16),
          if (learnedLaunches.isEmpty)
            const _EmptyNote('None yet.')
          else
            ...learnedLaunches.map((l) => _LaunchCard(launch: l, active: true)),

          const SizedBox(height: 20),
          const Text(
            'ALL LAUNCH OBSERVATIONS',
            style: TextStyle(
              fontFamily: 'monospace',
              letterSpacing: 2,
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          if (launchObservations.isEmpty)
            const _EmptyNote('Nothing logged yet.')
          else
            ...launchObservations.take(10).map((l) => _LaunchCard(
                  launch: l,
                  active: l.confidence >= LaunchLearner.confidenceThreshold,
                )),

          const SizedBox(height: 28),
          const _SectionHeader('RECENT DECISIONS'),
          const SizedBox(height: 8),
          const Text(
            'What actually happened each time a mode change was proposed, applied, '
            'cancelled, or made directly.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (log.isEmpty)
            const _EmptyNote('No decisions yet.')
          else
            ...log.map((entry) => _DecisionCard(entry: entry)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'monospace',
        letterSpacing: 2,
        color: AppColors.accent,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.4));
  }
}

class _ObservationCard extends StatelessWidget {
  final String label;
  final LearnedRoutine routine;
  final bool active;
  const _ObservationCard({required this.label, required this.routine, required this.active});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(active ? Icons.schedule : Icons.hourglass_empty, color: AppColors.accent),
        title: Text('$label around ${routine.timeLabel}'),
        subtitle: Text(
          '${routine.weekdayLabel}s — seen ${routine.confidence} '
          'time${routine.confidence == 1 ? '' : 's'}',
          style: const TextStyle(color: AppColors.inkSoft),
        ),
        trailing: _Pill(
          text: active ? 'Active routine' : 'Still learning',
          color: active ? AppColors.accent : AppColors.inkSoft,
        ),
      ),
    );
  }
}

class _LaunchCard extends StatelessWidget {
  final LearnedTimeLaunch launch;
  final bool active;
  const _LaunchCard({required this.launch, required this.active});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(active ? Icons.open_in_new : Icons.hourglass_empty, color: AppColors.accent),
        title: Text('Open "${launch.target}" around ${launch.timeLabel}'),
        subtitle: Text(
          '${launch.weekdayLabel}s — seen ${launch.confidence} '
          'time${launch.confidence == 1 ? '' : 's'}',
          style: const TextStyle(color: AppColors.inkSoft),
        ),
        trailing: _Pill(
          text: active ? 'Active' : 'Still learning',
          color: active ? AppColors.accent : AppColors.inkSoft,
        ),
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  final TransitionLogEntry entry;
  const _DecisionCard({required this.entry});

  IconData get _icon {
    switch (entry.outcome) {
      case 'applied':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'override':
        return Icons.swap_horiz;
      default:
        return Icons.circle_outlined;
    }
  }

  String get _pillText {
    switch (entry.outcome) {
      case 'applied':
        return 'Applied';
      case 'cancelled':
        return 'Cancelled';
      case 'override':
        return 'Manual';
      default:
        return entry.outcome;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(_icon, color: AppColors.accent),
        title: Text('${entry.fromLabel} → ${entry.toLabel}'),
        subtitle: Text(
          '${entry.reason}\n${_formatTime(entry.at)}',
          style: const TextStyle(color: AppColors.inkSoft),
        ),
        isThreeLine: true,
        trailing: _Pill(text: _pillText, color: AppColors.inkSoft),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final period = t.hour >= 12 ? 'PM' : 'AM';
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
