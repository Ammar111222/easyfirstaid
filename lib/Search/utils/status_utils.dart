
import 'package:flutter/material.dart';

String formatStatus(String status) {
  switch (status) {
    case 'detected':
      return 'Detected';
    case 'false_alarm':
      return 'False Alarm';
    case 'need_help':
      return 'Help Needed';
    case 'no_response':
      return 'No Response';
    default:
      return status;
  }
}

Color getStatusColor(String status) {
  switch (status) {
    case 'Detected':
      return Colors.blue;
    case 'False Alarm':
      return Colors.yellow[700]!;
    case 'Help Needed':
      return Colors.red;
    case 'No Response':
      return Colors.orange;
    default:
      return Colors.grey;
  }
}