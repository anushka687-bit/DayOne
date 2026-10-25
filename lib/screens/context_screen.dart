import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/context_snapshot.dart';
import '../services/esp32_context_service.dart';
import '../theme/app_theme.dart';
import 'routines_screen.dart';

/// Stands in for the ESP32 + BH1750 + MPU6050 + sound sensor during
/// development and demo — and, now that firmware/dayone_esp32 exists, can
/// also pull real readings from it over the ESP32's own WiFi access point.
/// Either way it calls `updateContext`; nothing downstream (the engine, the
/// dashboard) needs to know or care which source it was.
///
/// Also where the *routine* side of the demo lives: a "simulate a moment"
/// control, since waiting for 6:00pm to actually arrive isn't practical
/// mid-demo. It drives the exact same code path real time would.
class ContextScreen extends StatefulWidget {
  const ContextScreen({super.key});

  @override
  State<ContextScreen> createState() => _ContextScreenState();
}

class _ContextScreenState extends State<ContextScreen> {
  late double _noise;
  late double _movement;
  late double _light;

  final Esp32ContextService _esp32 = Esp32ContextService();
  bool _liveSensors = false;
  String? _liveError;

  static const _presets = [
    ('Early morning', 6, 0),
    ('Mid-morning', 9, 30),
    ('Afternoon', 13, 0),
    ('5:00 PM', 17, 0),
    ('Evening', 18, 0),
    ('Night', 22, 0),
  ];

  @override
  void initState() {
    super.initState();
    final c = context.read<AppState>().sensorContext;
    _noise = c.noise;
    _movement = c.movement;
    _light = c.light;
  }

  @override
  void dispose() {
    _esp32.dispose();
    super.dispose();
  }

  void _push() {
    context.read<AppState>().updateContext(
          ContextSnapshot(noise: _noise, movement: _movement, light: _light),
        );
  }

  void _toggleLiveSensors(bool on) {
    setState(() {
      _liveSensors = on;
      _liveError = null;
    });
    if (on) {
      _esp32.start(
        onUpdate: (snapshot) {
          if (!mounted) return;
          setState(() {
            _noise = snapshot.noise;
            _movement = snapshot.movement;
            _light = snapshot.light;
            _liveError = null;
          });
          _push();
        },
        onError: (e) {
          if (!mounted) return;
          setState(() => _liveError = 'Not reachable — connect this phone '
              'to the "DayOne-ESP32" WiFi network.');
        },
      );
    } else {
      _esp32.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final mode = state.currentMode;
    final pending = state.pendingTransition;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Current context'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Routines',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RoutinesScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'LIVE SENSORS (ESP32)',
            style: TextStyle(
              fontFamily: 'monospace',
              letterSpacing: 2,
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _liveSensors,
            onChanged: _toggleLiveSensors,
            activeColor: AppColors.accent,
            title: const Text('Pull readings from the ESP32',
                style: TextStyle(color: AppColors.ink)),
            subtitle: Text(
              _liveSensors
                  ? (_liveError ??
                      'Polling http://192.168.4.1/context — sliders below '
                          'now mirror the hardware.')
                  : 'Off — use the sliders below to simulate context.',
              style: TextStyle(
                color: _liveError != null ? Colors.redAccent : AppColors.inkSoft,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'SIMULATED SENSOR LAYER',
            style: TextStyle(
              fontFamily: 'monospace',
              letterSpacing: 2,
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Standing in for the ESP32 (BH1750, MPU6050, sound sensor) so the '
            'engine can be demoed and developed without hardware attached.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 28),
          _SensorSlider(
            label: 'Noise',
            icon: Icons.graphic_eq,
            value: _noise,
            lowLabel: 'Quiet',
            highLabel: 'Loud',
            enabled: !_liveSensors,
            onChanged: (v) {
              setState(() => _noise = v);
              _push();
            },
          ),
          _SensorSlider(
            label: 'Movement',
            icon: Icons.directions_walk,
            value: _movement,
            lowLabel: 'Still',
            highLabel: 'Active',
            enabled: !_liveSensors,
            onChanged: (v) {
              setState(() => _movement = v);
              _push();
            },
          ),
          _SensorSlider(
            label: 'Light',
            icon: Icons.wb_sunny_outlined,
            value: _light,
            lowLabel: 'Dim',
            highLabel: 'Bright',
            enabled: !_liveSensors,
            onChanged: (v) {
              setState(() => _light = v);
              _push();
            },
          ),
          const SizedBox(height: 28),
          const Text(
            'SIMULATE A MOMENT',
            style: TextStyle(
              fontFamily: 'monospace',
              letterSpacing: 2,
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.isClockSimulated
                ? 'Pretending it is ${_formatNow(state.effectiveNow)}.'
                : 'Using the real clock. If DayOne has learned a routine for '
                    'a time of day, jump there to see it propose a switch '
                    'without touching the sliders above.',
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets
                .map((p) => OutlinedButton(
                      onPressed: () {
                        final now = DateTime.now();
                        final fake = DateTime(now.year, now.month, now.day, p.$2, p.$3);
                        state.simulateClock(fake);
                      },
                      child: Text(p.$1),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          if (state.isClockSimulated)
            TextButton(
              onPressed: () => state.simulateClock(null),
              child: const Text('Back to real time'),
            ),
          const SizedBox(height: 16),
          if (pending != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'DayOne is proposing a switch to ${pending.to.label} — '
                      'go check the Dashboard tab.',
                      style: const TextStyle(color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Currently in ${mode.label}.',
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ),
        ],
      ),
    );
  }

  String _formatNow(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final period = t.hour >= 12 ? 'PM' : 'AM';
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }
}

class _SensorSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final String lowLabel;
  final String highLabel;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _SensorSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.lowLabel,
    required this.highLabel,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.ink, size: 20),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
                const Spacer(),
                Text('${(value * 100).round()}%',
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
              ],
            ),
            Slider(value: value, onChanged: enabled ? onChanged : null),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(lowLabel, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                Text(highLabel, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
