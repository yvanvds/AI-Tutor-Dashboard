import 'package:cloud_firestore/cloud_firestore.dart';

class Goal {
  final String id;
  final String title;
  final String? description;
  final String? parentId;
  final int order;
  final bool optional;
  final List<String> suggestions;
  final List<String> tags;

  Goal({
    required this.id,
    required this.title,
    this.description,
    this.parentId,
    required this.order,
    this.optional = false,
    this.suggestions = const [],
    this.tags = const [],
  });

  factory Goal.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Goal(
      id: doc.id,
      title: d['title'] ?? '',
      description: d['description'],
      parentId: d['parentId'],
      order: d['order'] ?? 0,
      optional: d['optional'] ?? false,
      suggestions: List<String>.from(d['suggestions'] ?? []),
      tags: List<String>.from(d['tags'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'parentId': parentId,
    'order': order,
    'optional': optional,
    'suggestions': suggestions,
    'tags': tags,
  };
}
