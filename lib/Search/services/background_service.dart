import 'dart:async';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../search_fall_detection_service.dart';
import '../search_notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  late SearchFallDetectionService _fallDetectionService;
  late SearchNotificationService _notificationService;
  bool _isServiceRunning = false;

  Future<void> initialize() async {
    if (_isServiceRunning) return;

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'fall_detection_channel',
        initialNotificationTitle: 'Fall Detection Active',
        initialNotificationContent: 'Monitoring for falls',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    _isServiceRunning = true;
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Initialize services
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    final notificationService = SearchNotificationService(
      auth: auth,
      firestore: firestore,
      fcm: FirebaseMessaging.instance,
      onChildTap: (data) {}, );

    final fallDetectionService = SearchFallDetectionService(
      auth: auth,
      firestore: firestore,
      notificationService: notificationService,
    );

    // Start fall detection
    fallDetectionService.startFallDetection();

    // Keep the service running
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: "Fall Detection Active",
            content: "Monitoring for falls",
          );
        }
      }
    });
  }
} 