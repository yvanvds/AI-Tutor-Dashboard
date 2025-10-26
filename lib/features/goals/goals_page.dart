import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/goal.dart';
import '../../data/goal_providers.dart';

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rootsAsync = ref.watch(rootGoalsProvider);
    final selectedRootId = ref.watch(selectedRootIdProvider);

    return Row(
      children: [
        // LEFT: Roots
        SizedBox(
          width: 320,
          child: rootsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (roots) {
              // Auto-select first root if none selected and there is data
              if (selectedRootId == null && roots.isNotEmpty) {
                Future.microtask(
                  () => ref
                      .read(selectedRootIdProvider.notifier)
                      .select(roots.first.id),
                );
              }
              return ListView.builder(
                itemCount: roots.length,
                itemBuilder: (_, i) {
                  final g = roots[i];
                  final selected = g.id == ref.watch(selectedRootIdProvider);
                  return ListTile(
                    selected: selected,
                    selectedTileColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    title: Text(
                      g.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('order=${g.order}'),
                    onTap:
                        () => ref
                            .read(selectedRootIdProvider.notifier)
                            .select(g.id),
                  );
                },
              );
            },
          ),
        ),

        const VerticalDivider(width: 1),

        // RIGHT: Children of selected root
        Expanded(child: _ChildrenPane()),
      ],
    );
  }
}

class _ChildrenPane extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRootId = ref.watch(selectedRootIdProvider);
    if (selectedRootId == null) {
      return const Center(
        child: Text('Select a root goal to see its children.'),
      );
    }

    final childrenAsync = ref.watch(childGoalsProvider);
    return childrenAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (children) {
        if (children.isEmpty) {
          return const Center(child: Text('No children yet.'));
        }
        return ListView.separated(
          itemCount: children.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final c = children[i];
            return ListTile(
              title: Text(c.title),
              subtitle: Text('order=${c.order}'),
              onTap: () {
                // (Later) open details pane / edit drawer
              },
            );
          },
        );
      },
    );
  }
}
