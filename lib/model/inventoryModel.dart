import 'package:cloud_firestore/cloud_firestore.dart';

class Todo {
  final String id, title, description;
  final bool completed;
  final Timestamp timestamp;

  Todo({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.description,
    required this.completed,
  });
}
