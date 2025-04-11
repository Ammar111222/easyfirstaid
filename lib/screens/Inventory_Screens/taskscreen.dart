// import 'package:easy_first_aid/components/bottomnavbar.dart';
import 'package:easy_first_aid/database/database_services.dart';
import 'package:easy_first_aid/model/inventoryModel.dart';
import 'package:easy_first_aid/screens/Inventory_Screens/completed_widget.dart';
import 'package:easy_first_aid/screens/Inventory_Screens/pending_widget.dart';
import 'package:flutter/material.dart';

class Taskscreen extends StatefulWidget {
  const Taskscreen({super.key});

  @override
  State<Taskscreen> createState() => _TaskscreenState();
}

class _TaskscreenState extends State<Taskscreen> {
  // int currentIndex = 4;
  // void onTap(int index) {
  //   setState(() {
  //     currentIndex = index;
  //   });
  // }

  int _buttonIndex = 0;
  final _widgets = [const PendingWidget(), const CompletedWidget()];

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: const Color(0xFF1d2630),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF1d2630),
        foregroundColor: Colors.white,
        title: const Text("Inventory"),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: screenHeight * 0.03,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(50),
                onTap: () {
                  setState(() {
                    _buttonIndex = 0;
                  });
                },
                child: Container(
                  height: screenHeight * 0.05,
                  width: MediaQuery.of(context).size.width / 2.2,
                  decoration: BoxDecoration(
                    color: _buttonIndex == 0 ? Colors.indigo : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      "Pending",
                      style: TextStyle(
                        fontSize: _buttonIndex == 0 ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        color:
                            _buttonIndex == 0 ? Colors.white : Colors.black38,
                      ),
                    ),
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(50),
                onTap: () {
                  setState(() {
                    _buttonIndex = 1;
                  });
                },
                child: Container(
                  height: screenHeight * 0.05,
                  width: MediaQuery.of(context).size.width / 2.2,
                  decoration: BoxDecoration(
                    color: _buttonIndex == 1 ? Colors.indigo : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      "Completed",
                      style: TextStyle(
                        fontSize: _buttonIndex == 1 ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        color:
                            _buttonIndex == 1 ? Colors.white : Colors.black38,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: screenHeight * 0.03,
          ),
          // Wrapping this inside an Expanded widget to take up remaining space
          Expanded(
            child: _widgets[_buttonIndex],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () {
          _showTaskDialog(context);
        },
      ),
      // bottomNavigationBar:
      //     BottomNavBar(currentIndex: currentIndex, onTap: onTap),
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
