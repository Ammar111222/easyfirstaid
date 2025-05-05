
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'search_notification_service.dart';
import 'search_fall_detection_service.dart';
import 'search_tracking_service.dart';
import 'widgets/child_tracking_screen.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/search_results_widget.dart';
import 'widgets/pending_requests_widget.dart';
import 'widgets/children_list_widget.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _children = [];
  bool _isSearching = false;

  // Services
  late SearchNotificationService _notificationService;
  late SearchFallDetectionService _fallDetectionService;
  late SearchTrackingService _trackingService;

  @override
  void initState() {
    super.initState();

    // Initialize services
    _notificationService = SearchNotificationService(
      auth: _auth,
      firestore: _firestore,
      fcm: _fcm,
      onChildTap: _handleNotificationTap,
    );

    _fallDetectionService = SearchFallDetectionService(
      auth: _auth,
      firestore: _firestore,
      notificationService: _notificationService,
    );

    _trackingService = SearchTrackingService(
        auth: _auth,
        firestore: _firestore
    );

    _notificationService.initialize();
    _fetchPendingRequests();
    _fetchChildren();

    // If this user is a child, start fall detection
    _checkIfChild().then((isChild) {
      if (isChild) {
        _fallDetectionService.startFallDetection();
        _trackingService.startLocationTracking();
      }
    });
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    if (data.containsKey('type') && data['type'] == 'fall_detection') {
      if (data.containsKey('childId')) {
        // Find the child in the list
        for (var child in _children) {
          if (child['uid'] == data['childId']) {
            // Navigate to child tracking screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChildTrackingScreen(
                  childId: child['uid'],
                  childName: child['displayName'],
                ),
              ),
            );
            break;
          }
        }
      }
    }
  }

  Future<bool> _checkIfChild() async {
    DocumentSnapshot userDoc = await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .get();

    Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
    return userData != null && userData['parentId'] != null;
  }

  Future<void> _fetchPendingRequests() async {
    try {
      QuerySnapshot requestsSnapshot = await _firestore
          .collection('requests')
          .where('receiverId', isEqualTo: _auth.currentUser!.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      List<Map<String, dynamic>> requests = [];
      for (var doc in requestsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        // Get sender details
        DocumentSnapshot senderDoc = await _firestore
            .collection('users')
            .doc(data['senderId'])
            .get();

        Map<String, dynamic> senderData = senderDoc.data() as Map<String, dynamic>;

        requests.add({
          'requestId': doc.id,
          'senderId': data['senderId'],
          'senderEmail': senderData['email'],
          'senderName': senderData['displayName'] ?? 'User',
          'timestamp': data['timestamp'],
        });
      }

      setState(() {
        _pendingRequests = requests;
      });
    } catch (e) {
      print('Error fetching pending requests: $e');
    }
  }

  Future<void> _fetchChildren() async {
    try {
      QuerySnapshot childrenSnapshot = await _firestore
          .collection('users')
          .where('parentId', isEqualTo: _auth.currentUser!.uid)
          .get();

      List<Map<String, dynamic>> children = [];
      for (var doc in childrenSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        children.add({
          'uid': doc.id,
          'email': data['email'],
          'displayName': data['displayName'] ?? 'Child User',
          'location': data['location'],
        });
      }

      setState(() {
        _children = children;
      });
    } catch (e) {
      print('Error fetching children: $e');
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // Search for users by email
      QuerySnapshot userSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: query)
          .get();

      List<Map<String, dynamic>> results = [];
      for (var doc in userSnapshot.docs) {
        // Skip if user is the current user
        if (doc.id == _auth.currentUser!.uid) continue;

        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Check if there's already a pending request
        QuerySnapshot pendingRequestsSnapshot = await _firestore
            .collection('requests')
            .where('senderId', isEqualTo: _auth.currentUser!.uid)
            .where('receiverId', isEqualTo: doc.id)
            .where('status', isEqualTo: 'pending')
            .get();

        bool hasPendingRequest = pendingRequestsSnapshot.docs.isNotEmpty;

        // Check if this user is already a child
        QuerySnapshot childSnapshot = await _firestore
            .collection('users')
            .where('uid', isEqualTo: doc.id)
            .where('parentId', isEqualTo: _auth.currentUser!.uid)
            .get();

        bool isAlreadyChild = childSnapshot.docs.isNotEmpty;

        results.add({
          'uid': doc.id,
          'email': data['email'],
          'displayName': data['displayName'] ?? 'User',
          'hasPendingRequest': hasPendingRequest,
          'isAlreadyChild': isAlreadyChild,
        });
      }

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _sendParentRequest(String receiverId) async {
    try {
      // Create a new request
      await _firestore.collection('requests').add({
        'senderId': _auth.currentUser!.uid,
        'receiverId': receiverId,
        'status': 'pending',
        'type': 'parent',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update search results to show pending request
      setState(() {
        for (var i = 0; i < _searchResults.length; i++) {
          if (_searchResults[i]['uid'] == receiverId) {
            _searchResults[i]['hasPendingRequest'] = true;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parent request sent successfully')),
      );
    } catch (e) {
      print('Error sending parent request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send parent request')),
      );
    }
  }

  Future<void> _handleRequestResponse(String requestId, String response) async {
    try {
      // Find the request
      DocumentSnapshot requestDoc = await _firestore
          .collection('requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      Map<String, dynamic> requestData = requestDoc.data() as Map<String, dynamic>;

      // Update request status
      await _firestore.collection('requests').doc(requestId).update({
        'status': response,
      });

      if (response == 'accepted') {
        // Update the child user with parentId
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
          'parentId': requestData['senderId'],
        });

        // Start fall detection and location tracking
        _fallDetectionService.startFallDetection();
        _trackingService.startLocationTracking();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You accepted the parent request')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You declined the parent request')),
        );
      }

      // Refresh pending requests
      _fetchPendingRequests();
    } catch (e) {
      print('Error handling request response: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to process your response')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SearchBarWidget(
                controller: _searchController,
                onChanged: _searchUsers,
                onClear: () {
                  _searchController.clear();
                  setState(() {
                    _searchResults = [];
                  });
                }
            ),
            if (_searchController.text.isNotEmpty)
              SearchResultsWidget(
                results: _searchResults,
                isSearching: _isSearching,
                onAddChild: _sendParentRequest,
              ),
            PendingRequestsWidget(
              requests: _pendingRequests,
              onResponse: _handleRequestResponse,
            ),
            ChildrenListWidget(
              children: _children,
            ),
          ],
        ),
      ),
    );
  }
}
