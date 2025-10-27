import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../data/goal_providers.dart';
import '../../../data/goals_repository.dart';
import '../../../data/goal.dart';
import '../../../widgets/chips_editor.dart';
import '../../../widgets/undo_snackbar.dart';
import 'goal_form.dart';

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
                    return const Center(child: Text('No goal selected.'));
                  }
                  return GoalForm(goal: goal, repo: repo);
                },
              )
              : const SizedBox.shrink(),
    );
  }
}
