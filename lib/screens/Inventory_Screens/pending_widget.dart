import 'package:easy_first_aid/database/database_services.dart';
import 'package:easy_first_aid/model/inventoryModel.dart';
import 'package:easy_first_aid/services/notificationservices.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class PendingWidget extends StatefulWidget {
  const PendingWidget({super.key});

  @override
  State<PendingWidget> createState() => _PendingWidgetState();
}

class _PendingWidgetState extends State<PendingWidget> {
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
      stream: _databaseServices.todos,
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
              "Your inventory is empty",
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Slidable(
                  endActionPane: ActionPane(
                    motion: DrawerMotion(),
                    children: [
                      SlidableAction(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          icon: Icons.done,
                          label: "Mark done",
                          onPressed: (context) {
                            _databaseServices.updateTodoStatus(todo.id, true);
                            Future.delayed(Duration(seconds: 1), () {
                              _notificationService
                                  .showCompleteTaskNotification();
                            });
                          })
                    ],
                  ),
                  startActionPane: ActionPane(
                    motion: DrawerMotion(),
                    children: [
                      SlidableAction(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.white,
                        icon: Icons.edit,
                        label: "Edit",
                        onPressed: (context) {
                          _showTaskDialog(context, todo: todo);
                        },
                      ),
                      SlidableAction(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                        label: "Delete",
                        onPressed: (context) async {
                          await _databaseServices.deleteTodoTask(todo.id);
                          Future.delayed(Duration(milliseconds: 500), () {
                            _notificationService.showDeleteTaskNotification();
                          });
                        },
                      )
                    ],
                  ),
                  key: ValueKey(todo.id),
                  child: ListTile(
                    title: Text(
                      todo.title,
                      style: const TextStyle(
                        color: Colors.black, // Changed to black for readability
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      todo.description,
                      style: const TextStyle(
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

  void _showTaskDialog(BuildContext context, {Todo? todo}) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final TextEditingController _titleController =
        TextEditingController(text: todo?.title);
    final TextEditingController _descriptionController =
        TextEditingController(text: todo?.description);
    final DatabaseServices _databaseServices = DatabaseServices();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            todo == null ? "Add Tasks" : 'Edit tasks',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: "Title",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(
                  height: screenHeight * 0.01,
                ),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: "Description",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (todo == null) {
                  await _databaseServices.addTodoTask(
                    _titleController.text,
                    _descriptionController.text,
                  );
                } else {
                  await _databaseServices.updateTodo(
                    todo.id,
                    _titleController.text,
                    _descriptionController.text,
                  );
                  Future.delayed(Duration(seconds: 1), () {
                    _notificationService.showUpdateTaskNotification();
                  });
                }
                Navigator.pop(context);
              },
              child: Text(todo == null ? "Add" : "Update"),
            ),
          ],
        );
      },
    );
  }
}
