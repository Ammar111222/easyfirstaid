import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
class SearchTrackingService {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  Stream<Position>? _positionStream;

  SearchTrackingService({
    required this.auth,
    required this.firestore,
  });

  Future<void> startLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Handle location services not enabled
      throw LocationServiceDisabledException();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Handle permission denied
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Handle permission denied forever
      throw Exception('Location permission permanently denied');
    }

    // Start location tracking
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );

    _positionStream!.listen((Position position) async {
      // Update location in Firestore
      await firestore.collection('users').doc(auth.currentUser!.uid).update({
        'location': GeoPoint(position.latitude, position.longitude),
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> stopLocationTracking() async {
    // Cancel the position stream subscription if it exists
    _positionStream = null;
  }

  Future<Position> getCurrentLocation() async {
    // Get the current location once
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceDisabledException();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> updateLocationOnce() async {
    try {
      Position position = await getCurrentLocation();

      // Update location in Firestore
      await firestore.collection('users').doc(auth.currentUser!.uid).update({
        'location': GeoPoint(position.latitude, position.longitude),
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update location: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyUsers({
    required double radiusInKm,
    int limit = 20,
  }) async {
    try {
      Position currentPosition = await getCurrentLocation();
      GeoPoint userLocation = GeoPoint(
        currentPosition.latitude,
        currentPosition.longitude,
      );

      // Get current user's data
      DocumentSnapshot userDoc = await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .get();

      // Calculate the rough lat/lng bounds for the query
      // This is an optimization to avoid checking all users
      double lat = userLocation.latitude;
      double lng = userLocation.longitude;

      // Approximately 0.01 degrees = 1.11 km
      double latBound = radiusInKm * 0.01;
      double lngBound = radiusInKm * 0.01 / cos(lat * pi / 180);

      // Query users within the rough bound
      QuerySnapshot nearbyUsersSnapshot = await firestore
          .collection('users')
          .where('location', isGreaterThan: GeoPoint(lat - latBound, lng - lngBound))
          .where('location', isLessThan: GeoPoint(lat + latBound, lng + lngBound))
          .limit(limit * 2) // Get more than needed as we'll filter further
          .get();

      List<Map<String, dynamic>> nearbyUsers = [];

      // Filter users by actual distance and exclude the current user
      for (var doc in nearbyUsersSnapshot.docs) {
        if (doc.id != auth.currentUser!.uid) {
          Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
          GeoPoint userGeoPoint = userData['location'] as GeoPoint;

          // Calculate actual distance
          double distanceInMeters = Geolocator.distanceBetween(
            userLocation.latitude,
            userLocation.longitude,
            userGeoPoint.latitude,
            userGeoPoint.longitude,
          );

          if (distanceInMeters <= radiusInKm * 1000) {
            userData['id'] = doc.id;
            userData['distance'] = distanceInMeters / 1000; // Convert to km
            nearbyUsers.add(userData);
          }
        }
      }

      // Sort by distance
      nearbyUsers.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      // Limit results
      if (nearbyUsers.length > limit) {
        nearbyUsers = nearbyUsers.sublist(0, limit);
      }

      return nearbyUsers;
    } catch (e) {
      throw Exception('Failed to get nearby users: $e');
    }
  }

  // Helper function for getNearbyUsers
  double cos(double radians) {
    return math.cos(radians);
  }

  double pi = math.pi;
}

// Don't forget to add this import at the top
