import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/goal.dart';
import '../../data/goal_providers.dart';
import '../../data/goals_repository.dart';
import '../../widgets/inline_title.dart';
import '../../widgets/add_input.dart';
import '../goals/tree_utils.dart';
import '../../widgets/undo_snackbar.dart';
import 'edit_goal_panel.dart';
import 'dnd.dart';

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rootsAsync = ref.watch(rootGoalsProvider);
    final selectedRootId = ref.watch(selectedRootIdProvider);
    final repo = ref.watch(goalsRepositoryProvider);

    return Row(
      children: [
        // LEFT: Roots + root drop zone
        SizedBox(
          width: 360,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: AddInput(
                  hint: 'Add root goal… (Enter)',
                  onSubmit: (t) => repo.createRoot(t),
                ),
              ),

              // --- Drop zone to promote a goal to root (parentId=null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _MakeRootDropZone(),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: rootsAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (roots) {
                    // auto-select first
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

                    // --- Reorder roots
                    return ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      onReorder: (oldIndex, newIndex) async {
                        final before = [...roots];
                        var list = [...roots];
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = list.removeAt(oldIndex);
                        list.insert(newIndex, item);
                        await repo.applyOrder(
                          null,
                          list.map((g) => g.id).toList(),
                        );
                        final messenger = ScaffoldMessenger.of(context);

                        showUndoSnackBar(
                          messenger,
                          message: 'Reordered "${item.title}".',
                          onUndo:
                              () async => repo.applyOrder(
                                null,
                                before.map((g) => g.id).toList(),
                              ),
                        );
                      },

                      itemCount: roots.length,
                      itemBuilder: (_, i) {
                        final g = roots[i];
                        final selected =
                            g.id == ref.watch(selectedRootIdProvider);
                        return _RootRow(
                          key: ValueKey(g.id),
                          goal: g,
                          selected: selected,
                          index: i,
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

        // RIGHT: Children of selected root
        Expanded(child: _ChildrenPane()),
        const VerticalDivider(width: 1),

        SizedBox(width: 420, child: const EditGoalPanel()),
      ],
    );
  }
}

/// A drop target strip that turns dropped items into roots (parentId=null).
class _MakeRootDropZone extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(goalsRepositoryProvider);
    return DragTarget<GoalDragData>(
      onWillAccept: (data) => data != null, // accept any goal
      onAcceptWithDetails: (details) async {
        final data = details.data;
        final dragged = await repo.getGoalOnce(data.goalId);
        if (dragged == null) return;
        final fromParent = dragged.parentId;
        final beforeSource = await repo.getChildrenOnce(fromParent);
        final beforeRoots = await repo.getChildrenOnce(null);

        final rootIds = [...beforeRoots.map((g) => g.id)];
        if (!rootIds.contains(data.goalId)) rootIds.add(data.goalId);
        await repo.applyOrder(null, rootIds);

        void undo() async {
          await repo.applyOrder(null, beforeRoots.map((g) => g.id).toList());
          await repo.applyOrder(
            fromParent,
            beforeSource.map((g) => g.id).toList(),
          );
        }

        final messenger = ScaffoldMessenger.of(context);

        showUndoSnackBar(
          messenger,
          message: 'Made "${dragged.title}" a root.',
          onUndo: undo,
        );
      },
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;
        return Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  hovering
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).dividerColor,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            hovering ? 'Release to make root' : 'Drop here to make a root',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: hovering ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        );
      },
    );
  }
}

class _RootRow extends ConsumerWidget {
  const _RootRow({
    super.key,
    required this.goal,
    required this.selected,
    required this.index,
  });
  final Goal goal;
  final bool selected;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(goalsRepositoryProvider);
    final allGoals = ref.watch(allGoalsProvider).value ?? const <Goal>[];
    final parentOf = buildParentMap(allGoals);

    // Each root row is both draggable (to reorder within roots) and a drop target
    // to accept children dragged from the right pane (reparent to this root).
    return DragTarget<GoalDragData>(
      onWillAccept: (data) {
        if (data == null || data.goalId == goal.id) return false;
        final ok = !wouldCreateCycle(parentOf, data.goalId, goal.id);
        return ok;
      },
      onAcceptWithDetails: (details) async {
        final data = details.data;
        // capture previous state for undo
        final dragged = await repo.getGoalOnce(data.goalId);
        if (dragged == null) return;
        final fromParent = dragged.parentId;
        final beforeSource = await repo.getChildrenOnce(fromParent);
        final beforeTarget = await repo.getChildrenOnce(goal.id);

        // perform move: append at end
        final targetIds = [...beforeTarget.map((g) => g.id)];
        if (!targetIds.contains(data.goalId)) targetIds.add(data.goalId);
        await repo.applyOrder(goal.id, targetIds);

        // undo closure
        void undo() async {
          // restore target list
          await repo.applyOrder(
            goal.id,
            beforeTarget.map((g) => g.id).toList(),
          );
          // restore source list (put the dragged back)
          final srcIds = beforeSource.map((g) => g.id).toList();
          await repo.applyOrder(fromParent, srcIds);
        }

        final messenger = ScaffoldMessenger.of(context);

        showUndoSnackBar(
          messenger,
          message: 'Moved "${dragged.title}" under "${goal.title}".',
          onUndo: undo,
        );
      },
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        final validHover =
            hovering &&
            candidate.every(
              (d) => !wouldCreateCycle(parentOf, d?.goalId, goal.id),
            );

        final tile = ListTile(
          selected: selected,
          selectedTileColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          title: InlineTitle(
            initial: goal.title,
            onChangedDebounced: (txt) => repo.updateTitle(goal.id, txt),
          ),
          subtitle: Text('order=${goal.order}'),
          onTap:
              () => ref.read(selectedRootIdProvider.notifier).select(goal.id),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed:
                    () =>
                        ref.read(editingGoalIdProvider.notifier).open(goal.id),
              ),
            ],
          ),
        );

        final decorated = Container(
          key: ValueKey('root_${goal.id}'),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color:
                    hovering
                        ? (validHover
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error)
                        : Colors.transparent,
                width: hovering ? 3 : 0,
              ),
            ),
          ),
          child: tile,
        );

        return LongPressDraggable<GoalDragData>(
          data: GoalDragData(goalId: goal.id, fromParentId: null),
          feedback: _dragFeedback(context, goal.title),
          childWhenDragging: Opacity(opacity: 0.5, child: decorated),
          child: decorated,
        );
      },
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
              // Reorder within the selected parent
              return ReorderableListView.builder(
                buildDefaultDragHandles: false,
                onReorder: (oldIndex, newIndex) async {
                  final before = [...children]; // snapshot for undo
                  var list = [...children];
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = list.removeAt(oldIndex);
                  list.insert(newIndex, item);
                  await repo.applyOrder(
                    selectedRootId,
                    list.map((g) => g.id).toList(),
                  );

                  final messenger = ScaffoldMessenger.of(context);

                  showUndoSnackBar(
                    messenger,
                    message: 'Reordered "${item.title}".',
                    onUndo:
                        () async => repo.applyOrder(
                          selectedRootId,
                          before.map((g) => g.id).toList(),
                        ),
                  );
                },

                itemCount: children.length,
                itemBuilder: (_, i) {
                  final c = children[i];
                  final tile = ListTile(
                    title: InlineTitle(
                      initial: c.title,
                      onChangedDebounced: (txt) => repo.updateTitle(c.id, txt),
                    ),
                    subtitle: Text('order=${c.order}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_handle),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit',
                          onPressed:
                              () => ref
                                  .read(editingGoalIdProvider.notifier)
                                  .open(c.id),
                        ),
                      ],
                    ),
                    onTap: () {},
                  );

                  // Make a child draggable across panes
                  return LongPressDraggable<GoalDragData>(
                    key: ValueKey('child_${c.id}'),
                    data: GoalDragData(
                      goalId: c.id,
                      fromParentId: selectedRootId,
                    ),
                    feedback: _dragFeedback(context, c.title),
                    childWhenDragging: Opacity(opacity: 0.5, child: tile),
                    child: tile,
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

Widget _dragFeedback(BuildContext context, String title) {
  return Material(
    elevation: 6,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 320),
      color: Theme.of(context).colorScheme.surface,
      child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}
