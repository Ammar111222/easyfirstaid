
import 'package:flutter/material.dart';

class FallAlertDialog extends StatelessWidget {
  final Map<String, dynamic> incident;
  final Function(String) onAcknowledge;

  const FallAlertDialog({
    Key? key,
    required this.incident,
    required this.onAcknowledge,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Fall Detected!',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('A fall has been detected for your child!'),
          const SizedBox(height: 16),
          Text('Time: ${incident['timestamp']}'),
          const SizedBox(height: 8),
          Text('Status: ${incident['status']}'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onAcknowledge(incident['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('View Location'),
          ),
        ],
      ),
    );
  }
}
