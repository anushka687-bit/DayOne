import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/environment_profile.dart';
import '../models/mode.dart';
import '../theme/app_theme.dart';

/// Modes aren't a fixed four anymore — this is where the user sees all of
/// them, adds their own, and (optionally) wires one to a smart-home scene.
/// Nothing wired here ever leaves the device except the one opaque scene
/// id when that mode becomes active.
class ModesScreen extends StatelessWidget {
  const ModesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Modes')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.paper,
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
        itemCount: state.modes.length,
        itemBuilder: (context, i) {
          final mode = state.modes[i];
          final isCurrent = mode.id == state.currentMode.id;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Row(
                children: [
                  Text(mode.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (isCurrent) ...[
                    const SizedBox(width: 8),
                    const _Pill(text: 'Active'),
                  ],
                  if (mode.builtIn) ...[
                    const SizedBox(width: 8),
                    const _Pill(text: 'Built-in', filled: false),
                  ],
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mode.tagline, style: const TextStyle(color: AppColors.inkSoft)),
                    const SizedBox(height: 4),
                    Text(
                      'Layout: ${mode.layout.label}'
                      '${mode.sceneTriggers.isNotEmpty ? ' · ${mode.sceneTriggers.length} scene linked' : ''}'
                      '${mode.scheduledMinuteOfDay != null ? ' · daily at ${Mode.formatMinuteOfDay(mode.scheduledMinuteOfDay!)}' : ''}',
                      style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
                    ),
                    if (mode.environment != null && !mode.environment!.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [
                            if (mode.environment!.brightness != null)
                              'brightness ${mode.environment!.brightness}%',
                            if (mode.environment!.volume != null)
                              'volume ${mode.environment!.volume}%',
                            if (mode.environment!.alexaSceneId != null)
                              'Alexa "${mode.environment!.alexaSceneId}"',
                          ].join(' · '),
                          style: const TextStyle(color: AppColors.accent, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _openEditor(context, existing: mode);
                  if (value == 'delete') state.removeMode(mode.id);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (!mode.builtIn) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openEditor(BuildContext context, {Mode? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ModeEditorSheet(existing: existing),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool filled;
  const _Pill({required this.text, this.filled = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? AppColors.accentLight : Colors.transparent,
        border: filled ? null : Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, color: AppColors.ink)),
    );
  }
}

class _ModeEditorSheet extends StatefulWidget {
  final Mode? existing;
  const _ModeEditorSheet({this.existing});

  @override
  State<_ModeEditorSheet> createState() => _ModeEditorSheetState();
}

class _ModeEditorSheetState extends State<_ModeEditorSheet> {
  late TextEditingController _label;
  late TextEditingController _tagline;
  late TextEditingController _sceneId;
  late TextEditingController _sceneLabel;
  late TextEditingController _alexaEventName;
  late LayoutArchetype _layout;
  late String _adapterId;
  int? _scheduledMinute;

  // The mode's default environment — applied in full every time the mode
  // becomes active (see AppState._applyEnvironment), not just via the
  // one-off "smart-home scene" trigger below.
  bool _brightnessEnabled = false;
  double _brightnessPercent = 80;
  bool _volumeEnabled = false;
  double _volumePercent = 50;
  bool _alexaEnabled = false;

  static const _adapterChoices = {
    'mock': 'Simulated smart-home link',
  };

  bool get _isNew => widget.existing == null;
  bool get _identityEditable => _isNew || widget.existing?.builtIn == false;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _label = TextEditingController(text: m?.label ?? '');
    _tagline = TextEditingController(text: m?.tagline ?? '');
    _layout = m?.layout ?? LayoutArchetype.guided;
    _scheduledMinute = m?.scheduledMinuteOfDay;

    final env = m?.environment;
    _brightnessEnabled = env?.brightness != null;
    _brightnessPercent = (env?.brightness ?? 80).toDouble();
    _volumeEnabled = env?.volume != null;
    _volumePercent = (env?.volume ?? 50).toDouble();
    _alexaEnabled = env?.alexaSceneId != null;
    _alexaEventName = TextEditingController(text: env?.alexaSceneId ?? '');

    final firstTrigger = (m?.sceneTriggers.isNotEmpty ?? false) ? m!.sceneTriggers.first : null;
    _adapterId = 'mock';
    _sceneId = TextEditingController(text: firstTrigger?.sceneId ?? '');
    _sceneLabel = TextEditingController(text: firstTrigger?.label ?? '');
  }

  Future<void> _pickTime() async {
    final initial = _scheduledMinute != null
        ? TimeOfDay(hour: _scheduledMinute! ~/ 60, minute: _scheduledMinute! % 60)
        : TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() => _scheduledMinute = picked.hour * 60 + picked.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isNew ? 'Add a mode' : 'Edit mode',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _label,
              enabled: _identityEditable,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _tagline,
              enabled: _identityEditable,
              decoration: const InputDecoration(labelText: 'Tagline'),
            ),
            const SizedBox(height: 18),
            const Text('Content shape', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: LayoutArchetype.values
                  .map((l) => ChoiceChip(
                        label: Text(l.label),
                        selected: _layout == l,
                        onSelected: _identityEditable ? (_) => setState(() => _layout = l) : null,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text('Run on a schedule (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'Switches to this mode at the same time every day, starting '
              'immediately — no history needed first (unlike a routine '
              'DayOne learns on its own from repeated use).',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _scheduledMinute == null
                        ? 'No fixed time set'
                        : 'Every day at ${Mode.formatMinuteOfDay(_scheduledMinute!)}',
                    style: const TextStyle(color: AppColors.ink),
                  ),
                ),
                TextButton(onPressed: _pickTime, child: const Text('Set time')),
                if (_scheduledMinute != null)
                  TextButton(
                    onPressed: () => setState(() => _scheduledMinute = null),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Default environment (optional)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'Applied in full the moment this mode becomes active — real on '
              'this laptop for brightness and volume; Alexa sends only an '
              'opaque event name, nothing about your preferences or sensors.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Screen brightness'),
              value: _brightnessEnabled,
              onChanged: (v) => setState(() => _brightnessEnabled = v),
            ),
            if (_brightnessEnabled) ...[
              Text('${_brightnessPercent.round()}%',
                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
              Slider(
                value: _brightnessPercent,
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: (v) => setState(() => _brightnessPercent = v),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('System volume'),
              subtitle: const Text('Approximate — simulated via volume keys',
                  style: TextStyle(fontSize: 11)),
              value: _volumeEnabled,
              onChanged: (v) => setState(() => _volumeEnabled = v),
            ),
            if (_volumeEnabled) ...[
              Text('${_volumePercent.round()}%',
                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
              Slider(
                value: _volumePercent,
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: (v) => setState(() => _volumePercent = v),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Alexa (via IFTTT)'),
              subtitle: const Text('Logged — no account needed to demo',
                  style: TextStyle(fontSize: 11)),
              value: _alexaEnabled,
              onChanged: (v) => setState(() => _alexaEnabled = v),
            ),
            if (_alexaEnabled)
              TextField(
                controller: _alexaEventName,
                decoration: const InputDecoration(labelText: 'IFTTT event name'),
              ),
            const SizedBox(height: 20),
            const Text('Smart-home scene (optional)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'A separate, one-off trigger — only an opaque scene id is ever '
              'sent.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _adapterId,
              decoration: const InputDecoration(labelText: 'Integration'),
              items: _adapterChoices.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _adapterId = v ?? 'mock'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _sceneLabel,
              decoration: const InputDecoration(labelText: 'Label (for you)'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _sceneId,
              decoration: const InputDecoration(labelText: 'Scene id'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: Text(_isNew ? 'Add mode' : 'Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final state = context.read<AppState>();
    final sceneTriggers = <SceneTriggerRef>[];

    if (_sceneId.text.trim().isNotEmpty) {
      sceneTriggers.add(SceneTriggerRef(
        adapterId: _adapterId,
        sceneId: _sceneId.text.trim(),
        label: _sceneLabel.text.trim().isEmpty ? _sceneId.text.trim() : _sceneLabel.text.trim(),
      ));
    }

    final environment = EnvironmentProfile(
      brightness: _brightnessEnabled ? _brightnessPercent.round() : null,
      volume: _volumeEnabled ? _volumePercent.round() : null,
      alexaSceneId: _alexaEnabled && _alexaEventName.text.trim().isNotEmpty
          ? _alexaEventName.text.trim()
          : null,
    );

    if (_isNew) {
      final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
      state.addMode(Mode(
        id: id,
        label: _label.text.trim().isEmpty ? 'New mode' : _label.text.trim(),
        tagline: _tagline.text.trim(),
        layout: _layout,
        sceneTriggers: sceneTriggers,
        scheduledMinuteOfDay: _scheduledMinute,
        environment: environment.isEmpty ? null : environment,
      ));
    } else {
      final existing = widget.existing!;
      state.updateMode(Mode(
        id: existing.id,
        label: existing.builtIn ? existing.label : _label.text.trim(),
        tagline: existing.builtIn ? existing.tagline : _tagline.text.trim(),
        layout: existing.builtIn ? existing.layout : _layout,
        builtIn: existing.builtIn,
        sceneTriggers: sceneTriggers,
        scheduledMinuteOfDay: _scheduledMinute,
        environment: environment.isEmpty ? null : environment,
      ));
    }
    Navigator.of(context).pop();
  }
}
