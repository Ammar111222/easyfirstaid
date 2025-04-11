import 'package:easy_first_aid/screens/homescreen.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class ContentPage extends StatefulWidget {
  final String title;
  final String description;
  final String step1;
  final String step2;
  final String step3;
  final String imageUrl;

  // Constructor that accepts title, description, steps, and image URL
  const ContentPage({
    Key? key,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.step1,
    required this.step2,
    required this.step3,
  }) : super(key: key);

  @override
  _ContentPageState createState() => _ContentPageState();
}

class _ContentPageState extends State<ContentPage> {
  final PageController _pageController =
      PageController(); // Controller for handling page navigation
  int _currentStep = 0; // Variable to track the current step

  // Function to make a phone call
  Future<void> _makePhoneCall(String number) async {
    // Check if the phone call permission is granted
    PermissionStatus status = await Permission.phone.status;

    if (status.isGranted) {
      // If permission is granted, try to launch the phone call
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: number,
      );
      if (await canLaunch(launchUri.toString())) {
        await launch(launchUri.toString());
      } else {
        throw 'Could not launch $number';
      }
    } else if (status.isDenied) {
      // If permission is denied, request permission
      status = await Permission.phone.request();
      if (status.isGranted) {
        print("Phone permission status: ${status.toString()}");
        _makePhoneCall(
            number); // Try making the call again if permission is granted
      } else {
        _showPermissionDeniedDialog(); // Show permission denied dialog
      }
    } else if (status.isPermanentlyDenied) {
      // If permission is permanently denied, open app settings
      openAppSettings();
    }
  }

  // Show a dialog if permission is denied
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Denied'),
          content: const Text(
              'Phone call permission is required to make calls. Please enable it in the app settings.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Settings'),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Navigate to the next step in the PageView
  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.decelerate,
        );
      });
    }
  }

  // Navigate to the previous step in the PageView
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.decelerate,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 244, 46, 20),
        title: Text(
          widget.title,
          style: TextStyle(color: Colors.white),
        ), // Display the title of the content
        leading: IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const Homescreen(), // Navigate back to the home screen
              ),
            );
          },
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
        ),
      ),
      body: Column(
        children: [
          // Image container at the top, occupying 40% of the screen height
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                    widget.imageUrl), // Load image from the provided URL
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Expanded section for description, steps, and navigation
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description of the content
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    widget.description,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                // Display the current step number
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                  child: Center(
                    child: Text(
                      'Step ${_currentStep + 1}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 244, 46, 20),
                      ),
                    ),
                  ),
                ),
                // PageView to display steps with swipe navigation
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentStep = index;
                      });
                    },
                    children: [
                      _buildStepContent(widget.step1), // Display step 1
                      _buildStepContent(widget.step2), // Display step 2
                      _buildStepContent(widget.step3), // Display step 3
                    ],
                  ),
                ),
                // Navigation buttons for next and previous steps
                _buildNavigationButtons(),
              ],
            ),
          ),
          // Container at the bottom for making a phone call
          AnimatedContainer(
            duration: const Duration(milliseconds: 1000),
            width: double.infinity,
            color: const Color.fromARGB(255, 244, 46, 20),
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () {
                _makePhoneCall('1166'); // Make a call when tapped
              },
              child: const Center(
                child: Text(
                  'Call for Medical Assistance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build content for each step in the PageView
  Widget _buildStepContent(String stepDescription) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stepDescription,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  // Build the navigation buttons for next and previous steps
  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavigationButton(
              Icons.arrow_back, _previousStep), // Previous step button
          _buildNavigationButton(
              Icons.arrow_forward, _nextStep), // Next step button
        ],
      ),
    );
  }

  // Helper method to create circular navigation buttons
  Widget _buildNavigationButton(IconData icon, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(), // Circular button shape
        backgroundColor: Color.fromARGB(255, 244, 46, 20),
        padding: const EdgeInsets.all(16),
      ),
      child: Icon(icon, color: Colors.white), // Icon inside the button
    );
  }
}
