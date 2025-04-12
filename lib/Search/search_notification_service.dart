import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';

class SearchNotificationService {

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseMessaging fcm;
  final Function(Map<String, dynamic>) onChildTap;
  bool _isInitialized = false; // Add flag to prevent reinitialization
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  Function(String?, String?)? _actionHandler;
  Timer? _fallResponseTimer;
  bool _isNotificationActive = false;

  // Use a consistent notification ID for fall detection
  static const int fallDetectionNotificationId = 100;

  SearchNotificationService({
    required this.auth,
    required this.firestore,
    required this.fcm,
    required this.onChildTap,
  });

  void _debugLog(String message) {
    print('NotificationService: $message');
  }

  Future<void> initialize() async {
    if (_isInitialized) return; // Prevent multiple initializations
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await _setupNotificationChannels();
    await _initializeNotifications();
    await _initializeFCM();
    _isInitialized = true;
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'fall_detection',
          actions: [
            DarwinNotificationAction.plain(
              'ok_action',
              'I\'m Okay',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              'help_action',
              'Need Help',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
      ],
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _debugLog('Notification response received: actionId=${response.actionId}, payload=${response.payload}');
        if (response.actionId != null) {
          handleFallDetectionResponse(response.actionId!);
        }
      },
    );
    _debugLog('Notification initialization completed');
  }

  Future<void> _setupNotificationChannels() async {
    // Android notification channel for fall detection
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'fall_detection_channel',
      'Fall Detection',
      description: 'Notifications for fall detection alerts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Colors.red,

      showBadge: true,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _initializeFCM() async {
    // Request permission for notifications
    NotificationSettings settings = await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Notification permissions granted');

      // Get FCM token for this device
      String? token = await fcm.getToken();
      print('FCM Token: $token');

      // Save token to Firestore
      if (token != null && auth.currentUser != null) {
        await firestore.collection('users').doc(auth.currentUser!.uid).update({
          'fcmToken': token,
          'deviceUpdatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Handle token refresh
      fcm.onTokenRefresh.listen((newToken) async {
        print('FCM Token refreshed: $newToken');
        if (auth.currentUser != null) {
          await firestore.collection('users').doc(auth.currentUser!.uid).update({
            'fcmToken': newToken,
            'deviceUpdatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // Handle incoming FCM messages when app is in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');

        if (message.notification != null) {
          print('Message also contained a notification: ${message.notification}');
          showLocalNotification(
            message.notification?.title ?? 'Alert',
            message.notification?.body ?? 'You received a new notification',
            payload: jsonEncode(message.data),
          );
        }
      });

      // Handle notification clicks when app was terminated
      fcm.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          print('App opened from terminated state via notification');
          onChildTap(message.data);
        }
      });

      // Handle notification clicks when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('App opened from background state via notification');
        onChildTap(message.data);
      });
    } else {
      print('Notification permissions denied');
    }
  }

  Future<void> showLocalNotification(String title, String body, {String? payload}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'fall_detection_channel',
      'Fall Detection Notifications',
      channelDescription: 'Notifications for fall detection alerts',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000, // Unique ID
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  Future<void> showActionableNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'fall_detection_channel',
        'Fall Detection',
        channelDescription: 'Used for fall detection alerts',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('im_okay', 'I\'m Okay'),
        AndroidNotificationAction('need_help', 'Need Help'),
      ],
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      categoryIdentifier: 'fall_detection',
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
      100, // Use a consistent ID for fall detection notifications
        title,
        body,
        platformDetails,
        payload: payload,
      );
  }

  void setActionHandler(Function(String?, String?) handler) {
    _actionHandler = handler;
    _debugLog('Action handler set');

    // Check for launch details only if not already checked
    _flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails().then((details) {
      if (details?.didNotificationLaunchApp ?? false) {
        final response = details?.notificationResponse;
        if (response != null && _actionHandler != null && !_isNotificationActive) {
          _actionHandler!(response.payload, response.actionId);
          cancelFallDetectionNotification();
          _debugLog('Handled launch notification action: ${response.actionId}');
        }
      }
    });
  }

  Future<void> showFallDetectionNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    if (_isNotificationActive) {
      _debugLog('Notification already active, skipping...');
      return;
    }

    _debugLog('Showing fall detection notification...');
    _isNotificationActive = true;
    
    // Define notification details
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'fall_detection_channel',
      'Fall Detection',
      channelDescription: 'Notifications for fall detection',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      enableLights: true,
      color: Colors.red,
      ledColor: Colors.red,
      ledOnMs: 1000,
      ledOffMs: 500,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      showProgress: false,
      onlyAlertOnce: false,
      styleInformation: BigTextStyleInformation(body),
      actions: const [
        AndroidNotificationAction(
          'ok_action',
          'I\'m Okay',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'help_action',
          'Need Help',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
      categoryIdentifier: 'fall_detection',
    );

    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      // Cancel any existing notification first
      await _flutterLocalNotificationsPlugin.cancel(fallDetectionNotificationId);
      
      // Show the new notification
      await _flutterLocalNotificationsPlugin.show(
        fallDetectionNotificationId,
        title,
        body,
        platformDetails,
        payload: payload,
      );
      _debugLog('Fall detection notification shown successfully');
    } catch (e) {
      _debugLog('Error showing fall detection notification: $e');
      _isNotificationActive = false;
    }

    // Start 30-second timer for automatic parent notification if no response
    _fallResponseTimer?.cancel();
    _fallResponseTimer = Timer(Duration(seconds: 30), () async {
      if (_isNotificationActive) {
        _debugLog('No response received within 30 seconds. Notifying parent...');
        await notifyParentAboutFall();
        await cancelFallDetectionNotification();
      }
    });
  }

  void handleFallDetectionResponse(String action) async {
    if (!_isNotificationActive) {
      _debugLog('No active notification to handle response for');
      return;
    }

    _debugLog('Handling fall detection response: $action');
    
    if (action == 'ok_action') {
      _debugLog("User responded: I'm okay");
      _fallResponseTimer?.cancel();
      await cancelFallDetectionNotification();
    } else if (action == 'help_action') {
      _debugLog("User responded: I need help");
      _fallResponseTimer?.cancel();
      await notifyParentAboutFall();
      await cancelFallDetectionNotification();
    }
  }

  Future<void> cancelFallDetectionNotification() async {
    if (_isNotificationActive) {
      await _flutterLocalNotificationsPlugin.cancel(fallDetectionNotificationId);
      _isNotificationActive = false;
      _debugLog('Fall detection notification cancelled');
    }
  }

  Future<void> notifyParentAboutFall() async {
    if (!_isNotificationActive) {
      _debugLog('No active notification to notify parent about');
      return;
    }

    try {
      _debugLog('Starting parent notification process...');
      
      // Get current user's document
      DocumentSnapshot userDoc = await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .get();
      _debugLog('Got user document');

      // Check if parent exists with validation
      String? parentId = userDoc.get('parentId') as String?;
      if (parentId == null || parentId.isEmpty) {
        _debugLog('No valid parent ID found in user document');
        return;
      }
      _debugLog('Found parent ID: $parentId');

      // Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _debugLog('Got current location: ${position.latitude}, ${position.longitude}');

      // Create the notification data
      Map<String, dynamic> notificationData = {
        'type': 'fall_alert',
        'title': 'Fall Alert',
        'body': 'Your child has fallen and needs help!',
        'latitude': position.latitude.toString(),
        'longitude': position.longitude.toString(),
        'childId': auth.currentUser!.uid,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Store the notification in Firestore
      await firestore.collection('notifications').add({
        'type': 'fall_alert',
        'recipientId': parentId,
        'senderId': auth.currentUser!.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'location': GeoPoint(position.latitude, position.longitude),
        'status': 'pending',
        'data': notificationData,
        'read': false,
      });
      _debugLog('Notification stored in Firestore');

    } catch (e, stackTrace) {
      _debugLog('Error in parent notification process: $e');
      _debugLog('Stack trace: $stackTrace');
      
      // Log the error in Firestore
      await firestore.collection('notification_errors').add({
        'type': 'parent_notification_error',
        'userId': auth.currentUser!.uid,
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  FlutterLocalNotificationsPlugin getNotificationPlugin() {
    return _flutterLocalNotificationsPlugin;
  }

  Future<void> sendNotificationFallback(String parentId, String title, String body) async {
    try {
      await firestore.collection('pending_notifications').add({
        'recipientId': parentId,
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'fall_detection',
        'childId': auth.currentUser?.uid,
      });
      print('Created fallback notification in Firestore');
    } catch (e) {
      print('Error sending fallback notification: $e');
    }
  }
}