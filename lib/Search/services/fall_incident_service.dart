import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FallIncidentService {
  final String childId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  StreamSubscription? _incidentSubscription;
  bool _isInitialized = false;

  FallIncidentService({
    required this.childId,
  }) {
    _initialize();
  }
  
  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    final AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(initSettings);
    _isInitialized = true;
    
    // Start listening for new incidents if this is a parent
    _setupIncidentListener();
  }
  
  void _setupIncidentListener() {
    // First, check if this is a parent
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _firestore.collection('users')
            .where('parentId', isEqualTo: user.uid)
            .get()
            .then((querySnapshot) {
          if (querySnapshot.docs.isNotEmpty) {
            // This is a parent, so start listening for new incidents for all children
            _listenForNewIncidents();
          }
        });
      }
    });
  }
  
  void _listenForNewIncidents() {
    // Cancel any existing subscription
    _incidentSubscription?.cancel();
    
    // Get current user
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    // Get all children of this parent
    _firestore.collection('users')
        .where('parentId', isEqualTo: currentUser.uid)
        .get()
        .then((querySnapshot) {
      // Extract all child IDs
      List<String> childIds = querySnapshot.docs.map((doc) => doc.id).toList();
      
      if (childIds.isEmpty) return;
      
      // Listen for new incidents for any of these children
      _incidentSubscription = _firestore.collection('fall_incidents')
          .where('childId', whereIn: childIds)
          .orderBy('timestamp', descending: true)
          .limit(20) // Limit to reasonable number
          .snapshots()
          .listen((snapshot) {
        // Check if there's a new document
        if (snapshot.docChanges.isNotEmpty) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              // Only show notification for recent incidents (last 5 minutes)
              Map<String, dynamic> data = change.doc.data() as Map<String, dynamic>;
              if (data['timestamp'] != null) {
                DateTime incidentTime = (data['timestamp'] as Timestamp).toDate();
                if (DateTime.now().difference(incidentTime).inMinutes < 5) {
                  _showNewIncidentNotification(change.doc);
                }
              }
            }
          }
        }
      });
    });
  }
  
  Future<void> _showNewIncidentNotification(DocumentSnapshot doc) async {
    try {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String childId = data['childId'];
      
      // Get child's name
      DocumentSnapshot childDoc = await _firestore.collection('users').doc(childId).get();
      Map<String, dynamic> childData = childDoc.data() as Map<String, dynamic>;
      String childName = childData['displayName'] ?? 'Your child';
      
      // Format timestamp
      String timestamp = 'Just now';
      if (data['timestamp'] != null) {
        timestamp = DateFormat('MM/dd/yyyy HH:mm').format((data['timestamp'] as Timestamp).toDate());
      }
      
      // Create notification
      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'fall_incident_channel',
        'Fall Incidents',
        channelDescription: 'Notifications for new fall incidents',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        enableLights: true,
        color: Color(0xFFE53935),
        playSound: true,
        styleInformation: const BigTextStyleInformation(''),
      );
      
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
      
      NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      // Determine message based on status
      String status = data['status'] ?? 'detected';
      String message;
      switch (status) {
        case 'need_help':
          message = '$childName needs help! They responded "Need Help" to a fall alert.';
          break;
        case 'no_response':
          message = '$childName has not responded to a fall alert! Please check immediately.';
          break;
        case 'false_alarm':
          message = '$childName had a false alarm fall detection and is okay.';
          break;
        case 'detected':
        default:
          message = 'A fall was detected for $childName. Waiting for their response.';
          break;
      }
      
      // Show notification
      await _notifications.show(
        doc.id.hashCode % 1000000, // Use hash of document ID for consistent but unique IDs
        'Fall Incident: $childName',
        '$message\nTime: $timestamp',
        platformDetails,
        payload: '{"type":"fall_detection","childId":"$childId","fallIncidentId":"${doc.id}"}',
      );
    } catch (e) {
      print('Error showing fall incident notification: $e');
    }
  }

  Stream<QuerySnapshot> listenToFallIncidents() {
    return _firestore.collection('fall_incidents')
        .where('childId', isEqualTo: childId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> fetchFallIncidents() async {
    final QuerySnapshot snapshot = await _firestore.collection('fall_incidents')
        .where('childId', isEqualTo: childId)
        .orderBy('timestamp', descending: true)
        .get();

    return _processIncidentDocs(snapshot.docs);
  }

  List<Map<String, dynamic>> _processIncidentDocs(List<QueryDocumentSnapshot> docs) {
    return docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      Timestamp? timestamp = data['timestamp'] as Timestamp?;
      GeoPoint? location = data['location'] as GeoPoint?;

      String formattedDate = timestamp != null
          ? DateFormat('MM/dd/yyyy HH:mm').format(timestamp.toDate())
          : 'Unknown';

      return {
        'id': doc.id,
        'rawTimestamp': timestamp,
        'timestamp': formattedDate,
        'status': data['status'] ?? 'Unknown',
        'location': location != null ? LatLng(location.latitude, location.longitude) : null,
        'acknowledged': data['acknowledged'] ?? false,
        // Add other fields as needed
      };
    }).toList();
  }

  Future<void> acknowledgeIncident(String incidentId) async {
    await _firestore.collection('fall_incidents').doc(incidentId).update({
      'acknowledged': true,
      'acknowledgedAt': FieldValue.serverTimestamp(),
      'acknowledgedBy': _auth.currentUser?.uid,
    });
  }

  void dispose() {
    _incidentSubscription?.cancel();
  }
}
