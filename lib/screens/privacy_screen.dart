import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme/app_theme.dart';
import 'welcome_screen.dart';

/// The privacy guarantee, made inspectable and reversible: shows exactly
/// what's stored, in plain language — including the learned model and
/// routines, not just the onboarding answers — plus exactly what, if
/// anything, has been sent outside the device, and a Delete button that
/// actually deletes all of it, not a cosmetic reset.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete my profile?'),
        content: const Text(
          'This permanently removes your preference profile, learned '
          'weights, learned routines, and custom modes from this device. '
          'The app will return to the generic, first-run experience.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AppState>().deleteProfile();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.preference;
    final model = state.model;
    final routineCount = state.routines.allRoutines().length;
    final customModeCount = state.modes.where((m) => !m.builtIn).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Center')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _Guarantee(icon: Icons.cloud_off, text: 'No cloud profile'),
          const _Guarantee(icon: Icons.history_toggle_off, text: 'No account history'),
          const _Guarantee(icon: Icons.visibility_off_outlined, text: 'No third-party tracking'),
          const _Guarantee(icon: Icons.wifi_off, text: 'Works with no internet connection'),
          const SizedBox(height: 28),
          const Text(
            'WHAT IS STORED ON THIS DEVICE',
            style: TextStyle(
              fontFamily: 'monospace',
              letterSpacing: 1.5,
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          if (profile == null)
            const Text('Nothing yet — no profile has been created.',
                style: TextStyle(color: AppColors.inkSoft))
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _ProfileRow('Prefers concise information', profile.conciseness),
                    _ProfileRow('Prefers visual content', profile.visual),
                    _ProfileRow('Prefers guided interaction', profile.guided),
                    _ProfileRow('Prefers minimal notifications', profile.minimalNotifications),
                    const Divider(height: 28, color: AppColors.line),
                    _CountRow('Learned corrections applied', model?.updateCount ?? 0),
                    _CountRow('Modes (built-in + custom)', state.modes.length),
                    _CountRow('Custom modes you added', customModeCount),
                    _CountRow('Learned time-of-day routines', routineCount),
                    _CountRow('Modes with a learned default launch',
                        state.modes.where((m) => state.launches.learnedForMode(m.id) != null).length),
                    _CountRow('Learned time-of-day launches', state.launches.allTimeLaunches().length),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 28),
          const Text(
            'CONNECTED INTEGRATIONS',
            style: TextStyle(
              fontFamily: 'monospace',
              letterSpacing: 1.5,
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'A mode can be wired to fire a scene on a smart-home system '
            '(Alexa Routine, Home Assistant, etc.) from the Modes tab. Only '
            'an opaque scene id ever crosses that line — never your '
            'preferences or sensor readings.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          ...state.adapters.values.map((adapter) {
            final count = state.triggerLog.where((e) => e.adapterLabel == adapter.label).length;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hub_outlined, size: 18, color: AppColors.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(adapter.label,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      count == 0
                          ? 'No scenes fired yet.'
                          : '$count scene trigger${count == 1 ? '' : 's'} fired so far.',
                      style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 28),
          const Text(
            'AI MODE',
            style: TextStyle(
              fontFamily: 'monospace',
              letterSpacing: 1.5,
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.claudeSettings.hasKey
                ? 'A Claude API key is saved on this device. AI Mode is the one '
                    'exception to "nothing leaves the device": whatever you type '
                    'there, plus a short style instruction built from your '
                    'onboarding answers, is sent to Anthropic\'s API to get an '
                    'answer. Nothing else — no sensor data, no learned model — '
                    'is ever included.'
                : 'No Claude API key saved — AI Mode is off. If you add one, '
                    'only what you type there (plus a short style instruction '
                    'from your onboarding answers) is ever sent to Anthropic\'s '
                    'API — nothing else leaves this device.',
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: profile == null ? null : () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Delete My Profile', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Guarantee extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Guarantee({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final double value;
  const _ProfileRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.ink))),
          Text('${(value * 100).round()}%',
              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  final String label;
  final int value;
  const _CountRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.ink))),
          Text('$value',
              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
