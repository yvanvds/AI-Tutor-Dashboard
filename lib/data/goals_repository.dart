import 'package:cloud_firestore/cloud_firestore.dart';
import 'goal.dart';

class GoalsRepository {
  final _col = FirebaseFirestore.instance.collection('goals');

  Stream<List<Goal>> streamRoots() => _col
      .where('parentId', isNull: true)
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map((d) => Goal.fromDoc(d)).toList());

  Stream<List<Goal>> streamChildren(String parentId) => _col
      .where('parentId', isEqualTo: parentId)
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map((d) => Goal.fromDoc(d)).toList());

  Future<void> createRoot(String title) async {
    final snap =
        await _col
            .where('parentId', isNull: true)
            .orderBy('order', descending: true)
            .limit(1)
            .get();
    final next =
        (snap.docs.isEmpty ? 0 : snap.docs.first['order'] as int) + 1000;
    await _col.add({'title': title, 'order': next});
  }

  Future<void> createChild(String parentId, String title) async {
    final snap =
        await _col
            .where('parentId', isEqualTo: parentId)
            .orderBy('order', descending: true)
            .limit(1)
            .get();
    final next =
        (snap.docs.isEmpty ? 0 : snap.docs.first['order'] as int) + 1000;
    await _col.add({'title': title, 'parentId': parentId, 'order': next});
  }
}
