import 'dart:async';
import 'package:easy_first_aid/Search/widgets/fall_incident_list.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/child_location_service.dart';
import '../services/fall_incident_service.dart';
import '../utils/date_time_utils.dart';
import 'fall_alert_dialog.dart';
import 'fall_history_sheet.dart';
import 'fall_incident_details_dialog.dart';



class ChildTrackingScreen extends StatefulWidget {
  final String childId;
  final String childName;

  const ChildTrackingScreen({
    Key? key,
    required this.childId,
    required this.childName,
  }) : super(key: key);

  @override
  _ChildTrackingScreenState createState() => _ChildTrackingScreenState();
}

class _ChildTrackingScreenState extends State<ChildTrackingScreen> {
  // Services
  late ChildLocationService _locationService;
  late FallIncidentService _fallIncidentService;

  // State variables
  GoogleMapController? _mapController;
  LatLng? _childLocation;
  DateTime? _lastLocationUpdate;
  bool _isLoading = true;
  bool _showFallIncidents = false;
  List<Map<String, dynamic>> _fallIncidents = [];
  Set<Marker> _markers = {};

  // Subscriptions
  StreamSubscription? _locationSubscription;
  StreamSubscription? _fallIncidentsSubscription;

  @override
  void initState() {
    super.initState();
    _locationService = ChildLocationService(childId: widget.childId);
    _fallIncidentService = FallIncidentService(childId: widget.childId);

    _setupNotificationListener();
    _fetchChildData();
    _listenToFallIncidents();
    _fetchChildLocation();
    _setupLocationListener();
    _fetchFallIncidents();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _fallIncidentsSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // Setup to listen for notifications while in the tracking screen
  void _setupNotificationListener() {
    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        // Check if this notification is for the child we're tracking
        if (message.data.containsKey('childId') &&
            message.data['childId'] == widget.childId &&
            message.data.containsKey('type') &&
            message.data['type'] == 'fall_detection') {

          // Show an alert dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Fall Detected!'),
                content: Text('${widget.childName} may have fallen. Please check on them immediately.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Refresh fall incidents
                      _fetchFallIncidents();
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );

          // Refresh the map and data
          _fetchChildData();
        }
      }
    });
  }

  Future<void> _fetchChildData() async {
    try {
      Map<String, dynamic>? childData = await _locationService.fetchChildData();

      if (childData == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _childLocation = childData['location'] as LatLng?;
      });

      // Update map camera
      if (_mapController != null && _childLocation != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_childLocation!, 15),
        );
      }

      _fetchFallIncidents();
    } catch (e) {
      print('Error fetching child data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _fetchChildLocation() async {
    try {
      Map<String, dynamic>? childData = await _locationService.fetchChildData();

      if (childData != null) {
        setState(() {
          _childLocation = childData['location'] as LatLng?;
          _lastLocationUpdate = childData['lastLocationUpdate'] as DateTime?;
          _updateMarkers();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching child location: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupLocationListener() {
    _locationSubscription?.cancel();
    _locationSubscription = _locationService.listenToChildLocation().listen(
          (DocumentSnapshot snapshot) {
        if (snapshot.exists) {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
          GeoPoint? location = data['location'] as GeoPoint?;
          Timestamp? lastUpdate = data['lastLocationUpdate'] as Timestamp?;

          // Check if a new fall was detected
          Timestamp? lastFallDetected = data['lastFallDetected'] as Timestamp?;
          String? lastFallIncidentId = data['lastFallIncidentId'] as String?;

          if (lastFallDetected != null && lastFallIncidentId != null) {
            DateTime lastFallTime = lastFallDetected.toDate();
            // If fall was detected in the last 5 minutes, show an alert
            if (DateTime.now().difference(lastFallTime).inMinutes < 5) {
              _showFallAlert(lastFallIncidentId);
            }
          }

          setState(() {
            if (location != null) {
              _childLocation = LatLng(location.latitude, location.longitude);
              _updateMarkers();

              // Update map camera position
              if (_mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLng(_childLocation!),
                );
              }
            }

            if (lastUpdate != null) {
              _lastLocationUpdate = lastUpdate.toDate();
            }
          });
        }
      },
    );
  }

  void _listenToFallIncidents() {
    _fallIncidentsSubscription?.cancel();
    _fallIncidentsSubscription = _fallIncidentService.listenToFallIncidents().listen(
          (snapshot) {
        _fetchFallIncidents();
      },
    );
  }

  Future<void> _fetchFallIncidents() async {
    try {
      List<Map<String, dynamic>> incidents = await _fallIncidentService.fetchFallIncidents();

      setState(() {
        _fallIncidents = incidents;
        _updateMarkers();
      });
    } catch (e) {
      print('Error fetching fall incidents: $e');
    }
  }

  void _updateMarkers() {
    Set<Marker> markers = _locationService.createMarkers(
      childLocation: _childLocation,
      childName: widget.childName,
      lastUpdateText: formatLastUpdate(_lastLocationUpdate),
      fallIncidents: _fallIncidents,
      showFallIncidents: _showFallIncidents,
      onFallIncidentTap: _showFallIncidentDetails,
    );

    setState(() {
      _markers = markers;
    });
  }

  void _showFallAlert(String incidentId) {
    // Find the incident details
    Map<String, dynamic>? incident;
    for (var inc in _fallIncidents) {
      if (inc['id'] == incidentId) {
        incident = inc;
        break;
      }
    }

    if (incident == null) return;

    // Show alert dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return FallAlertDialog(
          incident: incident!,
          onAcknowledge: (id) {
            // Center map on the fall location
            if (_mapController != null && incident?['location'] != null) {
              _mapController!.animateCamera(
                CameraUpdate.newLatLngZoom(
                  incident!['location'],
                  18,
                ),
              );
            }

            // Mark incident as acknowledged
            _acknowledgeIncident(id);
          },
        );
      },
    );
  }

  Future<void> _acknowledgeIncident(String incidentId) async {
    try {
      await _fallIncidentService.acknowledgeIncident(incidentId);

      // Refresh the list
      _fetchFallIncidents();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incident acknowledged')),
      );
    } catch (e) {
      print('Error acknowledging incident: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to acknowledge incident')),
      );
    }
  }

  void _showFallIncidentDetails(Map<String, dynamic> incident) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FallIncidentDetailsDialog(
          incident: incident,
          onAcknowledge: (id) {
            Navigator.of(context).pop();
            _acknowledgeIncident(id);
          },
          onCallChild: _callChild,
        );
      },
    );
  }

  void _callChild() {
    // Implement calling functionality
    // This could launch the phone app with the child's number
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    if (_childLocation != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(_childLocation!, 15),
      );
    }
  }

  void _showFallHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FallHistorySheet(
          fallIncidents: _fallIncidents,
          onIncidentTap: (incident) {
            // Center map on the fall location
            if (_mapController != null && incident['location'] != null) {
              _mapController!.animateCamera(
                CameraUpdate.newLatLngZoom(
                  incident['location'],
                  18,
                ),
              );
            }

            // Show incident details
            _showFallIncidentDetails(incident);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking ${widget.childName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchChildData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Map taking upper half
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: _childLocation == null
                ? const Center(child: Text('No location data available'))
                : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _childLocation!,
                zoom: 15,
              ),
              markers: _markers.isEmpty && _childLocation != null
                  ? {
                Marker(
                  markerId: MarkerId(widget.childId),
                  position: _childLocation!,
                  infoWindow: InfoWindow(
                    title: widget.childName,
                    snippet: 'Last updated: ${formatLastUpdate(_lastLocationUpdate)}',
                  ),
                ),
              }
                  : _markers,
              onMapCreated: _onMapCreated,
            ),
          ),

          // Fall incidents list
          Expanded(
            child: FallIncidentList(
              fallIncidents: _fallIncidents,
              onAcknowledge: _acknowledgeIncident,
              onTap: _showFallIncidentDetails,
              onRefresh: _fetchFallIncidents,
              mapController: _mapController,
            ),
          ),
        ],
      ),
      floatingActionButton: _childLocation != null
          ? FloatingActionButton(
        onPressed: () {
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(_childLocation!, 15),
            );
          }
        },
        child: const Icon(Icons.my_location),
      )
          : null,
    );
  }
}
