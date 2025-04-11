import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class Tokenservices {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Method to store device token in Firestore
  Future<void> storeDeviceToken() async {
    User? user = _auth.currentUser;
    if (user != null) {
      // Get the device token
      String? deviceToken = await FirebaseMessaging.instance.getToken();

      if (deviceToken != null) {
        // Reference to the user's document in Firestore
        DocumentReference userDoc =
            _firestore.collection('users').doc(user.uid);

        // Use set with merge option to create or update the document
        await userDoc.set({
          'deviceToken': deviceToken,
          'email': user.email,

          // You can add more user data here
        }, SetOptions(merge: true)).then((_) {
          print("Device token updated successfully");
        }).catchError((error) {
          print("Failed to update device token: $error");
        });
      } else {
        print("Failed to get device token");
      }
    } else {
      print("No user is currently signed in");
    }
  }
}
