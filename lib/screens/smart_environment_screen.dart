import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/panel.dart';

/// The direct analogue of the demo's "Smart environment" page, laid out
/// to match it panel-for-panel: a header bar, a "Hardware connection"
/// panel for an ESP32-over-serial link, then the appliance grid (room
/// light, desk fan, cooling, night light) as toggle + level cards.
///
/// No ESP32 serial driver is wired into this build yet (see the project
/// README's stated gaps), so — honestly, same as the demo — the "Connect"
/// action here explains that rather than pretending a link exists; the
/// appliance cards themselves stay a local simulator, useful for
/// reviewing what a mode's environment preset *would* set in the room.
class SmartEnvironmentScreen extends StatefulWidget {
  const SmartEnvironmentScreen({super.key});

  @override
  State<SmartEnvironmentScreen> createState() => _SmartEnvironmentScreenState();
}

class _ApplianceState {
  final bool on;
  final double level;
  const _ApplianceState({required this.on, required this.level});
}

class _SmartEnvironmentScreenState extends State<SmartEnvironmentScreen> {
  final Map<String, _ApplianceState> _devices = {
    'light': const _ApplianceState(on: true, level: 72),
    'fan': const _ApplianceState(on: true, level: 35),
    'cooling': const _ApplianceState(on: false, level: 24),
    'night': const _ApplianceState(on: false, level: 18),
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DemoHeaderBar(
                heading: 'Your environment, connected.',
                onReset: () => _confirmReset(context),
              ),
              const SizedBox(height: 28),
              const EyebrowLabel('Connected environment demo'),
              const SizedBox(height: 10),
              const Text(
                'These appliance cards are simulated until a compatible board '
                "(an ESP32, say) is wired in — DayOne's environment presets can "
                'still be reviewed and tried here even though nothing physical '
                'is connected yet.',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 10),
              const Text(
                'Smart environment',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 20),
              _HardwareConnectionPanel(onConnect: _showNoDriverNotice, onSync: _showNoDriverNotice),
              const SizedBox(height: 16),
              AppPanel(
                title: 'Appliance controls',
                subtitle: 'Recommended settings update when a mode is applied. Individual controls remain editable.',
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
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.95,
                      children: [
                        _ApplianceCard(
                          icon: Icons.wb_sunny_outlined,
                          label: 'Room light',
                          note: 'Brightness · PWM output in hardware mode',
                          device: _devices['light']!,
                          levelLabel: (v) => '${v.round()}%',
                          onChanged: (next) => setState(() => _devices['light'] = next),
                        ),
                        _ApplianceCard(
                          icon: Icons.air,
                          label: 'Desk fan',
                          note: 'Low-voltage DC fan · driver required for hardware mode',
                          device: _devices['fan']!,
                          levelLabel: (v) => '${v.round()}%',
                          onChanged: (next) => setState(() => _devices['fan'] = next),
                        ),
                        _ApplianceCard(
                          icon: Icons.ac_unit_outlined,
                          label: 'Cooling (demo)',
                          note: 'Relay state simulation · not connected to an actual AC',
                          device: _devices['cooling']!,
                          min: 18,
                          max: 30,
                          levelLabel: (v) => '${v.round()}°C',
                          onChanged: (next) => setState(() => _devices['cooling'] = next),
                        ),
                        _ApplianceCard(
                          icon: Icons.nightlight_outlined,
                          label: 'Night light',
                          note: 'Low-brightness auxiliary light · PWM output in hardware mode',
                          device: _devices['night']!,
                          levelLabel: (v) => '${v.round()}%',
                          onChanged: (next) => setState(() => _devices['night'] = next),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4ECD8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: const Text(
                        'Hardware safety: test with LEDs and a low-voltage DC fan '
                        'first. Do not connect mains-powered lights, AC units or '
                        'household wiring directly to a microcontroller. Use '
                        'properly rated, isolated hardware and qualified supervision.',
                        style: TextStyle(color: AppColors.inkSoft, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNoDriverNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "No ESP32 serial driver is wired into this build yet — appliance cards below stay in simulator mode.",
        ),
      ),
    );
  }
}

/// Shared with `DeviceControlsScreen` by duplication-on-purpose: each
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

/// Mirrors the demo's "Hardware connection" panel: a status chip, a row
/// of connect/disconnect/sync actions, and an honest note that the
/// simulator still works without any board attached.
class _HardwareConnectionPanel extends StatelessWidget {
  final VoidCallback onConnect;
  final VoidCallback onSync;
  const _HardwareConnectionPanel({required this.onConnect, required this.onSync});

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      title: 'Hardware connection',
      subtitle: 'USB serial · Windows desktop · ESP32 firmware required',
      trailing: const AppChip('Not connected'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(onPressed: onConnect, child: const Text('Connect ESP32 over USB')),
              OutlinedButton(onPressed: onConnect, child: const Text('Disconnect')),
              OutlinedButton(onPressed: onSync, child: const Text('Sync current device state')),
            ],
          ),
          const SizedBox(height: 12),
          const NoteBox('No hardware? The simulated appliance controls below still work for your review.'),
          const SizedBox(height: 10),
          const Text(
            'Serial port access runs through this app directly. Connect only a board running matching DayOne firmware.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ApplianceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String note;
  final _ApplianceState device;
  final double min;
  final double max;
  final String Function(double) levelLabel;
  final ValueChanged<_ApplianceState> onChanged;

  const _ApplianceCard({
    required this.icon,
    required this.label,
    required this.note,
    required this.device,
    required this.levelLabel,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
  });

  @override
  Widget build(BuildContext context) {
    final level = device.level.clamp(min, max).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: device.on ? AppColors.accentLight : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: device.on ? AppColors.accent : AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: device.on ? AppColors.accent : AppColors.inkSoft),
              ),
              const Spacer(),
              Switch(
                value: device.on,
                activeColor: AppColors.accent,
                onChanged: (v) => onChanged(_ApplianceState(on: v, level: device.level)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppColors.inkSoft, height: 1.3),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                device.on ? 'ON' : 'OFF',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: device.on ? AppColors.accent : AppColors.inkSoft,
                ),
              ),
              Text(
                levelLabel(level),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 3),
            child: Slider(
              value: level,
              min: min,
              max: max,
              onChanged: device.on ? (v) => onChanged(_ApplianceState(on: device.on, level: v)) : null,
            ),
          ),
        ],
      ),
    );
  }
}
