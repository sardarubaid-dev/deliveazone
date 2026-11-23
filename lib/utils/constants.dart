import 'dart:ui';

import 'package:flutter/material.dart';

class ApiConstants {
  static const String baseUrl = "https://app.deliveazone.com";
  // Auth Endpoints
  static const String login = '$baseUrl/api/login';
  static const String logout = '$baseUrl/api/logout';
  static const String deactivateProfile = '$baseUrl/api/deactivate-profile';
  static const String profile = '$baseUrl/api/profile';
  static const String updateProfile = '$baseUrl/api/update-profile';
  static const String changePassword = '$baseUrl/api/change-password';
  static const String updateAvailability = '$baseUrl/api/update-availability';

  // Location Endpoints
  static const String updateLocation = '$baseUrl/api/update-location';
  static const String locationHistory = '$baseUrl/api/location/history';
  static const String routeInfo = '$baseUrl/api/route-info';

  // Parcel Endpoints
  // Parcel/Order Endpoints
  static const String assignedParcels = '$baseUrl/api/orders/assigned';
  static const String parcelHistory = '$baseUrl/api/orders/history';
  static const String scanParcel = '$baseUrl/api/orders/scan';
  static const String updateParcelStatus = '$baseUrl/api/orders';
  static const String uploadProof = '$baseUrl/api/orders';
  static const String parcelTracking = '$baseUrl/api/orders';
  static const String qrCode = '$baseUrl/api/orders';

  // Notification Endpoints
  static const String notifications = '$baseUrl/api/notifications';
  static const String markNotificationRead = '$baseUrl/api/notifications';
  static const String registerFcm = '$baseUrl/api/notifications/register-fcm';

  // Report Endpoints
  static const String dailyReport = '$baseUrl/api/reports/daily';
  static const String weeklyReport = '$baseUrl/api/reports/weekly';
  static const String monthlyReport = '$baseUrl/api/reports/monthly';
  static const String earningsReport = '$baseUrl/api/reports/earnings';
  static const String driverStatistics = '$baseUrl/api/driver/statistics';

  // Support Endpoints
  static const String createTicket = '$baseUrl/api/support/ticket';
  static const String getTickets = '$baseUrl/api/support/tickets';

  // App Config
  static const String appVersion = '$baseUrl/api/app/version';
  static const String appConfig = '$baseUrl/api/app/config';
}

class StorageKeys {
  static const String token = 'token';
  static const String userData = 'user_data';
  static const String cachedParcels = 'cached_parcels';
  static const String cachedHistory = 'cached_history';
  static const String isTracking = 'is_tracking';
  static const String lastLocation = 'last_location';
  static const String appConfig = 'app_config';
  static const String notificationsEnabled = 'notifications_enabled';
  static const String fcmToken = 'fcm_token';
  static const String language = 'language';
  static const String theme = 'theme';
}

class AppConstants {
  static const String appName = 'DeliveaZone Driver';
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'support@deliveazone.com';
  static const String supportPhone = '+1234567890';
  static const String privacyPolicyUrl = 'https://deliveazone.com/privacy';
  static const String termsUrl = 'https://deliveazone.com/terms';

  // Location Settings
  static const double mapDefaultZoom = 15.0;
  static const Duration locationUpdateInterval = Duration(seconds: 15);
  static const Duration backgroundLocationInterval = Duration(minutes: 5);
  static const Duration apiTimeout = Duration(seconds: 30);
  static const int maxLocationHistory = 100;

  // Delivery Settings
  static const List<String> statusFlow = [
    'assigned',
    'picked_up',
    'in_transit',
    'delivered'
  ];

  static const Map<String, String> statusLabels = {
    'pending': 'Pending',
    'assigned': 'Assigned',
    'picked_up': 'Picked Up',
    'in_transit': 'In Transit',
    'delivered': 'Delivered',
    'failed': 'Failed',
    'returned': 'Returned',
    'rescheduled': 'Rescheduled',
  };

  static const Map<String, Color> statusColors = {
    'pending': Colors.orange,
    'assigned': Colors.blue,
    'picked_up': Colors.indigo,
    'in_transit': Colors.purple,
    'delivered': Colors.green,
    'failed': Colors.red,
    'returned': Colors.grey,
    'rescheduled': Colors.orange,
  };

  // Design Constants
  static const double defaultPadding = 16.0;
  static const double cardRadius = 12.0;
  static const double buttonRadius = 8.0;
  static const Duration animationDuration = Duration(milliseconds: 300);
}