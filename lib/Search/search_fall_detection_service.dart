import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:easy_first_aid/Search/search_notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

// Define Priority enum for FCM
enum Priority { high, normal }

// Define configuration classes for FCM
class AndroidMessageConfiguration {
  final Priority priority;
  final AndroidNotification? notification;

  AndroidMessageConfiguration({
    required this.priority,
    this.notification,
  });

  Map<String, dynamic> toMap() {
    return {
      'priority': priority == Priority.high ? 'high' : 'normal',
      if (notification != null) 'notification': notification!.toMap(),
    };
  }
}

class AndroidNotification {
  final String channelId;
  final Priority priority;

  AndroidNotification({
    required this.channelId,
    required this.priority,
  });

  Map<String, dynamic> toMap() {
    return {
      'channel_id': channelId,
      'priority': priority == Priority.high ? 'high' : 'normal',
    };
  }
}

class NotificationAction {
  final String id;
  final String title;
  final Function onPressed;

  NotificationAction({
    required this.id,
    required this.title,
    required this.onPressed,
  });
}

class SearchFallDetectionService {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final SearchNotificationService notificationService;
  Timer? _fallResponseTimer;

  SearchFallDetectionService({
    required this.auth,
    required this.firestore,
    required this.notificationService,
  });

  // Constants for fall detection
  static const double FALL_THRESHOLD = 20.0; // Threshold for impact detection
  static const double FREE_FALL_THRESHOLD = 3.0; // Threshold for free fall detection
  static const double STILLNESS_THRESHOLD = 1.5; // Threshold for post-fall stillness
  static const int COOLDOWN_DURATION = 30; // Cooldown duration in seconds
  static const int MINIMUM_TIME_BETWEEN_DETECTIONS = 30; // seconds

  // Improved fall detection variables
  final List<double> _accelerationBuffer = [];
  final int _bufferSize = 50; // Increased buffer size for more accurate detection
  bool _isPotentialFallInProgress = false;
  bool _isProcessingFall = false;
  DateTime? _lastFallDetectionTime;

  // For debugging
  bool _debugMode = false;
  void Function(String)? onDebugMessage;

  void startFallDetection({bool debug = false}) {
    _debugMode = debug;
    _debugLog('Starting fall detection service...');
    
    // Reset all flags
    _isProcessingFall = false;
    _fallResponseTimer?.cancel();

    // Listen to accelerometer events
    accelerometerEvents.listen(
      (AccelerometerEvent event) {
        if (!_isProcessingFall) {
          _processAccelerometerData(event);
        }
      },
      onError: (error) {
        _debugLog('Error in accelerometer stream: $error');
      },
    );
  }

  void _processAccelerometerData(AccelerometerEvent event) {
    if (_isProcessingFall) return;

    // Calculate current acceleration
    double currentAcceleration = _calculateAcceleration(event.x, event.y, event.z);
    
    // Add current acceleration to buffer
    _accelerationBuffer.add(currentAcceleration);
    
    // Maintain buffer size
    if (_accelerationBuffer.length > _bufferSize) {
      _accelerationBuffer.removeAt(0);
    }

    // Check for potential fall conditions
    if (_checkFallConditions()) {
      _handlePossibleFall();
    }
  }

  bool _checkFallConditions() {
    // Check if enough time has passed since last fall detection
    if (_lastFallDetectionTime != null) {
      if (DateTime.now().difference(_lastFallDetectionTime!).inSeconds < MINIMUM_TIME_BETWEEN_DETECTIONS) {
        return false;
      }
    }

    // If buffer is not full, return false
    if (_accelerationBuffer.length < _bufferSize) return false;

    // Analyze acceleration patterns
    double maxAcceleration = _accelerationBuffer.reduce(max);
    double minAcceleration = _accelerationBuffer.reduce(min);
    
    // Sophisticated fall detection criteria
    bool highImpactDetected = maxAcceleration > FALL_THRESHOLD;
    bool freeFallDetected = minAcceleration < FREE_FALL_THRESHOLD;
    bool suddenStopDetected = _detectSuddenStop();

    // Combine conditions for more accurate fall detection
    return highImpactDetected && freeFallDetected && suddenStopDetected;
  }

  bool _detectSuddenStop() {
    // Look for a sudden transition from high acceleration to near-zero acceleration
    int suddenStopIndex = -1;
    for (int i = _accelerationBuffer.length - 10; i < _accelerationBuffer.length; i++) {
      if (_accelerationBuffer[i] < STILLNESS_THRESHOLD) {
        suddenStopIndex = i;
        break;
      }
    }

    // Ensure there was a high acceleration before the sudden stop
    if (suddenStopIndex != -1) {
      for (int j = 0; j < suddenStopIndex; j++) {
        if (_accelerationBuffer[j] > FALL_THRESHOLD) {
          return true;
        }
      }
    }

    return false;
  }

  Future<void> _handlePossibleFall() async {
    if (_isProcessingFall) return;

    try {
      _isProcessingFall = true;
      _debugLog('Sophisticated fall detection triggered');

      // Prevent repeated fall detections
      _lastFallDetectionTime = DateTime.now();

      // Get current user
      User? currentUser = auth.currentUser;
      if (currentUser == null) {
        _debugLog('No user logged in');
        _isProcessingFall = false;
        return;
      }

      // Create fall incident
      DocumentReference fallIncidentRef = await firestore.collection('fall_incidents').add({
        'childId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'detected',
        'accelerationData': _accelerationBuffer.map((e) => e.toString()).toList(), // Store raw data for analysis
      });

      // Show notification to child
      await _showActionNotification(fallIncidentRef.id);

      // Notify parent immediately
      await _sendParentNotification(
        'Fall Detected',
        'A potential fall was detected for your child. Waiting for their response.',
        fallIncidentRef.id,
      );

      // Start 30-second timer for no response
      _fallResponseTimer = Timer(Duration(seconds: 30), () async {
        DocumentSnapshot doc = await fallIncidentRef.get();
        if (doc.exists && doc.get('status') == 'detected') {
          await fallIncidentRef.update({'status': 'no_response'});
          await _sendParentNotification(
            'No Response',
            'Your child has not responded to the fall detection alert!',
            fallIncidentRef.id,
          );
        }
        _isProcessingFall = false;
      });

      // Reset acceleration buffer
      _accelerationBuffer.clear();

    } catch (e) {
      _debugLog('Error handling sophisticated fall detection: $e');
      _isProcessingFall = false;
    }
  }

  Future<void> _showActionNotification(String fallIncidentId) async {
    try {
      // Set up notification actions
      notificationService.setActionHandler((payload, actionId) async {
        _fallResponseTimer?.cancel();
        String status = actionId == 'ok_action' ? 'false_alarm' : 'need_help';
        
        await _updateFallStatus(status, fallIncidentId);

        await notificationService.cancelFallDetectionNotification();
        _isProcessingFall = false;
      });

      // Show notification
      await notificationService.showFallDetectionNotification(
        title: 'Fall Detected',
        body: 'Are you okay? Please respond.',
        payload: jsonEncode({
          'fallIncidentId': fallIncidentId,
        }),
      );

    } catch (e) {
      _debugLog('Error showing notification: $e');
      _isProcessingFall = false;
    }
  }

  Future<void> _sendParentNotification(String title, String message, String fallIncidentId) async {
    try {
      // Get current user
      User? currentUser = auth.currentUser;
      if (currentUser == null) return;

      // Get parent ID
      DocumentSnapshot userDoc = await firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      String? parentId = (userDoc.data() as Map<String, dynamic>)?['parentId'];
      if (parentId == null) {
        _debugLog('No parent ID found for this child');
        return;
      }

      // Get parent details
      DocumentSnapshot parentDoc = await firestore
          .collection('users')
          .doc(parentId)
          .get();

      Map<String, dynamic> parentData = parentDoc.data() as Map<String, dynamic>;
      String? parentFcmToken = parentData['fcmToken'];
      
      if (parentFcmToken == null) {
        _debugLog('No FCM token found for parent');
        return;
      }

      // Get child details for better notification
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String childName = userData['displayName'] ?? 'Your child';
      
      // Get location if available
      GeoPoint? location;
      if (userData.containsKey('location') && userData['location'] != null) {
        location = userData['location'];
      }
      
      // Create a more detailed message
      String detailedMessage = message;
      if (location != null) {
        detailedMessage += ' Last known location: ${location.latitude}, ${location.longitude}';
      }

      // Add fall incident to parent's notifications collection
      await firestore.collection('users').doc(parentId).collection('notifications').add({
        'title': title,
        'message': detailedMessage,
        'childId': currentUser.uid,
        'childName': childName,
        'fallIncidentId': fallIncidentId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
          'type': 'fall_detection',
      });

      // Send direct notification to parent's device
      await _sendFcmToParent(parentFcmToken, title, detailedMessage, currentUser.uid, childName, fallIncidentId);
      
      _debugLog('Parent notification sent successfully');
    } catch (e) {
      _debugLog('Error sending parent notification: $e');
    }
  }
  
  Future<void> _sendFcmToParent(String parentToken, String title, String message, 
      String childId, String childName, String fallIncidentId) async {
    try {
      // This would typically be done through a server function
      // For this implementation, we're using a direct approach
      
      // Create the notification payload
      Map<String, dynamic> notification = {
        'to': parentToken,
        'notification': {
          'title': title,
          'body': message,
          'sound': 'default',
          'priority': 'high',
          'android_channel_id': 'fall_detection_channel'
        },
        'data': {
          'type': 'fall_detection',
          'childId': childId,
          'childName': childName,
          'fallIncidentId': fallIncidentId,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        'priority': 'high',
        'content_available': true
      };

      // Log the notification data (in a real implementation, this would be sent to FCM)
      _debugLog('Would send FCM notification: ${jsonEncode(notification)}');

      // In a real implementation, you would use a cloud function or your backend
      // to send this notification, as FCM requires server keys that shouldn't be
      // included in client-side code.
    } catch (e) {
      _debugLog('Error sending FCM to parent: $e');
    }
  }

  Future<void> _updateFallStatus(String status, String fallIncidentId) async {
    try {
      // Get current user
      User? currentUser = auth.currentUser;
      if (currentUser == null) {
        _debugLog('No user logged in');
        return;
      }

      // If no fallIncidentId provided, get the latest one
      if (fallIncidentId.isEmpty) {
        QuerySnapshot latestIncident = await firestore
            .collection('fall_incidents')
            .where('childId', isEqualTo: currentUser.uid)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (latestIncident.docs.isEmpty) {
          _debugLog('No fall incident found');
          return;
        }

        fallIncidentId = latestIncident.docs.first.id;
      }

      // Update fall incident status
      await firestore.collection('fall_incidents').doc(fallIncidentId).update({
        'status': status,
        'responseTime': FieldValue.serverTimestamp(),
      });

      // If user needs help, send notification to parent
      if (status == 'need_help') {
        await _sendParentNotification(
          'Help Needed',
          'Your child needs immediate assistance!',
          fallIncidentId,
        );
      }

      _debugLog('Fall status updated to: $status');
    } catch (e) {
      _debugLog('Error updating fall status: $e');
    }
  }

  double _calculateAcceleration(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }

  void _debugLog(String message) {
    if (_debugMode) {
      print('FallDetectionService: $message');
      onDebugMessage?.call(message);
    }
  }

  void dispose() {
    _fallResponseTimer?.cancel();
    _isProcessingFall = false;
  }

  // Modify the background service initialization
  Future<void> initializeBackgroundService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onBackgroundStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'fall_detection_service',
        initialNotificationTitle: 'Fall Detection Active',
        initialNotificationContent: 'Monitoring for falls in background',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onBackgroundStart,
        onBackground: onIosBackground,
      ),
    );

    // Start the service
    await service.startService();
    
    // Ensure the service is running
    if (await service.isRunning()) {
      _debugLog('Background service is running');
    } else {
      _debugLog('Failed to start background service');
    }
  }

  @pragma('vm:entry-point')
  void onBackgroundStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    final fcm = FirebaseMessaging.instance;

    final notificationService = SearchNotificationService(
      auth: auth,
      firestore: firestore,
      fcm: fcm,
      onChildTap: (data) {
        _debugLog('Notification tapped in background: $data');
      },
    );

    await notificationService.initialize();

    final fallDetectionService = SearchFallDetectionService(
      auth: auth,
      firestore: firestore,
      notificationService: notificationService,
    );

    // Start fall detection with debug mode
    fallDetectionService.startFallDetection(debug: true);

    // Set up action handler for background notifications
    notificationService.setActionHandler((payload, actionId) async {
      _debugLog('Action received in background - ID: $actionId, Payload: $payload');
      try {
        fallDetectionService._fallResponseTimer?.cancel();
        if (actionId == 'im_okay') {
          await fallDetectionService._updateFallStatus('false_alarm', '');
          _debugLog('User confirmed they are okay in background');
        } else if (actionId == 'need_help') {
          await fallDetectionService._updateFallStatus('need_help', '');
          _debugLog('User requested help in background');
        }
        await notificationService.cancelFallDetectionNotification();
        _debugLog('Notification canceled in background');
      } catch (e) {
        _debugLog('Error handling notification action in background: $e');
      }
    });

    if (service is AndroidServiceInstance) {
      await service.setAsForegroundService();
    }

    // Update notification every minute to keep the service alive
    Timer.periodic(Duration(minutes: 1), (timer) async {
      if (service is AndroidServiceInstance && await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Fall Detection Active",
          content: "Monitoring for falls: ${DateTime.now().toString().substring(11, 19)}",
        );
      }
    });
  }

  @pragma('vm:entry-point')
  Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    return true;
  }

  Future<void> _checkFallResponseStatus() async {
    try {
      DocumentSnapshot userDoc = await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .get();

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String? lastFallIncidentId = userData['lastFallIncidentId'];

      if (lastFallIncidentId != null) {
        DocumentSnapshot incidentDoc = await firestore
            .collection('fall_incidents')
            .doc(lastFallIncidentId)
            .get();

        Map<String, dynamic> incidentData = incidentDoc.data() as Map<String, dynamic>;

        // If no response recorded, assume user needs help
        if (!incidentData.containsKey('responseTime')) {
          await firestore.collection('fall_incidents').doc(lastFallIncidentId).update({
            'status': 'no_response',
            'escalated': true,
          });

          _sendAdditionalHelpAlerts(lastFallIncidentId);
        }
      }
    } catch (e) {
      print('Error checking fall response status: $e');
    }
  }

  Future<void> _sendAdditionalHelpAlerts(String incidentId) async {
    try {
      // Get fall incident details
      DocumentSnapshot incidentDoc = await firestore
          .collection('fall_incidents')
          .doc(incidentId)
          .get();

      Map<String, dynamic> incidentData = incidentDoc.data() as Map<String, dynamic>;

      // Get user details
      DocumentSnapshot userDoc = await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .get();

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String parentId = userData['parentId'];

      // Get parent details
      DocumentSnapshot parentDoc = await firestore
          .collection('users')
          .doc(parentId)
          .get();

      Map<String, dynamic> parentData = parentDoc.data() as Map<String, dynamic>;
      String? parentFcmToken = parentData['fcmToken'];
      String? parentEmail = parentData['email'];

      // Generate urgent message
      String urgentMessage = '${userData['displayName'] ?? 'Your child'} needs help! '
          'They either responded "Need Help" or didn\'t respond to the fall alert. '
          'Last known location: ${incidentData['location'].latitude}, ${incidentData['location'].longitude}. '
          'Please check on them immediately or contact emergency services.';

      // Send urgent push notification
      if (parentFcmToken != null) {
        _sendPushNotification(
          parentFcmToken,
          'URGENT: Help Needed!',
          urgentMessage,
        );
      }

      // Send urgent email
      if (parentEmail != null) {
        _sendEmailAlert(
          parentEmail,
          'URGENT: Help Needed - ${userData['displayName'] ?? 'Your child'}',
          urgentMessage,
        );
      }

      // Get emergency contacts if any
      QuerySnapshot emergencyContactsSnapshot = await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('emergency_contacts')
          .get();

      // Send alerts to all emergency contacts
      for (var doc in emergencyContactsSnapshot.docs) {
        Map<String, dynamic> contactData = doc.data() as Map<String, dynamic>;

        if (contactData['email'] != null) {
          _sendEmailAlert(
            contactData['email'],
            'URGENT: Help Needed - ${userData['displayName'] ?? 'Child'}',
            urgentMessage,
          );
        }

        if (contactData['fcmToken'] != null) {
          _sendPushNotification(
            contactData['fcmToken'],
            'URGENT: Help Needed!',
            urgentMessage,
          );
        }
      }
    } catch (e) {
      print('Error sending additional help alerts: $e');
    }
  }

  Future<void> _sendPushNotification(String token, String title, String body) async {
    try {
      await FirebaseMessaging.instance.sendMessage(
        to: token,
        data: {
          'type': 'fall_alert',
          'title': title,
          'body': body,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'channel_id': 'fall_detection_channel',
          'priority': 'high',
        },
      );
      
      _debugLog('Push notification sent successfully');
    } catch (e) {
      _debugLog('Error sending push notification: $e');
      throw e;
    }
  }

  Future<void> _sendEmailAlert(String email, String subject, String body) async {
    try {
      // Get your app's email credentials from Firestore for security
      DocumentSnapshot emailConfigDoc = await firestore
          .collection('app_config')
          .doc('email_config')
          .get();

      Map<String, dynamic> emailConfig = emailConfigDoc.data() as Map<String, dynamic>;

      // Create the SMTP server configuration
      final smtpServer = gmail(
        emailConfig['username'],
        emailConfig['password'],
      );

      // Create the email message
      final message = mailer.Message()
        ..from = Address(emailConfig['username'], 'Fall Detection App')
        ..recipients.add(email)
        ..subject = subject
        ..text = body
        ..html = '''
        <h1>Emergency Alert</h1>
        <p>$body</p>
        <p>Open the app to view real-time location.</p>
      ''';

      // Send the email
      final sendReport = await send(message, smtpServer);

      print('Email sent: ${sendReport.toString()}');

      // Log the email sending to Firestore for tracking
      await firestore.collection('notifications_log').add({
        'type': 'email',
        'recipient': email,
        'subject': subject,
        'body': body,
        'status': 'sent',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending email: $e');

      // Log the failed email to Firestore
      await firestore.collection('notifications_log').add({
        'type': 'email',
        'recipient': email,
        'subject': subject,
        'body': body,
        'status': 'failed',
        'error': e.toString(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  void showNotification(QueryDocumentSnapshot notification) {
    // Show notification in the UI
    // Update the notification as read
    notification.reference.update({'read': true});
  }
}

extension on FirebaseAuth {
  get auth => null;

  clientViaServiceAccount(credentials, List<String> list) {}
}