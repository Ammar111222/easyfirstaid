import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Mapscreen extends StatefulWidget {
  const Mapscreen({Key? key}) : super(key: key);

  @override
  State<Mapscreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<Mapscreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {}; // For storing polylines
  bool _isLoading = false;
  bool _isDrawingRoute = false; // For route drawing loader

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  void _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Location permissions are permanently denied.')),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
    });

    _getNearbyHospitals();
  }

  void _getNearbyHospitals() async {
    if (_currentPosition == null) return;

    setState(() {
      _isLoading = true;
    });

    final String apiKey = 'AIzaSyAjdVXGes1tTvMDHZD6Yzgm_0mKl5lwtto'; // Replace with your API Key
    final url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
        'location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
        '&radius=9000&type=hospital&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _markers.clear();

          for (var hospital in data['results']) {
            if (hospital['types'] != null &&
                hospital['types'].contains('hospital')) {
              final lat = hospital['geometry']['location']['lat'];
              final lng = hospital['geometry']['location']['lng'];
              final name = hospital['name'];
              final vicinity = hospital['vicinity'];

              _markers.add(
                Marker(
                  markerId: MarkerId(hospital['place_id']),
                  position: LatLng(lat, lng),
                  infoWindow: InfoWindow(
                    title: name,
                    snippet: vicinity,
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure),
                  onTap: () => _drawRoute(LatLng(lat, lng)),
                ),
              );
            }
          }
        });
      } else {
        print('Failed to fetch data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching nearby hospitals: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _drawRoute(LatLng destination) async {
    if (_currentPosition == null) return;

    setState(() {
      _isDrawingRoute = true; // Show loader for route drawing
    });

    final String apiKey = 'AIzaSyAjdVXGes1tTvMDHZD6Yzgm_0mKl5lwtto'; // Replace with your API Key
    final url = 'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=driving&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final points = data['routes'][0]['overview_polyline']['points'];
        final List<LatLng> polylineCoordinates = _decodePolyline(points);

        setState(() {
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: polylineCoordinates,
              color: Colors.blue,
              width: 5,
            ),
          );
        });
      } else {
        print('Failed to fetch directions. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching directions: $e');
    }

    setState(() {
      _isDrawingRoute = false; // Hide loader after route drawing
    });
  }

  List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> coordinates = [];
    int index = 0, len = polyline.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int b;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      coordinates.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return coordinates;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Hospitals'),
      ),
      body: Stack(
        children: [
          if (_currentPosition != null)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                    _currentPosition!.latitude, _currentPosition!.longitude),
                zoom: 14,
              ),
              onMapCreated: (controller) => _mapController = controller,
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          if (_isLoading || _isDrawingRoute)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getNearbyHospitals,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
