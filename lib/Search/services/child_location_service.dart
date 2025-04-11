
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ChildLocationService {
  final FirebaseFirestore _firestore;
  final String childId;

  ChildLocationService({
    required this.childId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> fetchChildData() async {
    try {
      DocumentSnapshot childDoc = await _firestore
          .collection('users')
          .doc(childId)
          .get();

      if (!childDoc.exists) {
        return null;
      }

      Map<String, dynamic> childData = childDoc.data() as Map<String, dynamic>;
      LatLng? location;
      DateTime? lastUpdate;

      if (childData.containsKey('location')) {
        GeoPoint geoPoint = childData['location'] as GeoPoint;
        location = LatLng(geoPoint.latitude, geoPoint.longitude);
      }

      if (childData.containsKey('lastLocationUpdate')) {
        Timestamp timestamp = childData['lastLocationUpdate'] as Timestamp;
        lastUpdate = timestamp.toDate();
      }

      return {
        'location': location,
        'lastLocationUpdate': lastUpdate,
        'data': childData,
      };
    } catch (e) {
      print('Error fetching child data: $e');
      return null;
    }
  }

  Stream<DocumentSnapshot> listenToChildLocation() {
    return _firestore
        .collection('users')
        .doc(childId)
        .snapshots();
  }

  Set<Marker> createMarkers({
    required LatLng? childLocation,
    required String childName,
    required String lastUpdateText,
    required List<Map<String, dynamic>> fallIncidents,
    required bool showFallIncidents,
    required Function(Map<String, dynamic>) onFallIncidentTap,
  }) {
    if (childLocation == null) return {};

    Set<Marker> markers = {};

    // Add current location marker
    markers.add(
      Marker(
        markerId: MarkerId(childId),
        position: childLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: "$childName's Location",
          snippet: 'Last updated: $lastUpdateText',
        ),
      ),
    );

    // Add fall incident markers if enabled
    if (showFallIncidents) {
      for (int i = 0; i < fallIncidents.length; i++) {
        final incident = fallIncidents[i];
        if (incident['location'] != null) {
          // Use different colors based on fall status
          double hue;
          String status = incident['status'];

          switch (status) {
            case 'False Alarm':
              hue = BitmapDescriptor.hueYellow;
              break;
            case 'Help Needed':
              hue = BitmapDescriptor.hueRed;
              break;
            case 'No Response':
              hue = BitmapDescriptor.hueOrange;
              break;
            default:
              hue = BitmapDescriptor.hueRose;
          }

          markers.add(
            Marker(
              markerId: MarkerId('fall_${incident['id']}'),
              position: incident['location'],
              icon: BitmapDescriptor.defaultMarkerWithHue(hue),
              infoWindow: InfoWindow(
                title: 'Fall Incident',
                snippet: 'Time: ${incident['timestamp']}',
              ),
              onTap: () => onFallIncidentTap(incident),
            ),
          );
        }
      }
    }

    return markers;
  }
}