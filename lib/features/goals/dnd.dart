class GoalDragData {
  GoalDragData({required this.goalId, required this.fromParentId});
  final String goalId; // dragged goal
  final String? fromParentId; // null for roots, or the parent id for children
}
