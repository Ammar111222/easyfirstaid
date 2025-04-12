import 'package:flutter/material.dart';
import '../utils/status_utils.dart';

class FallHistorySheet extends StatelessWidget {
  final List<Map<String, dynamic>> fallIncidents;
  final Function(Map<String, dynamic>) onIncidentTap;

  const FallHistorySheet({
    Key? key,
    required this.fallIncidents,
    required this.onIncidentTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 8),
                  Text(
                    'Fall History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            Expanded(
              child: fallIncidents.isEmpty
                  ? const Center(
                child: Text('No fall incidents recorded'),
              )
                  : ListView.builder(
                controller: scrollController,
                itemCount: fallIncidents.length,
                itemBuilder: (context, index) {
                  final incident = fallIncidents[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: getStatusColor(incident['status']),
                        child: const Icon(
                          Icons.warning,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        'Fall Incident on ${incident['timestamp']}',
                      ),
                      subtitle: Text(
                        'Status: ${incident['status']}',
                      ),
                      trailing: incident['acknowledged']
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.error, color: Colors.red),
                      onTap: () {
                        Navigator.pop(context);
                        onIncidentTap(incident);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
