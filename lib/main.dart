import 'package:easy_first_aid/constants/apiKey.dart';
import 'package:easy_first_aid/firebase_options.dart';
import 'package:easy_first_aid/screens/ai_assistant.dart';
import 'package:easy_first_aid/screens/detectImage.dart';
import 'package:easy_first_aid/screens/homescreen.dart';
import 'package:easy_first_aid/auth/login.dart';
import 'package:easy_first_aid/auth/signup.dart';
import 'package:easy_first_aid/screens/mainscreen.dart';
import 'package:easy_first_aid/screens/startScreen.dart';
import 'package:easy_first_aid/screens/symptomscheck.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:easy_first_aid/services/notificationservices.dart';

import 'screens/mainscreenWidgets.dart';
// Import the notification service

// Main background handler for FCM
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Gemini
  Gemini.init(apiKey: Gemini_ApiKey);

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize NotificationService
  NotificationService notificationService = NotificationService();
  await notificationService.initialize();

  runApp(
    ShowCaseWidget(builder: (context) => const MyApp()),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // final NotificationService _notificationService = NotificationService();

  // @override
  // void initState() {
  //   super.initState();
  //   _notificationService
  //       .handleForegroundMessages(); // Handle foreground notifications
  //   _notificationService
  //       .requestNotificationPermission(); // Request permissions on iOS devices
  // }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home:  Startscreen(),
      routes: {
        'signup': (context) => const Signup(
              email: '',
            ),
        'login': (context) => const Login(),
        'homescreen': (context) => const Homescreen(),
        'symptomscheck': (context) => const Symptomscheck(),
        'ai_Assistant': (context) => const GeminiApp(),
      },
    );
  }
}
