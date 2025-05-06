import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/status_utils.dart';
import 'fall_incident_details_dialog.dart';

class FallIncidentList extends StatefulWidget {
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
  _FallIncidentListState createState() => _FallIncidentListState();
}

class _FallIncidentListState extends State<FallIncidentList> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _hasNewIncident = false;
  int _unacknowledgedCount = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animationController.repeat(reverse: true);
    _countUnacknowledgedIncidents();
  }
  
  @override
  void didUpdateWidget(FallIncidentList oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if there are new incidents
    if (widget.fallIncidents.length > oldWidget.fallIncidents.length) {
      _triggerNewIncidentNotification();
    }
    
    _countUnacknowledgedIncidents();
  }
  
  void _countUnacknowledgedIncidents() {
    int count = 0;
    for (var incident in widget.fallIncidents) {
      if (incident['acknowledged'] == false) {
        count++;
      }
    }
    
    setState(() {
      _unacknowledgedCount = count;
    });
  }
  
  void _triggerNewIncidentNotification() {
    setState(() {
      _hasNewIncident = true;
    });
    
    // Play animation for 5 seconds then stop
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _hasNewIncident = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

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
              Row(
                children: [
                  const Text(
                    'Fall Incidents',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_unacknowledgedCount > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_unacknowledgedCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              if (widget.fallIncidents.isNotEmpty)
                Row(
                  children: [
                    if (_hasNewIncident)
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.3 + 0.7 * _animationController.value),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'NEW!',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: widget.onRefresh,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: widget.fallIncidents.isEmpty
                ? const Center(child: Text('No fall incidents recorded'))
                : RefreshIndicator(
                  onRefresh: () async {
                    widget.onRefresh();
                  },
                  child: ListView.builder(
                    itemCount: widget.fallIncidents.length,
                    itemBuilder: (context, index) {
                      final incident = widget.fallIncidents[index];
                      final bool isNew = index == 0 && _hasNewIncident;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: isNew ? 8 : 2,
                        color: isNew ? Colors.yellow[50] : null,
                        child: InkWell(
                          onTap: () => widget.onTap(incident),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: getStatusColor(incident['status']),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        incident['timestamp'] ?? 'Unknown time',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        incident['status'] ?? 'Unknown status',
                                        style: TextStyle(
                                          color: getStatusColor(incident['status']),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!incident['acknowledged'])
                                  TextButton(
                                    onPressed: () => widget.onAcknowledge(incident['id']),
                                    child: const Text('Acknowledge'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
