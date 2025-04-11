import 'package:dash_chat_2/dash_chat_2.dart';
// import 'package:easy_first_aid/components/bottomnavbar.dart';
import 'package:easy_first_aid/controllers/geminiController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class GeminiApp extends StatefulWidget {
  const GeminiApp({super.key});

  @override
  State<GeminiApp> createState() => _GeminiAppState();
}

class _GeminiAppState extends State<GeminiApp> {
  final GeminiChatController chatController =
      Get.put(GeminiChatController()); // Initialize chat controller.
  // int _selectedIndex = 2; // Initial selected index for the bottom navigation.
  bool _showChatUI =
      false; // To toggle between chat UI and animated containers.

  // Method to handle tapping on the bottom navigation bar items.
  // void _onItemTapped(int index) {
  //   setState(() {
  //     _selectedIndex = index; // Update selected index when a tab is clicked.
  //   });
  // }

  // Method to show a confirmation dialog before deleting the chat.
  Future<void> _showDeleteConfirmationDialog() async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Are you sure you want to delete the chat?'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(false), // User pressed 'No'.
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(true), // User pressed 'Yes'.
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _clearChat(); // If user confirms, clear the chat.
    }
  }

  // Method to clear the chat and reset the UI to show animated containers.
  void _clearChat() {
    chatController.messages.clear(); // Clear all chat messages.
    setState(() {
      _showChatUI = false; // Show the animated containers again.
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            Color.fromARGB(255, 244, 46, 20), // AppBar background color.
        automaticallyImplyLeading: false, // Disable back arrow in the app bar.
        title: const Text(
          'Easy AI', // Title text of the app.
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true, // Center the title.
        actions: [
          if (chatController.messages
              .isNotEmpty) // Show delete button only if there are messages.
            IconButton(
              icon: const Icon(
                Icons.delete,
                color: Colors.white, // Delete button color.
              ),
              onPressed:
                  _showDeleteConfirmationDialog, // Trigger confirmation dialog on delete button press.
            ),
        ],
      ),
      // Use Obx to listen to changes in the chat messages or UI visibility.
      body: Obx(() => _showChatUI || chatController.messages.isNotEmpty
          ? _buildChatUI() // Show chat UI if there are messages or the chat UI is enabled.
          : _buildAnimatedContainers()), // Show animated containers if there are no messages.
      // bottomNavigationBar: BottomNavBar(
      //   currentIndex:
      //       _selectedIndex, // Pass the current index to the custom bottom navigation bar.
      //   onTap: _onItemTapped, // Handle navigation bar item taps.
      // ),
    );
  }

  // Method to build animated containers as the default UI.
  Widget _buildAnimatedContainers() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAnimatedContainer(Colors.red,
              "How to maintain a\nhealthy diet"), // First container.
          const SizedBox(height: 20), // Space between containers.
          _buildAnimatedContainer(
              Colors.green, "How can I stay Healthy"), // Second container.
          const SizedBox(height: 20),
          _buildAnimatedContainer(
              Colors.blue, "What is first Aid"), // Third container.
          const SizedBox(height: 20),
          _buildAnimatedContainer(Colors.orange,
              "Why is Basic first aid knowledge necessary "), // Fourth container.
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => setState(() {
              _showChatUI =
                  true; // Show the chat UI when "Ask a question" is tapped.
            }),
            child: _buildAnimatedContainer(
                Colors.purple, "Ask a question"), // Fifth container.
          ),
        ],
      ),
    );
  }

  // Helper method to build individual animated containers with different colors and text.
  Widget _buildAnimatedContainer(Color color, String text) {
    return GestureDetector(
      onTap: () {
        if (text != "Ask a question") {
          chatController.sendMessage(ChatMessage(
              user: chatController.currentUser,
              text: text,
              createdAt:
                  DateTime.now())); // Send the container text as a message.
        } else {
          setState(() {
            _showChatUI = true; // Show the chat UI for input.
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(seconds: 2), // Animation duration.
        height: 80, // Container height.
        width: 300, // Container width.
        decoration: BoxDecoration(
          color: color, // Container background color.
          borderRadius: BorderRadius.circular(20), // Rounded corners.
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(text, // Display the provided text inside the container.
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  // Method to build the chat UI with DashChat.
  Widget _buildChatUI() {
    return DashChat(
      currentUser:
          chatController.currentUser, // Set the current user for the chat.
      onSend: chatController.sendMessage, // Handle sending messages.
      messages:
          chatController.messages, // Pass the observable chat messages list.
    );
  }
}
