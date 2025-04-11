import 'package:easy_first_aid/auth/signup.dart';
import 'package:flutter/material.dart';
import 'package:swipeable_button_view/swipeable_button_view.dart';

class Startscreen extends StatefulWidget {
  const Startscreen({super.key});

  @override
  State<Startscreen> createState() => _StartscreenState();
}

class _StartscreenState extends State<Startscreen> {
  bool isFinished = false;

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.network(
              'https://img.freepik.com/free-photo/background-gradient-lights_23-2149304991.jpg?size=626&ext=jpg&ga=GA1.1.2008272138.1725840000&semt=ais_hybrid',
              fit: BoxFit.cover,
            ),
          ),
          // Foreground Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 10, bottom: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: screenHeight * 0.1,
                          width: screenWidth * 0.12,
                        ),
                        const Image(
                          image: AssetImage(
                            'assets/images/FirstAid.png',
                          ),
                        ),
                        const Text(
                          "Easy First Aid",
                          style: TextStyle(
                            fontSize: 25,
                            color: Color.fromARGB(255, 177, 34, 24),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.43),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30.0),
                    child: SizedBox(
                      width:
                          double.infinity, // Constrain the button to full width
                      child: SwipeableButtonView(
                        buttonText: 'SLIDE TO move forward',
                        buttonWidget: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.grey,
                        ),
                        activeColor: Color.fromARGB(255, 244, 46, 20),
                        isFinished: isFinished,
                        onWaitingProcess: () {
                          Future.delayed(const Duration(seconds: 2), () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const Signup(
                                  email: '',
                                ),
                              ),
                            );
                            setState(() {
                              isFinished = true;
                            });
                          });
                        },
                        onFinish: () async {
                          setState(() {
                            isFinished = false;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
