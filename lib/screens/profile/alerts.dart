// // search_screen.dart
// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart' as notifications;
// import 'package:mailer/mailer.dart' as mailer;
// import 'package:http/http.dart' as http;
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:googleapis_auth/auth_io.dart' as auth;
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:sensors_plus/sensors_plus.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:mailer/mailer.dart';
//
//
// import 'package:mailer/smtp_server.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:http/http.dart' as http;
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:firebase_auth/firebase_auth.dart';
// class SearchScreen extends StatefulWidget {
//   const SearchScreen({Key? key}) : super(key: key);
//
//   @override
//   _SearchScreenState createState() => _SearchScreenState();
// }
//
// class _SearchScreenState extends State<SearchScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseMessaging _fcm = FirebaseMessaging.instance;
//
//   List<Map<String, dynamic>> _searchResults = [];
//   List<Map<String, dynamic>> _pendingRequests = [];
//   List<Map<String, dynamic>> _children = [];
//   bool _isSearching = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeFCM();
//     _fetchPendingRequests();
//     _fetchChildren();
//
//     // If this user is a child, start fall detection
//     _checkIfChild().then((isChild) {
//       if (isChild) {
//         _startFallDetection();
//         _startLocationTracking();
//       }
//     });
//   }
//
//   // 2. Improved FCM initialization method
//   Future<void> _initializeFCM() async {
//     // Initialize local notifications
//     FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
//     const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
//     const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
//     await flutterLocalNotificationsPlugin.initialize(
//       initSettings,
//       onDidReceiveNotificationResponse: (NotificationResponse response) {
//         // Handle notification tap
//         print('Notification tapped: ${response.payload}');
//       },
//     );
//
//     // Request permission for notifications
//     NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//     );
//
//     if (settings.authorizationStatus == AuthorizationStatus.authorized) {
//       print('Notification permissions granted');
//
//       // Get FCM token for this device
//       String? token = await FirebaseMessaging.instance.getToken();
//       print('FCM Token: $token');
//
//       // Save token to Firestore
//       if (token != null && _auth.currentUser != null) {
//         await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
//           'fcmToken': token,
//           'deviceUpdatedAt': FieldValue.serverTimestamp(),
//         });
//       }
//
//       // Handle token refresh
//       FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
//         print('FCM Token refreshed: $newToken');
//         if (_auth.currentUser != null) {
//           await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
//             'fcmToken': newToken,
//             'deviceUpdatedAt': FieldValue.serverTimestamp(),
//           });
//         }
//       });
//
//       // Handle incoming FCM messages when app is in foreground
//       FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//         print('Got a message whilst in the foreground!');
//         print('Message data: ${message.data}');
//
//         if (message.notification != null) {
//           print('Message also contained a notification: ${message.notification}');
//           _showLocalNotification(
//             message.notification?.title ?? 'Alert',
//             message.notification?.body ?? 'You received a new notification',
//             payload: jsonEncode(message.data),
//           );
//         }
//       });
//
//       // Handle notification clicks when app was terminated
//       FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
//         if (message != null) {
//           print('App opened from terminated state via notification');
//           _handleNotificationTap(message.data);
//         }
//       });
//
//       // Handle notification clicks when app is in background
//       FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//         print('App opened from background state via notification');
//         _handleNotificationTap(message.data);
//       });
//     } else {
//       print('Notification permissions denied');
//     }
//   }
//
//   void _handleNotificationTap(Map<String, dynamic> data) {
//     print('Handling notification tap: $data');
//
//     if (data.containsKey('type') && data['type'] == 'fall_detection') {
//       if (data.containsKey('childId')) {
//         // Find the child in the list
//         for (var child in _children) {
//           if (child['uid'] == data['childId']) {
//             // Navigate to child tracking screen
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => ChildTrackingScreen(
//                   childId: child['uid'],
//                   childName: child['displayName'],
//                 ),
//               ),
//             );
//             break;
//           }
//         }
//       }
//     }
//   }
//   Future<void> _setupNotifications() async {
//     // Request permission for notifications
//     NotificationSettings settings = await _fcm.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//     );
//
//     // Get FCM token for this device
//     String? token = await _fcm.getToken();
//
//     // Save token to Firestore
//     if (token != null && _auth.currentUser != null) {
//       await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
//         'fcmToken': token,
//       });
//     }
//
//     // Handle incoming FCM messages
//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       // Show local notification
//       _showLocalNotification(
//         message.notification?.title ?? 'Alert',
//         message.notification?.body ?? 'You received a new notification',
//       );
//     });
//   }
//
//   Future<void> _showLocalNotification(String title, String body, {String? payload}) async {
//     FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
//
//     const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
//       'fall_detection_channel',
//       'Fall Detection Notifications',
//       channelDescription: 'Notifications for fall detection alerts',
//       importance: Importance.high,
//       priority: Priority.high,
//       showWhen: true,
//       enableVibration: true,
//       playSound: true,
//     );
//
//     const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
//
//     await flutterLocalNotificationsPlugin.show(
//       DateTime.now().millisecond, // Use unique ID for each notification
//       title,
//       body,
//       platformDetails,
//       payload: payload,
//     );
//   }
//   Future<bool> _checkIfChild() async {
//     DocumentSnapshot userDoc = await _firestore
//         .collection('users')
//         .doc(_auth.currentUser!.uid)
//         .get();
//
//     Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
//     return userData != null && userData['parentId'] != null;
//   }
//
//   Future<void> _fetchPendingRequests() async {
//     try {
//       QuerySnapshot requestsSnapshot = await _firestore
//           .collection('requests')
//           .where('receiverId', isEqualTo: _auth.currentUser!.uid)
//           .where('status', isEqualTo: 'pending')
//           .get();
//
//       List<Map<String, dynamic>> requests = [];
//       for (var doc in requestsSnapshot.docs) {
//         Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
//         // Get sender details
//         DocumentSnapshot senderDoc = await _firestore
//             .collection('users')
//             .doc(data['senderId'])
//             .get();
//
//         Map<String, dynamic> senderData = senderDoc.data() as Map<String, dynamic>;
//
//         requests.add({
//           'requestId': doc.id,
//           'senderId': data['senderId'],
//           'senderEmail': senderData['email'],
//           'senderName': senderData['displayName'] ?? 'User',
//           'timestamp': data['timestamp'],
//         });
//       }
//
//       setState(() {
//         _pendingRequests = requests;
//       });
//     } catch (e) {
//       print('Error fetching pending requests: $e');
//     }
//   }
//
//   Future<void> _fetchChildren() async {
//     try {
//       QuerySnapshot childrenSnapshot = await _firestore
//           .collection('users')
//           .where('parentId', isEqualTo: _auth.currentUser!.uid)
//           .get();
//
//       List<Map<String, dynamic>> children = [];
//       for (var doc in childrenSnapshot.docs) {
//         Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
//         children.add({
//           'uid': doc.id,
//           'email': data['email'],
//           'displayName': data['displayName'] ?? 'Child User',
//           'location': data['location'],
//         });
//       }
//
//       setState(() {
//         _children = children;
//       });
//     } catch (e) {
//       print('Error fetching children: $e');
//     }
//   }
//
//   Future<void> _searchUsers(String query) async {
//     if (query.isEmpty) {
//       setState(() {
//         _searchResults = [];
//         _isSearching = false;
//       });
//       return;
//     }
//
//     setState(() {
//       _isSearching = true;
//     });
//
//     try {
//       // Search for users by email
//       QuerySnapshot userSnapshot = await _firestore
//           .collection('users')
//           .where('email', isEqualTo: query)
//           .get();
//
//       List<Map<String, dynamic>> results = [];
//       for (var doc in userSnapshot.docs) {
//         // Skip if user is the current user
//         if (doc.id == _auth.currentUser!.uid) continue;
//
//         Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
//
//         // Check if there's already a pending request
//         QuerySnapshot pendingRequestsSnapshot = await _firestore
//             .collection('requests')
//             .where('senderId', isEqualTo: _auth.currentUser!.uid)
//             .where('receiverId', isEqualTo: doc.id)
//             .where('status', isEqualTo: 'pending')
//             .get();
//
//         bool hasPendingRequest = pendingRequestsSnapshot.docs.isNotEmpty;
//
//         // Check if this user is already a child
//         QuerySnapshot childSnapshot = await _firestore
//             .collection('users')
//             .where('uid', isEqualTo: doc.id)
//             .where('parentId', isEqualTo: _auth.currentUser!.uid)
//             .get();
//
//         bool isAlreadyChild = childSnapshot.docs.isNotEmpty;
//
//         results.add({
//           'uid': doc.id,
//           'email': data['email'],
//           'displayName': data['displayName'] ?? 'User',
//           'hasPendingRequest': hasPendingRequest,
//           'isAlreadyChild': isAlreadyChild,
//         });
//       }
//
//       setState(() {
//         _searchResults = results;
//         _isSearching = false;
//       });
//     } catch (e) {
//       print('Error searching users: $e');
//       setState(() {
//         _isSearching = false;
//       });
//     }
//   }
//
//   Future<void> _sendParentRequest(String receiverId) async {
//     try {
//       // Create a new request
//       await _firestore.collection('requests').add({
//         'senderId': _auth.currentUser!.uid,
//         'receiverId': receiverId,
//         'status': 'pending',
//         'type': 'parent',
//         'timestamp': FieldValue.serverTimestamp(),
//       });
//
//       // Update search results to show pending request
//       setState(() {
//         for (var i = 0; i < _searchResults.length; i++) {
//           if (_searchResults[i]['uid'] == receiverId) {
//             _searchResults[i]['hasPendingRequest'] = true;
//           }
//         }
//       });
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Parent request sent successfully')),
//       );
//     } catch (e) {
//       print('Error sending parent request: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Failed to send parent request')),
//       );
//     }
//   }
//
//   Future<void> _handleRequestResponse(String requestId, String response) async {
//     try {
//       // Find the request
//       DocumentSnapshot requestDoc = await _firestore
//           .collection('requests')
//           .doc(requestId)
//           .get();
//
//       if (!requestDoc.exists) {
//         throw Exception('Request not found');
//       }
//
//       Map<String, dynamic> requestData = requestDoc.data() as Map<String, dynamic>;
//
//       // Update request status
//       await _firestore.collection('requests').doc(requestId).update({
//         'status': response,
//       });
//
//       if (response == 'accepted') {
//         // Update the child user with parentId
//         await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
//           'parentId': requestData['senderId'],
//         });
//
//         // Start fall detection and location tracking
//         _startFallDetection();
//         _startLocationTracking();
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('You accepted the parent request')),
//         );
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('You declined the parent request')),
//         );
//       }
//
//       // Refresh pending requests
//       _fetchPendingRequests();
//     } catch (e) {
//       print('Error handling request response: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Failed to process your response')),
//       );
//     }
//   }
//
//   void _startFallDetection() {
//     // Accelerometer stream for fall detection
//     accelerometerEvents.listen((AccelerometerEvent event) {
//       // Calculate magnitude of acceleration
//       double acceleration = _calculateAcceleration(event.x, event.y, event.z);
//
//       // Check if acceleration exceeds threshold (typically 2.5-3g for falls)
//       if (acceleration > 25.0) {  // Using 30 m/s² (about 3g) as threshold
//         _handlePossibleFall();
//       }
//     });
//   }
//
//   double _calculateAcceleration(double x, double y, double z) {
//     return _calculateMagnitude(x, y, z);
//   }
//
//   double _calculateMagnitude(double x, double y, double z) {
//     return _calculateSquareRoot(x * x + y * y + z * z);
//   }
//
//   // Simple square root calculation
//   double _calculateSquareRoot(double value) {
//     return value <= 0 ? 0 : value > 0 ? _sqrt(value) : 0;
//   }
//
//   // Replacement for sqrt function
//   double _sqrt(double value) {
//     double a = value;
//     double x = 1;
//     for (int i = 0; i < 10; i++) {
//       x = 0.5 * (x + a / x);
//     }
//     return x;
//   }
//
// // 3. Enhanced _handlePossibleFall method to store fall history
//   Future<void> _handlePossibleFall() async {
//     try {
//       // First show a local notification to the child right away
//       _showLocalNotification(
//         'Fall Detected',
//         'We\'re checking if you\'re okay. Please respond.',
//       );
//
//       // Get current location
//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//
//       // Get user info
//       DocumentSnapshot userDoc = await _firestore
//           .collection('users')
//           .doc(_auth.currentUser!.uid)
//           .get();
//
//       if (!userDoc.exists) {
//         print('User document not found');
//         return;
//       }
//
//       Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
//       String? parentId = userData['parentId'];
//
//       if (parentId == null) {
//         print('No parent ID found for this user');
//         return;
//       }
//
//       // Create a fall incident record in Firestore
//       DocumentReference fallIncidentRef = await _firestore.collection('fall_incidents').add({
//         'childId': _auth.currentUser!.uid,
//         'childName': userData['displayName'] ?? 'Unknown',
//         'parentId': parentId,
//         'location': GeoPoint(position.latitude, position.longitude),
//         'timestamp': FieldValue.serverTimestamp(),
//         'status': 'detected', // Can be updated to 'confirmed' or 'false_alarm'
//         'acknowledged': false,
//       });
//
//       // Get parent's FCM token and email
//       DocumentSnapshot parentDoc = await _firestore
//           .collection('users')
//           .doc(parentId)
//           .get();
//
//       if (!parentDoc.exists) {
//         print('Parent document not found');
//         return;
//       }
//
//       Map<String, dynamic> parentData = parentDoc.data() as Map<String, dynamic>;
//       String? parentFcmToken = parentData['fcmToken'];
//       String? parentEmail = parentData['email'];
//
//       print('Parent FCM token: $parentFcmToken');
//
//       // Generate an alert message with incident ID
//       String alertMessage = '${userData['displayName'] ?? 'Your child'} may have fallen. '
//           'Location: ${position.latitude}, ${position.longitude}. '
//           'Incident ID: ${fallIncidentRef.id}';
//
//       // Update user's location in Firestore
//       await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
//         'location': GeoPoint(position.latitude, position.longitude),
//         'lastFallDetected': FieldValue.serverTimestamp(),
//         'lastFallIncidentId': fallIncidentRef.id,
//       });
//
//       // Send push notification to parent with retry mechanism
//       if (parentFcmToken != null) {
//         bool success = false;
//         for (int i = 0; i < 3; i++) { // Try up to 3 times
//           try {
//             await _sendPushNotification(
//               parentFcmToken,
//               'Fall Detected!',
//               alertMessage,
//             );
//             success = true;
//             break;
//           } catch (e) {
//             print('Error sending notification (attempt ${i+1}): $e');
//             await Future.delayed(Duration(seconds: 1)); // Wait before retrying
//           }
//         }
//
//         if (!success) {
//           // Fallback to another notification method if FCM fails
//           _sendNotificationFallback(parentId, 'Fall Detected!', alertMessage);
//         }
//       } else {
//         print('No FCM token found for parent');
//         // Try fallback notification
//         _sendNotificationFallback(parentId, 'Fall Detected!', alertMessage);
//       }
//
//       // Send email to parent
//       if (parentEmail != null) {
//         _sendEmailAlert(
//           parentEmail,
//           'Fall Detected - ${userData['displayName'] ?? 'Your child'}',
//           'A possible fall has been detected for ${userData['displayName'] ?? 'your child'}. '
//               'Location: ${position.latitude}, ${position.longitude}\n'
//               'Time: ${DateTime.now()}\n'
//               'Incident ID: ${fallIncidentRef.id}',
//         );
//       }
//
//       // Show confirmation dialog to the child
//       _showFallConfirmationDialog();
//     } catch (e) {
//       print('Error handling fall detection: $e');
//     }
//   }
//   Timer? _fallResponseTimer;
//
//   Future<void> _sendNotificationFallback(String parentId, String title, String body) async {
//     try {
//       // Create a Firestore notification record that the parent app will check for
//       await _firestore.collection('pending_notifications').add({
//         'recipientId': parentId,
//         'title': title,
//         'body': body,
//         'timestamp': FieldValue.serverTimestamp(),
//         'read': false,
//         'type': 'fall_detection',
//         'childId': _auth.currentUser!.uid,
//       });
//
//       print('Created fallback notification in Firestore');
//     } catch (e) {
//       print('Error sending fallback notification: $e');
//     }
//   }
//   // 4. Add a method to show a confirmation dialog to the child
//   void _showFallConfirmationDialog() {
//     // Show the fall confirmation dialog
//     showDialog(
//       context: context,
//       barrierDismissible: false, // Prevent dismissing the dialog by tapping outside
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Fall Detected'),
//           content: const Text('Are you okay? If you don\'t respond within 30 seconds, '
//               'we\'ll assume you need help and send another alert to your emergency contacts.'),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop(); // Close the dialog
//                 _updateFallStatus('false_alarm'); // Update fall status to false alarm
//                 _fallResponseTimer?.cancel(); // Cancel the timer
//               },
//               child: const Text('I\'m Fine'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.of(context).pop(); // Close the dialog
//                 _updateFallStatus('need_help'); // Update fall status to need help
//                 _fallResponseTimer?.cancel(); // Cancel the timer
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red,
//               ),
//               child: const Text('Need Help'),
//             ),
//           ],
//         );
//       },
//     );
//
//     // Set up a timer to send additional alerts if no response is received within 30 seconds
//     _fallResponseTimer = Timer(const Duration(seconds: 5), () {
//       _checkFallResponseStatus();
//     });
//   }
//
//   // 5. Method to update fall status
//   Future<void> _updateFallStatus(String status) async {
//     try {
//       DocumentSnapshot userDoc = await _firestore
//           .collection('users')
//           .doc(_auth.currentUser!.uid)
//           .get();
//
//       Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
//       String? lastFallIncidentId = userData['lastFallIncidentId'];
//
//       if (lastFallIncidentId != null) {
//         await _firestore.collection('fall_incidents').doc(lastFallIncidentId).update({
//           'status': status,
//           'responseTime': FieldValue.serverTimestamp(),
//         });
//
//         // If user needs help, send additional alert
//         if (status == 'need_help') {
//           _sendAdditionalHelpAlerts(lastFallIncidentId);
//         }
//       }
//     } catch (e) {
//       print('Error updating fall status: $e');
//     }
//   }
//
//
//
//   Future<void> _sendPushNotification(String token, String title, String body) async {
//     try {
//       // Load service account credentials
//       final serviceAccount = jsonDecode(await rootBundle.loadString('assets/service-account.json'));
//
//       // Authenticate and get OAuth token
//       final credentials = auth.ServiceAccountCredentials.fromJson(serviceAccount);
//       final client = await auth.clientViaServiceAccount(
//         credentials,
//         ['https://www.googleapis.com/auth/firebase.messaging'],
//       );
//
//       // Your Firebase project ID
//       const String projectId = 'easy-first-aid-e3f8f';
//       final Uri url = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');
//
//       // Create the payload for the FCM request
//       final Map<String, dynamic> payload = {
//         "message": {
//           "token": token,
//           "notification": {
//             "title": title,
//             "body": body,
//             "sound": "default",
//           },
//           "data": {
//             "click_action": "FLUTTER_NOTIFICATION_CLICK",
//             "type": "fall_detection",
//             "childId": _auth.currentUser!.uid,
//           },
//           "android": {
//             "priority": "high",
//             "notification": {
//               "sound": "default",
//               "priority": "high",
//               "default_sound": true,
//               "default_vibrate_timings": true,
//               "default_light_settings": true,
//             }
//           },
//           "apns": {
//             "payload": {
//               "aps": {
//                 "sound": "default",
//                 "badge": 1,
//                 "content-available": 1
//               }
//             }
//           }
//         }
//       };
//
//       // Make an HTTP request to send the notification
//       final response = await client.post(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//         },
//         body: jsonEncode(payload),
//       );
//
//       if (response.statusCode == 200) {
//         print('Notification sent successfully');
//
//         // Log the notification in Firestore
//         await _firestore.collection('notifications_log').add({
//           'type': 'push',
//           'token': token,
//           'title': title,
//           'body': body,
//           'status': 'sent',
//           'timestamp': FieldValue.serverTimestamp(),
//         });
//       } else {
//         print('Failed to send notification: ${response.body}');
//         throw Exception('FCM returned status code ${response.statusCode}: ${response.body}');
//       }
//     } catch (e) {
//       print('Error sending notification: $e');
//       // Log error to Firestore
//       await _firestore.collection('notifications_log').add({
//         'type': 'push',
//         'token': token,
//         'title': title,
//         'body': body,
//         'status': 'error',
//         'error': e.toString(),
//         'timestamp': FieldValue.serverTimestamp(),
//       });
//       throw e; // Re-throw to allow retry logic
//     }
//   }  // 6. Method to check if user responded to fall alert
//   Future<void> _checkFallResponseStatus() async {
//     try {
//       DocumentSnapshot userDoc = await _firestore
//           .collection('users')
//           .doc(_auth.currentUser!.uid)
//           .get();
//
//       Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
//       String? lastFallIncidentId = userData['lastFallIncidentId'];
//
//       if (lastFallIncidentId != null) {
//         DocumentSnapshot incidentDoc = await _firestore
//             .collection('fall_incidents')
//             .doc(lastFallIncidentId)
//             .get();
//
//         Map<String, dynamic> incidentData = incidentDoc.data() as Map<String, dynamic>;
//
//         // If no response recorded, assume user needs help
//         if (!incidentData.containsKey('responseTime')) {
//           await _firestore.collection('fall_incidents').doc(lastFallIncidentId).update({
//             'status': 'no_response',
//             'escalated': true,
//           });
//
//           _sendAdditionalHelpAlerts(lastFallIncidentId);
//         }
//       }
//     } catch (e) {
//       print('Error checking fall response status: $e');
//     }
//   }
//
// // 7. Method to send additional help alerts
//   Future<void> _sendAdditionalHelpAlerts(String incidentId) async {
//     try {
//       // Get fall incident details
//       DocumentSnapshot incidentDoc = await _firestore
//           .collection('fall_incidents')
//           .doc(incidentId)
//           .get();
//
//       Map<String, dynamic> incidentData = incidentDoc.data() as Map<String, dynamic>;
//
//       // Get user details
//       DocumentSnapshot userDoc = await _firestore
//           .collection('users')
//           .doc(_auth.currentUser!.uid)
//           .get();
//
//       Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
//       String parentId = userData['parentId'];
//
//       // Get parent details
//       DocumentSnapshot parentDoc = await _firestore
//           .collection('users')
//           .doc(parentId)
//           .get();
//
//       Map<String, dynamic> parentData = parentDoc.data() as Map<String, dynamic>;
//       String? parentFcmToken = parentData['fcmToken'];
//       String? parentEmail = parentData['email'];
//
//       // Generate urgent message
//       String urgentMessage = '${userData['displayName'] ?? 'Your child'} needs help! '
//           'They either responded "Need Help" or didn\'t respond to the fall alert. '
//           'Last known location: ${incidentData['location'].latitude}, ${incidentData['location'].longitude}. '
//           'Please check on them immediately or contact emergency services.';
//
//       // Send urgent push notification
//       if (parentFcmToken != null) {
//         _sendPushNotification(
//           parentFcmToken,
//           'URGENT: Help Needed!',
//           urgentMessage,
//         );
//       }
//
//       // Send urgent email
//       if (parentEmail != null) {
//         _sendEmailAlert(
//           parentEmail,
//           'URGENT: Help Needed - ${userData['displayName'] ?? 'Your child'}',
//           urgentMessage,
//         );
//       }
//
//       // Get emergency contacts if any
//       QuerySnapshot emergencyContactsSnapshot = await _firestore
//           .collection('users')
//           .doc(_auth.currentUser!.uid)
//           .collection('emergency_contacts')
//           .get();
//
//       // Send alerts to all emergency contacts
//       for (var doc in emergencyContactsSnapshot.docs) {
//         Map<String, dynamic> contactData = doc.data() as Map<String, dynamic>;
//
//         if (contactData['email'] != null) {
//           _sendEmailAlert(
//             contactData['email'],
//             'URGENT: Help Needed - ${userData['displayName'] ?? 'Child'}',
//             urgentMessage,
//           );
//         }
//
//         if (contactData['fcmToken'] != null) {
//           _sendPushNotification(
//             contactData['fcmToken'],
//             'URGENT: Help Needed!',
//             urgentMessage,
//           );
//         }
//       }
//     } catch (e) {
//       print('Error sending additional help alerts: $e');
//     }
//   }
//
//   Future<void> _sendEmailAlert(String email, String subject, String body) async {
//     try {
//       // Get your app's email credentials from Firestore for security
//       DocumentSnapshot emailConfigDoc = await _firestore
//           .collection('app_config')
//           .doc('email_config')
//           .get();
//
//       Map<String, dynamic> emailConfig = emailConfigDoc.data() as Map<String, dynamic>;
//
//       // Create the SMTP server configuration
//       final smtpServer = gmail(
//         emailConfig['username'],
//         emailConfig['password'],
//       );
//
//       // Create the email message
//       final message = mailer.Message()
//         ..from = Address(emailConfig['username'], 'Fall Detection App')
//         ..recipients.add(email)
//         ..subject = subject
//         ..text = body
//         ..html = '''
//         <h1>Emergency Alert</h1>
//         <p>$body</p>
//         <p>Open the app to view real-time location.</p>
//       ''';
//
//       // Send the email
//       final sendReport = await send(message, smtpServer);
//
//       print('Email sent: ${sendReport.toString()}');
//
//       // Log the email sending to Firestore for tracking
//       await _firestore.collection('notifications_log').add({
//         'type': 'email',
//         'recipient': email,
//         'subject': subject,
//         'body': body,
//         'status': 'sent',
//         'timestamp': FieldValue.serverTimestamp(),
//       });
//     } catch (e) {
//       print('Error sending email: $e');
//
//       // Log the failed email to Firestore
//       await _firestore.collection('notifications_log').add({
//         'type': 'email',
//         'recipient': email,
//         'subject': subject,
//         'body': body,
//         'status': 'failed',
//         'error': e.toString(),
//         'timestamp': FieldValue.serverTimestamp(),
//       });
//     }
//   }
//
//   Future<void> _startLocationTracking() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       // Handle location services not enabled
//       return;
//     }
//
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         // Handle permission denied
//         return;
//       }
//     }
//
//     // Start location tracking
//     Geolocator.getPositionStream(
//       locationSettings: const LocationSettings(
//         accuracy: LocationAccuracy.high,
//         distanceFilter: 10,
//       ),
//     ).listen((Position position) async {
//       // Update location in Firestore
//       await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
//         'location': GeoPoint(position.latitude, position.longitude),
//         'lastLocationUpdate': FieldValue.serverTimestamp(),
//       });
//     });
//   }
//
//   Widget _buildSearchBar() {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: TextField(
//         controller: _searchController,
//         decoration: InputDecoration(
//           hintText: 'Search by email...',
//           prefixIcon: const Icon(Icons.search),
//           suffixIcon: _searchController.text.isNotEmpty
//               ? IconButton(
//             icon: const Icon(Icons.clear),
//             onPressed: () {
//               _searchController.clear();
//               setState(() {
//                 _searchResults = [];
//               });
//             },
//           )
//               : null,
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//         onChanged: (value) {
//           // Debounce the search to avoid too many Firestore queries
//           Future.delayed(const Duration(milliseconds: 500), () {
//             if (value == _searchController.text) {
//               _searchUsers(value);
//             }
//           });
//         },
//       ),
//     );
//   }
//
//   Widget _buildSearchResults() {
//     if (_isSearching) {
//       return const Center(child: CircularProgressIndicator());
//     }
//
//     if (_searchResults.isEmpty) {
//       return const Center(
//         child: Text('No users found'),
//       );
//     }
//
//     return ListView.builder(
//       shrinkWrap: true,
//       itemCount: _searchResults.length,
//       itemBuilder: (context, index) {
//         Map<String, dynamic> user = _searchResults[index];
//         return ListTile(
//           leading: CircleAvatar(
//             child: Text(user['displayName'][0].toUpperCase()),
//           ),
//           title: Text(user['displayName']),
//           subtitle: Text(user['email']),
//           trailing: user['isAlreadyChild']
//               ? const Chip(
//             label: Text('Child'),
//             backgroundColor: Colors.green,
//           )
//               : user['hasPendingRequest']
//               ? const Chip(
//             label: Text('Pending'),
//             backgroundColor: Colors.orange,
//           )
//               : ElevatedButton(
//             onPressed: () => _sendParentRequest(user['uid']),
//             child: const Text('Add as Child'),
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildPendingRequests() {
//     if (_pendingRequests.isEmpty) {
//       return const SizedBox.shrink();
//     }
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Padding(
//           padding: EdgeInsets.all(16.0),
//           child: Text(
//             'Pending Requests',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//         ListView.builder(
//           shrinkWrap: true,
//           physics: const NeverScrollableScrollPhysics(),
//           itemCount: _pendingRequests.length,
//           itemBuilder: (context, index) {
//             Map<String, dynamic> request = _pendingRequests[index];
//             return Card(
//               margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       '${request['senderName']} wants to add you as a child',
//                       style: const TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text('Email: ${request['senderEmail']}'),
//                     const SizedBox(height: 16),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.end,
//                       children: [
//                         TextButton(
//                           onPressed: () => _handleRequestResponse(
//                             request['requestId'],
//                             'declined',
//                           ),
//                           child: const Text('Decline'),
//                         ),
//                         const SizedBox(width: 8),
//                         ElevatedButton(
//                           onPressed: () => _handleRequestResponse(
//                             request['requestId'],
//                             'accepted',
//                           ),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.green,
//                           ),
//                           child: const Text('Accept'),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }
//
//   Widget _buildChildren() {
//     if (_children.isEmpty) {
//       return const SizedBox.shrink();
//     }
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Padding(
//           padding: EdgeInsets.all(16.0),
//           child: Text(
//             'Your Children',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//         ListView.builder(
//           shrinkWrap: true,
//           physics: const NeverScrollableScrollPhysics(),
//           itemCount: _children.length,
//           itemBuilder: (context, index) {
//             Map<String, dynamic> child = _children[index];
//             return Card(
//               margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//               child: InkWell(
//                 onTap: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => ChildTrackingScreen(
//                         childId: child['uid'],
//                         childName: child['displayName'],
//                       ),
//                     ),
//                   );
//                 },
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Row(
//                     children: [
//                       CircleAvatar(
//                         child: Text(child['displayName'][0].toUpperCase()),
//                       ),
//                       const SizedBox(width: 16),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               child['displayName'],
//                               style: const TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             Text(child['email']),
//                           ],
//                         ),
//                       ),
//                       const Icon(Icons.arrow_forward_ios),
//                     ],
//                   ),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Search'),
//       ),
//       body: SingleChildScrollView(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildSearchBar(),
//             if (_searchController.text.isNotEmpty) _buildSearchResults(),
//             _buildPendingRequests(),
//             _buildChildren(),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // Child Tracking Screen to view child's location
// class ChildTrackingScreen extends StatefulWidget {
//   final String childId;
//   final String childName;
//
//   const ChildTrackingScreen({
//     Key? key,
//     required this.childId,
//     required this.childName,
//   }) : super(key: key);
//
//   @override
//   _ChildTrackingScreenState createState() => _ChildTrackingScreenState();
// }
//
// // Now, let's update the ChildTrackingScreen to show fall history
// class _ChildTrackingScreenState extends State<ChildTrackingScreen> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   GoogleMapController? _mapController;
//   LatLng? _childLocation;
//   DateTime? _lastLocationUpdate;
//   bool _isLoading = true;
//   bool _showFallIncidents = false;
//   List<Map<String, dynamic>> _fallIncidents = [];
//   Set<Marker> _markers = {};
//   StreamSubscription? _locationSubscription;
//   StreamSubscription? _fallIncidentsSubscription;
//   @override
//   void initState() {
//     super.initState();
//     _setupNotificationListener();
//     _fetchChildData();
//     _listenToFallIncidents();
//
//     _fetchChildLocation();
//     _setupLocationListener();
//     _fetchFallIncidents();
//   }
//   @override
//   void dispose() {
//     _locationSubscription?.cancel();
//     _fallIncidentsSubscription?.cancel();
//     _mapController?.dispose();
//     super.dispose();
//   }
//   // Setup to listen for notifications while in the tracking screen
//   void _setupNotificationListener() {
//     // Listen for foreground messages
//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       if (message.notification != null) {
//         // Check if this notification is for the child we're tracking
//         if (message.data.containsKey('childId') &&
//             message.data['childId'] == widget.childId &&
//             message.data.containsKey('type') &&
//             message.data['type'] == 'fall_detection') {
//
//           // Show an alert dialog
//           showDialog(
//             context: context,
//             barrierDismissible: false,
//             builder: (BuildContext context) {
//               return AlertDialog(
//                 title: Text('Fall Detected!'),
//                 content: Text('${widget.childName} may have fallen. Please check on them immediately.'),
//                 actions: [
//                   TextButton(
//                     onPressed: () {
//                       Navigator.of(context).pop();
//                       // Refresh fall incidents
//                       _fetchFallIncidents();
//                     },
//                     child: Text('OK'),
//                   ),
//                 ],
//               );
//             },
//           );
//
//           // Refresh the map and data
//           _fetchChildData();
//         }
//       }
//     });
//   }
//   Future<void> _fetchChildData() async {
//     try {
//       // Get child's data
//       DocumentSnapshot childDoc = await _firestore.collection('users').doc(widget.childId).get();
//
//       if (!childDoc.exists) {
//         setState(() {
//           _isLoading = false;
//         });
//         return;
//       }
//
//       Map<String, dynamic> childData = childDoc.data() as Map<String, dynamic>;
//
//       // Check if location data exists
//       if (childData.containsKey('location')) {
//         GeoPoint location = childData['location'] as GeoPoint;
//         setState(() {
//           _childLocation = LatLng(location.latitude, location.longitude);
//         });
//
//         // Update map camera
//         if (_mapController != null && _childLocation != null) {
//           _mapController!.animateCamera(
//             CameraUpdate.newLatLngZoom(_childLocation!, 15),
//           );
//         }
//       }
//
//       // Listen to location updates
//       _locationSubscription?.cancel();
//       _locationSubscription = _firestore
//           .collection('users')
//           .doc(widget.childId)
//           .snapshots()
//           .listen((snapshot) {
//         if (snapshot.exists) {
//           Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
//           if (data.containsKey('location')) {
//             GeoPoint location = data['location'] as GeoPoint;
//             setState(() {
//               _childLocation = LatLng(location.latitude, location.longitude);
//             });
//
//             // Update map camera
//             if (_mapController != null && _childLocation != null) {
//               _mapController!.animateCamera(
//                 CameraUpdate.newLatLngZoom(_childLocation!, 15),
//               );
//             }
//           }
//         }
//       });
//
//       _fetchFallIncidents();
//     } catch (e) {
//       print('Error fetching child data: $e');
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//
//   void _fetchChildLocation() async {
//     try {
//       DocumentSnapshot childDoc = await _firestore
//           .collection('users')
//           .doc(widget.childId)
//           .get();
//
//       Map<String, dynamic> childData = childDoc.data() as Map<String, dynamic>;
//       GeoPoint? location = childData['location'] as GeoPoint?;
//       Timestamp? lastUpdate = childData['lastLocationUpdate'] as Timestamp?;
//
//       setState(() {
//         if (location != null) {
//           _childLocation = LatLng(location.latitude, location.longitude);
//           _updateMarkers();
//         }
//
//         if (lastUpdate != null) {
//           _lastLocationUpdate = lastUpdate.toDate();
//         }
//
//         _isLoading = false;
//       });
//     } catch (e) {
//       print('Error fetching child location: $e');
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//
//   void _setupLocationListener() {
//     _firestore
//         .collection('users')
//         .doc(widget.childId)
//         .snapshots()
//         .listen((DocumentSnapshot snapshot) {
//       if (snapshot.exists) {
//         Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
//         GeoPoint? location = data['location'] as GeoPoint?;
//         Timestamp? lastUpdate = data['lastLocationUpdate'] as Timestamp?;
//
//         // Check if a new fall was detected
//         Timestamp? lastFallDetected = data['lastFallDetected'] as Timestamp?;
//         String? lastFallIncidentId = data['lastFallIncidentId'] as String?;
//
//         if (lastFallDetected != null && lastFallIncidentId != null) {
//           DateTime lastFallTime = lastFallDetected.toDate();
//           // If fall was detected in the last 5 minutes, show an alert
//           if (DateTime.now().difference(lastFallTime).inMinutes < 5) {
//             _showFallAlert(lastFallIncidentId);
//           }
//         }
//
//         setState(() {
//           if (location != null) {
//             _childLocation = LatLng(location.latitude, location.longitude);
//             _updateMarkers();
//
//             // Update map camera position
//             if (_mapController != null) {
//               _mapController!.animateCamera(
//                 CameraUpdate.newLatLng(_childLocation!),
//               );
//             }
//           }
//
//           if (lastUpdate != null) {
//             _lastLocationUpdate = lastUpdate.toDate();
//           }
//         });
//       }
//     });
//   }
//   void _listenToFallIncidents() {
//     _fallIncidentsSubscription?.cancel();
//     _fallIncidentsSubscription = _firestore
//         .collection('fall_incidents')
//         .where('childId', isEqualTo: widget.childId)
//         .orderBy('timestamp', descending: true)
//         .snapshots()
//         .listen((snapshot) {
//       _fetchFallIncidents();
//     });
//   }
//   Future<void> _fetchFallIncidents() async {
//     try {
//       QuerySnapshot incidentsSnapshot = await _firestore
//           .collection('fall_incidents')
//           .where('childId', isEqualTo: widget.childId)
//           .orderBy('timestamp', descending: true)
//           .limit(10) // Get the most recent 10 incidents
//           .get();
//
//       List<Map<String, dynamic>> incidents = [];
//       for (var doc in incidentsSnapshot.docs) {
//         Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
//
//         // Format timestamp
//         Timestamp timestamp = data['timestamp'] as Timestamp;
//         DateTime dateTime = timestamp.toDate();
//         String formattedDate = '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
//
//         // Format status
//         String status = 'Unknown';
//         if (data.containsKey('status')) {
//           switch (data['status']) {
//             case 'detected':
//               status = 'Detected';
//               break;
//             case 'false_alarm':
//               status = 'False Alarm';
//               break;
//             case 'need_help':
//               status = 'Help Needed';
//               break;
//             case 'no_response':
//               status = 'No Response';
//               break;
//             default:
//               status = data['status'];
//           }
//         }
//
//         incidents.add({
//           'id': doc.id,
//           'timestamp': formattedDate,
//           'rawTimestamp': timestamp,
//           'status': status,
//           'acknowledged': data['acknowledged'] ?? false,
//           'location': data.containsKey('location')
//               ? LatLng((data['location'] as GeoPoint).latitude, (data['location'] as GeoPoint).longitude)
//               : null,
//         });
//       }
//
//       setState(() {
//         _fallIncidents = incidents;
//       });
//     } catch (e) {
//       print('Error fetching fall incidents: $e');
//     }
//   }
//   void _updateMarkers() {
//     if (_childLocation == null) return;
//
//     Set<Marker> markers = {};
//
//     // Add current location marker
//     markers.add(
//       Marker(
//         markerId: MarkerId(widget.childId),
//         position: _childLocation!,
//         icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
//         infoWindow: InfoWindow(
//           title: "${widget.childName}'s Location",
//           snippet: 'Last updated: ${_formatLastUpdate()}',
//         ),
//       ),
//     );
//
//     // Add fall incident markers if enabled
//     if (_showFallIncidents) {
//       for (int i = 0; i < _fallIncidents.length; i++) {
//         final incident = _fallIncidents[i];
//         final position = LatLng(incident['latitude'], incident['longitude']);
//
//         // Use different colors based on fall status
//         double hue;
//         String status = incident['status'];
//
//         switch (status) {
//           case 'false_alarm':
//             hue = BitmapDescriptor.hueYellow;
//             break;
//           case 'need_help':
//             hue = BitmapDescriptor.hueRed;
//             break;
//           case 'no_response':
//             hue = BitmapDescriptor.hueOrange;
//             break;
//           default:
//             hue = BitmapDescriptor.hueRose;
//         }
//
//         markers.add(
//           Marker(
//             markerId: MarkerId('fall_${incident['id']}'),
//             position: position,
//             icon: BitmapDescriptor.defaultMarkerWithHue(hue),
//             infoWindow: InfoWindow(
//               title: 'Fall Incident',
//               snippet: 'Time: ${_formatDateTime(incident['timestamp'])}',
//               onTap: () {
//                 _showFallIncidentDetails(incident);
//               },
//             ),
//           ),
//         );
//       }
//     }
//
//     setState(() {
//       _markers = markers;
//     });
//   }
//
//   void _showFallAlert(String incidentId) {
//     // Find the incident details
//     Map<String, dynamic>? incident;
//     for (var inc in _fallIncidents) {
//       if (inc['id'] == incidentId) {
//         incident = inc;
//         break;
//       }
//     }
//
//     if (incident == null) return;
//
//     // Show alert dialog
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Fall Detected!',
//               style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Text('A fall has been detected for your child!'),
//               const SizedBox(height: 16),
//               Text('Time: ${_formatDateTime(incident!['timestamp'])}'),
//               const SizedBox(height: 8),
//               Text('Status: ${_formatStatus(incident['status'])}'),
//               const SizedBox(height: 16),
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.of(context).pop();
//
//                   // Center map on the fall location
//                   if (_mapController != null) {
//                     _mapController!.animateCamera(
//                       CameraUpdate.newLatLngZoom(
//                         LatLng(incident?['latitude'], incident?['longitude']),
//                         18,
//                       ),
//                     );
//                   }
//
//                   // Mark incident as acknowledged
//                   _acknowledgeIncident(incidentId);
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.red,
//                 ),
//                 child: const Text('View Location'),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   Future<void> _acknowledgeIncident(String incidentId) async {
//     try {
//       await _firestore.collection('fall_incidents').doc(incidentId).update({
//         'acknowledged': true,
//       });
//
//       // Refresh the list
//       _fetchFallIncidents();
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Incident acknowledged')),
//       );
//     } catch (e) {
//       print('Error acknowledging incident: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Failed to acknowledge incident')),
//       );
//     }
//   void _showFallIncidentDetails(Map<String, dynamic> incident) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Fall Incident Details'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text('Time: ${_formatDateTime(incident['timestamp'])}'),
//               const SizedBox(height: 8),
//               Text('Status: ${_formatStatus(incident['status'])}'),
//               const SizedBox(height: 8),
//               Text('Acknowledged: ${incident['acknowledged'] ? 'Yes' : 'No'}'),
//               const SizedBox(height: 16),
//               if (!incident['acknowledged'])
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                     _acknowledgeIncident(incident['id']);
//                   },
//                   child: const Text('Acknowledge'),
//                 ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//               child: const Text('Close'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 _callChild();
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.green,
//               ),
//               child: const Text('Call Child'),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   void _callChild() {
//     // Implement calling functionality
//     // This could launch the phone app with the child's number
//   }
//
//   String _formatStatus(String status) {
//     switch (status) {
//       case 'detected':
//         return 'Detected';
//       case 'false_alarm':
//         return 'False Alarm';
//       case 'need_help':
//         return 'Help Needed';
//       case 'no_response':
//         return 'No Response';
//       default:
//         return 'Unknown';
//     }
//   }
//
//   String _formatDateTime(DateTime dateTime) {
//     return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
//   }
//
//   String _formatLastUpdate() {
//     if (_lastLocationUpdate == null) {
//       return 'No updates yet';
//     }
//
//     // Calculate time difference
//     Duration difference = DateTime.now().difference(_lastLocationUpdate!);
//
//     if (difference.inMinutes < 1) {
//       return 'Just now';
//     } else if (difference.inHours < 1) {
//       return '${difference.inMinutes} minutes ago';
//     } else if (difference.inDays < 1) {
//       return '${difference.inHours} hours ago';
//     } else {
//       return '${difference.inDays} days ago';
//     }
//   }
//
//   void _onMapCreated(GoogleMapController controller) {
//     _mapController = controller;
//
//     if (_childLocation != null) {
//       controller.animateCamera(
//         CameraUpdate.newLatLngZoom(_childLocation!, 15),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Tracking ${widget.childName}'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: _fetchChildData,
//           ),
//         ],
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : Column(
//         children: [
//           // Map taking upper half
//           SizedBox(
//             height: MediaQuery.of(context).size.height * 0.5,
//             child: _childLocation == null
//                 ? const Center(child: Text('No location data available'))
//                 : GoogleMap(
//               initialCameraPosition: CameraPosition(
//                 target: _childLocation!,
//                 zoom: 15,
//               ),
//               markers: _childLocation != null
//                   ? {
//                 Marker(
//                   markerId: MarkerId(widget.childId),
//                   position: _childLocation!,
//                   infoWindow: InfoWindow(
//                     title: widget.childName,
//                     snippet: 'Last updated: ${DateTime.now().toString()}',
//                   ),
//                 ),
//               }
//                   : {},
//               onMapCreated: (controller) {
//                 _mapController = controller;
//               },
//             ),
//           ),
//
//           // Fall incidents taking lower half
//           Expanded(
//             child: Container(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       const Text(
//                         'Fall Incidents',
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       if (_fallIncidents.isNotEmpty)
//                         TextButton(
//                           onPressed: _fetchFallIncidents,
//                           child: const Text('Refresh'),
//                         ),
//                     ],
//                   ),
//                   const SizedBox(height: 8),
//                   Expanded(
//                     child: _fallIncidents.isEmpty
//                         ? const Center(child: Text('No fall incidents recorded'))
//                         : ListView.builder(
//                       itemCount: _fallIncidents.length,
//                       itemBuilder: (context, index) {
//                         final incident = _fallIncidents[index];
//                         final bool isRecent = DateTime.now().difference(
//                             (incident['rawTimestamp'] as Timestamp).toDate()
//                         ).inHours < 24;
//
//                         Color statusColor;
//                         switch (incident['status']) {
//                           case 'Help Needed':
//                             statusColor = Colors.red;
//                             break;
//                           case 'No Response':
//                             statusColor = Colors.orange;
//                             break;
//                           case 'False Alarm':
//                             statusColor = Colors.green;
//                             break;
//                           case 'Detected':
//                             statusColor = Colors.blue;
//                             break;
//                           default:
//                             statusColor = Colors.grey;
//                         }
//
//                         return Card(
//                           margin: const EdgeInsets.only(bottom: 8.0),
//                           elevation: isRecent ? 3 : 1,
//                           child: ListTile(
//                             title: Text(
//                               incident['timestamp'],
//                               style: TextStyle(
//                                 fontWeight: isRecent ? FontWeight.bold : FontWeight.normal,
//                               ),
//                             ),
//                             subtitle: Text(
//                               incident['status'],
//                               style: TextStyle(
//                                 color: statusColor,
//                                 fontWeight: isRecent ? FontWeight.bold : FontWeight.normal,
//                               ),
//                             ),
//                             trailing: incident['acknowledged']
//                                 ? const Icon(Icons.check_circle, color: Colors.green)
//                                 : TextButton(
//                               onPressed: () => _acknowledgeIncident(incident['id']),
//                               child: const Text('Acknowledge'),
//                             ),
//                             onTap: () {
//                               // If there's a location, center the map on it
//                               if (incident['location'] != null && _mapController != null) {
//                                 _mapController!.animateCamera(
//                                   CameraUpdate.newLatLngZoom(incident['location'], 15),
//                                 );
//                               }
//                             },
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: _childLocation != null
//           ? FloatingActionButton(
//         onPressed: () {
//           if (_mapController != null) {
//             _mapController!.animateCamera(
//               CameraUpdate.newLatLngZoom(_childLocation!, 15),
//             );
//           }
//         },
//         child: const Icon(Icons.my_location),
//       )
//           : null,
//     );
//   }
//   }
//   void _showFallHistorySheet() {
//     showModalBottomSheet(
//         context: context,
//         isScrollControlled: true,
//         shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//     ),
//     builder: (context) {
//     return DraggableScrollableSheet(
//     initialChildSize: 0.6,
//     minChildSize: 0.3,
//     maxChildSize: 0.9,
//     expand: false,
//     builder: (context, scrollController) {
//     return Column(
//     children: [
//     Padding(
//     padding: const EdgeInsets.all(16.0),
//     child: Row(
//     mainAxisAlignment: MainAxisAlignment.center,
//     children: [
//     const Icon(Icons.history),
//     const SizedBox(width: 8),
//     Text(
//     'Fall History',
//     style: Theme.of(context).textTheme.titleLarge,
//     ),
//     ],
//     ),
//     ),
//     Expanded(
//     child: _fallIncidents.isEmpty
//     ? const Center(
//     child: Text('No fall incidents recorded'),
//     )
//         : ListView.builder(
//     controller: scrollController,
//     itemCount: _fallIncidents.length,
//     itemBuilder: (context, index) {
//     final incident = _fallIncidents[index];
//     return Card(
//       margin: const EdgeInsets.symmetric(
//           horizontal: 16.0, vertical: 8.0),
//       child: ListTile(
//         leading: CircleAvatar(
//           backgroundColor: _getStatusColor(incident['status']),
//           child: Icon(
//             Icons.warning,
//             color: Colors.white,
//           ),
//         ),
//         title: Text(
//           'Fall Incident on ${_formatDateTime(incident['timestamp'])}',
//         ),
//         subtitle: Text(
//           'Status: ${_formatStatus(incident['status'])}',
//         ),
//         trailing: incident['acknowledged']
//             ? const Icon(Icons.check_circle, color: Colors.green)
//             : const Icon(Icons.error, color: Colors.red),
//         onTap: () {
//           Navigator.pop(context);
//
//           // Center map on the fall location
//           if (_mapController != null) {
//             _mapController!.animateCamera(
//               CameraUpdate.newLatLngZoom(
//                 LatLng(incident['latitude'], incident['longitude']),
//                 18,
//               ),
//             );
//           }
//
//           // Show incident details
//           _showFallIncidentDetails(incident);
//         },
//       ),
//     );
//     },
//     ),
//     ),
//     ],
//     );
//     },
//     );
//     },
//     );
//   }
//
//   Color _getStatusColor(String status) {
//     switch (status) {
//       case 'detected':
//         return Colors.blue;
//       case 'false_alarm':
//         return Colors.yellow[700]!;
//       case 'need_help':
//         return Colors.red;
//       case 'no_response':
//         return Colors.orange;
//       default:
//         return Colors.grey;
//     }
//   }
// }