// import 'package:easy_first_aid/auth/login.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:pin_code_text_field/pin_code_text_field.dart';
// import 'package:email_auth/email_auth.dart';

// class Verification extends StatefulWidget {
//   final String email; // Email passed from previous screen

//   const Verification({
//     Key? key,
//     required this.email,
//   }) : super(key: key);

//   @override
//   State<Verification> createState() => _VerificationState();
// }

// class _VerificationState extends State<Verification> {
//   bool hasError = false;
//   int pinLength = 6;
//   EmailAuth emailAuth = EmailAuth(sessionName: 'Signup');
//   final TextEditingController otpController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();

  
//   @override
//   void initState() {
//     super.initState();
//     // Assign widget.email to emailController
//     emailController.text = widget.email;

//     // Automatically send OTP when screen loads
//     sendOtp();
//   }

//   void _showErrorDialog(String title, String message) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text(title),
//           content: Text(message),
//           actions: <Widget>[
//             TextButton(
//               child: const Text("OK"),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Future<void> sendOtp() async {
//     try {
//       // Print email before sending to verify it's correct
//       print("Sending OTP to email: ${emailController.text}");

//       var result = await emailAuth.sendOtp(
//         recipientMail: emailController.text,
//         otpLength: 6,
//       );

//       if (result) {
//         print("OTP sent to email: ${emailController.text}");
//       } else {
//         // Failed to send OTP
//         _showErrorDialog("Error", "Failed to send OTP. Please try again.");
//       }
//     } catch (e) {
//       // Log and show the error
//       print("Error sending OTP: ${e.toString()}");
//       _showErrorDialog(
//           "Error", "An unexpected error occurred: ${e.toString()}");
//     }
//   }

//   Future<void> verifyOtp() async {
//     var result = emailAuth.validateOtp(
//         recipientMail: emailController.text, userOtp: otpController.text);
//     if (result) {
//       Get.snackbar("Success", "OTP verification successful");
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => const Login()),
//       );
//     } else {
//       _showErrorDialog("Error", "Invalid OTP. Please try again.");
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SingleChildScrollView(
//         child: Column(
//           children: [
//             const SizedBox(height: 100),
//             const Center(
//               child: Text(
//                 'Verify Code',
//                 style: TextStyle(
//                   fontSize: 30,
//                   color: Color.fromARGB(255, 19, 18, 18),
//                   decoration: TextDecoration.none,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 10),
//             Center(
//               child: Text(
//                 'Please enter the code sent to ${widget.email}',
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(
//                   fontSize: 15,
//                   color: Colors.grey,
//                   decoration: TextDecoration.none,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 40),
//             Padding(
//               padding: const EdgeInsets.only(left: 0),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
//                   PinCodeTextField(
//                     pinBoxRadius: 10,
//                     autofocus: true,
//                     controller: otpController,
//                     hideCharacter: false,
//                     highlight: true,
//                     defaultBorderColor:
//                         const Color.fromARGB(255, 153, 153, 153),
//                     hasTextBorderColor:
//                         const Color.fromARGB(255, 153, 153, 153),
//                     highlightPinBoxColor:
//                         const Color.fromARGB(255, 153, 153, 153),
//                     maxLength: pinLength,
//                     hasError: hasError,
//                     onTextChanged: (text) {
//                       setState(() {
//                         hasError = false;
//                       });
//                     },
//                     onDone: (text) {
//                       print("DONE $text");
//                     },
//                     pinBoxWidth: 60,
//                     pinBoxHeight: 60,
//                     hasUnderline: false,
//                     wrapAlignment: WrapAlignment.spaceEvenly,
//                     pinBoxDecoration:
//                         ProvidedPinBoxDecoration.defaultPinBoxDecoration,
//                     pinTextStyle: const TextStyle(fontSize: 22.0),
//                     pinTextAnimatedSwitcherTransition:
//                         ProvidedPinBoxTextAnimation.scalingTransition,
//                     pinTextAnimatedSwitcherDuration:
//                         const Duration(milliseconds: 400),
//                     highlightAnimationBeginColor:
//                         const Color.fromARGB(255, 153, 153, 153),
//                     highlightAnimationEndColor: Colors.white12,
//                     keyboardType: TextInputType.number,
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 30),
//             const Text(
//               "Didn't receive the OTP?",
//               style: TextStyle(fontSize: 16),
//             ),
//             TextButton(
//               onPressed: () {
//                 sendOtp();
//               },
//               child: const Text(
//                 "Resend Code",
//                 style: TextStyle(
//                     color: Colors.black, decoration: TextDecoration.underline),
//               ),
//             ),
//             const SizedBox(height: 50),
//             ElevatedButton(
//               onPressed: () {
//                 verifyOtp();
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color.fromARGB(255, 51, 49, 49),
//                 fixedSize: const Size(350, 60),
//               ),
//               child: const Text(
//                 "Verify",
//                 style: TextStyle(color: Colors.white, fontSize: 20),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
