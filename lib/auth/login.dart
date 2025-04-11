import 'package:easy_first_aid/auth/signup.dart';
import 'package:easy_first_aid/database/devicetoken.dart';
import 'package:easy_first_aid/screens/mainscreen.dart';
import 'package:easy_first_aid/screens/profile/alerts.dart';
// import 'package:easy_first_aid/screens/homescreen.dart';
// import 'package:easy_first_aid/screens/mainscreen.dart';
// import 'package:easy_first_aid/screens/mainscreenWidgets.dart';
import 'package:easy_first_aid/services/notificationservices.dart';
// import 'package:easy_first_aid/services/database_services.dart'; // Import the DatabaseServices class
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  final Tokenservices _dbServices =
      Tokenservices(); // Instantiate the DatabaseServices class
  final NotificationService _notificationService = NotificationService();

  // Show loading indicator
  void _showLoadingIndicator() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  // Hide loading indicator
  void _hideLoadingIndicator() {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  // Method to handle login
  Future<void> _login() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isNotEmpty && password.isNotEmpty) {
      _showLoadingIndicator(); // Show loading indicator
      try {
        // Sign in the user
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);

        _hideLoadingIndicator(); // Hide loading indicator

        User? user = userCredential.user;

        if (user != null && !user.emailVerified) {
          // If the user's email is not verified
          Get.snackbar(
            "Email Not Verified",
            "Please verify your email before logging in.",
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          // Send verification email again
          await user.sendEmailVerification();
          FirebaseAuth.instance.signOut(); // Sign out the user
        } else if (user != null && user.emailVerified) {
          // Store device token in Firestore
          await _dbServices
              .storeDeviceToken(); // Store the FCM token after successful login

          // Navigate to home if email is verified
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainScreen()),
          );
          _notificationService.showLoginNotification();
        }
      } on FirebaseAuthException catch (e) {
        _hideLoadingIndicator(); // Hide loading indicator on error
        if (e.code == 'user-not-found') {
          Get.snackbar(
              "User not found", "This user does not exist, please signup");
        } else if (e.code == 'wrong-password') {
          Get.snackbar("Error", "The supplied credentials are incorrect.",
              backgroundColor: Colors.red, colorText: Colors.white);
        } else {
          Get.snackbar("Error", e.toString(),
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      } catch (e) {
        _hideLoadingIndicator(); // Hide loading indicator on error
        Get.snackbar("Error", "${e.toString()}");
      }
    } else {
      Get.snackbar("Error", "Please fill all the fields",
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevents resizing when keyboard shows
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://img.freepik.com/free-photo/background-gradient-lights_23-2149304991.jpg?size=626&ext=jpg&ga=GA1.1.2008272138.1725840000&semt=ais_hybrid',
                ),
                fit: BoxFit.cover, // Ensures the image covers the entire screen
              ),
            ),
          ),
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: screenHeight * 0.11),
                const Center(
                  child: Text(
                    'Sign in',
                    style: TextStyle(
                      fontSize: 30,
                      color: Color.fromARGB(255, 19, 18, 18),
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                const Center(
                  child: Text(
                    'Hi! Welcome back, you have been missed',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Color.fromARGB(255, 65, 63, 63),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.04),
                CustomTextField(
                  controller: _emailController,
                  label: 'Email',
                  hintText: 'example@gmail.com',
                  obscureText: false,
                ),
                CustomTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hintText: 'Enter your password',
                  isPasswordField: true,
                  obscureText: true,
                ),
                SizedBox(height: screenHeight * 0.03),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 51, 49, 49),
                    fixedSize: const Size(350, 60),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : const Text(
                          "Sign in",
                          style: TextStyle(color: Colors.white, fontSize: 20),
                        ),
                ),
                SizedBox(height: screenHeight * 0.03),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Signup(email: ''),
                          ),
                        );
                      },
                      child: const Text("Sign up"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
