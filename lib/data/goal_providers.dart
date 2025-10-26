import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'goals_repository.dart';
import 'goal.dart';

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  return GoalsRepository();
});

/// Notifier-based selection (Riverpod 3 preferred)
class SelectedRootId extends Notifier<String?> {
  @override
  String? build() => null; // no selection initially
  void select(String? id) => state = id;
  void clear() => state = null;
}

final selectedRootIdProvider = NotifierProvider<SelectedRootId, String?>(
  SelectedRootId.new,
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
