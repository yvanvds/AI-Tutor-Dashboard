import 'package:cloud_firestore/cloud_firestore.dart';
import 'goal.dart';

class GoalsRepository {
  // Make the collection strongly typed to avoid casts later:
  final CollectionReference<Map<String, dynamic>> _col = FirebaseFirestore
      .instance
      .collection('goals');

  Stream<List<Goal>> streamRoots() => _col
      .where('parentId', isNull: true)
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map((d) => Goal.fromDoc(d)).toList());

  Stream<Goal?> streamGoal(String id) => _col.doc(id).snapshots().map((doc) {
    if (!doc.exists) return null;
    return Goal.fromDoc(doc);
  });

  Stream<List<Goal>> streamChildren(String parentId) => _col
      .where('parentId', isEqualTo: parentId)
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map((d) => Goal.fromDoc(d)).toList());

  /// ---- Create --------------------------------------------------------------

  Future<void> createRoot(String title) async {
    final next = await _nextOrder(parentId: null);
    await _col.add({'title': title, 'order': next, 'parentId': null});
  }

  Future<void> createChild(String parentId, String title) async {
    final next = await _nextOrder(parentId: parentId);
    await _col.add({'title': title, 'parentId': parentId, 'order': next});
  }

  /// ---- Update --------------------------------------------------------------

  Future<void> updateTitle(String id, String title) async {
    await _col.doc(id).update({'title': title});
  }

  /// ---- Helpers -------------------------------------------------------------

  Future<int> _nextOrder({String? parentId}) async {
    try {
      Query<Map<String, dynamic>> q = _col
          .orderBy('order', descending: true)
          .limit(1);
      q =
          parentId == null
              ? q.where('parentId', isNull: true)
              : q.where('parentId', isEqualTo: parentId);

      final snap = await q.get();
      final currentMax =
          snap.docs.isEmpty
              ? 0
              : (snap.docs.first.data()['order'] as int? ?? 0);
      return currentMax + 1000;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        // Fallback: put new item at end with a safe default
        // (still unique; we’ll normalize during drag-reorder later)
        return DateTime.now().millisecondsSinceEpoch;
      }
      rethrow;
    }
  }

  Future<void> updateDescription(String id, String? description) =>
      _col.doc(id).update({'description': description});

  Future<void> updateOptional(String id, bool optional) =>
      _col.doc(id).update({'optional': optional});

  Future<void> updateTags(String id, List<String> tags) =>
      _col.doc(id).update({'tags': tags});

  Future<void> updateSuggestions(String id, List<String> suggestions) =>
      _col.doc(id).update({'suggestions': suggestions});

  Future<void> reparent(String id, String? newParentId) async {
    // place at end of new parent's list (or roots)
    final next = await _nextOrder(parentId: newParentId);
    await _col.doc(id).update({'parentId': newParentId, 'order': next});
  }

  /// For dropdown: we only need (id, title). With <=100 docs this is fine.
  Stream<List<Goal>> streamAllGoals() => _col
      .orderBy('title')
      .snapshots()
      .map((s) => s.docs.map(Goal.fromDoc).toList());
}
