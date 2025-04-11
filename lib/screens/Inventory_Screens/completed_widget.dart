import 'package:easy_first_aid/database/database_services.dart';
import 'package:easy_first_aid/model/inventoryModel.dart';
import 'package:easy_first_aid/services/notificationservices.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class CompletedWidget extends StatefulWidget {
  const CompletedWidget({super.key});

  @override
  State<CompletedWidget> createState() => _CompletedWidgetState();
}

class _CompletedWidgetState extends State<CompletedWidget> {
  User? user = FirebaseAuth.instance.currentUser;
  late String uid;
  final DatabaseServices _databaseServices = DatabaseServices();
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    uid = user?.uid ?? '';
    print("Current User UID: $uid");
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Todo>>(
      stream: _databaseServices.completedTodos,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Loading state
          print("Loading data...");
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // No data available
          print("No pending tasks found.");
          return const Center(
            child: Text(
              "Nothing done yet ",
              style: TextStyle(color: Colors.white),
            ),
          );
        } else {
          // Data is available
          List<Todo> todos = snapshot.data!;
          print("Fetched ${todos.length} pending tasks.");
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: todos.length,
            itemBuilder: (context, index) {
              Todo todo = todos[index];
              DateTime? dt;

              // Handle possible null timestamp
              try {
                dt = todo.timestamp.toDate();
              } catch (e) {
                print("Error parsing timestamp: $e");
              }

              return Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 142, 140, 140),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Slidable(
                  startActionPane: ActionPane(
                    motion: DrawerMotion(),
                    children: [
                      SlidableAction(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                          label: "delete",
                          onPressed: (context) {
                            _databaseServices.deleteTodoTask(todo.id);
                            Future.delayed(Duration(seconds: 1), () {
                              _notificationService.showDeleteTaskNotification();
                            });
                          })
                    ],
                  ),
                  key: ValueKey(todo.id),
                  child: ListTile(
                    title: Text(
                      todo.title,
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.black, // Changed to black for readability
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      todo.description,
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color:
                            Colors.black38, // Changed to black for readability
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: dt != null
                        ? Text(
                            "${dt.day}/${dt.month}/${dt.year}",
                            style: const TextStyle(color: Colors.black54),
                          )
                        : const Text(
                            "No date",
                            style: TextStyle(color: Colors.black54),
                          ),
                  ),
                ),
              );
            },
          );
        }
      },
    );
  }
}
