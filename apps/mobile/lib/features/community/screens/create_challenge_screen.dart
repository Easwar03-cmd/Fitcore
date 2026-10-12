import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../providers/challenge_provider.dart';
import '../providers/community_provider.dart' show CommunityException;
import '../widgets/notepad_field.dart';

class CreateChallengeScreen extends ConsumerStatefulWidget {
  const CreateChallengeScreen({super.key, required this.communityId});
  final String communityId;

  @override
  ConsumerState<CreateChallengeScreen> createState() =>
      _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends ConsumerState<CreateChallengeScreen> {
  static const _presets = [7, 21, 30, 60, 90];

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _customDays = TextEditingController();
  final _description = TextEditingController();
  String _kind = 'personal';
  int _days = 21;
  bool _custom = false;
  String _notes = '';
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _customDays.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final days = _custom ? int.parse(_customDays.text) : _days;
    setState(() => _saving = true);
    try {
      final id = await ref.read(challengeActionsProvider).create(
            communityId: widget.communityId,
            kind: _kind,
            title: _title.text,
            description: _description.text,
            totalDays: days,
            notes: _notes,
          );
      if (!mounted) return;
      context.pushReplacement(
          AppRoutes.communityChallengePath(widget.communityId, id));
    } on CommunityException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New challenge')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'personal',
                  label: Text('Personal'),
                  icon: Icon(Icons.person_outline_rounded),
                ),
                ButtonSegment(
                  value: 'group',
                  label: Text('Group'),
                  icon: Icon(Icons.groups_outlined),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              _kind == 'personal'
                  ? 'Only you do this challenge. The admin can see your '
                      'progress only if you share your report.'
                  : 'Everyone in the community can join. Each person tracks '
                      'their own days and progress is visible to the group.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Challenge name',
                hintText: 'e.g. 21 days of 10k steps',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            Text('Duration', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final d in _presets)
                  ChoiceChip(
                    label: Text('$d days'),
                    selected: !_custom && _days == d,
                    onSelected: (_) => setState(() {
                      _custom = false;
                      _days = d;
                    }),
                  ),
                ChoiceChip(
                  label: const Text('Custom'),
                  selected: _custom,
                  onSelected: (_) => setState(() => _custom = true),
                ),
              ],
            ),
            if (_custom) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customDays,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of days (1–365)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 1 || n > 365)
                      ? 'Enter a number from 1 to 365'
                      : null;
                },
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              maxLength: 2000,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Rules / description (optional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text('Notepad', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            NotepadField(
              initialText: '',
              minLines: 5,
              onChanged: (text) => _notes = text,
              onSave: (_) async {},
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _create,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Start challenge'),
            ),
          ],
        ),
      ),
    );
  }
}
