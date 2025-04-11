import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_first_aid/model/inventoryModel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_first_aid/services/notificationservices.dart';

class DatabaseServices {
  final NotificationService _notificationService = NotificationService();
  User? user = FirebaseAuth.instance.currentUser;

  // Get reference to the user's todos subcollection
  CollectionReference get todoCollection {
    return FirebaseFirestore.instance
        .collection("users") // Parent collection "users"
        .doc(user!.uid) // Document with user's uid
        .collection("todos"); // Subcollection "todos"
  }

  // Add a new todo task to the user's subcollection
  Future<DocumentReference> addTodoTask(
      String title, String description) async {
    var result = await todoCollection.add({
      'uid': user!.uid,
      'title': title,
      'description': description,
      'completed': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _notificationService.showTaskActionNotification("added");
    return result;
  }

  // Update a todo item in the user's subcollection
  Future<void> updateTodo(String id, String title, String description) async {
    await todoCollection.doc(id).update({
      'title': title,
      'description': description,
    });
    await _notificationService.showTaskActionNotification("updated");
  }

  // Update the completion status of a todo task
  Future<void> updateTodoStatus(String id, bool completed) async {
    await todoCollection.doc(id).update({'completed': completed});
    await _notificationService.showTaskActionNotification(
      completed ? "completed" : "marked incomplete",
    );
  }

  // Delete a todo task from the user's subcollection
  Future<void> deleteTodoTask(String id) async {
    await todoCollection.doc(id).delete();
    await _notificationService.showTaskActionNotification("deleted");
  }

  // Get the pending tasks for the current user
  Stream<List<Todo>> get todos {
    return todoCollection
        .where('completed', isEqualTo: false)
        .snapshots()
        .map(_todoListFromSnapshot);
  }

  // Get the completed tasks for the current user
  Stream<List<Todo>> get completedTodos {
    return todoCollection
        .where('completed', isEqualTo: true)
        .snapshots()
        .map(_todoListFromSnapshot);
  }

  // Convert the Firestore snapshot to a list of Todo objects
  List<Todo> _todoListFromSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return Todo(
        id: doc.id,
        timestamp: doc['createdAt'] ?? "",
        title: doc['title'] ?? "",
        description: doc['description'] ?? "",
        completed: doc['completed'] ?? false,
      );
    }).toList();
  }
}
