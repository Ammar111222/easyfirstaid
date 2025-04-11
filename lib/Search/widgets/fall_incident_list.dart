
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/status_utils.dart';
import 'fall_incident_details_dialog.dart';

class FallIncidentList extends StatelessWidget {
  final List<Map<String, dynamic>> fallIncidents;
  final Function(String) onAcknowledge;
  final Function(Map<String, dynamic>) onTap;
  final Function() onRefresh;
  final GoogleMapController? mapController;

  const FallIncidentList({
    Key? key,
    required this.fallIncidents,
    required this.onAcknowledge,
    required this.onTap,
    required this.onRefresh,
    this.mapController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fall Incidents',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (fallIncidents.isNotEmpty)
                TextButton(
                  onPressed: onRefresh,
                  child: const Text('Refresh'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: fallIncidents.isEmpty
                ? const Center(child: Text('No fall incidents recorded'))
                : ListView.builder(
              itemCount: fallIncidents.length,
              itemBuilder: (context, index) {
                final incident = fallIncidents[index];
                final bool isRecent = DateTime.now().difference(
                    (incident['rawTimestamp'] as Timestamp).toDate()
                ).inHours < 24;

                Color statusColor = getStatusColor(incident['status']);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  elevation: isRecent ? 3 : 1,
                  child: ListTile(
                    title: Text(
                      incident['timestamp'],
                      style: TextStyle(
                        fontWeight: isRecent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      incident['status'],
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: isRecent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: incident['acknowledged']
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : TextButton(
                      onPressed: () => onAcknowledge(incident['id']),
                      child: const Text('Acknowledge'),
                    ),
                    onTap: () {
                      // If there's a location, center the map on it
                      if (incident['location'] != null && mapController != null) {
                        mapController!.animateCamera(
                          CameraUpdate.newLatLngZoom(incident['location'], 15),
                        );
                      }

                      // Show incident details
                      onTap(incident);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
