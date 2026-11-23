import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:deliveazone_driver_app/models/api_response.dart';
import 'package:deliveazone_driver_app/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  String? _token;
  final String baseUrl = ApiConstants.baseUrl;

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  Future<ApiResponse> _handleResponse(http.Response response) async {
    try {
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        // Assume success if status is 200/201, unless explicitly false in the map
        bool success = true;
        if (data is Map && data.containsKey('success')) {
          success = data['success'] ?? false;
        }
        return ApiResponse(
          success: success,
          message: data is Map ? (data['message'] ?? '') : '',
          data: data,
        );
      } else if (response.statusCode == 401) {
        // Token expired or invalid credentials
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        await prefs.remove('user_data');
        String errorMessage = 'Invalid credentials or session expired.';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {}
        return ApiResponse(
          success: false,
          message: errorMessage,
        );
      } else if (response.statusCode == 422) {
        // Validation error
        final errorData = json.decode(response.body);
        String errorMessage = errorData['message'] ?? 'Validation failed';
        
        // Extract first validation error if available
        if (errorData['errors'] != null && errorData['errors'] is Map) {
          final errors = errorData['errors'] as Map;
          if (errors.isNotEmpty) {
            final firstError = errors.values.first;
            if (firstError is List && firstError.isNotEmpty) {
              errorMessage = firstError.first.toString();
            }
          }
        }
        
        return ApiResponse(
          success: false,
          message: errorMessage,
          errors: errorData['errors'],
        );
      } else {
        final errorData = json.decode(response.body);
        return ApiResponse(
          success: false,
          message: errorData['message'] ?? 'Something went wrong',
          errors: errorData['errors'],
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Invalid server response',
      );
    }
  }

  Future<ApiResponse> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        body: {
          'email': email,
          'password': password,
        },
      ).timeout(const Duration(seconds: 30));

      final result = await _handleResponse(response);
      if (result.success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', result.data['token']);
        _token = result.data['token'];
      }
      return result;
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Connection error. Please check your internet.',
      );
    }
  }

  Future<ApiResponse> getAssignedParcels() async {
    await _loadToken();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders/assigned'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      return await _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to load parcels',
      );
    }
  }

  Future<ApiResponse> getParcelHistory({int page = 1}) async {
    await _loadToken();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders/history?page=$page'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      return await _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to load history',
      );
    }
  }

  Future<ApiResponse> scanParcel(String qrCode) async {
    await _loadToken();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/orders/scan'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
        body: {'qr_code': qrCode},
      ).timeout(const Duration(seconds: 30));

      return await _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Scan failed. Please try again.',
      );
    }
  }

  Future<ApiResponse> manualPickup(int parcelId) async {
    await _loadToken();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/orders/$parcelId/manual-pickup'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      return await _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Manual pickup failed. Please try again.',
      );
    }
  }

  Future<ApiResponse> updateParcelStatus(
      int parcelId,
      String status, {
        String? remarks,
        String? proofImage,
        String? otp,
        String? acceptedBy,
        String? receiverName,
        String? signature,
        double? lat,
        double? lng,
        String? paymentMethod,
        String? rescheduledDate,
      }) async {
    await _loadToken();

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/orders/$parcelId/update-status'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $_token',
        'Accept': 'application/json',
      });

      request.fields['status'] = status;
      if (remarks != null) request.fields['remarks'] = remarks;
      if (otp != null) request.fields['otp'] = otp;
      if (acceptedBy != null) request.fields['accepted_by'] = acceptedBy;
      if (receiverName != null) request.fields['receiver_name'] = receiverName;
      if (signature != null) request.fields['signature'] = signature;
      if (paymentMethod != null) request.fields['payment_method'] = paymentMethod;
      if (rescheduledDate != null) request.fields['rescheduled_date'] = rescheduledDate;
      if (lat != null) request.fields['delivery_latitude'] = lat.toString();
      if (lng != null) request.fields['delivery_longitude'] = lng.toString();

      if (proofImage != null && proofImage.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('proof_image', proofImage),
        );
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      final statusCode = streamedResponse.statusCode;
      final response = http.Response(responseBody, statusCode);
      
      return await _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to update status: $e',
      );
    }
  }

  // REAL-TIME LOCATION TRACKING WITH MYSQL
  Future<ApiResponse> updateLocation(double lat, double lng) async {
    await _loadToken();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/update-location'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
        body: {
          'latitude': lat.toString(),
          'longitude': lng.toString(),
        },
      ).timeout(const Duration(seconds: 10));

      return await _handleResponse(response);
    } catch (e) {
      // Don't throw error for location updates - just log in debug mode
      if (kDebugMode) print('Location update failed: $e');
      return ApiResponse(
        success: false,
        message: 'Location update failed',
      );
    }
  }

  Future<ApiResponse> updateAvailability(String availability) async {
    await _loadToken();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/update-availability'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
        body: {
          'availability': availability,
        },
      ).timeout(const Duration(seconds: 10));

      return await _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to update availability',
      );
    }
  }

  Future<ApiResponse> getProfile() async {
    await _loadToken();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/profile'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      return await _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to load profile',
      );
    }
  }

  Future<ApiResponse> updateProfile(Map<String, dynamic> data, {String? profileImagePath}) async {
    await _loadToken();

    try {
      var request = http.MultipartRequest(
        'POST', // Using POST with _method=PUT or just POST for profile update with file
        Uri.parse('$baseUrl/api/update-profile'),
      );

      request.headers['Authorization'] = 'Bearer $_token';
      request.headers['Accept'] = 'application/json';

      // Add fields
      data.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });

      // Add file if exists
      if (profileImagePath != null && profileImagePath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('profile_photo', profileImagePath),
        );
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      final statusCode = streamedResponse.statusCode;
      final response = http.Response(responseBody, statusCode);

      return await _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to update profile: $e',
      );
    }
  }

  Future<ApiResponse> changePassword(
      String currentPassword,
      String newPassword,
      String confirmPassword,
      ) async {
    await _loadToken();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/change-password'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'new_password_confirmation': confirmPassword,
        },
      ).timeout(const Duration(seconds: 30));

      return await _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to change password',
      );
    }
  }

  Future<ApiResponse> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/forgot-password'),
        body: {'email': email},
      ).timeout(const Duration(seconds: 30));

      return await _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to send OTP. Please check your internet.',
      );
    }
  }

  Future<ApiResponse> resetPassword(String email, String otp, String password, String confirmPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/reset-password'),
        body: {
          'email': email,
          'otp': otp,
          'password': password,
          'password_confirmation': confirmPassword,
        },
      ).timeout(const Duration(seconds: 30));

      return await _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to reset password. Please check your internet.',
      );
    }
  }

  Future<ApiResponse> logout() async {
    await _loadToken();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/logout'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      return await _handleResponse(response);
    } catch (e) {
      // Even if logout API fails, clear local data
      return ApiResponse(
        success: true,
        message: 'Logged out',
      );
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user_data');
      await prefs.remove('cached_parcels');
      _token = null;
    }
  }

  Future<ApiResponse> deactivateProfile() async {
    await _loadToken();
  
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/deactivate-profile'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
  
      final apiResponse = await _handleResponse(response);
      
      // If successful, clear local data same as logout
      if (apiResponse.success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        await prefs.remove('user_data');
        await prefs.remove('cached_parcels');
        _token = null;
      }
      
      return apiResponse;
    } catch (e) {
      return ApiResponse(
        success: false,
        message: e.toString(),
      );
    }
  }

  Future<ApiResponse> uploadProofImage(int parcelId, String imagePath) async {
    await _loadToken();

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/orders/$parcelId/upload-proof'),
      );

      request.headers['Authorization'] = 'Bearer $_token';
      request.files.add(
        await http.MultipartFile.fromPath(
          'proof_image',
          imagePath,
        ),
      );

      final response = await request.send();
      final responseStr = await response.stream.bytesToString();
      final responseData = json.decode(responseStr);

      return ApiResponse(
        success: responseData['success'] ?? false,
        message: responseData['message'] ?? '',
        data: responseData,
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to upload image',
      );
    }
  }

  Future<ApiResponse> getParcelTracking(int parcelId) async {
    await _loadToken();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders/$parcelId/tracking'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      return await _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to load tracking data',
      );
    }
  }

  Future<ApiResponse> registerFcmToken(String fcmToken) async {
    await _loadToken();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/notifications/register-fcm'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
        body: {'fcm_token': fcmToken},
      ).timeout(const Duration(seconds: 30));

      return await _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to register notification token',
      );
    }
  }

  Future<ApiResponse> getNotifications() async {
    await _loadToken();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/notifications'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      return await _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to load notifications',
      );
    }
  }

  Future<ApiResponse> markNotificationAsRead(String notificationId) async {
    await _loadToken();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/notifications/$notificationId/mark-read'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      return await _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to mark notification as read',
      );
    }
  }

  Future<ApiResponse> getEarningsReport(DateTime startDate, DateTime endDate) async {
    await _loadToken();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/earnings-report?'
            'start_date=${startDate.toIso8601String()}&'
            'end_date=${endDate.toIso8601String()}'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      return await _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to load earnings report',
      );
    }
  }

  Future<ApiResponse> getStatistics() async {
    await _loadToken();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/driver/statistics'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      return await _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to load statistics',
      );
    }
  }
}