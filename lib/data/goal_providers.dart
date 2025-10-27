import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'goals_repository.dart';
import 'goal.dart';

// Repository provider
final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  return GoalsRepository();
});

// Selected root goal id state
class SelectedRootId extends Notifier<String?> {
  @override
  String? build() => null; // no selection initially
  void select(String? id) => state = id;
  void clear() => state = null;
}

/// Which goal is being edited in the drawer? (null = closed)
class EditingGoalId extends Notifier<String?> {
  @override
  String? build() => null;
  void open(String id) => state = id;
  void close() => state = null;
}

// Selected root goal id (for viewing its children)
final selectedRootIdProvider = NotifierProvider<SelectedRootId, String?>(
  SelectedRootId.new,
);

// Editing goal id state
final editingGoalIdProvider = NotifierProvider<EditingGoalId, String?>(
  EditingGoalId.new,
);

/// Stream of root goals (StreamProvider is fine to keep)
final rootGoalsProvider = StreamProvider<List<Goal>>((ref) {
  final repo = ref.watch(goalsRepositoryProvider);
  return repo.streamRoots();
});

/// Stream of children for the selected root
final childGoalsProvider = StreamProvider<List<Goal>>((ref) {
  final repo = ref.watch(goalsRepositoryProvider);
  final rootId = ref.watch(selectedRootIdProvider);
  if (rootId == null) return const Stream<List<Goal>>.empty();
  return repo.streamChildren(rootId);
});

/// Stream the single goal being edited
final editingGoalProvider = StreamProvider<Goal?>((ref) {
  final id = ref.watch(editingGoalIdProvider);
  if (id == null) return const Stream.empty();
  final repo = ref.watch(goalsRepositoryProvider);
  return repo.streamGoal(id); // ← direct single-doc stream
});

/// For parent dropdown
final allGoalsProvider = StreamProvider<List<Goal>>((ref) {
  final repo = ref.watch(goalsRepositoryProvider);
  return repo.streamAllGoals();
});
