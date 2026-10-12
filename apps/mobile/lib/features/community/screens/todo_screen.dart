import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_models.dart';
import '../providers/community_provider.dart' show CommunityException;
import '../providers/todo_provider.dart';

/// Private daily routine checklist. Not shared with anyone.
class TodoScreen extends ConsumerStatefulWidget {
  const TodoScreen({super.key});

  @override
  ConsumerState<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends ConsumerState<TodoScreen> {
  final _controller = TextEditingController();
  bool _repeat = false;
  bool _adding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _adding) return;
    setState(() => _adding = true);
    try {
      await ref.read(todoProvider.notifier).add(text, repeatDaily: _repeat);
      _controller.clear();
    } on CommunityException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(todoProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My daily to-do')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Private — never shared with your admin or anyone else.',
                      style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
          Expanded(
            child: todos.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.toString()),
                    TextButton(
                      onPressed: () => ref.invalidate(todoProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (items) => items.isEmpty
                  ? Center(
                      child: Text(
                        'Nothing planned for today.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final t in items)
                          _TodoRow(
                            item: t,
                            onToggle: () async {
                              try {
                                await ref.read(todoProvider.notifier).toggle(t);
                              } on CommunityException catch (e) {
                                _toast(e.message);
                              }
                            },
                            onDelete: () async {
                              try {
                                await ref.read(todoProvider.notifier).remove(t);
                              } on CommunityException catch (e) {
                                _toast(e.message);
                              }
                            },
                          ),
                      ],
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          maxLength: 200,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _add(),
                          decoration: const InputDecoration(
                            hintText: 'Add a task',
                            counterText: '',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _adding ? null : _add,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      avatar: const Icon(Icons.repeat_rounded, size: 18),
                      label: const Text('Repeat every day'),
                      selected: _repeat,
                      onSelected: (v) => setState(() => _repeat = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  final TodoItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final repeats = item.repeatDaily || item.isCopy;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: CheckboxListTile(
        value: item.done,
        onChanged: (_) => onToggle(),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          item.title,
          style: TextStyle(
            decoration: item.done ? TextDecoration.lineThrough : null,
          ),
        ),
        secondary: repeats ? const Icon(Icons.repeat_rounded, size: 18) : null,
      ),
    );
  }
}
