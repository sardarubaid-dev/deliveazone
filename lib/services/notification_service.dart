import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:deliveazone_driver_app/services/api_service.dart';
import 'package:deliveazone_driver_app/models/parcel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    if (kDebugMode) print('Background handler Firebase error: $e');
  }
}

class NotificationService {
  static NotificationService? _instance;
  
  // Lazy getter for the singleton instance
  static NotificationService get instance {
    _instance ??= NotificationService._internal();
    return _instance!;
  }

  // Factory constructor for backward compatibility
  factory NotificationService() => instance;
  
  NotificationService._internal();

  FirebaseMessaging? _fcm;
  FlutterLocalNotificationsPlugin? _localNotifications;
  final ApiService _apiService = ApiService();
  bool _isInitialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (_isInitialized && _navigatorKey != null) return;
    if (navigatorKey != null) _navigatorKey = navigatorKey;

    try {
      // Check if Firebase is available
      if (Firebase.apps.isEmpty) {
        if (kDebugMode) print('NotificationService: Firebase not initialized. Skipping FCM setup.');
        _isInitialized = true; 
        return;
      }

      _fcm = FirebaseMessaging.instance;
      _localNotifications = FlutterLocalNotificationsPlugin();

      // Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permission
      NotificationSettings settings = await _fcm!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) print('User granted permission');
        
        // Get the token
        String? token = await _fcm?.getToken();
        if (token != null) {
          if (kDebugMode) print('FCM Token: $token');
          await _apiService.registerFcmToken(token);
        }

        // Initialize local notifications
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('launcher_icon');
        
        const InitializationSettings initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
        );

        await _localNotifications?.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: (NotificationResponse response) async {
             if (response.payload != null) {
               _handlePayloadNavigation(response.payload!);
             }
          }
        );

        // Create the channel on the device (Android 8.0+)
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'deliveazone_high_importance', // id
          'High Importance Notifications', // title
          description: 'This channel is used for important order updates.', // description
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );

        await _localNotifications
            ?.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          _showLocalNotification(message);
        });

        // Handle notification clicks when app is in background
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          _handleNotificationClick(message);
        });

        // Handle notification clicks when app is terminated
        RemoteMessage? initialMessage = await _fcm?.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationClick(initialMessage);
        }

        _isInitialized = true;
      }
    } catch (e) {
      if (kDebugMode) print('NotificationService: Failed to initialize: $e');
    }
  }

  void _handleNotificationClick(RemoteMessage message) {
    if (kDebugMode) print('Notification clicked: ${message.data}');
    _handlePayloadNavigation(jsonEncode(message.data), dataMap: message.data);
  }

  void _handlePayloadNavigation(String payload, {Map<String, dynamic>? dataMap}) async {
    try {
      Map<String, dynamic> data = dataMap ?? {};
      
      if (dataMap == null) {
        try {
          data = jsonDecode(payload);
        } catch (e) {
          if (kDebugMode) print('Payload is not valid JSON, skipping navigation');
          return;
        }
      }

      final parcelId = data['parcel_id'] ?? data['id'];
      
      if (parcelId != null && _navigatorKey?.currentState != null) {
        final result = await _apiService.getAssignedParcels();
        if (result.success) {
          final List<dynamic> parcelsData = result.data['orders'] ?? [];
          final parcels = parcelsData.map((p) => Parcel.fromJson(p)).toList();
          
          final parcel = parcels.firstWhere(
            (p) => p.id.toString() == parcelId.toString(), 
            orElse: () => throw 'Parcel not found'
          );

          _navigatorKey!.currentState!.pushNamed(
            '/parcel-detail',
            arguments: parcel,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error in payload navigation: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    if (_localNotifications == null) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'deliveazone_high_importance', 
      'High Importance Notifications', 
      channelDescription: 'Notifications for important updates',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications?.show(
      message.hashCode, 
      message.notification?.title,
      message.notification?.body,
      platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  }

  // Placeholder methods for backward compatibility with polling architecture
  void startPolling() {
    if (kDebugMode) print('Notification polling started (FCM mode)');
  }

  void stopPolling() {
    if (kDebugMode) print('Notification polling stopped');
  }
}
