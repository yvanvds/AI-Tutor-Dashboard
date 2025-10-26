import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/goal_providers.dart';
import '../../widgets/inline_title.dart';
import '../../widgets/add_input.dart';
import 'edit_goal_panel.dart';

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rootsAsync = ref.watch(rootGoalsProvider);
    final selectedRootId = ref.watch(selectedRootIdProvider);
    final repo = ref.watch(goalsRepositoryProvider);

    return Row(
      children: [
        // LEFT: Roots
        SizedBox(
          width: 360, // a bit wider
          child: Column(
            children: [
              Padding(
                // NEW: Add root
                padding: const EdgeInsets.all(8.0),
                child: AddInput(
                  hint: 'Add root goal… (Enter)',
                  onSubmit: (t) => repo.createRoot(t),
                ),
              ),
              Expanded(
                child: rootsAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (roots) {
                    if (selectedRootId == null && roots.isNotEmpty) {
                      Future.microtask(
                        () => ref
                            .read(selectedRootIdProvider.notifier)
                            .select(roots.first.id),
                      );
                    }
                    if (roots.isEmpty) {
                      return const Center(
                        child: Text('No goals yet. Add one above.'),
                      );
                    }
                    return ListView.builder(
                      itemCount: roots.length,
                      itemBuilder: (_, i) {
                        final g = roots[i];
                        final selected =
                            g.id == ref.watch(selectedRootIdProvider);
                        return ListTile(
                          selected: selected,
                          selectedTileColor:
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                          title: InlineTitle(
                            // NEW: inline edit
                            initial: g.title,
                            onChangedDebounced:
                                (txt) => repo.updateTitle(g.id, txt),
                          ),
                          subtitle: Text('order=${g.order}'),
                          onTap:
                              () => ref
                                  .read(selectedRootIdProvider.notifier)
                                  .select(g.id),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Edit',
                            onPressed:
                                () => ref
                                    .read(editingGoalIdProvider.notifier)
                                    .open(g.id),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        const VerticalDivider(width: 1),

        // Middle: Children
        Expanded(child: _ChildrenPane()),

        // >>> right: attach the edit drawer at the far right
        const VerticalDivider(width: 1),
        SizedBox(width: 420, child: EditGoalPanel()),
      ],
    );
  }
}

class _ChildrenPane extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRootId = ref.watch(selectedRootIdProvider);
    final repo = ref.watch(goalsRepositoryProvider);
    if (selectedRootId == null) {
      return const Center(
        child: Text('Select a root goal to see its children.'),
      );
    }

    final childrenAsync = ref.watch(childGoalsProvider);
    return Column(
      children: [
        Padding(
          // NEW: Add child
          padding: const EdgeInsets.all(8.0),
          child: AddInput(
            hint: 'Add child goal… (Enter)',
            onSubmit: (t) => repo.createChild(selectedRootId, t),
          ),
        ),
        Expanded(
          child: childrenAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (children) {
              if (children.isEmpty) {
                return const Center(
                  child: Text('No children yet. Add one above.'),
                );
              }
              return ListView.separated(
                itemCount: children.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final c = children[i];
                  return ListTile(
                    title: InlineTitle(
                      // NEW: inline edit
                      initial: c.title,
                      onChangedDebounced: (txt) => repo.updateTitle(c.id, txt),
                    ),
                    subtitle: Text('order=${c.order}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit',
                      onPressed:
                          () => ref
                              .read(editingGoalIdProvider.notifier)
                              .open(c.id),
                    ),
                    onTap: () {
                      // (Later) open details
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
