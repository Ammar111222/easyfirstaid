
import 'package:flutter/material.dart';

String formatLastUpdate(DateTime? lastUpdate) {
  if (lastUpdate == null) {
    return 'No updates yet';
  }

  // Calculate time difference
  Duration difference = DateTime.now().difference(lastUpdate);

  if (difference.inMinutes < 1) {
    return 'Just now';
  } else if (difference.inHours < 1) {
    return '${difference.inMinutes} minutes ago';
  } else if (difference.inDays < 1) {
    return '${difference.inHours} hours ago';
  } else {
    return '${difference.inDays} days ago';
  }
}

String formatDateTime(DateTime dateTime) {
  return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
}
