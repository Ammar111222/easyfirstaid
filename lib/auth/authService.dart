import 'package:easy_first_aid/auth/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create user with email and password
  Future<User?> createUserWithEmailAndPassword(
      BuildContext context, String email, String password) async {
    try {
      _showLoadingIndicator(context);

      // Create the user
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        // Send email verification
        await user.sendEmailVerification();
        print("Verification email sent to ${user.email}");

        // Check if the email is verified
        bool isVerified = await _checkEmailVerified(user, context);

        // If the email is verified, return the user
        if (isVerified) {
          return user;
        }
      }

      return null;
    } on FirebaseAuthException catch (e) {
      _hideLoadingIndicator(context);
      if (e.code == 'weak-password') {
        _showSnackbar(
          'Weak Password',
          'The password provided is too weak.',
          Colors.red,
          Colors.white,
        );
      } else if (e.code == 'email-already-in-use') {
        _showSnackbar(
          'Email In Use',
          'The account already exists for that email.',
          Colors.red,
          Colors.white,
        );
      } else {
        _showSnackbar(
          'Error',
          e.message ?? 'An unknown error occurred',
          Colors.red,
          Colors.white,
        );
      }
      return null;
    } catch (e) {
      _hideLoadingIndicator(context);
      print(e.toString());
      _showSnackbar(
        'Unexpected Error',
        'An unexpected error occurred: ${e.toString()}',
        Colors.red,
        Colors.white,
      );
      return null;
    }
  }

  // Check if the email is verified
  Future<bool> _checkEmailVerified(User user, BuildContext context) async {
    bool isVerified = false;
    bool verificationSnackbarShown = false; // Flag to show snackbar only once

    while (!isVerified) {
      await user.reload(); // Refresh user status
      user = _auth.currentUser!;

      if (user.emailVerified) {
        isVerified = true;
        _hideLoadingIndicator(context);
        if (Get.isSnackbarOpen) {
          Get.back(); // Dismiss existing Snackbar if open
        }
        _showSnackbar(
          "Success",
          "Email verification successful",
          Colors.green,
          Colors.white,
        );
        // Navigate to login screen
        Future.delayed(const Duration(seconds: 3), () {
          if (isVerified) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Login()),
            );
          }
        });
      } else {
        // Show "Verify your email" snackbar only once
        if (!verificationSnackbarShown) {
          verificationSnackbarShown =
              true; // Set flag to true after first display
          _showSnackbar(
            'Email Verification',
            'Please verify your email to continue.',
            Colors.yellow,
            Colors.black,
          );
        }
        await Future.delayed(const Duration(seconds: 5));
      }
    }

    return isVerified;
  }

  void _showLoadingIndicator(BuildContext context) {
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

  void _hideLoadingIndicator(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  Future<User?> loginUserWithEmailAndPassword(
      String email, String password) async {
    try {
      final credentials = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return credentials.user;
    } catch (e) {
      print("Error: ${e.toString()}");
    }
    return null;
  }

  // Utility method to show Snackbar
  void _showSnackbar(
      String title, String message, Color backgroundColor, Color textColor) {
    if (Get.isSnackbarOpen) {
      Get.back(); // Dismiss the existing Snackbar if open
    }
    Get.snackbar(
      title,
      message,
      backgroundColor: backgroundColor,
      colorText: textColor,
    );
  }
}
