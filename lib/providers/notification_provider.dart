// lib/providers/notification_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deliveazone_driver_app/services/api_service.dart';
import 'package:deliveazone_driver_app/services/notification_service.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['data']?['title'] ?? json['title'] ?? 'Notification', // Fallback to data.title if available
      message: json['data']?['message'] ?? json['message'] ?? '', // Fallback to data.message
      type: json['data']?['type'] ?? json['type'] ?? 'general',
      isRead: json['read_at'] != null || (json['is_read'] ?? false), // Handle Laravel's read_at or generic is_read
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      data: json['data'] is Map<String, dynamic> ? json['data'] : (json['data'] is String ? {'value': json['data']} : {}),
    );
  }
}

class NotificationProvider with ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;
  bool _notificationsEnabled = true;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;
  bool get hasUnread => _unreadCount > 0;
  bool get notificationsEnabled => _notificationsEnabled;

  late final NotificationService _notificationService;
  late final ApiService _apiService;

  NotificationProvider() {
    _notificationService = NotificationService();
    _apiService = ApiService();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    
    await _notificationService.initialize();
    
    if (_notificationsEnabled) {
      _notificationService.startPolling();
    }
    notifyListeners();
  }

  Future<void> toggleNotifications(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    
    if (value) {
      _notificationService.startPolling();
    } else {
      _notificationService.stopPolling();
    }
    notifyListeners();
  }

  Future<void> loadNotifications({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final result = await _apiService.getNotifications();

      if (result.success) {
        final List<dynamic> data = result.data['notifications'] ?? [];
        _notifications = data
            .map((json) => NotificationModel.fromJson(json))
            .toList();
        
        // Sort by date, newest first
        _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        // Count unread
        _unreadCount = _notifications.where((n) => !n.isRead).length;
      } else {
        _error = result.message;
      }
    } catch (e) {
      _error = 'Failed to load notifications';
      print('NotificationProvider: Error loading notifications: $e');
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final result = await _apiService.markNotificationAsRead(notificationId);

      if (result.success) {
        // Update local state
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          final notification = _notifications[index];
          _notifications[index] = NotificationModel(
            id: notification.id,
            title: notification.title,
            message: notification.message,
            type: notification.type,
            isRead: true,
            createdAt: notification.createdAt,
            data: notification.data,
          );
          _unreadCount = _notifications.where((n) => !n.isRead).length;
          notifyListeners();
        }
      }
    } catch (e) {
      print('NotificationProvider: Error marking as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      // Mark all locally first for immediate UI update
      _notifications = _notifications.map((n) => NotificationModel(
        id: n.id,
        title: n.title,
        message: n.message,
        type: n.type,
        isRead: true,
        createdAt: n.createdAt,
        data: n.data,
      )).toList();
      _unreadCount = 0;
      notifyListeners();

      // Then mark on server
      for (var notification in _notifications) {
        await _apiService.markNotificationAsRead(notification.id);
      }
    } catch (e) {
      print('NotificationProvider: Error marking all as read: $e');
    }
  }

  void startPolling() {
    _notificationService.startPolling();
  }

  void stopPolling() {
    _notificationService.stopPolling();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
