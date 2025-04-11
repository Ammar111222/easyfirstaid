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

  // Add these new variables for improved detection
  final List<double> _accelerationHistory = [];
  final int _historySize = 20;
  static const int fallDetectionNotificationId = 100;
  bool _isMonitoringPotentialFall = false;
  bool _isFallDetectionCooldown = false;
  Timer? _fallConfirmationTimer;
  Timer? _cooldownTimer;
  bool _isNotificationActive = false; // Add this flag to track active notification
  // For debugging
  bool _debugMode = false;
  void Function(String)? onDebugMessage;

  void startFallDetection({bool debug = false}) {
    _debugMode = debug;
    // Use a more sophisticated approach to fall detection
    Stream<AccelerometerEvent> accStream = accelerometerEvents;

    // Use a fixed rate to sample accelerometer data
    Timer.periodic(Duration(milliseconds: 50), (timer) {
      accStream.first.then((AccelerometerEvent event) {
        _processAccelerometerData(event);
      });
    });

    if (_debugMode) {
      _debugLog("Fall detection service started");
    }
  }
  void _processAccelerometerData(AccelerometerEvent event) {
    // Calculate magnitude of acceleration
    double acceleration = _calculateAcceleration(event.x, event.y, event.z);

    // Update acceleration history
    _accelerationHistory.add(acceleration);
    if (_accelerationHistory.length > _historySize) {
      _accelerationHistory.removeAt(0);
    }

    // Skip processing if we're in cooldown period
    if (_isFallDetectionCooldown || _isNotificationActive) {
      return; // Skip if in cooldown or notification is already active
    }

    // Phase 1: Detect free-fall condition (near zero acceleration) followed by impact
    if (!_isMonitoringPotentialFall && _detectFreeFall()) {
      _isMonitoringPotentialFall = true;
      _debugLog("Free-fall detected! Monitoring for impact...");

      // Set a timer to check for impact after free-fall
      _fallConfirmationTimer?.cancel();
      _fallConfirmationTimer = Timer(Duration(milliseconds: 300), () {
        if (_detectImpact()) {
          _debugLog("Impact detected! Checking post-impact stillness...");

          // Phase 2: Check post-impact stillness
          Timer(Duration(milliseconds: 1000), () {
            if (_detectPostImpactStillness()) {
              _debugLog("Post-impact stillness confirmed. Triggering fall alert.");
              _handlePossibleFall();

              // Set cooldown to prevent multiple detections
              _isFallDetectionCooldown = true;
              _cooldownTimer?.cancel();
              _cooldownTimer = Timer(Duration(seconds: 30), () {
                _isFallDetectionCooldown = false;
                _debugLog("Fall detection cooldown ended");
              });
            } else {
              _debugLog("Post-impact stillness not detected - likely not a fall");
            }
          });
        } else {
          _debugLog("No significant impact detected - not a fall");
        }
        _isMonitoringPotentialFall = false;
      });
    }
  }

  bool _detectFreeFall() {
    // Check if we have enough samples
    if (_accelerationHistory.length < 5) return false;

    // Get last few samples
    List<double> recentSamples = _accelerationHistory.sublist(_accelerationHistory.length - 5);

    // Check for free-fall signature (acceleration close to zero due to weightlessness)
    // During free fall, acceleration approaches 0 m/s² as the device experiences weightlessness
    // Normal gravity is around 9.8 m/s²
    bool hasFreeFall = recentSamples.any((value) => value < 3.0);

    return hasFreeFall;
  }

  bool _detectImpact() {
    // Check if we have enough samples
    if (_accelerationHistory.length < 10) return false;

    // Get recent samples
    List<double> recentSamples = _accelerationHistory.sublist(_accelerationHistory.length - 10);

    // Calculate average before potential impact
    double preImpactAvg = recentSamples.sublist(0, 5).reduce((a, b) => a + b) / 5;

    // Find maximum acceleration (impact)
    double maxAcceleration = recentSamples.reduce(max);

    // Check if we have a significant impact spike (>20 m/s²) following potential free-fall
    return maxAcceleration > 20.0 && maxAcceleration > preImpactAvg * 2.5;
  }

  bool _detectPostImpactStillness() {
    // Check if we have enough samples
    if (_accelerationHistory.length < _historySize) return false;

    // Get the most recent samples after potential impact
    List<double> postImpactSamples = _accelerationHistory.sublist(_accelerationHistory.length - 8);

    // Calculate standard deviation to measure stillness
    double mean = postImpactSamples.reduce((a, b) => a + b) / postImpactSamples.length;
    double variance = postImpactSamples.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / postImpactSamples.length;
    double stdDev = _sqrt(variance);

    // If standard deviation is low, the device is relatively still after impact
    return stdDev < 5.0 && mean > 8.0 && mean < 12.0; // Close to normal gravity with little variation
  }

  double _calculateAcceleration(double x, double y, double z) {
    return _calculateMagnitude(x, y, z);
  }

  double _calculateMagnitude(double x, double y, double z) {
    return _calculateSquareRoot(x * x + y * y + z * z);
  }

  // Simple square root calculation
  double _calculateSquareRoot(double value) {
    return value <= 0 ? 0 : value > 0 ? _sqrt(value) : 0;
  }

  // Replacement for sqrt function
  double _sqrt(double value) {
    double a = value;
    double x = 1;
    for (int i = 0; i < 10; i++) {
      x = 0.5 * (x + a / x);
    }
    return x;
  }

  // Debug logging
  void _debugLog(String message) {
    if (_debugMode) {
      print("FallDetection: $message");
      if (onDebugMessage != null) {
        onDebugMessage!(message);
      }
    }
  }

  // Add this method to manually reset fall detection if needed
  void resetFallDetection() {
    _isFallDetectionCooldown = false;
    _isMonitoringPotentialFall = false;
    _accelerationHistory.clear();
    _fallConfirmationTimer?.cancel();
    _cooldownTimer?.cancel();
    _debugLog("Fall detection manually reset");
  }

  // Test method to help calibrate the algorithm
  Map<String, dynamic> getDebugData(AccelerometerEvent currentEvent) {
    double currentAcceleration = _calculateAcceleration(
        currentEvent.x, currentEvent.y, currentEvent.z);

    // Calculate statistics on recent data
    double mean = 0;
    double stdDev = 0;

    if (_accelerationHistory.isNotEmpty) {
      mean = _accelerationHistory.reduce((a, b) => a + b) / _accelerationHistory.length;
      double variance = _accelerationHistory
          .map((x) => pow(x - mean, 2))
          .reduce((a, b) => a + b) / _accelerationHistory.length;
      stdDev = _sqrt(variance);
    }

    return {
      'currentAcceleration': currentAcceleration,
      'historyLength': _accelerationHistory.length,
      'recentMean': mean,
      'recentStdDev': stdDev,
      'inCooldown': _isFallDetectionCooldown,
      'monitoringFall': _isMonitoringPotentialFall,
      'recentSamples': _accelerationHistory.length > 10
          ? _accelerationHistory.sublist(_accelerationHistory.length - 10)
          : _accelerationHistory.toList(),
    };
  }

  Future<void> _handlePossibleFall() async {
    if (_isNotificationActive) {
      _debugLog("Notification already active, skipping duplicate");
      return;
    }
    _isNotificationActive = true; // Set flag to prevent duplicates

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      DocumentReference fallIncidentRef = await firestore.collection('fall_incidents').add({
        'childId': auth.currentUser!.uid,
        'location': GeoPoint(position.latitude, position.longitude),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'detected',
        'acknowledged': false,
      });

      await firestore.collection('users').doc(auth.currentUser!.uid).update({
        'lastFallIncidentId': fallIncidentRef.id,
      });

      await _showActionNotification();
    } catch (e) {
      _debugLog('Error in _handlePossibleFall: $e');
      print('Error handling fall detection: $e');
    }
  }

  void _showFallConfirmationDialog() {
    // Start a timer to wait for user response
    _fallResponseTimer?.cancel();
    _fallResponseTimer = Timer(Duration(seconds: 30), () {
      // If user doesn't respond in 30 seconds, assume they need help
      _updateFallStatus('no_response');
      _checkFallResponseStatus();
    });

    // Show notification with actions using the platform's native capabilities
    _showActionNotification();
  }

  Future<void> _showActionNotification() async {
    try {
      await notificationService.showActionableNotification(
        title: 'Fall Detected',
        body: 'Are you okay? Please respond within 30 seconds.',
        payload: jsonEncode({
          'type': 'fall_detection',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      _debugLog('Actionable notification shown successfully');

      notificationService.setActionHandler((payload, actionId) async {
        _debugLog('Action received: $actionId with payload: $payload');
        _fallResponseTimer?.cancel();

        if (actionId == 'im_okay') {
          await _updateFallStatus('false_alarm');
          _debugLog('User confirmed they are okay');
        } else if (actionId == 'need_help') {
          await _updateFallStatus('need_help');
          _debugLog('User requested help');
        }

        await notificationService.cancelFallDetectionNotification();
        _debugLog('Notification canceled after action');
        _isNotificationActive = false;
      });

      _fallResponseTimer?.cancel();
      _fallResponseTimer = Timer(Duration(seconds: 30), () async {
        await _updateFallStatus('no_response');
        _debugLog('No response received within 30 seconds');
        _isNotificationActive = false;
      });
    } catch (e) {
      _debugLog('Error showing action notification: $e');
      _isNotificationActive = false;
    }
  }

  Future<void> _updateFallStatus(String status) async {
    try {
      // Ensure we have a current user
      if (auth.currentUser == null) {
        print('No current user found');
        return;
      }

      // Fetch user document
      DocumentSnapshot userDoc = await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .get();

      // Get last fall incident ID
      String? lastFallIncidentId = userDoc['lastFallIncidentId'];

      if (lastFallIncidentId == null) {
        print('No fall incident ID found');
        return;
      }

      // Update fall incident status
      await firestore.collection('fall_incidents').doc(lastFallIncidentId).update({
        'status': status,
        'responseTime': FieldValue.serverTimestamp(),
      });

      // Determine if parent needs to be notified
      if (status == 'need_help' || status == 'no_response') {
        // Notify parent with appropriate title
        await _notifyParentAboutFall();
      }
    } catch (e) {
      print('Error updating fall status: $e');
    }
  }

  Future<void> _notifyParentAboutFall() async {
    try {
      // Get current user's document
      DocumentSnapshot userDoc = await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .get();

      // Check if parent exists
      String? parentId = userDoc.get('parentId') as String?;
      if (parentId == null) {
        _debugLog('No parent ID found');
        return;
      }

      // Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Send fall alert to parent with location
      await notificationService.sendFallAlertToParent(
        location: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        childId: auth.currentUser!.uid,
      );

      // Update fall incident to mark parent as notified
      String? lastFallIncidentId = userDoc.get('lastFallIncidentId') as String?;
      if (lastFallIncidentId != null) {
        await firestore.collection('fall_incidents').doc(lastFallIncidentId).update({
          'parentNotified': true,
          'parentNotificationTime': FieldValue.serverTimestamp(),
          'parentNotificationStatus': 'sent',
        });
      }

      _debugLog('Parent notified about fall with location');
    } catch (e) {
      _debugLog('Error notifying parent: $e');
      
      // Get the last fall incident ID for error logging
      DocumentSnapshot userDoc = await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .get();
          
      String? lastFallIncidentId = userDoc.get('lastFallIncidentId') as String?;
      if (lastFallIncidentId != null) {
        await firestore.collection('fall_incidents').doc(lastFallIncidentId).update({
          'parentNotificationStatus': 'failed',
          'parentNotificationError': e.toString(),
        });
      }
    }
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

    await service.startService();
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
        print('Notification tapped in background: $data');
      },
    );

    await notificationService.initialize();

    final fallDetectionService = SearchFallDetectionService(
      auth: auth,
      firestore: firestore,
      notificationService: notificationService,
    );

    fallDetectionService.startFallDetection(debug: true);

    notificationService.setActionHandler((payload, actionId) async {
      _debugLog('Action received in background - ID: $actionId, Payload: $payload');
      print('Background action received: $actionId');
      try {
        fallDetectionService._fallResponseTimer?.cancel();
        if (actionId == 'im_okay') {
          await fallDetectionService._updateFallStatus('false_alarm');
          _debugLog('User confirmed they are okay in background');
          print('Background status updated to false_alarm');
        } else if (actionId == 'need_help') {
          await fallDetectionService._updateFallStatus('need_help');
          _debugLog('User requested help in background');
          print('Background status updated to need_help');
        } else {
          _debugLog('Unknown or null background action ID: $actionId');
          print('Background: No valid action ID received: $actionId');
        }
        await notificationService.cancelFallDetectionNotification();
        _debugLog('Notification canceled in background');
        print('Background notification canceled');
      } catch (e) {
        _debugLog('Error handling notification action in background: $e');
        print('Background action error: $e');
      }
    });

    if (service is AndroidServiceInstance) {
      await service.setAsForegroundService();
    }

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
}

extension on FirebaseAuth {
  get auth => null;

  clientViaServiceAccount(credentials, List<String> list) {}
}