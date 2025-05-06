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
          _actionHandler?.call(response.payload, response.actionId);
          handleFallDetectionResponse(response.actionId!, response.payload);
        } else if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            if (data.containsKey('type') && data['type'] == 'fall_detection') {
              _debugLog('Notification clicked for fall detection');
              onChildTap(data);
            }
          } catch (e) {
            _debugLog('Error parsing payload: $e');
          }
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
    AndroidNotificationDetails androidDetails = const AndroidNotificationDetails(
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
      category: AndroidNotificationCategory.alarm,
      actions: [
        AndroidNotificationAction(
          'ok_action',
          'I\'m Okay',
          showsUserInterface: true,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'help_action',
          'Need Help',
          showsUserInterface: true,
          cancelNotification: false,
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
    }

  void handleFallDetectionResponse(String actionId, [String? payload]) async {
    _debugLog('Handling fall detection response: $actionId, payload: $payload');
    _fallResponseTimer?.cancel();
    
    try {
      if (payload != null) {
        final Map<String, dynamic> data = jsonDecode(payload);
        if (data.containsKey('fallIncidentId')) {
          String fallIncidentId = data['fallIncidentId'];
          String status = actionId == 'ok_action' ? 'false_alarm' : 'need_help';
          
          // Update the fall incident status
          await firestore.collection('fall_incidents').doc(fallIncidentId).update({
            'status': status,
            'responseTime': FieldValue.serverTimestamp(),
          });
          
          _debugLog('Updated fall incident $fallIncidentId status to $status');
          
          // If need help, notify parent
          if (status == 'need_help') {
            await _sendParentHelpNotification(fallIncidentId);
          }
          
          // Cancel the notification
      await cancelFallDetectionNotification();
    }
  }
    } catch (e) {
      _debugLog('Error handling fall detection response: $e');
  }

      _isNotificationActive = false;
  }
  
  Future<void> _sendParentHelpNotification(String fallIncidentId) async {
    try {
      // Get incident details
      DocumentSnapshot incidentDoc = await firestore
          .collection('fall_incidents')
          .doc(fallIncidentId)
          .get();
      
      if (!incidentDoc.exists) return;
      
      Map<String, dynamic> incidentData = incidentDoc.data() as Map<String, dynamic>;
      String childId = incidentData['childId'];
      
      // Get child details
      DocumentSnapshot childDoc = await firestore
          .collection('users')
          .doc(childId)
          .get();
      
      if (!childDoc.exists) return;
      
      Map<String, dynamic> childData = childDoc.data() as Map<String, dynamic>;
      String? parentId = childData['parentId'];
      
      if (parentId == null) return;
      
      // Get parent FCM token
      DocumentSnapshot parentDoc = await firestore
          .collection('users')
          .doc(parentId)
          .get();
      
      if (!parentDoc.exists) return;
      
      Map<String, dynamic> parentData = parentDoc.data() as Map<String, dynamic>;
      String? fcmToken = parentData['fcmToken'];
      
      if (fcmToken == null) return;

      // Send urgent notification
      String childName = childData['displayName'] ?? 'Your child';
      String urgentMessage = '$childName needs help! They responded "Need Help" to the fall alert.';
      
      // This would typically be handled by a server-side function
      // Here we're simply logging it
      _debugLog('Would send urgent notification to parent: $urgentMessage');
    } catch (e) {
      _debugLog('Error sending parent help notification: $e');
    }
  }

  Future<void> cancelFallDetectionNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(fallDetectionNotificationId);
    _isNotificationActive = false;
    _debugLog('Fall detection notification canceled');
  }

  Future<void> notifyParentAboutFall() async {
    // This would typically be implemented with FCM to notify the parent
    _debugLog('Parent would be notified about fall');
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