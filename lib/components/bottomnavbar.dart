import 'package:easy_first_aid/screens/Inventory_Screens/taskscreen.dart';
import 'package:easy_first_aid/screens/ai_assistant.dart';
import 'package:easy_first_aid/screens/emergencynumbers.dart';
import 'package:easy_first_aid/screens/homescreen.dart';
import 'package:easy_first_aid/screens/symptomscheck.dart';
import 'package:flutter/material.dart';

class BottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap; // Callback to handle item tap

  const BottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap, // Callback to handle item tap
  }) : super(key: key);

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.call),
          label: 'Call',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_rounded),
          label: 'Easy AI',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.medical_information),
          label: 'Symptoms Checker',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory),
          label: 'Inventory',
        ),
      ],
      currentIndex: widget.currentIndex,
      selectedItemColor: Color.fromARGB(255, 244, 46, 20),
      unselectedItemColor: Colors.grey,
      iconSize: 30.0, // Adjust icon size
      selectedFontSize: 12.0, // Adjust label font size
      unselectedFontSize: 12.0, // Adjust label font size
      onTap: (index) {
        // Only navigate if the tapped index is different from the current index
        if (index != widget.currentIndex) {
          widget.onTap(index); // Trigger the callback

          // Navigate to a specific screen based on the tapped index
          switch (index) {
            case 0:
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const Homescreen()));
              break;
            case 1:
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => Emergencynumbers(
                            previousIndex: widget.currentIndex,
                          )));
              break;
            case 2:
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const GeminiApp()));
              break;
            case 3:
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const Symptomscheck()));
              break;
            case 4:
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const Taskscreen()));
              break;
          }
        }
      },
    );
  }
}
