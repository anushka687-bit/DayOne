import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme/app_theme.dart';

/// Makes the engine's decision inspectable instead of a black box — and,
/// now that the engine learns, shows that it's learning: the weights per
/// mode, how many corrections have shaped them, learned routines, and the
/// (simulated) scenes that would have fired outside the app.
class WhyThisModeScreen extends StatelessWidget {
  const WhyThisModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final decision = state.decision;
    final model = state.model;

    return Scaffold(
      appBar: AppBar(title: const Text('Why this mode?')),
      body: decision == null || model == null
          ? const Center(child: Text('No decision yet.'))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'ENGINE SCORES',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                ...state.modes.map((mode) {
                  final confidence = decision.confidences[mode.id] ?? 0;
                  final isWinner = mode.id == decision.modeId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              mode.label,
                              style: TextStyle(
                                fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
                                color: isWinner ? AppColors.ink : AppColors.inkSoft,
                              ),
                            ),
                            Text(
                              '${(confidence * 100).round()}%',
                              style: TextStyle(
                                fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
                                color: isWinner ? AppColors.accent : AppColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: confidence.clamp(0, 1),
                            minHeight: 10,
                            backgroundColor: AppColors.line,
                            color: isWinner ? AppColors.accent : AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                const Text(
                  'REASONING',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: decision.reasons
                          .map((r) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(r,
                                    style: const TextStyle(
                                        color: AppColors.inkSoft, height: 1.4)),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'LEARNED ROUTINES',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                if (state.routines.allRoutines().isEmpty)
                  const Text(
                    'None yet — DayOne needs to see the same mode happen at '
                    'the same time of day a few times before it counts as a '
                    'routine. Try the time presets on the Context tab.',
                    style: TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.4),
                  )
                else
                  ...state.routines.allRoutines().take(5).map((r) {
                    final matches = state.modes.where((m) => m.id == r.modeId);
                    final label = matches.isNotEmpty ? matches.first.label : r.modeId;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.schedule, color: AppColors.accent),
                        title: Text('$label around ${r.timeLabel}'),
                        subtitle: Text(
                          '${r.weekdayLabel}s — seen ${r.confidence} time${r.confidence == 1 ? '' : 's'}',
                          style: const TextStyle(color: AppColors.inkSoft),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                const Text(
                  'ENVIRONMENT TRIGGERS SENT',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                if (state.triggerLog.isEmpty)
                  const Text(
                    'None yet. A mode with a scene attached (Modes tab) would '
                    'fire one opaque trigger here — never preference or '
                    'sensor data — when it becomes active.',
                    style: TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.4),
                  )
                else
                  ...state.triggerLog.take(5).map((entry) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const Icon(Icons.bolt, color: AppColors.accent),
                          title: Text('Fired scene "${entry.sceneId}"'),
                          subtitle: Text(
                            _formatTime(entry.at),
                            style: const TextStyle(color: AppColors.inkSoft),
                          ),
                        ),
                      )),
                const SizedBox(height: 16),
                Text(
                  'Preference and context are never combined anywhere else. '
                  'This screen, and this screen only, is where the decision '
                  'gets made — and the weights it shows have moved '
                  '${model.updateCount} time${model.updateCount == 1 ? '' : 's'} '
                  'from your corrections, entirely on this device.',
                  style: const TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.5),
                ),
              ],
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
