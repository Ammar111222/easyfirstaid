import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_first_aid/auth/authService.dart';
import 'package:easy_first_aid/auth/login.dart';
import 'package:get/get.dart';

class Signup extends StatefulWidget {
  final String email;
  const Signup({Key? key, required this.email}) : super(key: key);

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passswordController = TextEditingController();

  bool _isChecked = false; // Checkbox state

  void _toggleCheckbox(bool? value) {
    setState(() {
      _isChecked = value ?? false;
    });
  }

  final AuthService _authService = AuthService(); // Instance of AuthService

  _signup() async {
    // Ensure terms and conditions are accepted
    if (!_isChecked) {
      Get.snackbar(
        'Terms and Conditions',
        'Please accept the terms and conditions to proceed.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final String email = _emailController.text.trim();
    final String password = _passswordController.text.trim();

    // Regular expression to validate email format
    RegExp emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+');

    if (email.isNotEmpty && password.isNotEmpty) {
      if (!emailRegExp.hasMatch(email)) {
        Get.snackbar(
          'Invalid Email',
          'Please enter a valid email address.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } else if (password.length < 6) {
        Get.snackbar(
          'Invalid Password',
          'Password must be at least 6 characters long.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } else {
        try {
          // Create user and send verification email
          User? user = await _authService.createUserWithEmailAndPassword(
              context, email, password);

          if (user != null) {
            // Show a message to ask the user to verify their email
            // Get.snackbar(
            //   "Success",
            //   "Moving to Login page",
            //   backgroundColor: Colors.orange,
            //   colorText: Colors.white,
            // );
          }
        } catch (e) {
          // Exception handling is now managed in AuthService
        }
      }
    } else {
      Get.snackbar(
        'Empty Fields',
        'Please fill in all fields to continue.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Container(
        height: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                'https://img.freepik.com/free-photo/background-gradient-lights_23-2149304991.jpg?size=626&ext=jpg&ga=GA1.1.2008272138.1725840000&semt=ais_hybrid', // Replace with your network image URL
                fit: BoxFit.cover,
              ),
            ),
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: screenHeight * 0.14),
                    const Center(
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 30,
                          color: Color.fromARGB(255, 19, 18, 18),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    const Center(
                      child: Text(
                        'Fill your information below',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Color.fromARGB(255, 52, 50, 50),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.05),
                    CustomTextField(
                      label: 'Email',
                      hintText: 'example@gmail.com',
                      obscureText: false,
                      controller: _emailController,
                    ),
                    CustomTextField(
                      label: 'Password',
                      hintText: 'Enter your password',
                      isPasswordField: true,
                      obscureText: true,
                      controller: _passswordController,
                    ),
                    SizedBox(height: screenHeight * 0.023),
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 0, 10),
                          child: Checkbox(
                            value: _isChecked,
                            onChanged: _toggleCheckbox,
                            activeColor: const Color.fromARGB(255, 51, 49, 49),
                            checkColor: Colors.white,
                          ),
                        ),
                        const Text("Agree with "),
                        TextButton(
                          onPressed: () {
                            // Navigate to Terms and Conditions page or show them
                          },
                          child: const Text("Terms and Conditions"),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Padding(
                      padding: const EdgeInsets.only(left: 30, right: 10),
                      child: ElevatedButton(
                        onPressed: () {
                          _signup();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 51, 49, 49),
                          fixedSize: const Size(350, 60),
                        ),
                        child: const Text(
                          "Sign up",
                          style: TextStyle(color: Colors.white, fontSize: 20),
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.03),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account?"),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: ((context) => const Login()),
                              ),
                            );
                          },
                          child: const Text("Sign in"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomTextField extends StatefulWidget {
  final String label;
  final String hintText;
  final bool isPasswordField;
  final ValueChanged<String>? onChanged;
  final double width;
  final bool obscureText;
  final TextEditingController? controller;

  const CustomTextField({
    Key? key,
    required this.label,
    required this.hintText,
    this.isPasswordField = false,
    this.onChanged,
    this.width = double.infinity,
    required this.obscureText,
    this.controller,
  }) : super(key: key);

  @override
  _CustomTextFieldState createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget
        .isPasswordField; // Initialize obscureText based on isPasswordField
  }

  void _toggleObscureText() {
    setState(() {
      _obscureText = !_obscureText; // Toggle the obscureText state
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black,
            ),
          ),
          // const SizedBox(height: 5),
          Container(
            width: widget.width, // Set the width of the container
            child: TextFormField(
              controller: widget.controller,
              obscureText: widget.isPasswordField ? _obscureText : false,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                floatingLabelBehavior: FloatingLabelBehavior.never,
                hintText: widget.hintText,
                filled: true,
                fillColor: const Color.fromARGB(255, 213, 210, 210),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15.0),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: widget.isPasswordField
                    ? IconButton(
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: _toggleObscureText,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
