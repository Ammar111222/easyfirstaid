
import 'package:flutter/material.dart';

class FallIncidentDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> incident;
  final Function(String) onAcknowledge;
  final VoidCallback onCallChild;

  const FallIncidentDetailsDialog({
    Key? key,
    required this.incident,
    required this.onAcknowledge,
    required this.onCallChild,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Fall Incident Details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Time: ${incident['timestamp']}'),
          const SizedBox(height: 8),
          Text('Status: ${incident['status']}'),
          const SizedBox(height: 8),
          Text('Acknowledged: ${incident['acknowledged'] ? 'Yes' : 'No'}'),
          const SizedBox(height: 16),
          if (!incident['acknowledged'])
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onAcknowledge(incident['id']);
              },
              child: const Text('Acknowledge'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onCallChild();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: const Text('Call Child'),
        ),
      ],
    );
  }
}
