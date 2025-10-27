import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/goal_providers.dart';
import '../../data/goals_repository.dart';
import '../../data/goal.dart';
import '../../widgets/chips_editor.dart';
import '../../widgets/undo_snackbar.dart';

class EditGoalPanel extends ConsumerWidget {
  const EditGoalPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editingId = ref.watch(editingGoalIdProvider);
    final goalAsync = ref.watch(editingGoalProvider);
    final repo = ref.watch(goalsRepositoryProvider);

    final isOpen = editingId != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: isOpen ? 420 : 0,
      decoration: BoxDecoration(
        border:
            isOpen
                ? Border(
                  left: BorderSide(color: Theme.of(context).dividerColor),
                )
                : null,
        color: Theme.of(context).colorScheme.surface,
      ),
      child:
          isOpen
              ? goalAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (goal) {
                  if (goal == null) {
                    return const Center(child: Text('Goal not found.'));
                  }
                  return _EditForm(goal: goal, repo: repo);
                },
              )
              : const SizedBox.shrink(),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.goal, required this.repo});
  final Goal goal;
  final GoalsRepository repo;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  bool _optional = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.goal.title);
    _desc = TextEditingController(text: widget.goal.description ?? '');
    _optional = widget.goal.optional;
  }

  @override
  void didUpdateWidget(covariant _EditForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goal.id != widget.goal.id) {
      _title.text = widget.goal.title;
      _desc.text = widget.goal.description ?? '';
      _optional = widget.goal.optional;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only roots in the parent dropdown
    final rootsAsync = ref.watch(rootGoalsProvider);

    Widget parentField;
    parentField = rootsAsync.when(
      loading:
          () => const SizedBox(
            height: 56,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      error: (e, _) => Text('Failed to load parents: $e'),
      data: (roots) {
        final items = <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('(no parent)'),
          ),
          ...roots
              .where((g) => g.id != widget.goal.id) // avoid self as parent
              .map(
                (g) => DropdownMenuItem<String?>(
                  value: g.id,
                  child: Text(g.title),
                ),
              ),
        ];
        return DropdownButtonFormField<String?>(
          value: widget.goal.parentId, // may be null
          items: items,
          onChanged: (newParent) async {
            if (newParent == widget.goal.parentId) return;
            await widget.repo.reparent(widget.goal.id, newParent);
          },
          decoration: const InputDecoration(
            labelText: 'Parent',
            border: OutlineInputBorder(),
          ),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit goal'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(
                context,
              ); // <-- capture BEFORE awaits/closing
              final repo = widget.repo;
              final id = widget.goal.id;

              // Count children for safety messaging
              final count = await repo.countDescendants(id);
              final confirmed =
                  await showDialog<bool>(
                    context: context,
                    builder: (dCtx) {
                      return AlertDialog(
                        title: const Text('Delete goal'),
                        content: Text(
                          count == 0
                              ? 'Delete “${widget.goal.title}”?'
                              : 'Delete “${widget.goal.title}” and its $count descendant(s)?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.error,
                            ),
                            onPressed: () => Navigator.pop(dCtx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      );
                    },
                  ) ??
                  false;

              if (!confirmed) return;

              // Backup → delete → Undo
              final backup = await repo.backupSubtree(id);
              await repo.deleteSubtree(id);

              // Close the editor if we just deleted the opened node
              if (mounted) {
                ref.read(editingGoalIdProvider.notifier).close();
              }

              showUndoSnackBar(
                messenger,
                message:
                    count == 0
                        ? 'Deleted "${widget.goal.title}".'
                        : 'Deleted "${widget.goal.title}" (+$count).',
                onUndo: () async {
                  await repo.restoreSubtree(backup);
                },
              );
            },
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => ref.read(editingGoalIdProvider.notifier).close(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
            onSubmitted:
                (t) => widget.repo.updateTitle(
                  widget.goal.id,
                  t.trim().isEmpty ? 'Untitled' : t.trim(),
                ),
            onChanged:
                (
                  t,
                ) {}, // explicit save on submit; we already have inline title elsewhere
          ),
          const SizedBox(height: 12),
          parentField,
          const SizedBox(height: 12),

          TextField(
            controller: _desc,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
            onChanged:
                (t) => widget.repo.updateDescription(
                  widget.goal.id,
                  t.isEmpty ? null : t,
                ),
          ),
          const SizedBox(height: 12),

          SwitchListTile(
            value: _optional,
            onChanged: (v) {
              setState(() => _optional = v);
              widget.repo.updateOptional(widget.goal.id, v);
            },
            title: const Text('Optional'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),

          ChipsEditor(
            label: 'Tags',
            values: widget.goal.tags,
            hintText: 'Type a tag and hit Enter',
            onChanged: (vals) => widget.repo.updateTags(widget.goal.id, vals),
          ),
          const SizedBox(height: 12),

          ChipsEditor(
            label: 'Suggestions',
            values: widget.goal.suggestions,
            hintText: 'Type a suggestion and hit Enter',
            onChanged:
                (vals) => widget.repo.updateSuggestions(widget.goal.id, vals),
          ),
        ],
      ),
    );
  }
}
