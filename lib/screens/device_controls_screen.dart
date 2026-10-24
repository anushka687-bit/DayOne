import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemSound, SystemSoundType;
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/panel.dart';

/// The direct analogue of the demo's "Device controls" page — laid out to
/// match it panel-for-panel (header bar, brightness panel, volume panel,
/// mode-to-action policy) — except these sliders drive the same real
/// adapters a mode change uses (`WindowsBrightnessAdapter` /
/// `WindowsVolumeAdapter`), so moving them actually dims this laptop's
/// screen and changes its system volume. The demo's controls only ever
/// touched a browser tab; these touch the OS, so the copy here says that
/// plainly rather than repeating the demo's "browser tab only" claim.
class DeviceControlsScreen extends StatefulWidget {
  const DeviceControlsScreen({super.key});

  @override
  State<DeviceControlsScreen> createState() => _DeviceControlsScreenState();
}

class _DeviceControlsScreenState extends State<DeviceControlsScreen> {
  double _brightness = 68;
  double _volume = 24;
  bool _seeded = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!_seeded) {
      final env = state.currentMode.environment;
      _brightness = (env?.brightness ?? 68).toDouble().clamp(10, 100).toDouble();
      _volume = (env?.volume ?? 24).toDouble().clamp(0, 100).toDouble();
      _seeded = true;
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DemoHeaderBar(
                heading: 'Control the experience.',
                onReset: () => _confirmReset(context),
              ),
              const SizedBox(height: 28),
              const EyebrowLabel('Actual device actions'),
              const SizedBox(height: 10),
              const Text(
                'These controls make real changes on this computer, through the '
                'same Windows adapters a mode change uses — not a simulated '
                'preview. They do not touch anything outside this device.',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 10),
              const Text(
                'Device controls',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final sideBySide = constraints.maxWidth >= 760;
                  final brightnessPanel = _BrightnessPanel(
                    value: _brightness,
                    onChanged: (v) => setState(() => _brightness = v),
                    onChangeEnd: (v) => state.windowsBrightnessAdapter.fire('brightness:${v.round()}'),
                    onDim: () => _setBrightness(state, _brightness - 10),
                    onBrighten: () => _setBrightness(state, _brightness + 10),
                    onReset: () => _setBrightness(state, 68),
                  );
                  final volumePanel = _VolumePanel(
                    value: _volume,
                    onChanged: (v) => setState(() => _volume = v),
                    onChangeEnd: (v) => state.windowsVolumeAdapter.fire('volume:${v.round()}'),
                    onPlayTestTone: () => SystemSound.play(SystemSoundType.click),
                    onReset: () => _setVolume(state, 24),
                  );
                  if (sideBySide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: brightnessPanel),
                        const SizedBox(width: 16),
                        Expanded(child: volumePanel),
                      ],
                    );
                  }
                  return Column(
                    children: [brightnessPanel, const SizedBox(height: 16), volumePanel],
                  );
                },
              ),
              const SizedBox(height: 16),
              _ModeToActionPolicy(state: state),
            ],
          ),
        ),
      ),
    );
  }

  void _setBrightness(AppState state, double value) {
    final clamped = value.clamp(10, 100).toDouble();
    setState(() => _brightness = clamped);
    state.windowsBrightnessAdapter.fire('brightness:${clamped.round()}');
  }

  void _setVolume(AppState state, double value) {
    final clamped = value.clamp(0, 100).toDouble();
    setState(() => _volume = clamped);
    state.windowsVolumeAdapter.fire('volume:${clamped.round()}');
  }
}

/// Shared with `SmartEnvironmentScreen` by duplication-on-purpose: each
/// screen owns its own small copy so neither depends on the other.
Future<void> _confirmReset(BuildContext context) async {
  final state = context.read<AppState>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Reset this device?'),
      content: const Text(
        'This clears your preference profile, modes, routines, and the '
        'learned model — all local to this device. This cannot be undone.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Reset')),
      ],
    ),
  );
  if (confirmed == true) {
    await state.deleteProfile();
  }
}

void _applyRecommended(BuildContext context, AppState state) {
  if (state.pendingTransition != null) {
    state.applyPendingTransitionNow();
    return;
  }
  if (state.decision != null && state.decision!.modeId != state.currentMode.id) {
    state.recordOverride(state.decision!.modeId);
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Already on the recommended mode.')),
  );
}

class _BrightnessPanel extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback onDim;
  final VoidCallback onBrighten;
  final VoidCallback onReset;

  const _BrightnessPanel({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onDim,
    required this.onBrighten,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      title: 'Screen brightness',
      subtitle: "Sets this laptop's display via a WMI call.",
      trailing: const AppChip('REAL · WINDOWS', color: AppColors.accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Brightness',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 13)),
                    Text('${value.round()}%',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent, fontSize: 13)),
                  ],
                ),
                Slider(value: value, min: 10, max: 100, onChanged: onChanged, onChangeEnd: onChangeEnd),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Dim', style: TextStyle(fontSize: 10, color: AppColors.inkSoft)),
                    Text('Bright', style: TextStyle(fontSize: 10, color: AppColors.inkSoft)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(onPressed: onDim, child: const Text('− Dim')),
              OutlinedButton(onPressed: onBrighten, child: const Text('+ Brighten')),
              TextButton(onPressed: onReset, child: const Text('Reset')),
            ],
          ),
          const SizedBox(height: 12),
          const NoteBox(
            'Only affects built-in panels that expose WMI brightness '
            'control; some external monitors silently ignore it.',
          ),
        ],
      ),
    );
  }
}

class _VolumePanel extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback onPlayTestTone;
  final VoidCallback onReset;

  const _VolumePanel({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onPlayTestTone,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      title: 'System volume',
      subtitle: 'Approximate — simulated hardware key presses.',
      trailing: const AppChip('REAL · APPROX.', color: AppColors.accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LevelDots(value),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Demo audio level',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 13)),
                    Text('${value.round()}%',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent, fontSize: 13)),
                  ],
                ),
                Slider(value: value, min: 0, max: 100, onChanged: onChanged, onChangeEnd: onChangeEnd),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Mute', style: TextStyle(fontSize: 10, color: AppColors.inkSoft)),
                    Text('Full', style: TextStyle(fontSize: 10, color: AppColors.inkSoft)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onPlayTestTone,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('Play test tone'),
              ),
              TextButton(onPressed: onReset, child: const Text('Reset')),
            ],
          ),
          const SizedBox(height: 12),
          const NoteBox(
            "Windows has no one-line call for an absolute volume level, "
            "so this lands close to the target, not exact.",
          ),
        ],
      ),
    );
  }
}

/// The audio-level dot/bar strip above the volume slider — mirrors the
/// demo's little "•••I•••I•••" ticker row. Purely decorative, driven by
/// the real target percentage.
class _LevelDots extends StatelessWidget {
  final double percent;
  const _LevelDots(this.percent);

  @override
  Widget build(BuildContext context) {
    const count = 28;
    final lit = (count * (percent.clamp(0, 100) / 100)).round();
    return SizedBox(
      height: 26,
      child: Row(
        children: List.generate(count, (i) {
          final on = i < lit;
          return Expanded(
            child: Align(
              alignment: Alignment.center,
              child: Container(
                height: on ? 12 : 5,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: on ? AppColors.accent : AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Mirrors the demo's two-column "Mode-to-action policy" panel: what
/// DayOne recommends on the left, the safety boundary on the right, with
/// a real "Apply recommended mode" action above both.
class _ModeToActionPolicy extends StatelessWidget {
  final AppState state;
  const _ModeToActionPolicy({required this.state});

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      title: 'Mode-to-action policy',
      subtitle: 'Review the actions DayOne proposes, then apply them intentionally.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () => _applyRecommended(context, state),
              child: const Text('Apply recommended mode'),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 560;
              final left = _PolicyColumn(
                title: 'Recommended device behaviour',
                rows: [
                  ('Status', state.hasProfile ? 'Learning from corrections' : 'Not set up'),
                  ('Control scope', 'This device only'),
                  ('Screen brightness', 'Managed by DayOne'),
                  ('System volume', 'Managed by DayOne'),
                ],
              );
              final right = const _PolicyColumn(
                title: 'Safety boundary',
                rows: [
                  ('Physical screen backlight', 'Changed — real WMI call'),
                  ('System volume', 'Changed — approximate'),
                  ('Appliances', 'Simulator or ESP32 only'),
                  ('Network / cloud', 'Not required'),
                ],
              );
              if (sideBySide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: left), const SizedBox(width: 20), Expanded(child: right)],
                );
              }
              return Column(children: [left, const SizedBox(height: 16), right]);
            },
          ),
        ],
      ),
    );
  }
}

class _PolicyColumn extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;
  const _PolicyColumn({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 13)),
        const SizedBox(height: 10),
        for (final r in rows) _PolicyRow(r.$1, r.$2),
      ],
    );
  }
}

class _PolicyRow extends StatelessWidget {
  final String label;
  final String value;
  const _PolicyRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.inkSoft, fontSize: 12))),
          Text(value, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}
