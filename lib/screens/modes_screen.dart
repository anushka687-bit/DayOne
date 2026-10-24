import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
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
                      '${mode.sceneTriggers.isNotEmpty ? ' · ${mode.sceneTriggers.length} scene linked' : ''}',
                      style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
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
  late LayoutArchetype _layout;

  bool get _isNew => widget.existing == null;
  bool get _identityEditable => _isNew || widget.existing?.builtIn == false;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _label = TextEditingController(text: m?.label ?? '');
    _tagline = TextEditingController(text: m?.tagline ?? '');
    _layout = m?.layout ?? LayoutArchetype.guided;
    final firstTrigger = (m?.sceneTriggers.isNotEmpty ?? false) ? m!.sceneTriggers.first : null;
    _sceneId = TextEditingController(text: firstTrigger?.sceneId ?? '');
    _sceneLabel = TextEditingController(text: firstTrigger?.label ?? '');
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
            const Text('Smart-home scene (optional)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'Only this scene id is ever sent — nothing about your '
              'preferences or sensors.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
            ),
            const SizedBox(height: 10),
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
        adapterId: 'mock',
        sceneId: _sceneId.text.trim(),
        label: _sceneLabel.text.trim().isEmpty ? _sceneId.text.trim() : _sceneLabel.text.trim(),
      ));
    }

    if (_isNew) {
      final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
      state.addMode(Mode(
        id: id,
        label: _label.text.trim().isEmpty ? 'New mode' : _label.text.trim(),
        tagline: _tagline.text.trim(),
        layout: _layout,
        sceneTriggers: sceneTriggers,
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
      ));
    }
    Navigator.of(context).pop();
  }
}
