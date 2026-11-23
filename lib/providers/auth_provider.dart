import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deliveazone_driver_app/models/user.dart';
import 'package:deliveazone_driver_app/services/api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;

  AuthProvider() {
    _loadUserData();
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final api = ApiService();
      final result = await api.login(email, password);

      if (result.success) {
        _user = User.fromJson(result.data['user']);
        _isLoggedIn = true;
        await _saveUserData();

        // Register FCM Token
        try {
          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await api.registerFcmToken(fcmToken);
          }
        } catch (e) {
          if (kDebugMode) print('Failed to register FCM token after login: $e');
        }

        // Update availability to online
        await api.updateAvailability('online');
      } else {
        _error = result.message;
        _isLoggedIn = false;
      }
    } catch (e) {
      _error = 'Network error. Please check your connection.';
      _isLoggedIn = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_data');
    final token = prefs.getString('token');

    print('DEBUG: _loadUserData: token=$token');
    print('DEBUG: _loadUserData: userJson=$userJson');

    if (userJson != null && token != null) {
      try {
        _user = User.fromJson(json.decode(userJson));
        print('DEBUG: Logged in User ID: ${_user?.id}');
        print('DEBUG: Logged in User Name: ${_user?.name}');
        _isLoggedIn = true;
        notifyListeners();
      } catch (e) {
        print('DEBUG: Error parsing user data: $e');
        await logout();
      }
    } else {
       print('DEBUG: No user data or token found');
    }
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (_user != null) {
      await prefs.setString('user_data', json.encode(_user!.toJson()));
    }
  }

  Future<void> logout() async {
    print('AuthProvider: Starting logout...');
    
    // Clear API token first
    try {
      final api = ApiService();
      await api.logout().timeout(const Duration(seconds: 5));
      print('AuthProvider: API logout successful');
    } catch (e) {
      print('AuthProvider: Logout API failed: $e');
    }

    // Clear ALL local data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    await prefs.remove('token');
    await prefs.remove('is_tracking');
    await prefs.remove('cached_parcels');
    await prefs.remove('cached_history');
    await prefs.remove('last_location');
    await prefs.remove('fcm_token');
    
    print('AuthProvider: All local data cleared');

    // Reset state
    _user = null;
    _isLoggedIn = false;
    _error = null;
    _isLoading = false;
    
    print('AuthProvider: State reset, isLoggedIn=$_isLoggedIn');
    notifyListeners();
  }

  Future<bool> deactivateProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final api = ApiService();
      final response = await api.deactivateProfile();
      
      if (response.success) {
        // Clear all local data and log out
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_data');
        await prefs.remove('token');
        await prefs.remove('is_tracking');
        await prefs.remove('cached_parcels');
        await prefs.remove('cached_history');
        await prefs.remove('last_location');
        await prefs.remove('fcm_token');

        _user = null;
        _isLoggedIn = false;
        _error = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to deactivate profile: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data, {String? profileImagePath}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final api = ApiService();
      final result = await api.updateProfile(data, profileImagePath: profileImagePath);

      if (result.success) {
        // Update user data
        if (_user != null) {
          // If API returns updated user object, verify and use it. 
          // Assuming API returns updated user in 'user' key like login
          if (result.data is Map && result.data.containsKey('user')) {
             _user = User.fromJson(result.data['user']);
          } else {
             // Fallback manual update if API doesn't return user
              _user = _user!.copyWith(
                name: data['name'] ?? _user!.name,
                phone: data['phone'] ?? _user!.phone,
                vehicleNumber: data['vehicle_number'] ?? _user!.vehicleNumber,
                vehicleType: data['vehicle_type'] ?? _user!.vehicleType,
                cnic: data['cnic'] ?? _user!.cnic,
                address: data['address'] ?? _user!.address,
                // Profile photo URL usually comes from backend in result.data or we need to refresh profile
              );
              // Ideally refetch profile here to get new photo URL
              await refreshUserData();
          }
          await _saveUserData();
        }
        return true;
      } else {
        _error = result.message;
        return false;
      }
    } catch (e) {
      _error = 'Failed to update profile: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword(
      String currentPassword,
      String newPassword,
      String confirmPassword,
      ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final api = ApiService();
      final result = await api.changePassword(
        currentPassword,
        newPassword,
        confirmPassword,
      );

      if (result.success) {
        return true;
      } else {
        _error = result.message;
        return false;
      }
    } catch (e) {
      _error = 'Failed to change password';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> forgotPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final api = ApiService();
      final result = await api.forgotPassword(email);

      if (result.success) {
        return true;
      } else {
        _error = result.message;
        return false;
      }
    } catch (e) {
      _error = 'Failed to send OTP';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email, String otp, String password, String confirmPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final api = ApiService();
      final result = await api.resetPassword(email, otp, password, confirmPassword);

      if (result.success) {
        return true;
      } else {
        _error = result.message;
        return false;
      }
    } catch (e) {
      _error = 'Failed to reset password';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateAvailability(String availability) async {
    try {
      final api = ApiService();
      final result = await api.updateAvailability(availability);

      if (result.success && _user != null) {
        _user = _user!.copyWith(availability: availability);
        await _saveUserData();
        notifyListeners();
      }
    } catch (e) {
      print('Failed to update availability: $e');
    }
  }

  Future<void> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _isLoggedIn = false;
    } else {
      try {
        // Verify token by making a simple API call
        final api = ApiService();
        final result = await api.getProfile();
        _isLoggedIn = result.success;
      } catch (e) {
        _isLoggedIn = false;
      }
    }
    notifyListeners();
  }

  Future<void> refreshUserData({bool showLoading = true}) async {
    try {
      final api = ApiService();
      final result = await api.getProfile();

      if (result.success) {
        _user = User.fromJson(result.data['user']);
        await _saveUserData();
        notifyListeners();
      }
    } catch (e) {
      print('Failed to refresh user data: $e');
    }
  }
}