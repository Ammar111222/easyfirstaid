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
              'im_okay',
              'I\'m Okay',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              'need_help',
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
        print('Notification response received: actionId=${response.actionId}, payload=${response.payload}');
        if (_actionHandler != null) {
          _actionHandler!(response.payload, response.actionId);
          cancelFallDetectionNotification();
          print('Notification canceled after action: ${response.actionId}');
        }
      },
    );
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
    print('Action handler set');

    // Check for launch details only if not already checked
    _flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails().then((details) {
      if (details?.didNotificationLaunchApp ?? false) {
        final response = details?.notificationResponse;
        if (response != null && _actionHandler != null) {
          _actionHandler!(response.payload, response.actionId);
          cancelFallDetectionNotification();
          print('Handled launch notification action: ${response.actionId}');
        }
      }
    });
  }

  Future<void> cancelFallDetectionNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(100);
    _isNotificationActive = false;
  }

  Future<void> checkLaunchNotification() async {
    final details = await _flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      final response = details?.notificationResponse;
      if (response != null && _actionHandler != null) {
        _actionHandler!(response.payload, response.actionId);
        await cancelFallDetectionNotification();
        print('Handled launch notification action: ${response.actionId}');
      }
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

  Future<void> showFallDetectionNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
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
      actions: [
        AndroidNotificationAction(
          'ok_action',
          'I\'m Okay',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          'help_action',
          'I Need Help',
          showsUserInterface: false,
        ),
      ],
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      fallDetectionNotificationId,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  void handleFallDetectionResponse(String action) {
    if (action == 'ok_action') {
      _debugLog("User responded: I'm okay");
      _fallResponseTimer?.cancel();
      _isNotificationActive = false;
    } else if (action == 'help_action') {
      _debugLog("User responded: I need help");
      _fallResponseTimer?.cancel();
      _notifyParentAboutFall();
    }
  }

  Future<void> _notifyParentAboutFall() async {
    try {
      // Get current user's location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get current user's document
      DocumentSnapshot userDoc = await firestore
          .collection('users')
          .doc(auth.currentUser?.uid)
          .get();

      // Get parent ID
      String? parentId = userDoc.get('parentId') as String?;
      if (parentId == null) {
        _debugLog('No parent ID found');
        return;
      }

      // Send fall alert to parent
      await sendFallAlertToParent(
        location: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        childId: auth.currentUser!.uid,
      );

      _debugLog('Parent notified about fall');
    } catch (e) {
      _debugLog('Error notifying parent: $e');
    }
  }

  Future<void> sendFallAlertToParent({
    required Map<String, dynamic> location,
    required String childId,
  }) async {
    String? parentId;  // Declare parentId outside try block
    
    try {
      // Get child's document to find parent ID
      DocumentSnapshot childDoc = await firestore.collection('users').doc(childId).get();
      parentId = childDoc.get('parentId') as String?;  // Assign value to parentId

      if (parentId == null) {
        _debugLog('No parent ID found');
        return;
      }

      // Get parent's document to find FCM token
      DocumentSnapshot parentDoc = await firestore.collection('users').doc(parentId).get();
      String? parentToken = parentDoc.get('fcmToken') as String?;

      if (parentToken == null) {
        _debugLog('No parent FCM token found');
        // Try fallback notification
        await sendNotificationFallback(parentId, 'Fall Detected', 'Your child may have fallen. Location: ${location['latitude']}, ${location['longitude']}');
        return;
      }

      // Send FCM message
      await fcm.sendMessage(
        to: parentToken,
        data: {
          'type': 'fall_alert',
          'title': 'Fall Detected - Help Needed',
          'body': 'Your child may have fallen. Location: ${location['latitude']}, ${location['longitude']}',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'channel_id': 'fall_detection_channel',
          'priority': 'high',
        },
      );

      // Log the notification in Firestore
      await firestore.collection('notifications_log').add({
        'type': 'fall_alert',
        'recipientId': parentId,
        'childId': childId,
        'location': location,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
        'fcmToken': parentToken,
      });

      _debugLog('Fall alert sent to parent successfully');
    } catch (e) {
      _debugLog('Error sending fall alert: $e');
      
      // Log the error in Firestore
      if (parentId != null) {  // Only log if we have a parentId
        await firestore.collection('notifications_log').add({
          'type': 'fall_alert',
          'recipientId': parentId,
          'childId': childId,
          'location': location,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'failed',
          'error': e.toString(),
        });
      }
    }
  }
}