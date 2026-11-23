// lib/models/user.dart
import 'dart:convert';

class User {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String? cnic;
  final String? vehicleNumber;
  final String? vehicleType;
  final String? userType;
  final String? status;
  final String? availability;
  final double? latitude;
  final double? longitude;
  final DateTime? lastLocationUpdate;
  final String? fcmToken;
  final String? profilePhoto;
  final String? address;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.cnic,
    this.vehicleNumber,
    this.vehicleType,
    this.userType,
    this.status,
    this.availability,
    this.latitude,
    this.longitude,
    this.lastLocationUpdate,
    this.fcmToken,
    this.profilePhoto,
    this.address,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      cnic: json['cnic'],
      vehicleNumber: json['vehicle_number'],
      vehicleType: json['vehicle_type'],
      userType: json['user_type'],
      status: json['status'],
      availability: json['availability'],
      latitude: json['latitude'] != null ? double.parse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.parse(json['longitude'].toString()) : null,
      lastLocationUpdate: json['last_location_update'] != null
          ? DateTime.parse(json['last_location_update'])
          : null,
      fcmToken: json['fcm_token'],
      profilePhoto: json['profile_photo'],
      address: json['address'],
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null || value.toString().isEmpty) return DateTime.now();
    try {
      String dateStr = value.toString();
      if (!dateStr.contains('T') && dateStr.contains(' ')) {
        dateStr = dateStr.replaceFirst(' ', 'T');
      }
      return DateTime.tryParse(dateStr) ?? DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'cnic': cnic,
      'vehicle_number': vehicleNumber,
      'vehicle_type': vehicleType,
      'user_type': userType,
      'status': status,
      'availability': availability,
      'latitude': latitude,
      'longitude': longitude,
      'last_location_update': lastLocationUpdate?.toIso8601String(),
      'fcm_token': fcmToken,
      'profile_photo': profilePhoto,
      'address': address,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? cnic,
    String? vehicleNumber,
    String? vehicleType,
    String? userType,
    String? status,
    String? availability,
    double? latitude,
    double? longitude,
    DateTime? lastLocationUpdate,
    String? fcmToken,
    String? profilePhoto,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      cnic: cnic ?? this.cnic,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      userType: userType ?? this.userType,
      status: status ?? this.status,
      availability: availability ?? this.availability,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      fcmToken: fcmToken ?? this.fcmToken,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}