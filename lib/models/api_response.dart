// lib/models/api_response.dart
class ApiResponse {
  final bool success;
  final String message;
  final Map<String, dynamic> data;
  final Map<String, dynamic>? errors;

  ApiResponse({
    required this.success,
    required this.message,
    this.data = const {},
    this.errors,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json is Map<String, dynamic> ? json : {},
      errors: json['errors'],
    );
  }
}