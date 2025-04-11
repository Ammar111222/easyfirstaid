
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FallIncidentService {
  final FirebaseFirestore _firestore;
  final String childId;

  FallIncidentService({
    required this.childId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> fetchFallIncidents() async {
    try {
      QuerySnapshot incidentsSnapshot = await _firestore
          .collection('fall_incidents')
          .where('childId', isEqualTo: childId)
          .orderBy('timestamp', descending: true)
          .limit(10) // Get the most recent 10 incidents
          .get();

      List<Map<String, dynamic>> incidents = [];
      for (var doc in incidentsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Format timestamp
        Timestamp timestamp = data['timestamp'] as Timestamp;
        DateTime dateTime = timestamp.toDate();
        String formattedDate = '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';

        // Format status
        String status = 'Unknown';
        if (data.containsKey('status')) {
          switch (data['status']) {
            case 'detected':
              status = 'Detected';
              break;
            case 'false_alarm':
              status = 'False Alarm';
              break;
            case 'need_help':
              status = 'Help Needed';
              break;
            case 'no_response':
              status = 'No Response';
              break;
            default:
              status = data['status'];
          }
        }

        incidents.add({
          'id': doc.id,
          'timestamp': formattedDate,
          'rawTimestamp': timestamp,
          'status': status,
          'acknowledged': data['acknowledged'] ?? false,
          'location': data.containsKey('location')
              ? LatLng((data['location'] as GeoPoint).latitude, (data['location'] as GeoPoint).longitude)
              : null,
        });
      }

      return incidents;
    } catch (e) {
      print('Error fetching fall incidents: $e');
      return [];
    }
  }

  Future<void> acknowledgeIncident(String incidentId) async {
    try {
      await _firestore.collection('fall_incidents').doc(incidentId).update({
        'acknowledged': true,
      });
    } catch (e) {
      print('Error acknowledging incident: $e');
      throw Exception('Failed to acknowledge incident');
    }
  }

  Stream<QuerySnapshot> listenToFallIncidents() {
    return _firestore
        .collection('fall_incidents')
        .where('childId', isEqualTo: childId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
