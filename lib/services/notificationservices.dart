import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize notifications
  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Set app icon
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Request notification permissions
  Future<void> requestNotificationPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');
    } else {
      print('User denied or has not accepted notification permission');
    }
  }

  // Handle foreground notifications
  void handleForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        // Show the notification with the title and body from the message
        showNotification(
          message.notification!.title ??
              'Notification', // Use a default title if null
          message.notification!.body ??
              'You have a new message.', // Use a default body if null
        );
      }
    });
  }

  // Show a notification
  Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'login_task_channel', // Channel ID
      'User and Task Notifications', // Channel name
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      title,
      body,
      platformChannelSpecifics,
    );
  }

  // Show notification when user logs in
  Future<void> showLoginNotification() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await showNotification(
        'Welcome, ${user.email}',
        'You have successfully logged in.',
      );
    }
  }

  // Show notification for task actions (add, delete, update, complete)
  Future<void> showTaskActionNotification(String action) async {
    await showNotification(
      'Task Update',
      'You have $action a task.',
    );
  }

  // Helper method to show notification when a task is added
  Future<void> showAddTaskNotification() async {
    await showTaskActionNotification('added');
  }

  // Helper method to show notification when a task is deleted
  Future<void> showDeleteTaskNotification() async {
    await showTaskActionNotification('deleted');
  }

  // Helper method to show notification when a task is updated
  Future<void> showUpdateTaskNotification() async {
    await showTaskActionNotification('updated');
  }

  // Helper method to show notification when a task is marked as completed
  Future<void> showCompleteTaskNotification() async {
    await showTaskActionNotification('completed');
  }
}
