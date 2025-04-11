import 'package:easy_first_aid/auth/login.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  // Sign out function
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    // Redirect to login after sign out
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const Login())); // Adjust route accordingly
  }

  @override
  Widget build(BuildContext context) {
    // Get the current user
    User? user = FirebaseAuth.instance.currentUser;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.grey[900], // Set background color to black
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
          child: Column(
            children: [
              // Profile container with gradient
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.purple.shade600, Colors.pink.shade600],
                  ),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 25, // Avatar size
                      backgroundImage: CachedNetworkImageProvider(
                        'https://i.imgur.com/BoN9kdC.png', // Pick any image from the internet
                      ),
                    ),
                    const SizedBox(width: 12), // Space between avatar and email
                    if (user != null)
                      Expanded(
                        child: Text(
                          user.email ?? 'No Email', // Display the user's email
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis, // Handle overflow
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.3),
              // Welcome Text with gradient
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "Welcome ",
                      style: TextStyle(
                        fontSize: 25, // Reduced font size
                        fontWeight: FontWeight.bold,
                        foreground: Paint()
                          ..shader = const LinearGradient(
                            colors: <Color>[Colors.purple, Colors.pink],
                          ).createShader(Rect.fromLTWH(0, 0, 200, 70)),
                      ),
                    ),
                    if (user != null)
                      TextSpan(
                        text: user.email ?? 'No Email',
                        style: TextStyle(
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: <Color>[
                                Color.fromARGB(255, 15, 95, 188),
                                Color.fromARGB(255, 204, 96, 33)
                              ],
                            ).createShader(Rect.fromLTWH(0, 0, 200, 70)),
                          fontSize: 18, // Reduced font size
                          fontWeight: FontWeight.bold,
                          // color: Colors.white, // User email color
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Sign Out Button
              ElevatedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout, color: Colors.black),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.black, fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Additional button for editing profile
              ElevatedButton.icon(
                onPressed: () {
                  // Placeholder for additional profile actions (e.g., Edit Profile)
                  Get.snackbar("Not available at the moment", "Coming Soon...",
                      backgroundColor: Colors.red, colorText: Colors.white);
                },
                icon: const Icon(Icons.edit, color: Colors.black),
                label: const Text(
                  'Edit Profile',
                  style: TextStyle(color: Colors.black, fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
